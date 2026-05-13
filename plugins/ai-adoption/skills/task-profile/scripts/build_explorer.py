#!/usr/bin/env python3
"""Build out/explorer.html from profile.json, coaching-panel.json, skill-proposals.json.

Self-contained light theme (bg #FAFAFA, dark #090D1F, aquamarine accent #62FFD8,
purple-link accent #8097F3). Work Sans for headings, Geist for body, JetBrains Mono
for numerics. Progressive disclosure, categories open to tasks, tasks open to detail,
coaching and proposals collapse.
"""
from __future__ import annotations

import json
from pathlib import Path

PROFILE = Path("out/profile.json")
COACHING = Path("out/coaching-panel.json")
SKILL_PROPOSALS = Path("out/skill-proposals.json")
PERSONA = Path("out/persona.json")
OUT = Path("out/explorer.html")

# Generic fallback glyph when no branded logo is available.
GENERIC_GLYPH = (
    '<svg viewBox="0 0 40 40" width="32" height="32" role="img" aria-label="Task profile">'
    '<rect x="1" y="1" width="38" height="38" rx="8" fill="#090D1F"/>'
    '<path d="M12 20 L18 26 L29 14" fill="none" stroke="#62FFD8" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>'
)

# Logo lives alongside the script inside the skill bundle (./assets/logo.svg relative
# to this file). Portable: copies travel with the skill, no external dependency.
SKILL_DIR = Path(__file__).resolve().parent.parent
BUNDLED_LOGO = SKILL_DIR / "assets" / "logo.svg"


def load_logo() -> str:
    if BUNDLED_LOGO.is_file():
        svg = BUNDLED_LOGO.read_text()
        return svg.replace("<svg", '<svg style="height:16px;width:auto;" ', 1)
    return GENERIC_GLYPH


def main() -> int:
    import argparse
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument(
        "--allow-empty",
        action="store_true",
        help="Render explorer.html even when coaching-panel.json or skill-proposals.json are missing. "
             "By default the script refuses to build an explorer with blank coaching/proposal sections, "
             "those are main-agent judgment outputs that must not be silently skipped.",
    )
    args = p.parse_args()

    if not PROFILE.exists():
        print(f"error: {PROFILE} missing, run inventory.py + write_profile.py first.", flush=True)
        return 1

    missing = [f for f in (COACHING, SKILL_PROPOSALS, PERSONA) if not f.exists()]
    if missing and not args.allow_empty:
        print(
            "error: the following main-agent outputs are missing:\n"
            + "\n".join(f"  - {m}" for m in missing)
            + "\n\nThese are mandatory parts of the explorer output, main-agent judgment work "
              "(Phases E + G of SKILL.md), not optional. Produce them before running build_explorer.py.\n"
              "  · coaching-panel.json, 3–5 AI-first habit cards with session-path evidence. "
              "See references/ai-first-principles.md for the card shape.\n"
              "  · skill-proposals.json, up to 5 task-centric skills each impacting ≥ 2 top tasks. "
              "Read the existing skill inventory first to avoid overlap.\n"
              "  · persona.json, one persona from references/personas.md with tailored blurb. "
              "Run scripts/persona_features.py first to get the feature sheet.\n\n"
              "Override with --allow-empty only if you explicitly want to ship an explorer with blank panels.",
            flush=True,
        )
        return 2

    profile = json.loads(PROFILE.read_text())
    coaching = json.loads(COACHING.read_text()) if COACHING.exists() else {"cards": []}
    skill_proposals = json.loads(SKILL_PROPOSALS.read_text()) if SKILL_PROPOSALS.exists() else {"proposals": []}
    persona = json.loads(PERSONA.read_text()) if PERSONA.exists() else None

    if not (coaching.get("cards") or []):
        print("warning: coaching-panel.json has no cards, explorer will render an empty coaching section.", flush=True)
    if not (skill_proposals.get("proposals") or []):
        print("warning: skill-proposals.json has no proposals, explorer will render an empty proposals section.", flush=True)

    # Gate: skill proposals must have done the installed-skill pre-check (SKILL.md Phase E.2).
    # Without this check, proposals drift toward generic "build a memo / prep a meeting" shapes
    # that duplicate skills the user already has installed.
    proposals_list = skill_proposals.get("proposals") or []
    if proposals_list and not args.allow_empty:
        missing_precheck = "_installed_skills_checked" not in skill_proposals
        missing_fields = []
        for i, p in enumerate(proposals_list):
            for required in ("modelled_after", "overlaps_considered"):
                if required not in p:
                    missing_fields.append(f"proposals[{i}].{required}")
        if missing_precheck or missing_fields:
            print(
                "error: skill-proposals.json did not run the installed-skill pre-check required by "
                "Phase E.2 of SKILL.md. Without it, proposals duplicate skills the user already has.\n"
                + (f"  - missing top-level `_installed_skills_checked`\n" if missing_precheck else "")
                + ("".join(f"  - missing `{f}`\n" for f in missing_fields) if missing_fields else "")
                + "\nRe-run Phase E.2: enumerate installed skills first, then propose only skills that "
                  "are genuinely distinct. Populate `modelled_after` (which installed skill inspired this) "
                  "and `overlaps_considered` (which installed skills cover adjacent territory + why the "
                  "proposal is still distinct) for every proposal, and add `_installed_skills_checked` at "
                  "the top level listing the skills you enumerated.\n"
                  "Override with --allow-empty only for debugging.",
                flush=True,
            )
            return 3
    if persona is None:
        print("warning: persona.json missing, explorer will omit the persona card.", flush=True)

    # Bundle the persona emblem SVG alongside the persona data.
    emblem_svg = ""
    if persona is not None:
        try:
            from persona_emblems import get as get_emblem
        except ImportError:
            import sys as _sys
            _sys.path.insert(0, str(Path(__file__).resolve().parent))
            from persona_emblems import get as get_emblem
        emblem_svg = get_emblem(persona.get("id", "explorer"))

    data = {
        "profile": profile,
        "coaching": coaching,
        "skill_proposals": skill_proposals,
        "persona": persona,
        "emblem_svg": emblem_svg,
    }
    html = TEMPLATE.replace("__DATA_JSON__", json.dumps(data)).replace("__LOGO_SVG__", load_logo())
    OUT.write_text(html)
    print(f"wrote {OUT} ({OUT.stat().st_size:,} bytes)")
    return 0


TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Task profile</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Work+Sans:ital,wght@0,400;0,500;0,600;0,700;1,400;1,500&family=Geist:wght@300;400;500;600&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js"></script>
<style>
/* ─── palette ─── */
:root {
  --bg:             #FAFAFA;
  --bg-secondary:   #F3F3F2;
  --bg-card:        #FFFFFF;
  --dark:           #090D1F;
  --dark-secondary: #15192A;
  --grey:           #5B607B;
  --grey-alt:       #AFB4CB;
  --grey-10:        rgba(132,135,150,.10);
  --grey-30:        rgba(132,135,150,.30);
  --border:         rgba(9,13,31,.10);
  --border-strong:  rgba(9,13,31,.18);

  --green:          #62FFD8;
  --green-light:    #8DFFE3;
  --purple:         #90A0E0;
  --purple-link:    #8097F3;
  /* Accent text on light bg uses purple-link. --green-text is aliased so
     existing rules continue to work. */
  --green-text:     var(--purple-link);
  --lila:           #E3E6F5;
  --lila-50:        rgba(227,230,245,.5);
  --yellow:         #FCC264;

  --radius:         .5rem;       /* 8px */
  --radius-sm:      .25rem;      /* 4px */
  --radius-pill:    999px;

  --font-title: "Work Sans", -apple-system, BlinkMacSystemFont, sans-serif;
  --font-body:  "Geist", -apple-system, BlinkMacSystemFont, sans-serif;
  --font-mono:  "JetBrains Mono", ui-monospace, Menlo, monospace;

  --shadow-soft: 0 1px 2px rgba(9,13,31,.04);
  --shadow-card: 0 2px 4px rgba(9,13,31,.03), 0 8px 24px rgba(9,13,31,.05);
}

* { box-sizing: border-box; }
html, body {
  margin: 0; padding: 0;
  background: var(--bg);
  color: var(--dark);
  font-family: var(--font-body);
  font-weight: 400;
  font-size: 16px;
  line-height: 1.55;
  -webkit-font-smoothing: antialiased;
}

/* ─── page shell ─── */
.page { max-width: 1180px; margin: 0 auto; padding: 48px 48px 140px; }

/* ─── header ─── */
.header {
  display: flex; align-items: center; justify-content: space-between; gap: 32px;
  padding-bottom: 16px; border-bottom: 1px solid var(--border);
}
.header .mark { display: flex; align-items: center; gap: 18px; }
.header .mark svg { display: block; }
.header .mark .sep {
  width: 1px; height: 18px; background: var(--border-strong);
}
.header .mark .title {
  font-family: var(--font-title);
  font-weight: 500;
  color: var(--grey);
  font-size: 14px;
  letter-spacing: 0;
}
.header .meta { color: var(--grey); font-size: 13px; font-family: var(--font-mono); }

/* ─── hero ─── */
.hero { padding: 56px 0 40px; max-width: 880px; }
.hero h1 {
  font-family: var(--font-title);
  font-weight: 600;
  font-size: 56px;
  line-height: 1.05;
  letter-spacing: -0.03em;
  color: var(--dark);
  margin: 0 0 20px;
}
.hero h1 em {
  font-style: normal;
  color: var(--purple-link);
}
.hero .lead { color: var(--grey); font-size: 19px; line-height: 1.5; max-width: 680px; }

/* ─── stats strip ─── */
.stats {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 1px;
  background: var(--border);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  margin: 32px 0 0;
  overflow: hidden;
}
.stat { background: var(--bg-card); padding: 22px 26px; }
.stat .v {
  font-family: var(--font-title);
  font-weight: 600;
  font-size: 36px;
  line-height: 1;
  letter-spacing: -0.02em;
  color: var(--dark);
  font-feature-settings: "tnum";
}
.stat .l {
  color: var(--grey); font-size: 13px; margin-top: 8px;
  font-family: var(--font-body);
}

/* ─── section ─── */
.section { margin-top: 64px; }
.section-head {
  margin-bottom: 20px;
  padding-bottom: 14px;
  border-bottom: 1px solid var(--border);
  display: flex; align-items: baseline; justify-content: space-between; gap: 24px;
}
.section-head h2 {
  font-family: var(--font-title);
  font-size: 26px; font-weight: 600;
  color: var(--dark); margin: 0;
  letter-spacing: -0.02em;
}
.section-head .tagline { color: var(--grey); font-size: 14px; max-width: 440px; text-align: right; line-height: 1.5; }

/* ─── card ─── */
.card {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  box-shadow: var(--shadow-soft);
}
.card.pad { padding: 24px 28px; }
h3 { font-family: var(--font-title); font-size: 17px; font-weight: 600; color: var(--dark); margin: 0 0 8px; letter-spacing: -0.01em; }
h4 { font-family: var(--font-title); font-size: 12px; font-weight: 600; color: var(--grey); margin: 18px 0 8px; text-transform: uppercase; letter-spacing: 0.08em; }
h4:first-child { margin-top: 0; }
.muted { color: var(--grey); }

/* ─── token chart (by category) ─── */
.chart-card { padding: 24px 28px; }
.chart-legend { display: flex; gap: 18px; font-size: 12px; color: var(--grey); margin: 4px 0 18px; }
.chart-legend i { width: 10px; height: 10px; border-radius: 2px; display: inline-block; margin-right: 6px; vertical-align: 1px; }
.chart-legend .code { background: var(--green); border: 1px solid var(--purple-link); }
.chart-legend .cowork { background: var(--purple); }
.chart-row { display: grid; grid-template-columns: 140px 1fr 96px; gap: 18px; align-items: center; padding: 7px 0; font-size: 14px; }
.chart-row .cat-lbl { color: var(--dark); text-transform: capitalize; font-weight: 500; }
.chart-row .bar { height: 12px; display: flex; border-radius: 3px; overflow: hidden; background: var(--bg-secondary); }
.chart-row .seg { height: 100%; }
.chart-row .seg.code   { background: var(--green); }
.chart-row .seg.cowork { background: var(--purple); }
.chart-row .total { font-family: var(--font-mono); font-size: 12px; color: var(--grey); text-align: right; font-feature-settings: "tnum"; }

