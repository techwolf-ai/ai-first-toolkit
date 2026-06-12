#!/usr/bin/env python3
"""Print a single Claude Code / Cowork or Codex session as readable turns.

Takes the transcript path reported by find_sessions.py (a .jsonl file). Codex
rollouts (~/.codex/sessions/.../rollout-*.jsonl) are detected by path and read
through the Codex adapter.
See ../SKILL.md for when to use this.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import codex_sessions  # noqa: E402


def _is_codex(path: Path) -> bool:
    parts = path.parts
    return ".codex" in parts and "sessions" in parts or path.name.startswith("rollout-")


def _extract_text(entry: dict) -> str:
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


def iter_turns(path: Path):
    with path.open(encoding="utf-8", errors="replace") as f:
        for line in f:
            try:
                e = json.loads(line)
            except json.JSONDecodeError:
                continue
            txt = _extract_text(e)
            if not txt.strip():
                continue
            ts = e.get("timestamp") or ""
            yield {"role": e.get("type"), "ts": ts, "text": txt}


def fmt_ts(ts: str) -> str:
    if not ts:
        return ""
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00")).strftime("%Y-%m-%d %H:%M")
    except ValueError:
        return ts


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("path", help="transcript .jsonl path (from find_sessions.py)")
    p.add_argument("--grep", help="only print turns matching regex (plus --context surrounding turns)")
    p.add_argument("--context", type=int, default=1, help="surrounding turns when using --grep (default 1)")
    p.add_argument("--tail", type=int, help="print only the last N turns")
    p.add_argument("--head", type=int, help="print only the first N turns")
    p.add_argument("--max-chars", type=int, default=4000, help="truncate each turn to N chars (default 4000)")
    args = p.parse_args()

    path = Path(args.path)
    if not path.is_file():
        print(f"not found: {path}", file=sys.stderr)
        return 1

    if _is_codex(path):
        turns = [{"role": role, "ts": "", "text": txt}
                 for role, txt in codex_sessions.iter_turns(path) if txt.strip()]
    else:
        turns = list(iter_turns(path))

    if args.grep:
        pat = re.compile(args.grep, re.IGNORECASE)
        keep = set()
        for i, t in enumerate(turns):
            if pat.search(t["text"]):
                for j in range(max(0, i - args.context), min(len(turns), i + args.context + 1)):
                    keep.add(j)
        turns = [t for i, t in enumerate(turns) if i in keep]

    if args.head:
        turns = turns[: args.head]
    if args.tail:
        turns = turns[-args.tail :]

    if not turns:
        print("(no matching turns)")
        return 0

    print(f"# {path}")
    print(f"# {len(turns)} turns\n")
    for t in turns:
        header = f"## {t['role']}"
        ts = fmt_ts(t["ts"])
        if ts:
            header += f"  ·  {ts}"
        print(header)
        body = t["text"]
        if len(body) > args.max_chars:
            body = body[: args.max_chars] + f"\n… [truncated at {args.max_chars} chars]"
        print(body)
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
