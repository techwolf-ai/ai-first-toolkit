#!/usr/bin/env python3
"""Select 12-20 sessions for deep analysis by subagents.

Balanced selection so the report covers expensive sessions AND positive examples:
  - Top 8 by absolute cost (where money is going)
  - Top 3 by cache_rebuild tokens (late context drip-feed)
  - Top 3 by turn count (raw marathon length)
  - Top 3 by read:create ratio at >= $5 cost (cache grind)
  - Top 3 positive examples: highest cost-per-turn efficiency among 20-100 turn sessions

Dedupes by sid. Writes out/hotspots.json with the selection + reason for each.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

def load_sessions(path: str) -> list[dict]:
    rows = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", default="out/sessions.jsonl")
    ap.add_argument("--out", default="out/hotspots.json")
    ap.add_argument("--top-cost",     type=int, default=8)
    ap.add_argument("--top-rebuild",  type=int, default=3)
    ap.add_argument("--top-turns",    type=int, default=3)
    ap.add_argument("--top-grind",    type=int, default=3)
    ap.add_argument("--top-positive", type=int, default=3)
    args = ap.parse_args()

    sessions = load_sessions(args.inp)

    def pick(rows, key_fn, n, reason, min_cost=0.0):
        sel = [s for s in rows if s["cost_usd"] >= min_cost]
        sel.sort(key=key_fn, reverse=True)
        return [(s, reason) for s in sel[:n]]

    bucket_cost    = pick(sessions, lambda s: s["cost_usd"], args.top_cost, "top-cost")
    bucket_rebuild = pick(sessions, lambda s: s.get("late_create_tokens", 0), args.top_rebuild, "drip-feed", min_cost=1)
    bucket_turns   = pick(sessions, lambda s: s["turn_count"], args.top_turns, "marathon", min_cost=1)
    bucket_grind   = pick(sessions, lambda s: s.get("rc_ratio", 0), args.top_grind, "cache-grind", min_cost=5)

    # Positive: efficient short-to-mid focused sessions (20-100 turns, lowest cost per turn)
    short_focused = [s for s in sessions if 20 <= s["turn_count"] <= 100 and s["cost_usd"] >= 0.5]
    short_focused.sort(key=lambda s: s["cost_usd"] / max(s["turn_count"], 1))
    bucket_positive = [(s, "positive-focused") for s in short_focused[:args.top_positive]]

    # Merge with dedup, preserving reason for each pick
    seen: dict[str, dict] = {}
    for s, reason in (bucket_cost + bucket_rebuild + bucket_turns + bucket_grind + bucket_positive):
        sid = s["sid"]
        if sid not in seen:
            seen[sid] = {"session": s, "reasons": [reason]}
        else:
            if reason not in seen[sid]["reasons"]:
                seen[sid]["reasons"].append(reason)

    # Sort final list by cost desc for output
    hotspots = sorted(seen.values(), key=lambda x: -x["session"]["cost_usd"])

    summary = [{
        "sid": h["session"]["sid"],
        "cost": round(h["session"]["cost_usd"], 2),
        "turns": h["session"]["turn_count"],
        "duration_min": h["session"].get("duration_min"),
        "rc_ratio": h["session"].get("rc_ratio"),
        "late_create_count": h["session"].get("late_create_count"),
        "peak_cache_read_k": round((h["session"].get("peak_cache_read") or 0)/1000),
        "cwd": h["session"].get("cwd"),
        "title": (h["session"].get("title") or "")[:120],
        "reasons": h["reasons"],
    } for h in hotspots]

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps({"count": len(hotspots), "hotspots": summary}, indent=2))
    print(f"Picked {len(hotspots)} hotspots to {args.out}")
    for h in summary:
        rs = ",".join(h["reasons"])
        title = h["title"] or "(no title)"
        print(f"  ${h['cost']:>7.2f}  {h['turns']:>4} turns  [{rs}]  {title[:60]}")

if __name__ == "__main__":
    main()