/* ─── category accordion ─── */
.cats { display: flex; flex-direction: column; gap: 10px; }
.cat {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  box-shadow: var(--shadow-soft);
  overflow: hidden;
  transition: border-color .15s;
}
.cat[open] { border-color: var(--border-strong); box-shadow: var(--shadow-card); }
.cat > summary {
  list-style: none;
  cursor: pointer;
  padding: 20px 28px;
  display: grid;
  grid-template-columns: 16px 12px minmax(0, 1fr) 90px 110px 110px;
  gap: 20px;
  align-items: center;
}
.cat > summary::-webkit-details-marker { display: none; }
.cat > summary .chev {
  width: 10px; height: 10px;
  border-right: 2px solid var(--dark);
  border-bottom: 2px solid var(--dark);
  transform: rotate(-45deg);
  transition: transform .2s ease;
  justify-self: center;
}
.cat[open] > summary .chev { transform: rotate(45deg); }
.cat > summary .dot { width: 10px; height: 10px; border-radius: 50%; justify-self: center; }
.cat > summary .name { font-family: var(--font-title); font-weight: 600; font-size: 17px; color: var(--dark); text-transform: capitalize; letter-spacing: -0.01em; }
.cat > summary .metric {
  font-family: var(--font-mono); font-size: 12px; color: var(--grey); text-align: right;
  font-feature-settings: "tnum";
}
.cat > summary .metric b { color: var(--dark); font-weight: 500; }

.cat > .cat-body { border-top: 1px solid var(--border); background: var(--bg-secondary); }

