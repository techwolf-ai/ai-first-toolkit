"""Per-token cost calculation for Anthropic models.

Per-million-token list rates. See references/pricing.md for the source-of-truth table.
"""
from __future__ import annotations

# (input, output, cache_read, cache_write_5m) per million tokens, USD.
_RATES = {
    "opus":   (15.00, 75.00, 1.50, 18.75),
    "sonnet": ( 3.00, 15.00, 0.30,  3.75),
    "haiku":  ( 1.00,  5.00, 0.10,  1.25),
}

def _family(model: str) -> str:
    m = (model or "").lower()
    if "opus" in m:   return "opus"
    if "haiku" in m:  return "haiku"
    # default sonnet (most common, and a safe fallback)
    return "sonnet"

def rates_for(model: str) -> tuple[float, float, float, float]:
    return _RATES[_family(model)]

def cost_for_turn(
    model: str,
    input_tokens: int = 0,
    output_tokens: int = 0,
    cache_read: int = 0,
    cache_create: int = 0,
) -> float:
    inp, out, cr, cw = rates_for(model)
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
