"""Host-platform detection for the ai-adoption skills.

One mechanism, shared by every script that reads agent session history. An
identical copy ships in each skill's scripts/ dir so it travels with the script
under all install shapes (Claude Code native, Codex flat, Antigravity nested).

Resolution order (first hit wins):
  1. AI_FIRST_PLATFORM env var, if set to a known platform (explicit override).
  2. The "platform" field stamped into .techwolf-plugin.json by install.sh.
     The installer knows the target IDE (--ide codex|antigravity), so this is
     deterministic for Codex/Antigravity installs.
  3. Fallback: if ~/.claude exists, assume Claude Code. Claude Code uses the
     native plugin system and never runs install.sh, so it is never stamped.
  4. Default: "claude".

Per-platform session-data reality (see each skill's SKILL.md):
  - claude       Claude Code (~/.claude/projects) + Cowork transcripts. Full.
  - codex        ~/.codex/sessions/**/rollout-*.jsonl, plaintext JSONL with
                 cwd, model, token usage, and turns. Parseable (session-search
                 routes here).
  - antigravity  IDE conversations are AEAD-encrypted at rest
                 (~/.gemini/antigravity/conversations/*.pb); the unencrypted CLI
                 store (~/.gemini/antigravity-cli/conversations/*.db) carries no
                 parseable turn/token content. No honest analysis path -> degrade.
"""
from __future__ import annotations

import json
import os
from pathlib import Path

CLAUDE = "claude"
CODEX = "codex"
ANTIGRAVITY = "antigravity"
_VALID = {CLAUDE, CODEX, ANTIGRAVITY}


def _from_stamp() -> str | None:
    # scripts/ -> skill root holds .techwolf-plugin.json (written by install.sh).
    here = Path(__file__).resolve()
    for d in (here.parent, here.parent.parent, here.parent.parent.parent):
        stamp = d / ".techwolf-plugin.json"
        if not stamp.is_file():
            continue
        try:
            platform = json.loads(stamp.read_text(encoding="utf-8")).get("platform")
        except (json.JSONDecodeError, OSError):
            return None
        if isinstance(platform, str) and platform.lower() in _VALID:
            return platform.lower()
        return None
    return None


def detect_platform() -> str:
    env = os.environ.get("AI_FIRST_PLATFORM", "").strip().lower()
    if env in _VALID:
        return env
    stamped = _from_stamp()
    if stamped:
        return stamped
    return CLAUDE


_DEGRADE = {
    CODEX: (
        "this analysis is not available on Codex yet.\n"
        "  Codex sessions (~/.codex/sessions) are parseable, but this skill does not\n"
        "  read them yet. Run it under Claude Code. (session-search already supports\n"
        "  Codex.)"
    ),
    ANTIGRAVITY: (
        "session analysis is not available on Antigravity.\n"
        "  Antigravity stores IDE conversations encrypted at rest\n"
        "  (~/.gemini/antigravity/conversations/*.pb, AEAD), and its unencrypted CLI\n"
        "  store carries no parseable turn/token content. There is no honest local\n"
        "  data path to analyse. Run this skill under Claude Code."
    ),
}


def degrade(skill: str, platform: str | None = None) -> None:
    """Print a clear, platform-specific 'not available' message and exit 0.

    Degrading is not an error: the skill simply isn't available on this host.
    """
    platform = platform or detect_platform()
    print(f"{skill}: {_DEGRADE.get(platform, f'not available on {platform}.')}")
    raise SystemExit(0)


def require_claude(skill: str) -> str:
    """Return the platform if Claude; otherwise degrade. For skills that only
    support Claude transcripts today (token-doctor, task-profile)."""
    platform = detect_platform()
    if platform == CLAUDE:
        return platform
    degrade(skill, platform)