/* ─── tasks list inside a category ─── */
.tasks { display: flex; flex-direction: column; }
.task { border-bottom: 1px solid var(--border); transition: background .15s; }
.task:last-child { border-bottom: 0; }
.task > summary {
  list-style: none;
  cursor: pointer;
  padding: 14px 28px 14px 56px;
  display: grid;
  grid-template-columns: 14px minmax(0, 1fr) 70px 70px 80px 90px;
  gap: 20px;
  align-items: center;
}
.task > summary::-webkit-details-marker { display: none; }
.task:hover > summary { background: var(--bg-card); }
.task[open] > summary { background: var(--bg-card); }
.task > summary .chev {
  width: 8px; height: 8px;
  border-right: 1.5px solid var(--grey);
  border-bottom: 1.5px solid var(--grey);
  transform: rotate(-45deg);
  justify-self: center;
  transition: transform .2s ease;
}
.task[open] > summary .chev { transform: rotate(45deg); }
.task > summary .title {
  font-size: 15px; color: var(--dark); font-weight: 400; line-height: 1.45;
  overflow: hidden;
}
.task > summary .m {
  font-family: var(--font-mono); font-size: 12px; color: var(--grey);
  text-align: right; font-feature-settings: "tnum";
}
.task > summary .m b { color: var(--dark); font-weight: 500; }
.task > summary .m.clean-good b { color: var(--green-text); }
.task > summary .m.clean-bad b  { color: #B54E20; }

.task > .detail {
  padding: 20px 28px 26px 56px;
  background: var(--bg-card);
  border-top: 1px solid var(--border);
}
.task > .detail h5 {
  font-family: var(--font-title);
  font-size: 11px; font-weight: 600;
  color: var(--grey);
  text-transform: uppercase; letter-spacing: 0.1em;
  margin: 18px 0 8px;
}
.task > .detail h5:first-child { margin-top: 0; }
.task > .detail .fps { display: flex; flex-direction: column; gap: 10px; }
.task > .detail .fp {
  padding: 12px 16px;
  background: var(--bg-secondary);
  border-radius: var(--radius-sm);
  border-left: 3px solid var(--green-text);
  font-size: 13px;
}
.task > .detail .fp .t { color: var(--dark); font-weight: 600; font-family: var(--font-title); font-size: 13px; }
.task > .detail .fp .e { color: var(--grey); font-style: italic; margin-top: 4px; }
.task > .detail .fp .p { color: var(--green-text); margin-top: 6px; font-weight: 500; }
.task > .detail .mdl-tbl { width: 100%; border-collapse: collapse; font-size: 12px; }
.task > .detail .mdl-tbl th {
  text-align: right; padding: 6px 12px 6px 0;
  color: var(--grey); font-weight: 500; font-size: 10px;
  text-transform: uppercase; letter-spacing: 0.08em;
  border-bottom: 1px solid var(--border);
  font-family: var(--font-title);
}
.task > .detail .mdl-tbl td {
  text-align: right; padding: 7px 12px 7px 0;
  color: var(--dark); font-family: var(--font-mono); font-feature-settings: "tnum";
  border-bottom: 1px solid var(--border);
}
.task > .detail .mdl-tbl th:first-child,
.task > .detail .mdl-tbl td:first-child { text-align: left; color: var(--grey); }
.task > .detail .sessions {
  font-family: var(--font-mono); font-size: 11px; color: var(--grey);
  max-height: 220px; overflow-y: auto;
  padding: 12px 14px;
  background: var(--bg-secondary);
  border-radius: var(--radius-sm);
}
.task > .detail .sessions div { padding: 3px 0; border-bottom: 1px solid var(--border); }
.task > .detail .sessions div:last-child { border: 0; }
.task > .detail .sessions b { color: var(--dark); font-weight: 500; }
.task > .detail .meta-strip {
  margin-top: 14px;
  font-size: 12px; color: var(--grey);
  display: flex; gap: 24px; flex-wrap: wrap;
}
.task > .detail .meta-strip b { color: var(--dark); font-weight: 500; }

/* ─── coaching ─── */
.coach { display: flex; flex-direction: column; gap: 10px; }
.coach-card {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  box-shadow: var(--shadow-soft);
  overflow: hidden;
  transition: border-color .15s;
}
.coach-card[open] { border-color: var(--border-strong); box-shadow: var(--shadow-card); }
.coach-card > summary {
  list-style: none; cursor: pointer;
  padding: 20px 28px;
  display: grid;
  grid-template-columns: 12px auto minmax(0, 1fr) auto;
  gap: 18px;
  align-items: center;
}
.coach-card > summary::-webkit-details-marker { display: none; }
.coach-card > summary .chev {
  width: 9px; height: 9px;
  border-right: 2px solid var(--green-text);
  border-bottom: 2px solid var(--green-text);
  transform: rotate(-45deg);
  transition: transform .2s ease;
  justify-self: center;
}
.coach-card[open] > summary .chev { transform: rotate(45deg); }
.coach-card > summary .badge {
  font-family: var(--font-title);
  font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.1em;
  color: var(--green-text);
  background: var(--green); background: rgba(98,255,216,.30);
  padding: 4px 10px; border-radius: var(--radius-pill);
}
.coach-card > summary .headline {
  font-family: var(--font-title); font-size: 17px; font-weight: 600; color: var(--dark);
  letter-spacing: -0.01em; line-height: 1.3;
}
.coach-card > summary .open { font-size: 12px; color: var(--grey); font-family: var(--font-mono); }
.coach-card > .body {
  padding: 6px 28px 28px 28px;
  border-top: 1px solid var(--border);
  margin-top: 0;
}
.coach-card > .body .pattern {
  padding: 18px 0;
  font-size: 15px; color: var(--dark); line-height: 1.55;
}
.coach-card > .body .ev { padding: 12px 0; border-top: 1px solid var(--border); font-size: 14px; color: var(--grey); }
.coach-card > .body .ev .tag {
  display: inline-block; font-family: var(--font-title);
  font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.1em;
  padding: 3px 9px; border-radius: var(--radius-pill); margin-right: 10px; vertical-align: 2px;
}
.coach-card > .body .ev .tag.good { background: rgba(98,255,216,.30); color: var(--green-text); }
.coach-card > .body .ev .tag.bad  { background: rgba(252,194,100,.30); color: #9A5A08; }
.coach-card > .body .ev b { color: var(--dark); font-weight: 500; }
.coach-card > .body .ev code {
  font-family: var(--font-mono); font-size: 11px; color: var(--grey);
  background: var(--bg-secondary); padding: 2px 7px; border-radius: var(--radius-sm);
  word-break: break-all; display: inline-block; margin-top: 6px;
}
.coach-card > .body .adjust {
  margin-top: 18px;
  padding: 16px 20px;
  background: var(--lila); background: rgba(227,230,245,.6);
  border-radius: var(--radius-sm);
  color: var(--dark); font-size: 14px; line-height: 1.5;
}
.coach-card > .body .adjust::before {
  content: "Try this →";
  font-family: var(--font-title); font-weight: 600; color: var(--green-text);
  margin-right: 10px;
}

/* ─── skill proposals ─── */
.props { display: flex; flex-direction: column; gap: 10px; }
.prop {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  box-shadow: var(--shadow-soft);
  overflow: hidden;
  transition: border-color .15s;
}
.prop[open] { border-color: var(--border-strong); box-shadow: var(--shadow-card); }
.prop > summary {
  list-style: none; cursor: pointer;
  padding: 20px 28px;
  display: grid;
  grid-template-columns: 12px auto minmax(0, 1fr) auto auto;
  gap: 18px;
  align-items: center;
}
.prop > summary::-webkit-details-marker { display: none; }
.prop > summary .chev {
  width: 9px; height: 9px;
  border-right: 2px solid var(--green-text);
  border-bottom: 2px solid var(--green-text);
  transform: rotate(-45deg);
  transition: transform .2s ease;
  justify-self: center;
}
.prop[open] > summary .chev { transform: rotate(45deg); }
.prop > summary .nm {
  font-family: var(--font-mono); font-weight: 500;
  font-size: 13px; color: var(--green-text);
  background: rgba(98,255,216,.22); padding: 6px 12px; border-radius: var(--radius-sm);
}
.prop > summary .head {
  font-family: var(--font-title); font-size: 16px; font-weight: 500; color: var(--dark);
  line-height: 1.4;
}
.prop > summary .pill {
  font-size: 11px; font-family: var(--font-title); font-weight: 500;
  padding: 4px 10px; background: var(--bg-secondary); color: var(--grey);
  border-radius: var(--radius-pill);
}
.prop > summary .saves { font-size: 12px; color: var(--grey); font-family: var(--font-body); }
.prop > summary .saves b { color: var(--green-text); font-weight: 600; font-family: var(--font-title); text-transform: capitalize; }
.prop > .body {
  padding: 6px 28px 28px; border-top: 1px solid var(--border); margin-top: 0;
}
.prop > .body .trigger {
  margin: 18px 0; padding: 14px 18px;
  background: var(--bg-secondary);
  border-left: 3px solid var(--green-text);
  border-radius: var(--radius-sm);
  font-size: 14px; color: var(--dark); line-height: 1.55;
}
.prop > .body h5 {
  font-family: var(--font-title); font-size: 11px; font-weight: 600;
  color: var(--grey); text-transform: uppercase; letter-spacing: 0.1em;
  margin: 16px 0 8px;
}
.prop > .body ol, .prop > .body ul { margin: 0; padding-left: 20px; color: var(--dark); font-size: 14px; line-height: 1.65; }
.prop > .body ol li, .prop > .body ul li { margin: 4px 0; }
.prop > .body ul li em { font-style: normal; color: var(--grey); font-size: 13px; }
.prop > .body .cmd {
  font-family: var(--font-mono); font-size: 12px;
  background: var(--dark); color: var(--green);
  padding: 10px 14px; border-radius: var(--radius-sm);
  margin-top: 16px; word-break: break-all;
}

/* ─── footer ─── */
.footer { margin-top: 80px; padding-top: 24px; border-top: 1px solid var(--border); font-size: 13px; color: var(--grey); }
.footer details > summary { cursor: pointer; padding: 6px 0; }
.footer details > summary:hover { color: var(--dark); }
.footer .list {
  font-family: var(--font-mono); font-size: 11px;
  max-height: 260px; overflow-y: auto;
  margin-top: 10px; padding: 14px 16px;
  background: var(--bg-card); border: 1px solid var(--border);
  border-radius: var(--radius-sm);
}
.footer .list div { padding: 3px 0; }

/* ─── persona card (4:3, 820×615, LinkedIn-scale) ─── */
.persona-shell { margin: 48px 0 24px; display: flex; flex-direction: column; align-items: center; gap: 24px; }
.persona-title-group {
  display: flex; flex-direction: column; align-items: center; gap: 8px;
  text-align: center;
}
.persona-header {
  font-family: var(--font-title);
  font-size: 34px; font-weight: 600;
  color: var(--dark);
  letter-spacing: -0.02em;
  line-height: 1.1;
  margin: 0;
}
.persona-subheader {
  font-family: var(--font-body);
  font-size: 15px; font-weight: 400;
  color: var(--grey);
  margin: 0;
}
.persona-frame {
  /* Outer wrapper scales the card down to fit narrow viewports without
     touching the card's intrinsic pixel dimensions used for PNG export. */
  width: 100%; max-width: 820px;
  display: flex; justify-content: center;
}
.persona-card {
  width: 820px; height: 615px;
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  box-shadow: var(--shadow-card);
  overflow: hidden;
  color: var(--dark);
  display: grid;
  grid-template-rows: 44px 205px 104px 52px 170px 40px;
  flex-shrink: 0;
}
.persona-card * { box-sizing: border-box; }

/* Header strip */
.persona-card .pc-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 0 24px;
  border-bottom: 1px solid var(--border);
}
.persona-card .pc-header .pc-label {
  font-family: var(--font-title);
  font-size: 11px; font-weight: 600;
  text-transform: uppercase; letter-spacing: 0.18em;
  color: var(--grey);
}
.persona-card .pc-header .pc-label b {
  color: var(--dark); font-weight: 700; letter-spacing: 0.12em;
}
.persona-card .pc-header .pc-date {
  font-family: var(--font-mono); font-size: 11px; color: var(--grey);
  font-feature-settings: "tnum";
}

/* Hero row: emblem (left) + identity (right) */
.persona-card .pc-hero {
  display: grid;
  grid-template-columns: 220px 1fr;
  border-bottom: 1px solid var(--border);
}
.persona-card .pc-emblem-panel {
  position: relative;
  background: var(--bg-secondary);
  display: flex; align-items: center; justify-content: center;
  border-right: 1px solid var(--border);
}
.persona-card .pc-emblem-panel::before {
  content: "";
  position: absolute;
  width: 160px; height: 160px;
  border-radius: 50%;
  background: var(--lila);
  opacity: 0.55;
}
.persona-card .pc-emblem-panel svg {
  position: relative; z-index: 1;
  width: 120px; height: 120px;
}
.persona-card .pc-identity {
  padding: 32px 32px 28px;
  display: flex; flex-direction: column; justify-content: center; gap: 10px;
  overflow: hidden;
}
.persona-card .pc-name {
  font-family: var(--font-title);
  font-size: 44px; font-weight: 600;
  line-height: 1; letter-spacing: -0.03em;
  color: var(--dark); margin: 0;
}
.persona-card .pc-tagline {
  font-family: var(--font-title);
  font-size: 17px; font-weight: 400; font-style: italic;
  color: var(--purple-link);
  letter-spacing: -0.005em;
  line-height: 1.3;
}
.persona-card .pc-modifier {
  align-self: flex-start;
  font-family: var(--font-mono); font-size: 12px;
  color: var(--dark);
  background: rgba(98,255,216,.4);
  padding: 4px 10px; border-radius: var(--radius-pill);
  letter-spacing: 0.03em;
  margin-top: 2px;
}

/* Big stats strip */
.persona-card .pc-stats {
  display: flex; align-items: center; justify-content: space-around;
  padding: 0 24px;
  border-bottom: 1px solid var(--border);
  background: var(--bg-card);
}
.persona-card .pc-stat {
  display: flex; flex-direction: column; gap: 6px;
  text-align: center; flex: 1;
}
.persona-card .pc-stat .v {
  font-family: var(--font-title);
  font-size: 32px; font-weight: 600; color: var(--dark);
  line-height: 1; letter-spacing: -0.02em;
  font-feature-settings: "tnum";
}
.persona-card .pc-stat .l {
  font-family: var(--font-mono);
  font-size: 11px; color: var(--grey);
  text-transform: uppercase; letter-spacing: 0.12em;
}

/* Code vs Cowork split bar */
.persona-card .pc-split {
  display: grid; grid-template-columns: auto 1fr auto;
  align-items: center; gap: 16px;
  padding: 0 24px;
  border-bottom: 1px solid var(--border);
  color: var(--grey);
}
.persona-card .pc-split-label {
  font-family: var(--font-mono); font-size: 11px;
  text-transform: uppercase; letter-spacing: 0.12em;
}
.persona-card .pc-split-bar {
  height: 10px; background: var(--bg-secondary);
  border-radius: 4px; overflow: hidden; display: flex;
}
.persona-card .pc-split-bar .seg-code   { background: var(--green); }
.persona-card .pc-split-bar .seg-cowork { background: var(--purple); }
.persona-card .pc-split-pcts {
  display: flex; gap: 16px;
  font-family: var(--font-mono); font-size: 14px;
  font-feature-settings: "tnum";
}
.persona-card .pc-split-pcts b { color: var(--dark); font-weight: 600; }

/* Top 3 tasks triptych */
.persona-card .pc-tasks {
  padding: 18px 24px 14px;
  display: flex; flex-direction: column; gap: 8px;
  background: var(--bg-card);
  border-bottom: 1px solid var(--border);
}
.persona-card .pc-tasks-label {
  font-family: var(--font-mono);
  font-size: 11px; letter-spacing: 0.14em; text-transform: uppercase;
  color: var(--grey);
  margin-bottom: 2px;
}
.persona-card .pc-tasks-list {
  list-style: none; padding: 0; margin: 0;
  display: flex; flex-direction: column; gap: 6px;
}
.persona-card .pc-tasks-list li {
  display: grid; grid-template-columns: 34px 1fr auto;
  align-items: center; gap: 14px;
}
.persona-card .pc-tasks-list .n {
  font-family: var(--font-title); font-size: 28px; font-weight: 600;
  color: var(--purple-link); line-height: 1;
  font-feature-settings: "tnum";
}
.persona-card .pc-tasks-list .t {
  font-size: 18px; color: var(--dark); line-height: 1.25;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.persona-card .pc-tasks-list .f {
  font-family: var(--font-mono); font-size: 14px; color: var(--grey);
  font-feature-settings: "tnum";
}
.persona-card .pc-tasks-list .f b { color: var(--dark); font-weight: 600; }

/* Footer */
.persona-card .pc-footer {
  display: flex; align-items: center; justify-content: space-between;
  padding: 0 24px;
  font-size: 11px; color: var(--grey);
}
.persona-card .pc-range {
  font-family: var(--font-mono); font-feature-settings: "tnum";
  font-size: 11px;
}
.persona-card .pc-powered {
  display: inline-flex; align-items: center; gap: 8px;
  font-size: 11px; color: var(--grey);
}
.persona-card .pc-powered svg { height: 12px; width: auto; }

/* Below the card: blurb caption + download button (not part of PNG) */
.persona-annex {
  width: 100%; max-width: 820px;
  display: flex; flex-direction: column; align-items: center; gap: 14px;
  padding: 0 20px;
}
.persona-annex .pa-blurb {
  font-size: 15px; line-height: 1.6; color: var(--dark);
  max-width: 720px; text-align: center;
  font-style: italic;
}
.persona-annex .pa-download {
  display: inline-flex; align-items: center; gap: 8px;
  font-family: var(--font-mono); font-size: 13px;
  color: var(--dark); cursor: pointer;
  background: var(--green);
  padding: 10px 20px; border-radius: var(--radius-sm);
  border: none;
  transition: background .15s;
}
.persona-annex .pa-download:hover { background: var(--green-light); }
.persona-annex .pa-download:disabled { opacity: 0.6; cursor: wait; }

@media (max-width: 880px) {
  .persona-frame {
    /* Scale the 820×615 card down proportionally so it fits without overflowing.
       Using transform keeps the intrinsic pixel layout intact for html2canvas. */
    transform-origin: top center;
    height: calc((100vw - 40px) * 615 / 820);
    max-height: 615px;
    overflow: visible;
  }
  .persona-card {
    transform: scale(calc((100vw - 40px) / 820));
    transform-origin: top center;
  }
}

/* ─── scrollbars ─── */
::-webkit-scrollbar { width: 8px; height: 8px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: var(--grey-30); border-radius: 4px; }
::-webkit-scrollbar-thumb:hover { background: var(--grey); }

/* ─── responsive ─── */
@media (max-width: 900px) {
  .page { padding: 28px 20px 80px; }
  .hero h1 { font-size: 38px; }
  .hero .lead { font-size: 16px; }
  .stats { grid-template-columns: repeat(2, 1fr); }
  .cat > summary { grid-template-columns: 16px 12px 1fr; }
  .cat > summary .metric { display: none; }
  .cat > summary .metric.primary { display: block; grid-column: 3; text-align: right; }
  .task > summary { grid-template-columns: 14px 1fr 70px; padding: 12px 20px 12px 40px; }
  .task > summary .m:not(.primary) { display: none; }
  .task > .detail { padding: 18px 20px 22px 40px; }
  .chart-row { grid-template-columns: 1fr; gap: 4px; }
  .prop > summary, .coach-card > summary { grid-template-columns: 12px 1fr auto; gap: 14px; }
  .prop > summary .head, .coach-card > summary .headline { grid-column: 1 / -1; }
}
</style>
</head>
<body>
<div class="page">

  <header class="header">
    <div class="mark">__LOGO_SVG__<div class="sep"></div><div class="title">Task profile</div></div>
    <div class="meta" id="window-label"></div>
  </header>

  <section class="persona-shell" id="persona-shell" hidden>
    <div class="persona-title-group">
      <h2 class="persona-header">Your AI adoption persona</h2>
      <p class="persona-subheader">Based on your Claude usage data</p>
    </div>
    <div class="persona-frame">
      <article class="persona-card" id="persona-card">
        <div class="pc-header">
          <div class="pc-label"><b>AI adoption</b> · persona</div>
          <div class="pc-date" id="pc-date"></div>
        </div>
        <div class="pc-hero">
          <div class="pc-emblem-panel" id="pc-emblem"></div>
          <div class="pc-identity">
            <h2 class="pc-name" id="pc-name"></h2>
            <div class="pc-tagline" id="pc-tagline"></div>
            <div class="pc-modifier" id="pc-modifier" hidden></div>
          </div>
        </div>
        <div class="pc-stats" id="pc-stats"></div>
        <div class="pc-split">
          <span class="pc-split-label">how you work</span>
          <div class="pc-split-bar"><div class="seg-code" id="pc-seg-code"></div><div class="seg-cowork" id="pc-seg-cowork"></div></div>
          <div class="pc-split-pcts"><span>Code <b id="pc-code-pct"></b>%</span><span>Cowork <b id="pc-cowork-pct"></b>%</span></div>
        </div>
        <div class="pc-tasks">
          <div class="pc-tasks-label">Your top 3 tasks</div>
          <ol class="pc-tasks-list" id="pc-tasks-list"></ol>
        </div>
        <div class="pc-footer">
          <div class="pc-range" id="pc-range"></div>
          <div class="pc-powered">powered by <span id="pc-tw-logo"></span></div>
        </div>
      </article>
    </div>
    <div class="persona-annex">
      <p class="pa-blurb" id="pa-blurb"></p>
      <button class="pa-download" id="pa-download" type="button">↓ Download card as PNG</button>
    </div>
  </section>

  <section class="section">
    <div class="section-head">
      <h2>Tokens by category</h2>
      <div class="tagline">Stacked per category. Shows where spend concentrates across the kinds of work you do.</div>
    </div>
    <div class="card chart-card">
      <div class="chart-legend">
        <span><i class="code"></i>Claude Code</span>
        <span><i class="cowork"></i>Cowork</span>
      </div>
      <div id="chart"></div>
    </div>
  </section>

  <section class="section">
    <div class="section-head">
      <h2>Tasks by category</h2>
      <div class="tagline">Open a category for its tasks; open a task for friction, model spend, and sessions.</div>
    </div>
    <div class="cats" id="cats"></div>
  </section>

  <section class="section">
    <div class="section-head">
      <h2>AI-first coaching</h2>
      <div class="tagline">Four habits worth nudging, each with a session where it worked and one where it slipped.</div>
    </div>
    <div class="coach" id="coach"></div>
  </section>

  <section class="section">
    <div class="section-head">
      <h2>Skills worth building</h2>
      <div class="tagline">Five task-centric skills that would each cut iteration across multiple top tasks.</div>
    </div>
    <div class="props" id="props"></div>
  </section>

  <div class="footer">
    <details>
      <summary id="auto-summary"></summary>
      <div class="list" id="auto-list"></div>
    </details>
  </div>

</div>

<script id="data" type="application/json">__DATA_JSON__</script>
<script>
const DATA = JSON.parse(document.getElementById('data').textContent);
const profile = DATA.profile;
const coaching = DATA.coaching;
const proposals = DATA.skill_proposals;
const persona = DATA.persona;
const emblemSvg = DATA.emblem_svg || '';

function fmt(n) {
  n = n || 0;
  if (n >= 1e9) return (n/1e9).toFixed(2) + 'B';
  if (n >= 1e6) return (n/1e6).toFixed(1) + 'M';
  if (n >= 1e3) return (n/1e3).toFixed(0) + 'k';
  return n.toLocaleString();
}
function taskTotal(t) {
  return (t.tokens_input||0) + (t.tokens_output||0) + (t.tokens_cache_read||0) + (t.tokens_cache_creation||0);
}

// ─── header ───
document.getElementById('window-label').textContent =
  `${profile.window.since || 'all time'} → ${profile.window.until || 'now'} · generated ${profile.generated_at.slice(0,10)}`;

// (The old stats strip lived in the hero; the persona card now carries the big numbers.)

// ─── category grouping ───
const catMap = {};
profile.tasks.forEach(t => {
  const k = t.category || 'ops';
  catMap[k] = catMap[k] || { tasks: [], tokens: 0, freq: 0 };
  catMap[k].tasks.push(t);
  catMap[k].tokens += taskTotal(t);
  catMap[k].freq += t.frequency;
});
const catList = Object.entries(catMap).map(([name, v]) => ({ name, ...v }));
catList.sort((a,b) => b.freq - a.freq);

const CAT_COLORS = {
  engineering: '#0E9373',
  research:    '#8097F3',
  writing:     '#C37410',
  analysis:    '#0E9373',
  ops:         '#5B607B',
  planning:    '#90A0E0',
  communication: '#9A5A08',
};

// ─── chart (tokens by kind: code vs cowork, per category) ───
function sessionTokens(s) {
  const t = s.tokens || {};
  return (t.input||0) + (t.output||0) + (t.cache_read||0) + (t.cache_creation||0);
}
const chartEl = document.getElementById('chart');
const chartMax = Math.max(...catList.map(c => c.tokens), 1);
catList.forEach(c => {
  const byKind = { code: 0, cowork: 0 };
  c.tasks.forEach(t => {
    (t.sessions || []).forEach(s => {
      const k = s.kind === 'cowork' ? 'cowork' : 'code';
      byKind[k] += sessionTokens(s);
    });
  });
  const totalKind = byKind.code + byKind.cowork;
  const bar = ['code','cowork'].map(k =>
    `<div class="seg ${k}" style="width:${(100*byKind[k]/chartMax).toFixed(2)}%" title="${k}: ${byKind[k].toLocaleString()}"></div>`).join('');
  const row = document.createElement('div');
  row.className = 'chart-row';
  row.innerHTML = `<div class="cat-lbl">${c.name}</div><div class="bar">${bar}</div><div class="total">${fmt(totalKind)}</div>`;
  chartEl.appendChild(row);
});

// ─── category accordion ───
const catsEl = document.getElementById('cats');
catList.forEach(c => {
  const color = CAT_COLORS[c.name] || '#5B607B';
  const tasks = c.tasks.slice().sort((a,b) => b.frequency - a.frequency);
  const el = document.createElement('details');
  el.className = 'cat';
  el.innerHTML = `
    <summary>
      <span class="chev"></span>
      <span class="dot" style="background:${color}"></span>
      <span class="name">${c.name}</span>
      <span class="metric primary"><b>${tasks.length}</b> tasks</span>
      <span class="metric"><b>${c.freq}</b> sessions</span>
      <span class="metric">${fmt(c.tokens)} tok</span>
    </summary>
    <div class="cat-body"><div class="tasks">${tasks.map(renderTask).join('')}</div></div>`;
  catsEl.appendChild(el);
});

function renderTask(t) {
  const fps = (t.friction_points||[]).slice(0, 5).map(fp =>
    `<div class="fp">
       <div class="t">${fp.type||'friction'}</div>
       ${fp.example ? `<div class="e">${fp.example}</div>` : ''}
       ${fp.what_would_prevent ? `<div class="p">↳ ${fp.what_would_prevent}</div>` : ''}
     </div>`).join('');
  const models = Object.entries(t.by_model||{})
    .sort((a,b) => (b[1].output+b[1].input) - (a[1].output+a[1].input))
    .map(([m, v]) => `<tr><td>${m}</td><td>${fmt(v.input)}</td><td>${fmt(v.output)}</td><td>${fmt(v.cache_read)}</td><td>${fmt(v.cache_creation)}</td></tr>`)
    .join('');
  const sess = (t.sessions||[]).slice(0, 40).map(s =>
    `<div><b>${s.mtime}</b> · ${s.kind} · t=${s.turns} c=${s.corrections} · ${(s.summary||'').slice(0,70)}</div>`).join('');
  const clean = t.success_clean_pct;
  const cleanClass = clean >= 60 ? 'clean-good' : (clean <= 10 ? 'clean-bad' : '');
  return `
    <details class="task">
      <summary>
        <span class="chev"></span>
        <span class="title">${t.task}</span>
        <span class="m primary"><b>${t.frequency}</b>×</span>
        <span class="m ${cleanClass}"><b>${clean}%</b></span>
        <span class="m"><b>${t.avg_iterations}</b> iter</span>
        <span class="m"><b>${fmt(taskTotal(t))}</b></span>
      </summary>
      <div class="detail">
        ${fps ? `<h5>Friction patterns</h5><div class="fps">${fps}</div>` : '<div class="muted">No friction patterns recorded.</div>'}
        <h5>Tokens by model</h5>
        <table class="mdl-tbl">
          <thead><tr><th>Model</th><th>Input</th><th>Output</th><th>Cache read</th><th>Cache create</th></tr></thead>
          <tbody>${models}</tbody>
        </table>
        <h5>Sessions (${(t.sessions||[]).length})</h5>
        <div class="sessions">${sess}</div>
        <div class="meta-strip">
          <div>Last seen: <b>${t.last_seen || ','}</b></div>
          <div>Top friction: <b>${t.top_friction || 'none'}</b></div>
        </div>
      </div>
    </details>`;
}

// ─── coaching ───
const coachEl = document.getElementById('coach');
(coaching.cards || []).forEach(c => {
  const good = c.good_example ? `<div class="ev"><span class="tag good">worked</span>${c.good_example.description}<br><code>${(c.good_example.session_path||'').replace(/^\/Users\/[^/]+/,'~')}</code></div>` : '';
  const slip = c.friction_example ? `<div class="ev"><span class="tag bad">slipped</span>${c.friction_example.description}<br><code>${(c.friction_example.session_path||'').replace(/^\/Users\/[^/]+/,'~')}</code></div>` : '';
  coachEl.innerHTML += `<details class="coach-card">
    <summary>
      <span class="chev"></span>
      <span class="badge">habit</span>
      <span class="headline">${c.principle}</span>
      <span class="open">open</span>
    </summary>
    <div class="body">
      <div class="pattern">${c.pattern}</div>
      ${good}${slip}
      <div class="adjust">${c.suggested_adjustment}</div>
    </div>
  </details>`;
});

// ─── skill proposals ───
const propsEl = document.getElementById('props');
(proposals.proposals || []).forEach(p => {
  const steps = (p.mandatory_steps || []).map(s => `<li>${s}</li>`).join('');
  const tasks = (p.tasks_impacted || []).map(t => `<li><b>${t.task_id||''}</b>, <em>${t.why_relevant}</em></li>`).join('');
  const shape = p.output_shape ? `<h5>Output shape</h5><div style="font-size:14px;color:var(--dark);line-height:1.55;">${p.output_shape}</div>` : '';
  const savings = (p.expected_savings || '').split(' ')[0];
  propsEl.innerHTML += `<details class="prop">
    <summary>
      <span class="chev"></span>
      <span class="nm">/${p.name}</span>
      <span class="head">${(p.trigger_description||'').split('.').slice(0,1)[0]}.</span>
      <span class="pill">${(p.tasks_impacted||[]).length} tasks</span>
      <span class="saves">savings <b>${savings}</b></span>
    </summary>
    <div class="body">
      <div class="trigger">${p.trigger_description}</div>
      <h5>Mandatory steps</h5>
      <ol>${steps || '<li>,</li>'}</ol>
      ${shape}
      <h5>Tasks impacted</h5>
      <ul>${tasks}</ul>
      <div class="cmd">${p.invocation_hint||''}</div>
    </div>
  </details>`;
});

// ─── footer ───
const breakdown = Object.entries(profile.automation_breakdown || {})
  .sort((a,b) => b[1] - a[1]).map(([k,v]) => `${v} ${k}`).join(' · ');
document.getElementById('auto-summary').textContent =
  `${profile.counts.automation} sessions excluded from analysis, ${breakdown}`;
document.getElementById('auto-list').innerHTML =
  (profile.automation_examples || []).map(e => `<div>[${e.reason}] ${e.summary || ''}</div>`).join('');

// ─── persona card ───
(function renderPersona() {
  if (!persona) return;
  const shell = document.getElementById('persona-shell');
  shell.hidden = false;

  document.getElementById('pc-date').textContent = (profile.generated_at || '').slice(0,10);
  document.getElementById('pc-emblem').innerHTML = emblemSvg;
  document.getElementById('pc-name').textContent = persona.name || '';
  document.getElementById('pc-tagline').textContent = persona.tagline || '';
  document.getElementById('pa-blurb').textContent = persona.blurb || '';

  const mod = document.getElementById('pc-modifier');
  if (persona.modifier) {
    mod.textContent = '◆ ' + persona.modifier;
    mod.hidden = false;
  }

  // Big numbers: sessions, tokens, one highlight stat picked by main agent
  const totalTok = profile.tasks.reduce((a,t) => a + taskTotal(t), 0);
  const nums = [
    { v: String(profile.counts.interactive), l: 'sessions' },
    { v: fmt(totalTok), l: 'tokens' },
  ];
  if (persona.highlight_stat && persona.highlight_stat.value !== undefined) {
    nums.push({ v: fmt(persona.highlight_stat.value), l: persona.highlight_stat.label || 'highlight' });
  }
  document.getElementById('pc-stats').innerHTML = nums.map(n =>
    `<div class="pc-stat"><div class="v">${n.v}</div><div class="l">${n.l}</div></div>`).join('');

  // Code vs Cowork split
  let codeTok = 0, coworkTok = 0;
  profile.tasks.forEach(t => (t.sessions||[]).forEach(s => {
    const sT = (s.tokens||{}); const total = (sT.input||0)+(sT.output||0)+(sT.cache_read||0)+(sT.cache_creation||0);
    if (s.kind === 'cowork') coworkTok += total; else codeTok += total;
  }));
  const splitTotal = Math.max(1, codeTok + coworkTok);
  const codePct = Math.round(100*codeTok/splitTotal);
  const coworkPct = 100 - codePct;
  document.getElementById('pc-seg-code').style.width   = codePct + '%';
  document.getElementById('pc-seg-cowork').style.width = coworkPct + '%';
  document.getElementById('pc-code-pct').textContent   = codePct;
  document.getElementById('pc-cowork-pct').textContent = coworkPct;

  // Top 3 tasks list (use persona-provided short names when present)
  const topTasks = (persona.top3_task_names && persona.top3_task_names.length)
    ? persona.top3_task_names.map((name, i) => ({ name, freq: (profile.tasks[i] || {}).frequency }))
    : profile.tasks.slice(0, 3).map(t => ({ name: t.task, freq: t.frequency }));
  document.getElementById('pc-tasks-list').innerHTML = topTasks.slice(0, 3).map((t, i) =>
    `<li><span class="n">${i+1}</span><span class="t">${t.name}</span><span class="f">${t.freq ? `<b>${t.freq}</b>×` : ''}</span></li>`
  ).join('');

  // Range + TechWolf footer logo (clone the one in the header)
  document.getElementById('pc-range').textContent =
    `${profile.window.since || 'all time'} → ${profile.window.until || 'now'}`;
  const twLogo = document.querySelector('.header .mark svg');
  if (twLogo) {
    const clone = twLogo.cloneNode(true);
    clone.setAttribute('style', 'height:16px;width:auto;');
    document.getElementById('pc-tw-logo').appendChild(clone);
  }

  // Download as PNG via html2canvas
  document.getElementById('pa-download').addEventListener('click', downloadPersonaCard);

  async function downloadPersonaCard() {
    const btn = document.getElementById('pa-download');
    const card = document.getElementById('pc-card') || document.getElementById('persona-card');
    if (!card || typeof html2canvas !== 'function') {
      console.warn('html2canvas not available');
      return;
    }
    const originalText = btn.textContent;
    btn.disabled = true;
    btn.textContent = 'Rendering…';

    // Make sure web fonts are loaded before we rasterise.
    try { if (document.fonts && document.fonts.ready) { await document.fonts.ready; } } catch (_) {}

    // The card may be transformed via CSS on narrow viewports. We want to
    // capture its intrinsic 1200×900 layout, so temporarily strip transforms
    // by rendering inside a fixed, off-screen wrapper at native size.
    const stage = document.createElement('div');
    stage.style.cssText = 'position:fixed;left:-10000px;top:0;width:820px;height:615px;background:#FAFAFA;';
    const clone = card.cloneNode(true);
    clone.style.transform = 'none';
    clone.style.width = '820px';
    clone.style.height = '615px';
    stage.appendChild(clone);
    document.body.appendChild(stage);

    try {
      const canvas = await html2canvas(clone, {
        backgroundColor: '#FAFAFA',
        scale: 2.4,
        width: 820,
        height: 615,
        windowWidth: 820,
        windowHeight: 615,
        useCORS: true,
        allowTaint: false,
        logging: false,
      });
      await new Promise((resolve) => {
        canvas.toBlob((blob) => {
          const slug = (persona.id || 'persona').toLowerCase();
          const yyyymm = new Date().toISOString().slice(0,7).replace('-','');
          const url = URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = url;
          a.download = `ai-adoption-${slug}-${yyyymm}.png`;
          document.body.appendChild(a); a.click(); a.remove();
          URL.revokeObjectURL(url);
          resolve();
        }, 'image/png');
      });
    } catch (err) {
      console.error('PNG export failed:', err);
      alert('PNG export failed: ' + err.message);
    } finally {
      stage.remove();
      btn.disabled = false;
      btn.textContent = originalText;
    }
  }
})();
</script>
</body>
</html>
"""

if __name__ == "__main__":
    raise SystemExit(main())
