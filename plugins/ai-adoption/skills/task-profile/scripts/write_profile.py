#!/usr/bin/env python3
"""Aggregate per-cluster analyses into canonical profile.csv + profile.json.

Consumes:
- out/analyses/*.json (Haiku outputs, one per cluster)
- out/inventory.json (session metadata + per-session tokens)
- out/canonical-merges.json (optional, main-agent judgment calls for cross-task merges)

Produces:
- out/profile.csv (company-shareable, one row per canonical task)
- out/profile.json (richer structure for explorer.html with per-task friction + sessions)

Scripted work here is strictly deterministic: read JSON, sum tokens, format CSV, apply redaction
rules once more on any text that made it through. All naming/merging/rewriting decisions live
in canonical-merges.json which the main agent produces by judgment.
"""
from __future__ import annotations

import csv
import glob
import hashlib
import json
import re
from pathlib import Path

INV = Path("out/inventory.json")
ANALYSES = Path("out/analyses")
MERGES = Path("out/canonical-merges.json")
OUT_CSV = Path("out/profile.csv")
OUT_JSON = Path("out/profile.json")

ALLOWED_SUCCESS = {"delivered_clean", "delivered_with_friction", "partial", "abandoned"}
ALLOWED_CATS = {"engineering", "research", "writing", "ops", "analysis", "planning", "communication"}


