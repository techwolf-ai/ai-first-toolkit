# Pricing table

Per-million-token list rates from Anthropic, last verified 2026-05-12. These are the rates the deterministic cost calculator uses. Token-doctor reports list-price equivalent (your actual billing may differ if you're on a fixed-cost plan; the report makes the list-price equivalent visible).

| Model family | Input ($/M) | Output ($/M) | Cache read ($/M) | Cache write 5m ($/M) | Cache write 1h ($/M) |
|---|---:|---:|---:|---:|---:|
| Opus 4.x (`claude-opus-4-*`) | 15.00 | 75.00 | 1.50 | 18.75 | 30.00 |
| Sonnet 4.x (`claude-sonnet-4-*`) | 3.00 | 15.00 | 0.30 | 3.75 | 6.00 |
| Haiku 4.x (`claude-haiku-4-*`) | 1.00 | 5.00 | 0.10 | 1.25 | 2.00 |

`scripts/pricing.py` exposes a single helper:

```python
from pricing import cost_for_turn

cost = cost_for_turn(
    model="claude-sonnet-4-6",
    input_tokens=120,
    output_tokens=850,
    cache_read=42_000,
    cache_create=8_500,
)
```

The helper maps any model id to a family by prefix match. Unknown models fall back to Sonnet rates with a logged warning.

The 1M-context tier suffix (`[1m]`) does not change the per-token rate; only the maximum window. Token-doctor treats `claude-opus-4-7[1m]` as `claude-opus-4-7`.

## Cache_create rate

The default is the 5-minute ephemeral cache rate (1.25× input). If a session uses 1h caching (rare; opt-in via beta header), the cost calculator will undercount. We accept this for now; the deviation is small (under 5% for typical sessions).
