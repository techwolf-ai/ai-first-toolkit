"""Per-token cost calculation.

Per-million-token list rates, USD: (input, output, cache_read, cache_write_5m).

Anthropic rates: see references/pricing.md.
OpenAI rates (for Codex sessions): public list prices, verified 2026-06.
  gpt-5.4       $2.50 in / $15.00 out / $0.25 cached-in   (cache_write n/a)
  gpt-5.4-mini  $0.75 in / $4.50  out / $0.075 cached-in
  gpt-5.4-nano  $0.20 in / $1.20  out / $0.02 cached-in
  Source: openai.com/api/pricing (gpt-5.4 family). Update when rates change.

Unknown models return no rate, and cost_for_usage() yields 0.0 so the caller can
show token counts without a fabricated dollar figure.
"""
from __future__ import annotations

# (input, output, cache_read, cache_write_5m) per million tokens, USD.
_RATES = {
    # Anthropic
    "opus":   (15.00, 75.00, 1.50, 18.75),
    "sonnet": ( 3.00, 15.00, 0.30,  3.75),
    "haiku":  ( 1.00,  5.00, 0.10,  1.25),
    # OpenAI (Codex). cache_write n/a -> 0.0.
    "gpt-5-nano": (0.20,  1.20, 0.02, 0.0),
    "gpt-5-mini": (0.75,  4.50, 0.075, 0.0),
    "gpt-5":      (2.50, 15.00, 0.25, 0.0),
}


def _family(model: str) -> str | None:
    m = (model or "").lower()
    # OpenAI / Codex
    if "gpt" in m or m.startswith("o1") or m.startswith("o3") or m.startswith("o4"):
        if "nano" in m:
            return "gpt-5-nano"
        if "mini" in m:
            return "gpt-5-mini"
        return "gpt-5"
    # Anthropic. Empty/"unknown" keeps the historical sonnet default (Claude
    # transcripts occasionally omit the model id).
    if "opus" in m:
        return "opus"
    if "haiku" in m:
        return "haiku"
    if "claude" in m or m in ("", "unknown"):
        return "sonnet"
    return None


def rates_for(model: str) -> tuple[float, float, float, float] | None:
    fam = _family(model)
    return _RATES[fam] if fam else None


def cost_for_turn(
    model: str,
    input_tokens: int = 0,
    output_tokens: int = 0,
    cache_read: int = 0,
    cache_create: int = 0,
) -> float:
    rates = rates_for(model)
    if rates is None:
        return 0.0
    inp, out, cr, cw = rates
    return (
        input_tokens   / 1e6 * inp +
        output_tokens  / 1e6 * out +
        cache_read     / 1e6 * cr  +
        cache_create   / 1e6 * cw
    )


def cost_for_usage(model: str, usage: dict) -> float:
    return cost_for_turn(
        model,
        input_tokens=int(usage.get("input") or 0),
        output_tokens=int(usage.get("output") or 0),
        cache_read=int(usage.get("cache_read") or 0),
        cache_create=int(usage.get("cache_creation") or usage.get("cache_create") or 0),
    )
