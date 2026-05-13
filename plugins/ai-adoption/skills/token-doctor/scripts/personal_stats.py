#!/usr/bin/env python3
"""Aggregate out/sessions.jsonl into out/user-stats.json and print a terminal summary.

Reproduces the team-dashboard metrics for one person: length buckets, marathon share,
cache rebuild $, read:create ratio, per-cwd breakdown with health classification.
"""
from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path

MARATHON_THRESHOLD = 300  # p95 of org turn distribution

def length_bucket(n: int) -> str:
    if n <= 5:    return "b1_1_5"
    if n <= 20:   return "b2_6_20"
    if n <= 50:   return "b3_21_50"
    if n <= 100:  return "b4_51_100"
    if n <= 300:  return "b5_101_300"
    if n <= 1000: return "b6_301_1000"
    return "b7_1001_plus"

def classify_cwd(c: dict) -> tuple[str, str]:
    """Return (emoji, one-word health) for a cwd given its rollup stats."""
    mara_share = c["mara_cost"] / c["cost"] if c["cost"] else 0
    rebuild_share = (c["late_tok"]/1e6 * 3) / c["cost"] if c["cost"] else 0
    issues = []
    if mara_share >= 0.5: issues.append("marathon")
    if rebuild_share >= 0.05: issues.append("rebuilds")
    if c["zomb"] >= max(2, c["conv"] // 3): issues.append("zombie")
    if not issues:
        return ("✅", "clean")
    if len(issues) >= 2:
        return ("⚠️ ", f"{','.join(issues)}")
    if "marathon" in issues:  return ("🏃", "marathon")
    if "rebuilds" in issues:  return ("🔄", "rebuilds")
    return ("🧟", "zombie")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", default="out/sessions.jsonl")
    ap.add_argument("--out", default="out/user-stats.json")
    ap.add_argument("--marathon-threshold", type=int, default=MARATHON_THRESHOLD)
    args = ap.parse_args()

    sessions = []
    with open(args.inp) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            sessions.append(json.loads(line))

    if not sessions:
        print("🩺 Nothing to diagnose. No sessions in inventory.")
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out).write_text(json.dumps({"empty": True}))
        return

    total_cost = sum(s["cost_usd"] for s in sessions)
    total_conv = len(sessions)
    bucket_cost = defaultdict(float)
    bucket_count = defaultdict(int)
    mara_cost = 0.0; mara_conv = 0
    zomb_cost = 0.0; zomb_conv = 0
    late_tokens = 0; late_evt = 0
    read_total = 0; cre_total = 0
    peak_max = 0
    by_cwd = defaultdict(lambda: {"cost":0.0,"conv":0,"mara_cost":0.0,"mara":0,"zomb":0,"late_tok":0})
    by_surface = defaultdict(lambda: {"cost":0.0,"conv":0})

    for s in sessions:
        n = s["turn_count"]
        b = length_bucket(n)
        bucket_cost[b] += s["cost_usd"]
        bucket_count[b] += 1
        is_mara = n >= args.marathon_threshold
        is_zomb = (s.get("duration_min") or 0) >= 240
        if is_mara: mara_cost += s["cost_usd"]; mara_conv += 1
        if is_zomb: zomb_cost += s["cost_usd"]; zomb_conv += 1
        late_tokens += s.get("late_create_tokens", 0)
        late_evt    += s.get("late_create_count", 0)
        read_total  += s.get("cache_read", 0)
        cre_total   += s.get("cache_creation", 0)
        peak_max     = max(peak_max, s.get("peak_cache_read", 0))
        cwd = s.get("cwd") or "(no cwd / Cowork)"
        c = by_cwd[cwd]
        c["cost"] += s["cost_usd"]; c["conv"] += 1
        if is_mara: c["mara"] += 1; c["mara_cost"] += s["cost_usd"]
        if is_zomb: c["zomb"] += 1
        c["late_tok"] += s.get("late_create_tokens", 0)
        bs = by_surface[s.get("surface","unknown")]
        bs["cost"] += s["cost_usd"]; bs["conv"] += 1

    # Top 12 cwds by spend.
    # Skip the synthetic "(no cwd / Cowork)" bucket — it's not a project, just an
    # aggregate of all cowork sessions. The surface line already shows cowork totals.
    real_cwds = [(k, v) for k, v in by_cwd.items() if k != "(no cwd / Cowork)"]
    top_cwds = sorted(real_cwds, key=lambda kv: -kv[1]["cost"])[:12]
    cwd_breakdown = []
    for k, v in top_cwds:
        emoji, health = classify_cwd(v)
        cwd_breakdown.append({
            "cwd": k,
            "cost": round(v["cost"], 2),
            "conv": v["conv"],
            "marathon_conv": v["mara"],
            "marathon_share": round(v["mara_cost"]/v["cost"], 3) if v["cost"] else 0,
            "zombie_conv": v["zomb"],
            "late_tokens_M": round(v["late_tok"]/1e6, 2),
            "health": health,
            "emoji": emoji,
        })

    # Also expose deeper clean projects (beyond top 12) so the main agent can cite them
    # when no top project is clean.
    smallest_top_cost = top_cwds[-1][1]["cost"] if top_cwds else 0
    deeper_clean = []
    for k, v in real_cwds:
        if v["cost"] < 20: continue
        if v["cost"] >= smallest_top_cost: continue
        emoji, health = classify_cwd(v)
        if health == "clean":
            deeper_clean.append({
                "cwd": k,
                "cost": round(v["cost"], 2),
                "conv": v["conv"],
            })
    deeper_clean.sort(key=lambda x: -x["cost"])
    deeper_clean = deeper_clean[:5]

    stats = {
        "marathon_threshold": args.marathon_threshold,
        "total_cost": round(total_cost, 2),
        "total_conv": total_conv,
        "by_surface": {k: {"cost": round(v["cost"], 2), "conv": v["conv"]} for k, v in by_surface.items()},
        "buckets": {
            b: {
                "cost": round(bucket_cost[b], 2),
                "count": bucket_count[b],
                "share": round(bucket_cost[b] / total_cost, 4) if total_cost else 0,
            } for b in [
                "b1_1_5","b2_6_20","b3_21_50","b4_51_100",
                "b5_101_300","b6_301_1000","b7_1001_plus",
            ]
        },
        "marathon_cost": round(mara_cost, 2),
        "marathon_share": round(mara_cost / total_cost, 4) if total_cost else 0,
        "marathon_conv": mara_conv,
        "zombie_cost": round(zomb_cost, 2),
        "zombie_share": round(zomb_cost / total_cost, 4) if total_cost else 0,
        "zombie_conv": zomb_conv,
        "cache_rebuild_tokens_M": round(late_tokens / 1e6, 2),
        "cache_rebuild_events": late_evt,
        "cache_rebuild_cost_est": round(late_tokens / 1e6 * 3, 2),
        "read_total_B": round(read_total / 1e9, 3),
        "create_total_B": round(cre_total / 1e9, 3),
        "rc_ratio": round(read_total / max(cre_total, 1), 1),
        "peak_cache_read_max_k": round(peak_max / 1000, 0),
        "by_cwd_top": cwd_breakdown,
        "by_cwd_clean_deeper": deeper_clean,
        "short_share": round(
            (bucket_cost["b1_1_5"] + bucket_cost["b2_6_20"] + bucket_cost["b3_21_50"]) / total_cost,
            4) if total_cost else 0,
    }

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(stats, indent=2))

    # Minimal confirmation only. The main agent reads user-stats.json and writes
    # the doctor's report directly to the terminal with framing and conclusions.
    def money(v): return f"${v:,.0f}" if v >= 100 else f"${v:.2f}"
    print(f"🩺  Stats ready: {money(stats['total_cost'])} across {stats['total_conv']:,} conversations, "
          f"{len(stats['by_cwd_top'])} top projects · saved to {args.out}")

if __name__ == "__main__":
    main()
