#!/usr/bin/env python3
"""Walk Claude Code + Cowork sessions into out/inventory.json.

Per-session row carries summary fields, per-model token totals, automation flag,
and a structured condensate (for Haiku subagents). Redaction applied to every
piece of text that leaves the transcript.

Default window: last 6 months. Override with --since / --until / --all.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable, Iterator

sys.path.insert(0, str(Path(__file__).parent))
import codex_sessions  # noqa: E402
from host_platform import ANTIGRAVITY, CODEX, degrade, detect_platform  # noqa: E402

HOME = Path.home()
CODE_ROOT = HOME / ".claude" / "projects"

# Cowork desktop app stores sessions in the OS-native app-data dir.
# macOS:   ~/Library/Application Support/Claude/local-agent-mode-sessions
# Windows: %APPDATA%\Claude\local-agent-mode-sessions
# Linux:   not applicable, Cowork is desktop-only (Mac/Windows).
def _cowork_root() -> Path:
    if sys.platform == "darwin":
        return HOME / "Library" / "Application Support" / "Claude" / "local-agent-mode-sessions"
    if sys.platform.startswith("win"):
        import os
        return Path(os.environ.get("APPDATA", HOME)) / "Claude" / "local-agent-mode-sessions"
    return HOME / ".config" / "Claude" / "local-agent-mode-sessions"  # fallback, unused on Linux
COWORK_ROOT = _cowork_root()

TASK_NOTIF_RE = re.compile(r"<task-notification>.*?</task-notification>", re.DOTALL)
COMMAND_WRAPPER_RE = re.compile(r"<command-(?:name|message|args)>.*?</command-\w+>", re.DOTALL)
LOCAL_COMMAND_CAVEAT_RE = re.compile(r"<local-command-caveat>.*?</local-command-caveat>", re.DOTALL)
AUTOMATION_SLASH_CMDS = {
    "/loop",
    "/schedule",
    "/babysit-prs",
    "/ultrareview",
    "/autonomous-loop",
    "/productivity:update",
    "/productivity:start",
}

CORRECTION_PHRASES = [
    r"\bno\b", r"\bnot quite\b", r"\bthat'?s wrong\b", r"\bthat is wrong\b",
    r"\bactually\b", r"\bwait\b", r"\bstop\b", r"\bdon'?t\b",
    r"\bno I meant\b", r"\blet me rephrase\b", r"\bthat'?s not what I\b",
    r"\bredo\b", r"\btry again\b", r"\bdifferent approach\b",
    r"\bsimpler\b", r"\bshorter\b", r"\blonger\b",
    r"\balso\b", r"\band also\b", r"\bone more thing\b",
    r"\byou forgot\b", r"\byou missed\b", r"\bmissing\b",
    r"\byou didn'?t\b", r"\bthis isn'?t\b", r"\bthat'?s not right\b",
    r"\bhold on\b", r"\bnevermind\b", r"\bscrap\b",
]
CORRECTION_RE = re.compile("|".join(CORRECTION_PHRASES), re.IGNORECASE)


# ---------- redaction ----------

REDACTIONS: list[tuple[re.Pattern, str]] = [
    (re.compile(r"-----BEGIN [A-Z ]+ PRIVATE KEY-----[\s\S]*?-----END [A-Z ]+ PRIVATE KEY-----"), "[REDACTED:private_key]"),
    (re.compile(r"eyJ[A-Za-z0-9_\-]+\.eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+"), "[REDACTED:jwt]"),
    (re.compile(r"sk-[A-Za-z0-9\-_]{20,}"), "[REDACTED:api_key]"),
    (re.compile(r"ghp_[A-Za-z0-9]{30,}"), "[REDACTED:token]"),
    (re.compile(r"ghs_[A-Za-z0-9]{30,}"), "[REDACTED:token]"),
    (re.compile(r"github_pat_[A-Za-z0-9_]{20,}"), "[REDACTED:token]"),
    (re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"), "[REDACTED:token]"),
    (re.compile(r"AIza[A-Za-z0-9\-_]{30,}"), "[REDACTED:api_key]"),
    (re.compile(r"AKIA[A-Z0-9]{16}"), "[REDACTED:api_key]"),
    (re.compile(r"\b[A-Z]{2}\d{2}[A-Z0-9]{10,30}\b"), "[REDACTED:iban]"),
]
KEY_VALUE_RE = re.compile(
    r"(?i)(password|passwd|pwd|secret|api[_-]?key|bearer)\s*[:=]\s*['\"]?([^\s'\"]{6,})['\"]?"
)
EMAIL_RE = re.compile(r"([A-Za-z0-9._%+\-]+)@([A-Za-z0-9.\-]+\.[A-Za-z]{2,})")
PHONE_CONTEXT_RE = re.compile(
    r"(?i)(phone|tel|call|mobile|sms|whatsapp)[^\n]{0,20}?(\+?\d[\d\s\-().]{7,}\d)"
)


def _luhn_ok(s: str) -> bool:
    digits = [int(c) for c in s if c.isdigit()]
    if not 13 <= len(digits) <= 19:
        return False
    total = 0
    for i, d in enumerate(reversed(digits)):
        if i % 2 == 1:
            d *= 2
            if d > 9:
                d -= 9
        total += d
    return total % 10 == 0


CARD_RE = re.compile(r"\b(?:\d[ -]?){13,19}\b")


def redact(text: str) -> str:
    if not text:
        return text
    for pat, repl in REDACTIONS:
        text = pat.sub(repl, text)
    text = KEY_VALUE_RE.sub(lambda m: f"{m.group(1)}=[REDACTED:token]", text)

    text = EMAIL_RE.sub(lambda m: f"[REDACTED:email]@{m.group(2)}", text)
    text = PHONE_CONTEXT_RE.sub(lambda m: f"{m.group(1)} [REDACTED:phone]", text)
    text = CARD_RE.sub(lambda m: "[REDACTED:card]" if _luhn_ok(m.group(0)) else m.group(0), text)
    return text


# ---------- transcript parsing ----------

def _text_of(entry: dict) -> str:
    msg = entry.get("message") or {}
    content = msg.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for c in content:
            if isinstance(c, dict) and c.get("type") == "text":
                txt = c.get("text") or ""
                if txt:
                    parts.append(txt)
        return "\n".join(parts)
    return ""


def _tool_calls(entry: dict) -> list[str]:
    msg = entry.get("message") or {}
    content = msg.get("content")
    names: list[str] = []
    if isinstance(content, list):
        for c in content:
            if isinstance(c, dict) and c.get("type") == "tool_use":
                n = c.get("name")
                if n:
                    names.append(n)
    return names


def _usage_of(entry: dict) -> tuple[str, dict] | None:
    msg = entry.get("message") or {}
    usage = msg.get("usage")
    if not isinstance(usage, dict):
        return None
    model = msg.get("model") or "unknown"
    return model, {
        "input": int(usage.get("input_tokens") or 0),
        "output": int(usage.get("output_tokens") or 0),
        "cache_read": int(usage.get("cache_read_input_tokens") or 0),
        "cache_creation": int(usage.get("cache_creation_input_tokens") or 0),
    }


def _strip_system_noise(text: str) -> str:
    # Cowork-specific: remove task-notification blocks entirely (user §7.1).
    text = TASK_NOTIF_RE.sub("", text)
    return text.strip()


def _is_only_wrappers(text: str) -> bool:
    """True if text is composed entirely of command-* / caveat wrappers plus whitespace."""
    stripped = COMMAND_WRAPPER_RE.sub("", text)
    stripped = LOCAL_COMMAND_CAVEAT_RE.sub("", stripped)
    return not stripped.strip()


def _extract_slash_cmd(text: str) -> str | None:
    m = re.search(r"<command-name>\s*(/\S+)\s*</command-name>", text)
    return m.group(1).strip() if m else None


def _load_turns(path: Path) -> list[dict]:
    """Return ordered list of text turns + tool calls + usage records."""
    turns: list[dict] = []
    try:
        with path.open(encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    e = json.loads(line)
                except json.JSONDecodeError:
                    continue
                t = e.get("type")
                ts = e.get("timestamp") or ""
                if t not in ("user", "assistant"):
                    continue
                raw_text = _text_of(e)
                stripped = _strip_system_noise(raw_text)
                entry: dict = {
                    "role": t,
                    "ts": ts,
                    "text": stripped,
                    "raw_has_content": bool(raw_text),
                    "is_only_wrappers": _is_only_wrappers(raw_text) if raw_text else True,
                    "tool_calls": _tool_calls(e),
                }
                usage = _usage_of(e)
                if usage:
                    entry["model"] = usage[0]
                    entry["usage"] = usage[1]
                turns.append(entry)
    except OSError:
        pass
    return turns


# ---------- automation detection ----------

def detect_automation(path: Path, first_entry_meta: dict, turns: list[dict], summary: str) -> tuple[bool, str]:
    p = str(path)
    entrypoint = first_entry_meta.get("entrypoint") or ""

    if entrypoint and entrypoint != "cli":
        return True, f"entrypoint:{entrypoint}"
    if "/agent/local_ditto_" in p or "/agent/local_routine_" in p:
        return True, "ditto-routine"
    if "--paperclip-instances-" in p:
        return True, "paperclip"

    # <scheduled-task> opener, Cowork schedule runs announce themselves this way.
    if turns:
        first_user = next((t for t in turns if t["role"] == "user"), None)
        if first_user and "<scheduled-task" in (first_user.get("text") or ""):
            m = re.search(r'name="([^"]+)"', first_user["text"])
            tag = m.group(1) if m else "unknown"
            return True, f"scheduled-task:{tag}"

    # Slash-command-only opener
    if turns:
        first_user = next((t for t in turns if t["role"] == "user"), None)
        if first_user and first_user["is_only_wrappers"]:
            cmd = _extract_slash_cmd(first_user.get("_raw_text") or "") or _extract_slash_cmd(
                first_user["text"]
            )
            if cmd and cmd in AUTOMATION_SLASH_CMDS:
                return True, f"slash-command-opener:{cmd}"

    # Composite: no freeform + short + recurring
    user_turns = [t for t in turns if t["role"] == "user"]
    assistant_turns = [t for t in turns if t["role"] == "assistant"]
    total_text_turns = len(user_turns) + len(assistant_turns)
    no_freeform = bool(user_turns) and all(t["is_only_wrappers"] or not t["text"] for t in user_turns)
    if no_freeform and total_text_turns < 6:
        duration_s = _duration(turns)
        if duration_s is not None and duration_s < 300:
            # Recurrence is checked at caller-level; leave caller to decide. For now:
            return True, "composite:short-no-freeform"

    return False, ""


def _duration(turns: list[dict]) -> float | None:
    stamps: list[float] = []
    for t in turns:
        ts = t.get("ts")
        if not ts:
            continue
        try:
            stamps.append(datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp())
        except ValueError:
            continue
    if len(stamps) < 2:
        return None
    return max(stamps) - min(stamps)


# ---------- condensate ----------

def _tool_flail_events(turns: list[dict]) -> list[tuple[int, list[str]]]:
    """Return up to one entry per tool that genuinely flails.

    Bar: ≥5 calls to the same tool within any 5-assistant-turn window, AND that
    tool represents ≥60% of tool calls in the window. This separates "working
    hard on files" (normal) from "stuck in a loop" (actual friction).

    Deduped by tool name so a persistent offender appears once.
    """
    assistant_idxs = [i for i, t in enumerate(turns) if t["role"] == "assistant"]
    first_seen: dict[str, int] = {}
    for i, idx in enumerate(assistant_idxs):
        window = assistant_idxs[max(0, i - 4) : i + 1]
        counts: dict[str, int] = {}
        for j in window:
            for name in turns[j]["tool_calls"]:
                counts[name] = counts.get(name, 0) + 1
        total_calls = sum(counts.values())
        if total_calls < 5:
            continue
        for name, c in counts.items():
            if c >= 5 and c / total_calls >= 0.6 and name not in first_seen:
                first_seen[name] = window[0]
    return sorted(((idx, [name]) for name, idx in first_seen.items()), key=lambda p: p[0])


def build_condensate(turns: list[dict]) -> dict:
    user_turns = [(i, t) for i, t in enumerate(turns) if t["role"] == "user" and t["text"]]
    first_3 = user_turns[:3]
    last_3 = user_turns[-3:]
    corrections = [(i, t) for i, t in user_turns if CORRECTION_RE.search(t["text"])]
    flail_events = _tool_flail_events(turns)
    final_assistant = None
    for i in range(len(turns) - 1, -1, -1):
        if turns[i]["role"] == "assistant" and turns[i]["text"]:
            final_assistant = (i, turns[i])
            break

    seen: set[int] = set()
    seen_text: set[str] = set()
    picks: list[dict] = []

    def add_text(i: int, t: dict, tag: str) -> None:
        if i in seen or not t["text"]:
            return
        # dedupe by leading 160 chars, Cowork sometimes re-posts the initial message
        key = t["text"][:160]
        if key in seen_text:
            return
        seen.add(i)
        seen_text.add(key)
        txt = t["text"]
        if len(txt) > 1200:
            txt = txt[:1200] + " …[trunc]"
        picks.append({"i": i, "role": t["role"], "ts": t.get("ts", ""), "tag": tag, "text": redact(txt)})

    def add_flail(i: int, tools: list[str]) -> None:
        picks.append(
            {
                "i": i,
                "role": "meta",
                "ts": turns[i].get("ts", "") if i < len(turns) else "",
                "tag": "tool-flail",
                "text": f"[tool-flail episode: {', '.join(sorted(tools))} called ≥3× within 10 assistant turns]",
            }
        )

    for i, t in first_3:
        add_text(i, t, "intent")
    # cap corrections at 10 to keep condensate lean
    for i, t in corrections[:10]:
        add_text(i, t, "correction")
    # cap flail events at 2, a strong signal rarely needs more
    for i, tools in flail_events[:2]:
        add_flail(i, tools)
    for i, t in last_3:
        add_text(i, t, "outcome")
    if final_assistant is not None:
        add_text(final_assistant[0], final_assistant[1], "final-assistant")

    picks.sort(key=lambda p: p["i"])
    return {
        "picks": picks,
        "correction_count": len(corrections),
        "tool_flail_events": len(flail_events),
    }


# ---------- token aggregation ----------

def aggregate_tokens(turns: list[dict]) -> dict:
    total = {"input": 0, "output": 0, "cache_read": 0, "cache_creation": 0}
    by_model: dict[str, dict] = {}
    for t in turns:
        usage = t.get("usage")
        if not usage:
            continue
        model = t.get("model") or "unknown"
        bm = by_model.setdefault(model, {"input": 0, "output": 0, "cache_read": 0, "cache_creation": 0})
        for k, v in usage.items():
            total[k] += v
            bm[k] += v
    return {**total, "by_model": by_model}


# ---------- session walking ----------

def _first_meta(path: Path) -> dict:
    """Scan early entries for entrypoint + cwd. First line may be metadata-only."""
    out = {"entrypoint": None, "cwd": None}
    try:
        with path.open(encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if i > 30 and out["cwd"] and out["entrypoint"]:
                    break
                try:
                    e = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if not out["entrypoint"] and isinstance(e.get("entrypoint"), str):
                    out["entrypoint"] = e["entrypoint"]
                if not out["cwd"] and isinstance(e.get("cwd"), str):
                    out["cwd"] = e["cwd"]
                if out["entrypoint"] and out["cwd"]:
                    break
    except OSError:
        pass
    return out


def _cowork_title(audit: Path) -> str:
    session_dir = audit.parent
    meta_file = session_dir.parent / f"{session_dir.name}.json"
    if not meta_file.is_file():
        return ""
    try:
        meta = json.loads(meta_file.read_text(encoding="utf-8", errors="replace"))
    except (json.JSONDecodeError, OSError):
        return ""
    return (meta.get("title") or meta.get("name") or (meta.get("initialMessage") or "")[:120] or "").strip()


def _candidates(since_ts: float | None, until_ts: float | None) -> Iterator[tuple[Path, str]]:
    if CODE_ROOT.is_dir():
        for project_dir in CODE_ROOT.iterdir():
            if not project_dir.is_dir():
                continue
            for jsonl in project_dir.glob("*.jsonl"):
                try:
                    mtime = jsonl.stat().st_mtime
                except OSError:
                    continue
                if since_ts is not None and mtime < since_ts:
                    continue
                if until_ts is not None and mtime > until_ts:
                    continue
                yield jsonl, "code"
    if COWORK_ROOT.is_dir():
        for audit in COWORK_ROOT.rglob("local_*/audit.jsonl"):
            if "skills-plugin" in audit.parts:
                continue
            try:
                mtime = audit.stat().st_mtime
            except OSError:
                continue
            if since_ts is not None and mtime < since_ts:
                continue
            if until_ts is not None and mtime > until_ts:
                continue
            yield audit, "cowork"


def process(path: Path, kind: str) -> dict | None:
    try:
        st = path.stat()
    except OSError:
        return None
    meta = _first_meta(path)
    turns = _load_turns(path)
    if not turns:
        return None

    # Extract first user message (raw text, ≤400 chars, redacted).
    first_user_msg = ""
    for t in turns:
        if t["role"] == "user" and t["text"]:
            first_user_msg = t["text"][:400]
            break
    first_user_msg = redact(first_user_msg)

    if kind == "cowork":
        summary = _cowork_title(path) or first_user_msg.splitlines()[0][:120] if first_user_msg else ""
    else:
        summary = first_user_msg.splitlines()[0][:120] if first_user_msg else ""

    is_auto, reason = detect_automation(path, meta, turns, summary)

    tokens = aggregate_tokens(turns)
    cond = build_condensate(turns) if not is_auto else {"picks": [], "correction_count": 0, "tool_flail_events": 0}

    return {
        "path": str(path),
        "kind": kind,
        "mtime": st.st_mtime,
        "cwd": meta.get("cwd") or "",
        "size": st.st_size,
        "entrypoint": meta.get("entrypoint") or "",
        "first_user_msg": first_user_msg,
        "summary": summary,
        "turns": sum(1 for t in turns if t["text"]),
        "user_correction_count": cond["correction_count"],
        "duration_s": _duration(turns),
        "is_automation": is_auto,
        "automation_reason": reason,
        "tokens": tokens,
        "condensate": cond,
    }


def process_codex(path: Path) -> dict | None:
    """Build an inventory row from a Codex rollout (~/.codex/sessions)."""
    try:
        st = path.stat()
    except OSError:
        return None
    meta = codex_sessions.session_meta(path)
    turns = codex_sessions.codex_turns(path, model_hint=meta.get("model", ""))
    if not turns:
        return None
    # Codex user_message turns are raw freeform prompts (no command wrappers).
    for t in turns:
        t.setdefault("raw_has_content", bool(t.get("text")))
        t.setdefault("is_only_wrappers", False)

    first_user_msg = ""
    for t in turns:
        if t["role"] == "user" and t["text"]:
            first_user_msg = redact(t["text"][:400])
            break
    summary = first_user_msg.splitlines()[0][:120] if first_user_msg else ""
    cond = build_condensate(turns)
    return {
        "path": str(path),
        "kind": "codex",
        "mtime": st.st_mtime,
        "cwd": meta.get("cwd") or "",
        "size": st.st_size,
        "entrypoint": "",
        "first_user_msg": first_user_msg,
        "summary": summary,
        "turns": sum(1 for t in turns if t["text"]),
        "user_correction_count": cond["correction_count"],
        "duration_s": _duration(turns),
        "is_automation": False,
        "automation_reason": "",
        "tokens": aggregate_tokens(turns),
        "condensate": cond,
    }


def apply_recurrence_automation(rows: list[dict]) -> None:
    """Post-pass: any row with composite short-no-freeform whose summary repeats ≥2× on same cwd within 7 days graduates to composite:short-recurring."""
    by_key: dict[tuple[str, str], list[dict]] = {}
    for r in rows:
        if r.get("automation_reason") == "composite:short-no-freeform":
            key = (r["cwd"], r["summary"])
            by_key.setdefault(key, []).append(r)
    for key, group in by_key.items():
        if len(group) < 2:
            # Revert solitary ones, one-off short wrapper-only sessions shouldn't be flagged.
            for r in group:
                r["is_automation"] = False
                r["automation_reason"] = ""
            continue
        group.sort(key=lambda r: r["mtime"])
        # If at least two within 7 days of each other, keep as recurring; else revert.
        window = 7 * 86400
        any_pair = False
        for i in range(len(group)):
            for j in range(i + 1, len(group)):
                if group[j]["mtime"] - group[i]["mtime"] <= window:
                    any_pair = True
                    break
            if any_pair:
                break
        if any_pair:
            for r in group:
                r["automation_reason"] = "composite:short-recurring"
        else:
            for r in group:
                r["is_automation"] = False
                r["automation_reason"] = ""


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--out", default="out/inventory.json")
    p.add_argument("--since", help="YYYY-MM-DD inclusive")
    p.add_argument("--until", help="YYYY-MM-DD inclusive")
    p.add_argument("--all", action="store_true", help="disable default 6-month window")
    args = p.parse_args()

    platform = detect_platform()
    if platform == ANTIGRAVITY:
        degrade("task-profile", platform)

    now = time.time()
    since_ts: float | None
    until_ts: float | None
    if args.all:
        since_ts = None
        until_ts = None
    else:
        since_ts = (
            datetime.strptime(args.since, "%Y-%m-%d").timestamp()
            if args.since
            else now - 180 * 86400
        )
        until_ts = (
            datetime.strptime(args.until, "%Y-%m-%d").timestamp() + 86400
            if args.until
            else None
        )

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    rows: list[dict] = []
    scanned = 0
    if platform == CODEX:
        for path in sorted(codex_sessions.CODEX_ROOT.glob("*/*/*/rollout-*.jsonl")):
            try:
                mtime = path.stat().st_mtime
            except OSError:
                continue
            if since_ts is not None and mtime < since_ts:
                continue
            if until_ts is not None and mtime > until_ts:
                continue
            scanned += 1
            row = process_codex(path)
            if row is not None:
                rows.append(row)
    else:
        for path, kind in _candidates(since_ts, until_ts):
            scanned += 1
            row = process(path, kind)
            if row is not None:
                rows.append(row)
    apply_recurrence_automation(rows)
    rows.sort(key=lambda r: r["mtime"], reverse=True)

    summary = {
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "window": {
            "since": datetime.fromtimestamp(since_ts).strftime("%Y-%m-%d") if since_ts else None,
            "until": datetime.fromtimestamp(until_ts).strftime("%Y-%m-%d") if until_ts else None,
        },
        "counts": {
            "scanned": scanned,
            "kept": len(rows),
            "automation": sum(1 for r in rows if r["is_automation"]),
            "interactive": sum(1 for r in rows if not r["is_automation"]),
            "code": sum(1 for r in rows if r["kind"] == "code"),
            "cowork": sum(1 for r in rows if r["kind"] == "cowork"),
            "codex": sum(1 for r in rows if r["kind"] == "codex"),
        },
        "sessions": rows,
    }
    out_path.write_text(json.dumps(summary, indent=2, default=str))
    print(
        f"wrote {out_path} | scanned={scanned} kept={len(rows)} "
        f"interactive={summary['counts']['interactive']} automation={summary['counts']['automation']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
