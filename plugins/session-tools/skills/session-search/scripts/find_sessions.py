#!/usr/bin/env python3
"""Find past Claude Code (CLI) and Claude Cowork (desktop) sessions on this Mac.

Reads transcripts directly from disk. Works for any user , paths come from $HOME.
See ../SKILL.md for when to use this.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Iterator

sys.path.insert(0, str(Path(__file__).parent))
import codex_sessions  # noqa: E402
from host_platform import CLAUDE, CODEX, degrade, detect_platform  # noqa: E402

HOME = Path.home()
CODE_ROOT = HOME / ".claude" / "projects"
COWORK_ROOT = HOME / "Library" / "Application Support" / "Claude" / "local-agent-mode-sessions"


def _extract_text(entry: dict) -> str:
    """Pull user/assistant text out of a transcript entry. Skip tool calls/results/system noise."""
    t = entry.get("type")
    if t not in ("user", "assistant"):
        return ""
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


def _peek_code(jsonl: Path) -> tuple[str, str]:
    """Return (cwd, first_user_line) for a Claude Code transcript."""
    cwd = ""
    first_user = ""
    try:
        with jsonl.open(encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if i > 80 and cwd and first_user:
                    break
                try:
                    e = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if not cwd and isinstance(e.get("cwd"), str):
                    cwd = e["cwd"]
                if not first_user and e.get("type") == "user":
                    txt = _extract_text(e)
                    if txt:
                        first_user = txt.strip().splitlines()[0]
    except OSError:
        pass
    return cwd, first_user


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


def iter_sessions(kind: str) -> Iterator[dict]:
    if kind in ("code", "all") and CODE_ROOT.is_dir():
        for project_dir in CODE_ROOT.iterdir():
            if not project_dir.is_dir():
                continue
            for jsonl in project_dir.glob("*.jsonl"):
                try:
                    st = jsonl.stat()
                except OSError:
                    continue
                cwd, title = _peek_code(jsonl)
                yield {
                    "kind": "code",
                    "mtime": st.st_mtime,
                    "size": st.st_size,
                    "title": title,
                    "cwd": cwd,
                    "path": str(jsonl),
                }
    if kind in ("cowork", "all") and COWORK_ROOT.is_dir():
        for audit in COWORK_ROOT.rglob("local_*/audit.jsonl"):
            if "skills-plugin" in audit.parts:
                continue
            try:
                st = audit.stat()
            except OSError:
                continue
            yield {
                "kind": "cowork",
                "mtime": st.st_mtime,
                "size": st.st_size,
                "title": _cowork_title(audit),
                "cwd": "",
                "path": str(audit),
            }


def grep_session(path: Path, pattern: re.Pattern, max_snippets: int) -> list[str]:
    """Return up to max_snippets short excerpts where pattern matched."""
    snippets: list[str] = []
    try:
        with path.open(encoding="utf-8", errors="replace") as f:
            for line in f:
                if len(snippets) >= max_snippets:
                    break
                try:
                    e = json.loads(line)
                except json.JSONDecodeError:
                    continue
                txt = _extract_text(e)
                if not txt:
                    continue
                for m in pattern.finditer(txt):
                    start = max(0, m.start() - 60)
                    end = min(len(txt), m.end() + 60)
                    snip = txt[start:end].replace("\n", " ").strip()
                    role = e.get("type", "?")
                    snippets.append(f"[{role}] …{snip}…")
                    if len(snippets) >= max_snippets:
                        break
    except OSError:
        pass
    return snippets


def grep_codex(path: Path, pattern: re.Pattern, max_snippets: int) -> list[str]:
    """grep_session equivalent for a Codex rollout (uses the codex adapter)."""
    snippets: list[str] = []
    for role, txt in codex_sessions.iter_turns(path):
        if len(snippets) >= max_snippets:
            break
        for m in pattern.finditer(txt):
            start = max(0, m.start() - 60)
            end = min(len(txt), m.end() + 60)
            snip = txt[start:end].replace("\n", " ").strip()
            snippets.append(f"[{role}] …{snip}…")
            if len(snippets) >= max_snippets:
                break
    return snippets


def fmt_size(b: float) -> str:
    for u in ("B", "K", "M", "G"):
        if b < 1024:
            return f"{b:.0f}{u}"
        b /= 1024
    return f"{b:.0f}T"


def parse_date(s: str) -> float:
    return datetime.strptime(s, "%Y-%m-%d").timestamp()


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--kind", choices=("code", "cowork", "all"), default="all")
    p.add_argument("--since", help="YYYY-MM-DD (inclusive)")
    p.add_argument("--until", help="YYYY-MM-DD (inclusive)")
    p.add_argument("--title", help="substring, case-insensitive")
    p.add_argument("--cwd", help="substring match against code session cwd")
    p.add_argument("--grep", help="regex searched against transcript body (case-insensitive)")
    p.add_argument("--snippets", type=int, default=2, help="matching snippets per session (default 2)")
    p.add_argument("-n", "--limit", type=int, default=50, help="max sessions to output (0 = all)")
    p.add_argument("--json", action="store_true")
    args = p.parse_args()

    # Route by host platform. Claude Code reads its own transcripts; Codex reads
    # ~/.codex/sessions rollouts; Antigravity has no parseable local store.
    platform = detect_platform()
    if platform not in (CLAUDE, CODEX):
        degrade("session-search", platform)

    since_ts = parse_date(args.since) if args.since else None
    until_ts = parse_date(args.until) + 86400 if args.until else None
    title_q = args.title.lower() if args.title else None
    cwd_q = args.cwd.lower() if args.cwd else None
    grep_re = re.compile(args.grep, re.IGNORECASE) if args.grep else None

    if platform == CODEX:
        sessions = list(codex_sessions.iter_sessions())
        grep_fn = grep_codex
    else:
        sessions = list(iter_sessions(args.kind))
        grep_fn = grep_session
    sessions.sort(key=lambda s: s["mtime"], reverse=True)

    results = []
    for s in sessions:
        if since_ts is not None and s["mtime"] < since_ts:
            continue
        if until_ts is not None and s["mtime"] > until_ts:
            continue
        if title_q and title_q not in (s["title"] or "").lower():
            continue
        if cwd_q and cwd_q not in (s["cwd"] or "").lower():
            continue
        if grep_re is not None:
            snips = grep_fn(Path(s["path"]), grep_re, args.snippets)
            if not snips:
                continue
            s = dict(s, snippets=snips)
        results.append(s)
        if args.limit > 0 and len(results) >= args.limit:
            break

    if args.json:
        json.dump(results, sys.stdout, indent=2, default=str)
        sys.stdout.write("\n")
        return 0

    if not results:
        print("(no matching sessions)")
        return 0

    print(f"{'WHEN':<17} {'KIND':<7} {'SIZE':>6}  LABEL")
    print("-" * 100)
    for s in results:
        ts = datetime.fromtimestamp(s["mtime"]).strftime("%Y-%m-%d %H:%M")
        if s["kind"] in ("code", "codex"):
            label = s["title"] or "(no user message yet)"
            if s["cwd"]:
                label = f"{label}  ·  {s['cwd']}"
        else:
            label = s["title"] or "(untitled cowork session)"
        print(f"{ts:<17} {s['kind']:<7} {fmt_size(s['size']):>6}  {label[:120]}")
        print(f"{'':<17} path: {s['path']}")
        for snip in s.get("snippets", []):
            print(f"{'':<17}   {snip[:180]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
