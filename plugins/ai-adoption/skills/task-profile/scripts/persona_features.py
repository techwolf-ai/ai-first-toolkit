#!/usr/bin/env python3
"""Build out/persona-features.json from profile.json + inventory.json.

Stdlib-only, pure calculation. The main agent reads this alongside the
other outputs and picks a persona + modifier; this script never does.
"""
from __future__ import annotations

import json
import re
import statistics
from collections import Counter
from datetime import datetime
from pathlib import Path

PROFILE = Path("out/profile.json")
INVENTORY = Path("out/inventory.json")
OUT = Path("out/persona-features.json")

MCP_RE = re.compile(r"mcp__([A-Za-z0-9_]+?)__")
CATEGORIES = ("engineering", "research", "writing", "ops", "analysis", "planning", "communication")


def _safe_pct(num: float, denom: float) -> float:
    return round(100 * num / denom, 1) if denom else 0.0


def _tokens_all(toks: dict) -> int:
    return sum((toks.get(k) or 0) for k in ("input", "output", "cache_read", "cache_creation"))


def main() -> int:
    if not PROFILE.exists():
        print(f"error: {PROFILE} missing. Run write_profile.py first.")
        return 1

    profile = json.loads(PROFILE.read_text())
    inv = json.loads(INVENTORY.read_text()) if INVENTORY.exists() else None

    tasks = profile.get("tasks") or []
    counts = profile.get("counts") or {}
    window = profile.get("window") or {}

    # ── per-session aggregation across all tasks ─────────────────
    session_kind: dict[str, str] = {}
    session_turns: list[int] = []
    session_tokens: dict[str, int] = {}
    session_mtime: dict[str, float] = {}

    for t in tasks:
        for s in t.get("sessions") or []:
            p = s["path"]
            if p in session_kind:
                continue
            session_kind[p] = s.get("kind", "code")
            session_turns.append(int(s.get("turns") or 0))
            session_tokens[p] = _tokens_all(s.get("tokens") or {})
            mt = s.get("mtime")
            if isinstance(mt, str):
                try:
                    session_mtime[p] = datetime.strptime(mt, "%Y-%m-%d %H:%M").timestamp()
                except ValueError:
                    pass

    total_sessions = counts.get("interactive") or len(session_kind)
    code_sessions = sum(1 for k in session_kind.values() if k == "code")
    cowork_sessions = sum(1 for k in session_kind.values() if k == "cowork")

    code_tokens = sum(v for p, v in session_tokens.items() if session_kind.get(p) == "code")
    cowork_tokens = sum(v for p, v in session_tokens.items() if session_kind.get(p) == "cowork")
    total_tokens = code_tokens + cowork_tokens or 1

    # ── category token distribution ──────────────────────────────
    cat_tokens: dict[str, int] = {c: 0 for c in CATEGORIES}
    for t in tasks:
        c = t.get("category") or "ops"
        cat_tokens[c] = cat_tokens.get(c, 0) + sum(
            (t.get(k) or 0) for k in ("tokens_input", "tokens_output", "tokens_cache_read", "tokens_cache_creation")
        )
    cat_share = {c: round(v / total_tokens, 3) for c, v in cat_tokens.items()}
    active_categories = sum(1 for v in cat_share.values() if v >= 0.08)

    # ── model mix ────────────────────────────────────────────────
    model_tokens: dict[str, int] = {}
    for t in tasks:
        for m, v in (t.get("by_model") or {}).items():
            model_tokens[m] = model_tokens.get(m, 0) + _tokens_all(v)
    model_tokens = dict(sorted(model_tokens.items(), key=lambda kv: -kv[1]))
    distinct_models_gt5pct = sum(1 for v in model_tokens.values() if v / total_tokens >= 0.05)
    opus_tokens = sum(v for m, v in model_tokens.items() if "opus" in m.lower())
    opus_share = round(opus_tokens / total_tokens, 3)

    # ── success + iteration signal across the top-10 tasks ───────
    top10 = sorted(tasks, key=lambda t: -(t.get("frequency") or 0))[:10]
    avg_clean = round(statistics.fmean(t.get("success_clean_pct") or 0 for t in top10), 1) if top10 else 0.0
    avg_friction = round(statistics.fmean(t.get("success_friction_pct") or 0 for t in top10), 1) if top10 else 0.0
    avg_iter = round(statistics.fmean(t.get("avg_iterations") or 0 for t in top10), 1) if top10 else 0.0

    median_turns = statistics.median(session_turns) if session_turns else 0
    max_turns = max(session_turns) if session_turns else 0
    long_sessions = sum(1 for t in session_turns if t >= 100)

    # ── cwd diversity (code sessions only; cowork cwds are generic) ──
    code_cwds: set[str] = set()
    for t in tasks:
        for s in t.get("sessions") or []:
            if s.get("kind") == "code":
                # recover cwd by walking parent path of jsonl; profile already has cwd via inventory if we joined
                pass
    # Fall back to reading the inventory for cwd data, easier and accurate
    distinct_cwds = 0
    if inv:
        code_cwd_set = {
            s.get("cwd") for s in (inv.get("sessions") or [])
            if s.get("kind") == "code" and s.get("cwd") and not s.get("is_automation")
        }
        distinct_cwds = len(code_cwd_set)

    # ── MCP discovery: scan condensate texts and first-user-msg for mcp__NAME__ prefixes ──
    mcp_counter: Counter[str] = Counter()
    if inv:
        for s in inv.get("sessions") or []:
            if s.get("is_automation"):
                continue
            haystack = [s.get("first_user_msg") or ""]
            for pick in (s.get("condensate") or {}).get("picks") or []:
                haystack.append(pick.get("text") or "")
            for m in MCP_RE.finditer(" ".join(haystack)):
                mcp_counter[m.group(1)] += 1
    distinct_mcps = len(mcp_counter)
    top_mcps = [{"name": k, "mentions": v} for k, v in mcp_counter.most_common(10)]

    # ── automation breakdown (visible in profile.json) ───────────
    auto_break = profile.get("automation_breakdown") or {}
    scheduled_run_count = sum(v for k, v in auto_break.items() if k.startswith("scheduled-task"))
    sdk_cli_count = auto_break.get("entrypoint:sdk-cli", 0)
    ditto_count = auto_break.get("ditto-routine", 0)

    # ── time window ──────────────────────────────────────────────
    mtimes = sorted(session_mtime.values())
    first_date = datetime.fromtimestamp(mtimes[0]).strftime("%Y-%m-%d") if mtimes else None
    last_date = datetime.fromtimestamp(mtimes[-1]).strftime("%Y-%m-%d") if mtimes else None

    # ── cache ratio ──────────────────────────────────────────────
    total_cache = sum(t.get("tokens_cache_read") or 0 for t in tasks)
    cache_ratio = round(total_cache / total_tokens, 3) if total_tokens else 0.0

    # ── opener signals (long first user messages = Architect hint) ──
    opener_chars: list[int] = []
    if inv:
        for s in inv.get("sessions") or []:
            if s.get("is_automation"):
                continue
            opener_chars.append(len(s.get("first_user_msg") or ""))
    median_opener_chars = int(statistics.median(opener_chars)) if opener_chars else 0

    # ── top 3 tasks ──────────────────────────────────────────────
    top3 = [{"task": t["task"], "frequency": t["frequency"]} for t in tasks[:3]]

    # ── output ───────────────────────────────────────────────────
    out = {
        "_note": "Deterministic feature sheet. Main agent reads this + personas.md to pick a persona and write a blurb. See SKILL.md Phase G.",
        "window": window,
        "total_sessions": total_sessions,
        "code_sessions": code_sessions,
        "cowork_sessions": cowork_sessions,
        "total_tokens": total_tokens,
        "code_token_share": round(code_tokens / total_tokens, 3),
        "cowork_token_share": round(cowork_tokens / total_tokens, 3),
        "tokens_by_category": cat_share,
        "active_categories_8pct": active_categories,
        "model_tokens": {m: v for m, v in model_tokens.items()},
        "distinct_models_gt5pct": distinct_models_gt5pct,
        "opus_share": opus_share,
        "avg_clean_pct_top10": avg_clean,
        "avg_friction_pct_top10": avg_friction,
        "avg_iter_top10": avg_iter,
        "median_turns": median_turns,
        "max_turns": max_turns,
        "long_sessions_ge100_turns": long_sessions,
        "distinct_cwds_code": distinct_cwds,
        "distinct_mcps": distinct_mcps,
        "top_mcps": top_mcps,
        "scheduled_run_count": scheduled_run_count,
        "sdk_cli_count": sdk_cli_count,
        "ditto_routine_count": ditto_count,
        "cache_ratio": cache_ratio,
        "median_opener_chars": median_opener_chars,
        "first_session_date": first_date,
        "last_session_date": last_date,
        "top3_tasks": top3,
    }
    OUT.write_text(json.dumps(out, indent=2))
    print(f"wrote {OUT}")
    # Brief highlights for the operator
    print(f"  sessions: {total_sessions} ({code_sessions} code, {cowork_sessions} cowork)")
    print(f"  tokens:   {total_tokens:,} | code {code_tokens/total_tokens*100:.0f}% / cowork {cowork_tokens/total_tokens*100:.0f}%")
    print(f"  top cats: {', '.join(f'{c} {int(v*100)}%' for c,v in sorted(cat_share.items(), key=lambda kv:-kv[1])[:3])}")
    print(f"  MCPs:     {distinct_mcps} distinct")
    print(f"  models:   {distinct_models_gt5pct} above 5% share | Opus {opus_share*100:.0f}%")
    print(f"  automation runs: {scheduled_run_count} scheduled, {sdk_cli_count} sub-agent, {ditto_count} ditto")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
