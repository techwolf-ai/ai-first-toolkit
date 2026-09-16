#!/usr/bin/env python3
"""Walk local Claude Code + Cowork transcripts into out/sessions.jsonl.

Per-session row contains everything later stages need: tokens by model, per-turn
timeline, late-create events, peak cache_read, duration, automation flag, cwd,
title, and computed cost.

Default window: last 90 days. Override with --since YYYY-MM-DD / --until / --all.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from pricing import cost_for_usage  # noqa: E402
import codex_sessions  # noqa: E402
from host_platform import ANTIGRAVITY, CLAUDE, CODEX, degrade, detect_platform  # noqa: E402

HOME = Path.home()
CODE_ROOT = HOME / ".claude" / "projects"

def _cowork_root() -> Path:
    if sys.platform == "darwin":
        return HOME / "Library" / "Application Support" / "Claude" / "local-agent-mode-sessions"
    if sys.platform.startswith("win"):
        import os
        return Path(os.environ.get("APPDATA", str(HOME))) / "Claude" / "local-agent-mode-sessions"
    return HOME / ".config" / "Claude" / "local-agent-mode-sessions"

COWORK_ROOT = _cowork_root()

# Automation markers we exclude by default (long-running automated processes inflate cost)
# Entrypoints that are background dispatch rather than a person at a keyboard.
# Deny-list on purpose: `cli`, `claude-desktop` and any future interactive surface
# count as spend. An unknown entrypoint is treated as interactive, because silently
# dropping real work is the worse failure for a cost tool.
AUTOMATION_ENTRYPOINTS = {"sdk-cli", "sdk"}
AUTOMATION_SLASH_CMDS = {
    "/loop", "/schedule", "/babysit-prs", "/ultrareview", "/autonomous-loop",
    "/productivity:update", "/productivity:start",
}
TASK_NOTIF_RE = re.compile(r"<task-notification>.*?</task-notification>", re.DOTALL)
COMMAND_WRAPPER_RE = re.compile(r"<command-(?:name|message|args)>.*?</command-\w+>", re.DOTALL)

def parse_ts(s: str | None) -> datetime | None:
    if not s: return None
    try:
        if s.endswith("Z"): s = s[:-1] + "+00:00"
        return datetime.fromisoformat(s)
    except Exception:
        return None

def _text_of(entry: dict) -> str:
    msg = entry.get("message") or {}
    c = msg.get("content")
    if isinstance(c, str): return c
    if isinstance(c, list):
        out = []
        for p in c:
            if isinstance(p, dict) and p.get("type") == "text":
                t = p.get("text") or ""
                if t: out.append(t)
        return "\n".join(out)
    return ""

def _tool_calls(entry: dict) -> list[str]:
    msg = entry.get("message") or {}
    c = msg.get("content")
    if not isinstance(c, list): return []
    return [p.get("name") for p in c if isinstance(p, dict) and p.get("type") == "tool_use" and p.get("name")]

def _usage(entry: dict) -> tuple[str, dict] | None:
    msg = entry.get("message") or {}
    u = msg.get("usage")
    if not isinstance(u, dict): return None
    return msg.get("model") or "unknown", {
        "input":          int(u.get("input_tokens") or 0),
        "output":         int(u.get("output_tokens") or 0),
        "cache_read":     int(u.get("cache_read_input_tokens") or 0),
        "cache_creation": int(u.get("cache_creation_input_tokens") or 0),
    }

def _strip_noise(text: str) -> str:
    return TASK_NOTIF_RE.sub("", text).strip()

def _first_user_text(turns: list[dict]) -> str:
    for t in turns:
        if t["role"] == "user" and t.get("text"):
            txt = COMMAND_WRAPPER_RE.sub("", t["text"]).strip()
            if txt:
                return txt[:400]
    return ""

def _is_automation(path: Path, turns: list[dict], first_meta: dict) -> str | None:
    p = str(path)
    ep = first_meta.get("entrypoint") or ""
    if ep in AUTOMATION_ENTRYPOINTS: return f"entrypoint:{ep}"
    if "/agent/local_ditto_" in p or "/agent/local_routine_" in p: return "ditto-routine"
    if "--paperclip-instances-" in p: return "paperclip"
    if turns:
        first_user = next((t for t in turns if t["role"] == "user"), None)
        if first_user:
            text = first_user.get("text") or ""
            if "<scheduled-task" in text: return "scheduled-task"
            m = re.search(r"<command-name>\s*(/\S+)", text)
            if m and m.group(1) in AUTOMATION_SLASH_CMDS:
                return f"slash-command:{m.group(1)}"
    return None

def _subagent_usage(path: Path) -> dict:
    """Cost and turns for one sub-agent transcript. Usage only: no text, no timeline.

    One turn = one assistant message, deduped by message id, matching how the main
    transcript is counted.
    """
    agg = {"cost": 0.0, "turns": 0, "by_model": {}}
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return agg
    seen_msgs: set[str] = set()
    for line in lines:
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        if e.get("type") != "assistant":
            continue
        # Same per-content-block duplication as the main transcript: count each
        # assistant message once, so a sub-agent turn is the same unit as a main turn.
        mid = (e.get("message") or {}).get("id")
        if mid:
            if mid in seen_msgs:
                continue
            seen_msgs.add(mid)
        u = _usage(e)
        if not u:
            continue
        model, usage = u
        cost = cost_for_usage(model, usage)
        agg["cost"] += cost
        agg["turns"] += 1
        bm = agg["by_model"].setdefault(model, {"turns": 0, "cost": 0.0})
        bm["turns"] += 1
        bm["cost"] += cost
    return agg

def _rollup_subagents(paths: list[Path]) -> dict:
    """Merge every sub-agent transcript belonging to one parent session."""
    agg = {"cost": 0.0, "turns": 0, "files": 0, "by_model": {}}
    for p in paths:
        u = _subagent_usage(p)
        if not u["turns"]:
            continue
        agg["files"] += 1
        agg["cost"] += u["cost"]
        agg["turns"] += u["turns"]
        for model, bm in u["by_model"].items():
            tgt = agg["by_model"].setdefault(model, {"turns": 0, "cost": 0.0})
            tgt["turns"] += bm["turns"]
            tgt["cost"] += bm["cost"]
    return agg

def _split_project(project_dir: Path) -> tuple[list[Path], dict[str, list[Path]]]:
    """Split a project dir into main session files and sub-agent files by parent sid.

    Main sessions are <project>/<sid>.jsonl. Sub-agents live at
    <project>/<sid>/subagents/agent-*.jsonl, and workflow agents one level deeper at
    <project>/<sid>/subagents/workflows/<wf>/agent-*.jsonl. Both shapes carry the
    parent session id as the first path component, so one rule covers them.
    """
    mains: list[Path] = []
    subs: dict[str, list[Path]] = {}
    for p in sorted(project_dir.rglob("*.jsonl")):
        parts = p.relative_to(project_dir).parts
        if len(parts) == 1:
            mains.append(p)
        elif "subagents" in parts:
            subs.setdefault(parts[0], []).append(p)
    return mains, subs

def _process_code_transcript(path: Path, subagents: dict | None = None) -> dict | None:
    """Parse a Claude Code .jsonl transcript."""
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return None
    if not lines: return None

    sid = None
    cwd = None
    first_meta: dict = {}
    turns: list[dict] = []
    # Claude Code writes ONE JSONL LINE PER CONTENT BLOCK of an assistant message
    # (thinking, text, and each tool_use), and every one of those lines repeats the
    # SAME message.usage object. Treating each line as a turn therefore counts the
    # same tokens once per block: measured ~2.4x on line counts and up to ~3x on
    # token totals. Lines sharing a message id are merged into one turn here, so
    # cost, token totals, the timeline, the cache metrics and turn_count are all
    # per-message. Keyed by message id rather than requestId: a retried request
    # reuses the id, and counting a retry twice would be the same bug again.
    by_msg_id: dict[str, dict] = {}

    for line in lines:
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        t = e.get("type")
        if not sid:
            sid = e.get("sessionId") or e.get("session_id")
        if not cwd:
            cwd = e.get("cwd") or (e.get("metadata") or {}).get("cwd")
            if cwd:
                first_meta["cwd"] = cwd
        if "entrypoint" not in first_meta:
            # Independent of cwd: an early entry can carry one without the other.
            ep = e.get("entryPointType") or e.get("entrypoint")
            if ep:
                first_meta["entrypoint"] = ep
        if t not in ("user", "assistant"):
            continue
        text = _strip_noise(_text_of(e))
        tools = _tool_calls(e)
        u = _usage(e)
        mid = (e.get("message") or {}).get("id") if t == "assistant" else None
        prev = by_msg_id.get(mid) if mid else None
        if prev is not None:
            # Another content block of a message already seen: fold it in, do not
            # re-count its usage.
            if text:
                prev["text"] = f"{prev['text']}\n{text}".strip() if prev["text"] else text
            if tools:
                prev["tool_calls"].extend(tools)
            if u and "usage" not in prev:
                prev["model"], prev["usage"] = u
            continue
        ent: dict = {
            "role": t,
            "ts": e.get("timestamp"),
            "text": text,
            "tool_calls": tools,
        }
        if u:
            ent["model"], ent["usage"] = u
        turns.append(ent)
        if mid:
            by_msg_id[mid] = ent

    if not turns:
        return None

    # The filename is the canonical session id. A resumed or forked transcript can
    # still carry the originating sessionId on an early line, and two files sharing
    # a sid would collide on out/payloads/<sid>.json in stage 2.
    sid = path.stem or sid
    autom = _is_automation(path, turns, first_meta)
    return _summarize_session(sid=sid, surface="code", path=path, cwd=cwd, turns=turns,
                              automation=autom, subagents=subagents)

def _process_codex_transcript(path: Path) -> dict | None:
    """Parse a Codex rollout (~/.codex/sessions/.../rollout-*.jsonl)."""
    meta = codex_sessions.session_meta(path)
    turns = codex_sessions.codex_turns(path, model_hint=meta.get("model", ""))
    if not turns:
        return None
    return _summarize_session(sid=path.stem, surface="codex", path=path,
                              cwd=meta.get("cwd") or None, turns=turns, automation=None)

def _process_cowork_transcript(audit_path: Path) -> dict | None:
    """Parse a Cowork audit.jsonl + companion json sidecar."""
    try:
        lines = audit_path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return None
    if not lines: return None

    # Sidecar metadata
    sidecar = audit_path.parent.parent / (audit_path.parent.name.replace("local_", "") + ".json")
    title = None
    if sidecar.exists():
        try:
            sd = json.loads(sidecar.read_text(encoding="utf-8", errors="replace"))
            title = sd.get("title") or (sd.get("metadata") or {}).get("title")
        except Exception:
            pass

    sid = audit_path.parent.name
    turns: list[dict] = []
    for line in lines:
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        t = e.get("type")
        if t not in ("user", "assistant"):
            continue
        text = _strip_noise(_text_of(e))
        ent: dict = {
            "role": t,
            "ts": e.get("timestamp"),
            "text": text,
            "tool_calls": _tool_calls(e),
        }
        u = _usage(e)
        if u:
            ent["model"], ent["usage"] = u
        turns.append(ent)

    if not turns: return None
    autom = _is_automation(audit_path, turns, {})
    return _summarize_session(sid=sid, surface="cowork", path=audit_path, cwd=None,
                              turns=turns, automation=autom, title_override=title)

def _summarize_session(sid: str, surface: str, path: Path, cwd: str | None,
                       turns: list[dict], automation: str | None,
                       title_override: str | None = None,
                       subagents: dict | None = None) -> dict:
    # One model turn = one assistant MESSAGE carrying usage. The caller has already
    # merged the per-content-block lines of a message into a single turn, so this is
    # a message count, not a JSONL line count.
    model_turns = [t for t in turns if t.get("usage")]
    turn_count = len(model_turns)
    # Per-turn timeline (compact)
    timeline = []
    cre_tot = 0; read_tot = 0; inp_tot = 0; out_tot = 0
    by_model: dict[str, dict] = {}
    peak_read = 0
    late_events = []  # (turn_index, tokens)
    for i, t in enumerate(model_turns):
        u = t["usage"]
        c_read = u["cache_read"]; c_cre = u["cache_creation"]
        inp = u["input"]; out = u["output"]
        model = t.get("model") or "unknown"
        cost = cost_for_usage(model, u)
        timeline.append({
            "i": i, "ts": t.get("ts"),
            "model": model,
            "inp": inp, "out": out, "read": c_read, "cre": c_cre,
            "cost": round(cost, 6),
            "tools": t.get("tool_calls") or [],
        })
        cre_tot += c_cre; read_tot += c_read; inp_tot += inp; out_tot += out
        peak_read = max(peak_read, c_read)
        if i >= 5 and c_cre >= 20_000:
            late_events.append({"turn": i, "tokens": c_cre})
        bm = by_model.setdefault(model, {"input":0,"output":0,"cache_read":0,"cache_creation":0,"cost":0.0,"turns":0})
        bm["input"]          += inp
        bm["output"]         += out
        bm["cache_read"]     += c_read
        bm["cache_creation"] += c_cre
        bm["cost"]           += cost
        bm["turns"]          += 1

    # Total cost. Sub-agent transcripts are separate files but the same piece of work,
    # so their cost rolls into the parent session. Turn counts, the timeline and the
    # cache metrics stay main-session-only: they describe this conversation's own
    # context growth, and the length buckets downstream are main-turn buckets.
    total_cost = sum(b["cost"] for b in by_model.values())
    for bm in by_model.values():
        bm["cost"] = round(bm["cost"], 6)
    sub = subagents or {}
    sub_cost = sub.get("cost", 0.0)
    sub_by_model = {m: {"turns": v["turns"], "cost": round(v["cost"], 6)}
                    for m, v in (sub.get("by_model") or {}).items()}

    # Duration
    first_ts = parse_ts(turns[0].get("ts"))
    last_ts  = parse_ts(turns[-1].get("ts"))
    dur_min = None
    if first_ts and last_ts:
        try:
            dur_min = round((last_ts - first_ts).total_seconds() / 60, 1)
        except Exception:
            pass

    # Tool-call counters
    tool_counts: dict[str, int] = {}
    for t in turns:
        for n in t.get("tool_calls") or []:
            tool_counts[n] = tool_counts.get(n, 0) + 1

    title = title_override or _first_user_text(turns)
    return {
        "sid": sid,
        "surface": surface,
        "path": str(path),
        "cwd": cwd,
        "title": title,
        "automation": automation,
        "turn_count": turn_count,
        "start_ts": turns[0].get("ts"),
        "end_ts": turns[-1].get("ts"),
        "duration_min": dur_min,
        "input": inp_tot, "output": out_tot,
        "cache_read": read_tot, "cache_creation": cre_tot,
        "peak_cache_read": peak_read,
        "late_create_events": late_events,
        "late_create_count": len(late_events),
        "late_create_tokens": sum(e["tokens"] for e in late_events),
        "rc_ratio": round(read_tot / max(cre_tot, 1), 2),
        "cost_usd": round(total_cost + sub_cost, 4),
        "main_cost_usd": round(total_cost, 4),
        "subagent_cost_usd": round(sub_cost, 4),
        "subagent_files": sub.get("files", 0),
        "subagent_turns": sub.get("turns", 0),
        "subagent_by_model": sub_by_model,
        "by_model": by_model,
        "tool_counts": tool_counts,
        "timeline": timeline,
    }

def _within_window(sess: dict, since: datetime | None, until: datetime | None) -> bool:
    ts = parse_ts(sess.get("end_ts") or sess.get("start_ts"))
    if not ts: return True  # keep unknown timestamps
    if since and ts < since: return False
    if until and ts > until: return False
    return True

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--since", type=str, default=None, help="YYYY-MM-DD")
    ap.add_argument("--until", type=str, default=None, help="YYYY-MM-DD")
    ap.add_argument("--all", action="store_true", help="No window filter (overrides --since/--until)")
    ap.add_argument("--include-automation", action="store_true",
                    help="Include sessions flagged as automation (paperclip, schedule, ditto, /loop, etc.)")
    ap.add_argument("--out", type=str, default="out/sessions.jsonl")
    ap.add_argument("--include-cowork", action="store_true", default=True)
    ap.add_argument("--no-cowork", dest="include_cowork", action="store_false")
    args = ap.parse_args()

    platform = detect_platform()
    if platform == ANTIGRAVITY:
        degrade("token-doctor", platform)

    if args.all:
        since = until = None
    else:
        until = datetime.now(timezone.utc) if not args.until else datetime.fromisoformat(args.until).replace(tzinfo=timezone.utc)
        if args.since:
            since = datetime.fromisoformat(args.since).replace(tzinfo=timezone.utc)
        else:
            since = until - timedelta(days=90)

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    n_in = n_out = n_autom = n_sub = n_orphan = 0
    orphan_cost = 0.0
    with out_path.open("w", encoding="utf-8") as f_out:
        if platform == CODEX:
            # Codex rollouts (~/.codex/sessions). Token usage comes from Codex's
            # own per-response token_count events; cost via OpenAI rates.
            for p in sorted(codex_sessions.CODEX_ROOT.glob("*/*/*/rollout-*.jsonl")):
                n_in += 1
                sess = _process_codex_transcript(p)
                if not sess: continue
                if not _within_window(sess, since, until): continue
                f_out.write(json.dumps(sess, default=str) + "\n")
                n_out += 1
        else:
            # Code transcripts. Sub-agent transcripts are rolled into their parent
            # session rather than emitted as sessions of their own: they are the same
            # unit of work, and counting them separately would double the session count
            # and corrupt the turn-count length buckets.
            if CODE_ROOT.exists():
                for project_dir in sorted(CODE_ROOT.iterdir()):
                    if not project_dir.is_dir() or project_dir.name.startswith("_archive"):
                        continue
                    mains, subs = _split_project(project_dir)
                    rollups = {sid: _rollup_subagents(paths) for sid, paths in subs.items()}
                    for p in mains:
                        n_in += 1
                        roll = rollups.pop(p.stem, None)
                        if roll:
                            n_sub += roll["files"]
                        sess = _process_code_transcript(p, roll)
                        if not sess: continue
                        if not _within_window(sess, since, until): continue
                        if sess.get("automation") and not args.include_automation:
                            n_autom += 1
                            continue
                        f_out.write(json.dumps(sess, default=str) + "\n")
                        n_out += 1
                    # Sub-agents whose parent transcript is gone have nothing to roll into.
                    for roll in rollups.values():
                        n_orphan += roll["files"]
                        orphan_cost += roll["cost"]
            # Cowork transcripts
            if args.include_cowork and COWORK_ROOT.exists():
                for p in sorted(COWORK_ROOT.glob("*/*/local_*/audit.jsonl")):
                    n_in += 1
                    sess = _process_cowork_transcript(p)
                    if not sess: continue
                    if not _within_window(sess, since, until): continue
                    if sess.get("automation") and not args.include_automation:
                        n_autom += 1
                        continue
                    f_out.write(json.dumps(sess, default=str) + "\n")
                    n_out += 1

    print(f"Scanned {n_in} transcripts, wrote {n_out} sessions to {out_path}, excluded {n_autom} automation runs.")
    if n_sub:
        print(f"Rolled {n_sub} sub-agent transcripts into their parent sessions.")
    if n_orphan:
        print(f"Skipped {n_orphan} sub-agent transcripts (~${orphan_cost:,.0f}) with no parent session on disk.")
    print(f"Window: {since.date() if since else 'all'} to {until.date() if until else 'now'}")

if __name__ == "__main__":
    main()
