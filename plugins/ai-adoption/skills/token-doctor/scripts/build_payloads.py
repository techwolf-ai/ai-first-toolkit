#!/usr/bin/env python3
"""Generate one payload JSON per hotspot for the Haiku subagent fan-out.

Each payload has:
  - header: numeric signals the subagent uses for step-1 classification
  - timeline: per-turn token + tool summary across the whole session
  - sample: a redacted sample of user prompts (first 5, every late-create context, last 3)

Subagents read references/diagnosis-rubric.md and references/antipattern-taxonomy.md,
then this payload, and emit out/analyses/<sid>.json.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

REDACTIONS = [
    (re.compile(r"-----BEGIN [A-Z ]+ PRIVATE KEY-----[\s\S]*?-----END [A-Z ]+ PRIVATE KEY-----"), "[REDACTED:pk]"),
    (re.compile(r"eyJ[A-Za-z0-9_\-]+\.eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+"), "[REDACTED:jwt]"),
    (re.compile(r"sk-[A-Za-z0-9\-_]{20,}"), "[REDACTED:apikey]"),
    (re.compile(r"ghp_[A-Za-z0-9]{30,}"), "[REDACTED:gh]"),
    (re.compile(r"github_pat_[A-Za-z0-9_]{20,}"), "[REDACTED:gh]"),
    (re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"), "[REDACTED:slack]"),
    (re.compile(r"AIza[A-Za-z0-9\-_]{30,}"), "[REDACTED:apikey]"),
    (re.compile(r"AKIA[A-Z0-9]{16}"), "[REDACTED:aws]"),
]

def redact(s: str) -> str:
    if not s: return s
    for rx, repl in REDACTIONS:
        s = rx.sub(repl, s)
    return s

def load_sessions(path: Path) -> dict[str, dict]:
    out: dict[str, dict] = {}
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line: continue
            s = json.loads(line)
            out[s["sid"]] = s
    return out

def pick_sample_turns(timeline: list[dict], late_events: list[dict], max_total: int = 40) -> list[int]:
    """Return ordered turn indices to include in the sample."""
    n = len(timeline)
    if n <= max_total:
        return list(range(n))
    keep = set()
    # First 5 turns
    keep.update(range(min(5, n)))
    # Late-create events + neighbours
    for e in late_events:
        idx = e["turn"]
        keep.update([idx-1, idx, idx+1])
    # Last 3 turns
    keep.update(range(max(0, n-3), n))
    # Fill with evenly-spaced ones until we have max_total
    if len(keep) < max_total:
        remaining = [i for i in range(n) if i not in keep]
        step = max(1, len(remaining) // (max_total - len(keep)))
        keep.update(remaining[::step][:max_total - len(keep)])
    return sorted(i for i in keep if 0 <= i < n)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sessions", default="out/sessions.jsonl")
    ap.add_argument("--hotspots", default="out/hotspots.json")
    ap.add_argument("--outdir", default="out/payloads")
    args = ap.parse_args()

    sessions = load_sessions(Path(args.sessions))
    hotspots = json.loads(Path(args.hotspots).read_text())["hotspots"]
    outdir = Path(args.outdir); outdir.mkdir(parents=True, exist_ok=True)

    written = 0
    for h in hotspots:
        sid = h["sid"]
        s = sessions.get(sid)
        if not s: continue
        timeline = s.get("timeline", [])
        late = s.get("late_create_events", [])

        # Tool-call counters
        tool_counts = s.get("tool_counts", {})
        tool_read = tool_counts.get("Read", 0)
        tool_edit = tool_counts.get("Edit", 0) + tool_counts.get("Write", 0) + tool_counts.get("NotebookEdit", 0)

        # Resume count proxy: count timeline gaps > 60 minutes between consecutive turns
        resume_count = 0
        from datetime import datetime
        last_ts = None
        for t in timeline:
            ts_raw = t.get("ts")
            if not ts_raw: continue
            try:
                ts = datetime.fromisoformat(ts_raw.replace("Z","+00:00"))
            except Exception:
                continue
            if last_ts is not None:
                gap_s = (ts - last_ts).total_seconds()
                if gap_s > 3600: resume_count += 1
            last_ts = ts

        keep = set(pick_sample_turns(timeline, late))
        sample_timeline = [t for t in timeline if t["i"] in keep]

        # Sample user prompts at the same indices, if we have them
        # We didn't store user text in inventory by design (privacy). Just expose tool calls + token shape.
        # Cap title at 120 chars for the payload. Subagents only need a short tag of what the session was.
        short_title = redact(s.get("title") or "")
        if len(short_title) > 120:
            short_title = short_title[:117] + "..."
        payload = {
            "sid": sid,
            "cwd": s.get("cwd"),
            "title": short_title,
            "surface": s.get("surface"),
            "reasons_picked": h["reasons"],
            "header": {
                "turn_count": s["turn_count"],
                "cost_usd": s["cost_usd"],
                "duration_min": s.get("duration_min"),
                "resume_count": resume_count,
                "peak_cache_read": s.get("peak_cache_read"),
                "rc_ratio": s.get("rc_ratio"),
                "late_create_count": s.get("late_create_count"),
                "late_create_tokens": s.get("late_create_tokens"),
                "tool_read_count": tool_read,
                "tool_edit_count": tool_edit,
                "tool_counts": tool_counts,
            },
            "late_create_events": late,
            "by_model": s.get("by_model"),
            "sample_timeline": sample_timeline,
        }
        out_path = outdir / f"{sid}.json"
        out_path.write_text(json.dumps(payload, indent=1, default=str))
        written += 1

    print(f"Wrote {written} payloads to {outdir}/")

if __name__ == "__main__":
    main()