# --- redaction (same rules as inventory.py, applied defensively on final outputs) ---
REDACTIONS = [
    (re.compile(r"-----BEGIN [A-Z ]+ PRIVATE KEY-----[\s\S]*?-----END [A-Z ]+ PRIVATE KEY-----"), "[REDACTED:private_key]"),
    (re.compile(r"eyJ[A-Za-z0-9_\-]+\.eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+"), "[REDACTED:jwt]"),
    (re.compile(r"sk-[A-Za-z0-9\-_]{20,}"), "[REDACTED:api_key]"),
    (re.compile(r"ghp_[A-Za-z0-9]{30,}"), "[REDACTED:token]"),
    (re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"), "[REDACTED:token]"),
    (re.compile(r"AIza[A-Za-z0-9\-_]{30,}"), "[REDACTED:api_key]"),
    (re.compile(r"AKIA[A-Z0-9]{16}"), "[REDACTED:api_key]"),
]
KV = re.compile(r"(?i)(password|passwd|pwd|secret|api[_-]?key|bearer)\s*[:=]\s*['\"]?([^\s'\"]{6,})['\"]?")


def redact(s: str) -> str:
    if not s:
        return s
    for p, r in REDACTIONS:
        s = p.sub(r, s)
    s = KV.sub(lambda m: f"{m.group(1)}=[REDACTED:token]", s)
    return s


def norm_success(v, iterations):
    if isinstance(v, str) and v in ALLOWED_SUCCESS:
        return v
    if isinstance(iterations, (int, float)):
        if iterations <= 1:
            return "delivered_clean"
        if iterations <= 5:
            return "delivered_with_friction"
    return "partial"


def norm_cat(v):
    if v in ALLOWED_CATS:
        return v
    v_lc = (v or "").lower()
    for c in ALLOWED_CATS:
        if c in v_lc:
            return c
    return "ops"


def task_id(canonical_task: str) -> str:
    return hashlib.sha1(canonical_task.lower().encode()).hexdigest()[:10]


def compact_token_str(by_model: dict) -> str:
    parts = []
    for m, t in sorted(by_model.items(), key=lambda x: -(x[1]["input"] + x[1]["output"])):
        short = m.replace("claude-", "").replace("-20251101", "").replace("-20251001", "").replace("-20250929", "")
        parts.append(f"{short}:in={t['input']//1000}k/out={t['output']//1000}k/cread={t['cache_read']//1000}k")
    return "; ".join(parts)


def main() -> int:
    inv = json.loads(INV.read_text())
    by_path = {s["path"]: s for s in inv["sessions"]}

    # Load all analyses
    entries = []
    for f in sorted(ANALYSES.glob("*.json")):
        try:
            d = json.loads(f.read_text())
        except json.JSONDecodeError:
            print(f"skip malformed: {f}")
            continue
        cid = d.get("cluster_id") or f.stem
        for t in d.get("tasks", []) or []:
            iters = int(t.get("iterations") or 0)
            entries.append(
                {
                    "_cluster": cid,
                    "task": redact((t.get("task") or "").strip()),
                    "category": norm_cat(t.get("category")),
                    "success": norm_success(t.get("success"), iters),
                    "success_evidence": redact(str(t.get("success_evidence") or "")[:240]),
                    "iterations": iters,
                    "friction_points": [
                        {
                            "type": str(fp.get("type") or "")[:40],
                            "example": redact(str(fp.get("example") or "")[:200]),
                            "what_would_prevent": redact(str(fp.get("what_would_prevent") or "")[:240]),
                        }
                        for fp in (t.get("friction_points") or []) if isinstance(fp, dict)
                    ],
                    "frequency_signal": int(t.get("frequency_signal") or 0),
                    "session_refs": list(t.get("session_refs") or []),
                }
            )

    # Apply main-agent-supplied canonical merges if present
    merges = []
    drop_thin_singletons = False
    if MERGES.exists():
        _m = json.loads(MERGES.read_text())
        merges = _m.get("merges", [])
        drop_thin_singletons = bool(_m.get("drop_low_context_singletons"))

    # Build merge map: {(cluster_id, task_index) or raw task text → canonical_name}
    # Each merge entry: {"canonical": "<new sentence>", "category": "<cat>", "source_tasks": [{"cluster": cid, "match": "<substring>"}]}
    merged_index: dict[int, dict] = {}
    for m in merges:
        m_can = {
            "canonical": redact(m["canonical"].strip()),
            "category": norm_cat(m.get("category", "ops")),
            "source_idxs": [],
        }
        for s in m.get("source_tasks", []):
            cid = s.get("cluster")
            match = (s.get("match") or "").lower()
            for i, e in enumerate(entries):
                if e["_cluster"] == cid and (not match or match in e["task"].lower()):
                    merged_index[i] = m_can
        merges_applied = sum(1 for v in merged_index.values() if v is m_can)
        m_can["applied_count"] = merges_applied

    # Canonicalize each entry
    canonical: dict[str, dict] = {}
    for i, e in enumerate(entries):
        target = merged_index.get(i)
        if target:
            key = target["canonical"]
            cat = target["category"]
        else:
            key = e["task"]
            cat = e["category"]

        tid = task_id(key)
        c = canonical.setdefault(
            tid,
            {
                "task_id": tid,
                "task": key,
                "category": cat,
                "contributing_entries": [],
                "sessions": set(),
                "successes": [],
                "iterations_list": [],
                "friction_points": [],
            },
        )
        c["contributing_entries"].append(e)
        for s in e["session_refs"]:
            c["sessions"].add(s)
        c["successes"].append(e["success"])
        c["iterations_list"].append(e["iterations"])
        c["friction_points"].extend(e["friction_points"])

    # Compute rollups + token totals
    rows_csv = []
    rows_json = []
    for tid, c in canonical.items():
        sessions = list(c["sessions"])
        total = {"input": 0, "output": 0, "cache_read": 0, "cache_creation": 0}
        by_model: dict[str, dict] = {}
        last_mtime = 0
        for sp in sessions:
            s = by_path.get(sp)
            if not s:
                continue
            last_mtime = max(last_mtime, s["mtime"])
            tok = s["tokens"]
            for k in total:
                total[k] += tok[k]
            for m, bm in tok["by_model"].items():
                agg = by_model.setdefault(m, {"input": 0, "output": 0, "cache_read": 0, "cache_creation": 0})
                for k, v in bm.items():
                    agg[k] += v

        success_counts = {k: 0 for k in ALLOWED_SUCCESS}
        for s in c["successes"]:
            success_counts[s] += 1
        n = max(1, len(c["successes"]))
        avg_iters = round(sum(c["iterations_list"]) / n, 1) if n else 0

        # Top friction types
        fp_type_counts: dict[str, int] = {}
        for fp in c["friction_points"]:
            t = fp["type"].strip()
            if t:
                fp_type_counts[t] = fp_type_counts.get(t, 0) + 1
        top_friction = ", ".join(t for t, _ in sorted(fp_type_counts.items(), key=lambda x: -x[1])[:2])

        freq = len(sessions) if sessions else sum(max(1, e["frequency_signal"]) for e in c["contributing_entries"])

        row_csv = {
            "task_id": tid,
            "task": c["task"],
            "category": c["category"],
            "frequency": freq,
            "last_seen": __import__("datetime").datetime.fromtimestamp(last_mtime).strftime("%Y-%m-%d") if last_mtime else "",
            "success_clean_pct": round(100 * success_counts["delivered_clean"] / n, 0),
            "success_friction_pct": round(100 * success_counts["delivered_with_friction"] / n, 0),
            "success_partial_pct": round(100 * success_counts["partial"] / n, 0),
            "success_abandoned_pct": round(100 * success_counts["abandoned"] / n, 0),
            "avg_iterations": avg_iters,
            "top_friction": top_friction,
            "tokens_input": total["input"],
            "tokens_output": total["output"],
            "tokens_cache_read": total["cache_read"],
            "tokens_cache_creation": total["cache_creation"],
            "tokens_by_model": compact_token_str(by_model),
            "sample_session": sessions[0] if sessions else "",
        }
        rows_csv.append(row_csv)

        # Per-session detail for the explorer
        session_detail = []
        for sp in sorted(sessions, key=lambda p: by_path[p]["mtime"] if p in by_path else 0, reverse=True):
            s = by_path.get(sp)
            if not s:
                continue
            session_detail.append(
                {
                    "path": sp,
                    "kind": s["kind"],
                    "mtime": __import__("datetime").datetime.fromtimestamp(s["mtime"]).strftime("%Y-%m-%d %H:%M"),
                    "summary": s["summary"],
                    "turns": s["turns"],
                    "corrections": s["user_correction_count"],
                    "tokens": s["tokens"],
                }
            )
        row_json = dict(row_csv)
        row_json["contributing_clusters"] = sorted({e["_cluster"] for e in c["contributing_entries"]})
        row_json["friction_points"] = c["friction_points"][:10]
        row_json["sessions"] = session_detail
        row_json["by_model"] = by_model
        rows_json.append(row_json)

    # Drop thin-context singletons: canonical tasks whose contributing entries are all
    # frequency_signal=1 AND whose underlying sessions have a first_user_msg shorter than
    # 40 chars with no file-path / URL / structured marker. These are noise that the Haiku
    # could not generalise from.
    if drop_thin_singletons:
        kept_csv, kept_json = [], []
        dropped = 0
        for rc, rj in zip(rows_csv, rows_json):
            if rc["frequency"] > 1:
                kept_csv.append(rc); kept_json.append(rj); continue
            sess_paths = [s["path"] for s in rj.get("sessions", [])]
            thin = True
            for sp in sess_paths:
                s = by_path.get(sp)
                if not s: continue
                msg = (s.get("first_user_msg") or "").strip()
                has_path = any(marker in msg for marker in ("/", "://", "```", "<", "{"))
                if len(msg) >= 40 or has_path:
                    thin = False
                    break
            if thin:
                dropped += 1
                continue
            kept_csv.append(rc); kept_json.append(rj)
        rows_csv, rows_json = kept_csv, kept_json
        if dropped:
            print(f"dropped {dropped} thin-context singleton tasks")

    rows_csv.sort(key=lambda r: -r["frequency"])
    rows_json.sort(key=lambda r: -r["frequency"])

    # Write CSV
    with OUT_CSV.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows_csv[0].keys()))
        w.writeheader()
        for r in rows_csv:
            w.writerow(r)

    # Write JSON (for explorer)
    counts = inv["counts"]
    automation_breakdown: dict[str, int] = {}
    automation_examples: list[dict] = []
    for s in inv["sessions"]:
        if s["is_automation"]:
            reason = s["automation_reason"]
            automation_breakdown[reason] = automation_breakdown.get(reason, 0) + 1
            if len(automation_examples) < 20:
                automation_examples.append({"path": s["path"], "reason": reason, "summary": s["summary"]})

    profile = {
        "generated_at": inv["generated_at"],
        "window": inv["window"],
        "counts": counts,
        "automation_breakdown": automation_breakdown,
        "automation_examples": automation_examples,
        "tasks": rows_json,
    }
    OUT_JSON.write_text(json.dumps(profile, indent=2, default=str))

    print(f"wrote {OUT_CSV} ({len(rows_csv)} tasks) and {OUT_JSON}")
    total_tokens = sum(r["tokens_input"] + r["tokens_output"] + r["tokens_cache_read"] + r["tokens_cache_creation"] for r in rows_csv)
    print(f"total tokens across all tasks: {total_tokens:,}")
    print()
    print("top 10 tasks:")
    for r in rows_csv[:10]:
        print(f"  f={r['frequency']:>3} clean={r['success_clean_pct']:>3.0f}% friction={r['success_friction_pct']:>3.0f}% avg_i={r['avg_iterations']:>4.1f} tok={(r['tokens_input']+r['tokens_output']+r['tokens_cache_read'])//1000:>6}k | {r['task'][:80]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
