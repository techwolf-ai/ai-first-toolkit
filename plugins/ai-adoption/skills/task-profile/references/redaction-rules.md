# Redaction rules

Applied by a single `redact(text)` function in the scripts. Runs on every piece of text that will:

- Be dispatched to a Haiku subagent.
- Be written to `out/profile.csv`, `out/explorer.html`, or `out/skill-proposals.md`.

Redaction is text-only. Paths, cwd names, session titles pass through untouched, they're often the user's project names which are not sensitive and removing them breaks usefulness.

## Replacement token format

`[REDACTED:<type>]`

Types: `api_key`, `token`, `jwt`, `private_key`, `email`, `phone`, `card`, `iban`.

## Patterns

### Credentials / API keys
- `sk-[A-Za-z0-9\-_]{20,}` → `[REDACTED:api_key]`
- `ghp_[A-Za-z0-9]{30,}` → `[REDACTED:token]`
- `ghs_[A-Za-z0-9]{30,}` → `[REDACTED:token]`
- `github_pat_[A-Za-z0-9_]{20,}` → `[REDACTED:token]`
- `xox[baprs]-[A-Za-z0-9-]{10,}` → `[REDACTED:token]` (Slack)
- `AIza[A-Za-z0-9\-_]{30,}` → `[REDACTED:api_key]` (Google)
- `AKIA[A-Z0-9]{16}` → `[REDACTED:api_key]` (AWS)
- `eyJ[A-Za-z0-9_\-]+\.eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+` → `[REDACTED:jwt]`
- `(?i)(password|passwd|pwd|secret|api[_-]?key|bearer)\s*[:=]\s*['"]?([^\s'"]+)['"]?` → keep the key name, replace the value: `$1=[REDACTED:token]`

### Private keys
- `-----BEGIN [A-Z ]+ PRIVATE KEY-----[\s\S]*?-----END [A-Z ]+ PRIVATE KEY-----` → `[REDACTED:private_key]`

### Emails
Every email matching `[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}` gets its local part replaced:
- Input: `first.last@example.com` → `[REDACTED:email]@example.com`
- Keep the domain so the context survives (`"an @example.com user asked"`).

### Phone numbers
Only when clearly a phone (low false-positive strategy):
- Match: within 20 characters preceding the number, one of `phone`, `tel`, `call`, `mobile`, `sms`, `whatsapp` appears.
- Number shape: `\+?\d[\d\s\-().]{7,}\d`
- Replace the number with `[REDACTED:phone]`.

### Credit cards
- Any 13–19 digit run (optionally dash- or space-separated in groups of 4) that passes the Luhn checksum → `[REDACTED:card]`.

### IBAN
- `[A-Z]{2}\d{2}[A-Z0-9]{10,30}` → `[REDACTED:iban]`.

## Conservative bias

False positives are cheap here, a person reading the output sees `[REDACTED:…]` and moves on. False negatives (a secret that leaks) are not. When a regex is close but uncertain, keep it in the rule set.

## Final manual-review prompt

After all output files are written, the skill lists the **top-100 highest-entropy tokens** in `profile.csv` and `explorer.html` for the user to scan. A high-entropy random-looking string that didn't match any pattern is the most likely way something sensitive slipped through. The skill does not mark itself complete until the user confirms the scan.

Entropy here means Shannon entropy of the byte distribution of each whitespace-separated token of length ≥ 16, filtered to tokens with mixed case + digits (typical key shapes).
