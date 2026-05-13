"""Hand-crafted SVG emblems for the 21 AI-adoption personas.

Shared design language:
  * 160×160 viewBox, centred composition with ~16px margin
  * Primary structural strokes: 2.5px, dark #090D1F, round caps + joins
  * Secondary strokes: 1.8px, purple-link #8097F3 (for depth / ornament)
  * Signature accent: a single aquamarine #62FFD8 fill (dot / shape fill)
  * No gradients, no shadows, no textures
  * Each emblem has ONE aquamarine dot, the brand echo
"""

DARK = "#090D1F"
PURPLE = "#8097F3"
AQUA = "#62FFD8"
LILA = "#E3E6F5"

_BASE = 'xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160" width="160" height="160"'
_S = f'stroke="{DARK}" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" fill="none"'
_S2 = f'stroke="{PURPLE}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" fill="none"'


EMBLEMS: dict[str, str] = {

    # ── speed & style ──────────────────────────────────────────────

    "one-shot-wonder": f"""
<svg {_BASE}>
  <circle cx="80" cy="80" r="62" {_S}/>
  <circle cx="80" cy="80" r="42" {_S}/>
  <circle cx="80" cy="80" r="22" {_S2}/>
  <line x1="22" y1="138" x2="74" y2="86" {_S}/>
  <path d="M22 138 L30 132 M22 138 L28 146" {_S}/>
  <circle cx="80" cy="80" r="6.5" fill="{AQUA}"/>
</svg>""",

    "iterator": f"""
<svg {_BASE}>
  <!-- 2.25-turn Archimedean spiral tightening to centre -->
  <path d="
    M 140 80
    A 60 60 0 1 1 20 80
    A 58 58 0 1 1 138 80
    A 46 46 0 1 0 34 80
    A 44 44 0 1 0 126 80
    A 32 32 0 1 1 48 80
    A 30 30 0 1 1 114 80
    A 18 18 0 1 0 62 80
    A 16 16 0 1 0 98 80
  " {_S}/>
  <circle cx="80" cy="80" r="5.5" fill="{AQUA}"/>
</svg>""",

    "architect": f"""
<svg {_BASE}>
  <!-- blueprint: nested brackets forming a spine -->
  <path d="M24 30 L24 130 M24 130 L38 130" {_S}/>
  <path d="M136 30 L136 130 M136 130 L122 130" {_S}/>
  <path d="M44 52 L44 130" {_S2}/>
  <path d="M116 52 L116 130" {_S2}/>
  <path d="M44 52 L116 52" {_S}/>
  <path d="M60 78 L100 78" {_S2}/>
  <path d="M60 104 L100 104" {_S2}/>
  <!-- vertical spine -->
  <line x1="80" y1="20" x2="80" y2="140" {_S}/>
  <circle cx="80" cy="52" r="6" fill="{AQUA}"/>
</svg>""",

    "sprinter": f"""
<svg {_BASE}>
  <!-- three motion dashes, right-to-left, getting longer (leading edge ahead) -->
  <line x1="30" y1="110" x2="62" y2="78" {_S}/>
  <line x1="54" y1="118" x2="92" y2="80" {_S}/>
  <line x1="76" y1="124" x2="130" y2="70" {_S}/>
  <!-- leading aquamarine streak head -->
  <circle cx="130" cy="70" r="6" fill="{AQUA}"/>
</svg>""",

    "marathoner": f"""
<svg {_BASE}>
  <!-- baseline + long rising path to a peak -->
  <line x1="18" y1="126" x2="142" y2="126" {_S2}/>
  <path d="M22 120 C 52 118, 72 96, 92 72 S 118 34, 132 38" {_S}/>
  <!-- summit flag -->
  <line x1="132" y1="38" x2="132" y2="22" {_S}/>
  <path d="M132 22 L 146 28 L 132 34" {_S} fill="{AQUA}"/>
  <circle cx="132" cy="38" r="5" fill="{AQUA}"/>
</svg>""",

    # ── work-type ──────────────────────────────────────────────────

    "wordsmith": f"""
<svg {_BASE}>
  <!-- flowing ligature, like a written 'e' loop opening outward -->
  <path d="M 30 112
           C 22 92, 44 62, 74 58
           C 108 54, 120 84, 102 102
           C 86 118, 58 120, 46 104
           C 38 92, 48 82, 66 84
           C 82 86, 94 96, 108 96" {_S}/>
  <!-- ink drop at the tail -->
  <circle cx="122" cy="96" r="5.5" fill="{AQUA}"/>
</svg>""",

    "engineer": f"""
<svg {_BASE}>
  <!-- isometric cube with one face displaced -->
  <!-- back three faces -->
  <polygon points="50,50 88,32 126,50 88,68" {_S}/>
  <polygon points="50,50 50,106 88,124 88,68" {_S}/>
  <polygon points="126,50 126,106 88,124 88,68" {_S}/>
  <!-- detached top face, floated up-right -->
  <polygon points="70,24 108,6 146,24 108,42" {_S}/>
  <!-- connecting dashed link suggesting displacement -->
  <line x1="88" y1="32" x2="108" y2="24" {_S2} stroke-dasharray="3 4"/>
  <circle cx="108" cy="24" r="5.5" fill="{AQUA}"/>
</svg>""",

    "researcher": f"""
<svg {_BASE}>
  <!-- compass rose -->
  <circle cx="80" cy="80" r="56" {_S2}/>
  <!-- four cardinal diamonds, N long -->
  <polygon points="80,20 86,68 80,80 74,68" {_S} fill="{DARK}"/>
  <polygon points="80,140 86,92 80,80 74,92" {_S2} fill="{PURPLE}" fill-opacity=".15"/>
  <polygon points="20,80 68,74 80,80 68,86" {_S2} fill="none"/>
  <polygon points="140,80 92,74 80,80 92,86" {_S2} fill="none"/>
  <!-- centre -->
  <circle cx="80" cy="80" r="7" fill="{AQUA}"/>
</svg>""",

    "diplomat": f"""
<svg {_BASE}>
  <!-- two meeting arcs (bridges) -->
  <path d="M 14 100 Q 50 50, 80 80" {_S}/>
  <path d="M 146 100 Q 110 50, 80 80" {_S}/>
  <!-- small notches on the outer ends -->
  <line x1="14" y1="100" x2="14" y2="112" {_S}/>
  <line x1="146" y1="100" x2="146" y2="112" {_S}/>
  <!-- baseline -->
  <line x1="14" y1="120" x2="146" y2="120" {_S2}/>
  <!-- shared node -->
  <circle cx="80" cy="80" r="7" fill="{AQUA}"/>
</svg>""",

    "data-whisperer": f"""
<svg {_BASE}>
  <!-- three rising bars on a baseline -->
  <line x1="22" y1="132" x2="138" y2="132" {_S}/>
  <rect x="32" y="96" width="22" height="36" {_S} rx="2"/>
  <rect x="68" y="72" width="22" height="60" {_S} rx="2"/>
  <rect x="104" y="40" width="22" height="92" {_S} rx="2" fill="{LILA}"/>
  <!-- aquamarine crown dot -->
  <circle cx="115" cy="34" r="6" fill="{AQUA}"/>
</svg>""",

    "strategist": f"""
<svg {_BASE}>
  <!-- concentric circles + an outbound arrow -->
  <circle cx="72" cy="88" r="52" {_S2}/>
  <circle cx="72" cy="88" r="34" {_S2}/>
  <circle cx="72" cy="88" r="18" {_S}/>
  <!-- vector pointing out through NE -->
  <line x1="72" y1="88" x2="142" y2="24" {_S}/>
  <path d="M142 24 L130 26 M142 24 L140 36" {_S}/>
  <!-- aquamarine target -->
  <circle cx="142" cy="24" r="6" fill="{AQUA}"/>
</svg>""",

    # ── tooling & behaviour ──────────────────────────────────────────

    "connector": f"""
<svg {_BASE}>
  <!-- hub -->
  <circle cx="80" cy="80" r="10" fill="{AQUA}"/>
  <!-- six satellites on a circle of radius 54, then connect -->
  <!-- angles: 0, 60, 120, 180, 240, 300 -->
  <line x1="80" y1="80" x2="134" y2="80" {_S}/>
  <line x1="80" y1="80" x2="107" y2="33" {_S}/>
  <line x1="80" y1="80" x2="53" y2="33" {_S}/>
  <line x1="80" y1="80" x2="26" y2="80" {_S}/>
  <line x1="80" y1="80" x2="53" y2="127" {_S}/>
  <line x1="80" y1="80" x2="107" y2="127" {_S}/>
  <circle cx="134" cy="80" r="7" {_S} fill="{LILA}"/>
  <circle cx="107" cy="33" r="7" {_S} fill="{LILA}"/>
  <circle cx="53"  cy="33" r="7" {_S} fill="{LILA}"/>
  <circle cx="26"  cy="80" r="7" {_S} fill="{LILA}"/>
  <circle cx="53"  cy="127" r="7" {_S} fill="{LILA}"/>
  <circle cx="107" cy="127" r="7" {_S} fill="{LILA}"/>
</svg>""",

    "automator": f"""
<svg {_BASE}>
  <!-- lemniscate / infinity -->
  <path d="M 80 80
           C 80 50, 40 50, 28 80
           C 40 110, 80 110, 80 80
           C 80 50, 120 50, 132 80
           C 120 110, 80 110, 80 80 Z" {_S}/>
  <!-- arrowheads at top of each lobe, suggesting motion -->
  <path d="M 44 64 L 50 58 M 44 64 L 50 68" {_S2}/>
  <path d="M 116 96 L 110 102 M 116 96 L 110 92" {_S2}/>
  <!-- crossing node -->
  <circle cx="80" cy="80" r="7" fill="{AQUA}"/>
</svg>""",

    "skill-crafter": f"""
<svg {_BASE}>
  <!-- cut gem / kite -->
  <polygon points="80,22 138,80 80,138 22,80" {_S}/>
  <!-- inner facets -->
  <line x1="80" y1="22" x2="80" y2="138" {_S2}/>
  <line x1="22" y1="80" x2="138" y2="80" {_S2}/>
  <!-- top-left facet filled lila to read as a facet -->
  <polygon points="80,22 80,80 22,80" fill="{LILA}"/>
  <!-- aquamarine glint on the right facet -->
  <polygon points="80,22 138,80 80,80" fill="{AQUA}" fill-opacity=".55"/>
  <polygon points="80,22 138,80 80,138 22,80" {_S}/>
  <!-- small sparkle dot -->
  <circle cx="116" cy="58" r="4" fill="{AQUA}"/>
</svg>""",

    "conductor": f"""
<svg {_BASE}>
  <!-- four arrows from corners converging on centre -->
  <line x1="22" y1="22" x2="68" y2="68" {_S}/>
  <line x1="138" y1="22" x2="92" y2="68" {_S}/>
  <line x1="22" y1="138" x2="68" y2="92" {_S}/>
  <line x1="138" y1="138" x2="92" y2="92" {_S}/>
  <!-- arrowheads -->
  <path d="M 68 68 L 58 66 M 68 68 L 66 58" {_S}/>
  <path d="M 92 68 L 102 66 M 92 68 L 94 58" {_S}/>
  <path d="M 68 92 L 58 94 M 68 92 L 66 102" {_S}/>
  <path d="M 92 92 L 102 94 M 92 92 L 94 102" {_S}/>
  <!-- central merged dot -->
  <circle cx="80" cy="80" r="9" fill="{AQUA}"/>
</svg>""",

    "bench-builder": f"""
<svg {_BASE}>
  <!-- baseline -->
  <line x1="18" y1="134" x2="142" y2="134" {_S2}/>
  <!-- three course of bricks, offset pattern -->
  <rect x="24" y="106" width="48" height="22" {_S} rx="2"/>
  <rect x="76" y="106" width="60" height="22" {_S} rx="2"/>
  <rect x="30" y="80" width="60" height="22" {_S} rx="2"/>
  <rect x="94" y="80" width="42" height="22" {_S} rx="2" fill="{LILA}"/>
  <rect x="42" y="54" width="60" height="22" {_S} rx="2"/>
  <rect x="106" y="54" width="24" height="22" {_S} rx="2"/>
  <!-- keystone brick -->
  <rect x="62" y="28" width="40" height="22" {_S} rx="2" fill="{AQUA}"/>
</svg>""",

    # ── volume & efficiency ──────────────────────────────────────────

    "token-titan": f"""
<svg {_BASE}>
  <!-- three stacked chips, perspective via ellipses -->
  <!-- bottom chip -->
  <ellipse cx="80" cy="118" rx="52" ry="12" {_S}/>
  <path d="M 28 118 L 28 104" {_S}/>
  <path d="M 132 118 L 132 104" {_S}/>
  <ellipse cx="80" cy="104" rx="52" ry="12" fill="{LILA}" {_S}/>
  <!-- middle chip -->
  <path d="M 34 96 L 34 82" {_S}/>
  <path d="M 126 96 L 126 82" {_S}/>
  <ellipse cx="80" cy="96" rx="46" ry="11" {_S}/>
  <ellipse cx="80" cy="82" rx="46" ry="11" fill="white" {_S}/>
  <!-- top chip, aquamarine -->
  <path d="M 42 72 L 42 58" {_S}/>
  <path d="M 118 72 L 118 58" {_S}/>
  <ellipse cx="80" cy="72" rx="38" ry="10" fill="{AQUA}" {_S}/>
  <ellipse cx="80" cy="58" rx="38" ry="10" fill="{AQUA}" {_S}/>
  <!-- small highlight -->
  <circle cx="62" cy="55" r="3" fill="white"/>
</svg>""",

    "cache-whisperer": f"""
<svg {_BASE}>
  <!-- three concentric shells, each a 270° open arc -->
  <path d="M 80 18
           A 62 62 0 1 1 18 80" {_S}/>
  <path d="M 126 80
           A 46 46 0 1 1 80 34" {_S}/>
  <path d="M 80 108
           A 28 28 0 1 1 108 80" {_S2}/>
  <!-- core -->
  <circle cx="80" cy="80" r="10" fill="{AQUA}"/>
</svg>""",

    "model-polyglot": f"""
<svg {_BASE}>
  <!-- 2x2 grid of dots, differing sizes, one aquamarine -->
  <circle cx="52" cy="52" r="14" fill="{DARK}"/>
  <circle cx="108" cy="52" r="10" fill="{PURPLE}"/>
  <circle cx="52" cy="108" r="8" fill="{LILA}" {_S}/>
  <circle cx="108" cy="108" r="18" fill="{AQUA}"/>
  <!-- subtle grid cross -->
  <line x1="80" y1="28" x2="80" y2="132" {_S2}/>
  <line x1="28" y1="80" x2="132" y2="80" {_S2}/>
</svg>""",

    "focused-craftsman": f"""
<svg {_BASE}>
  <!-- single deep vertical mark, wedge/chisel shape -->
  <path d="M 80 20
           L 88 22
           L 92 120
           L 80 138
           L 68 120
           L 72 22 Z" {_S} fill="{LILA}"/>
  <line x1="80" y1="20" x2="80" y2="100" {_S}/>
  <!-- aquamarine base -->
  <circle cx="80" cy="138" r="8" fill="{AQUA}"/>
</svg>""",

    # ── fallback ──────────────────────────────────────────────────

    "explorer": f"""
<svg {_BASE}>
  <!-- compass triangle -->
  <polygon points="80,30 94,64 80,56 66,64" fill="{DARK}"/>
  <circle cx="80" cy="80" r="34" {_S}/>
  <!-- dashed unspooling path -->
  <path d="M 80 80
           Q 110 70, 128 90
           T 132 128" {_S2} stroke-dasharray="3 5"/>
  <!-- starting point -->
  <circle cx="80" cy="80" r="6" fill="{AQUA}"/>
</svg>""",
}


def get(persona_id: str) -> str:
    """Return the SVG string for a persona id, falling back to the explorer emblem."""
    return EMBLEMS.get(persona_id, EMBLEMS["explorer"]).strip()


if __name__ == "__main__":
    # Quick self-test: make sure every persona in the catalogue has an emblem.
    from pathlib import Path
    cat = Path(__file__).resolve().parent.parent / "references" / "personas.md"
    if cat.is_file():
        import re
        ids = set(re.findall(r"^### ([a-z0-9-]+)", cat.read_text(), flags=re.M))
        missing = ids - set(EMBLEMS)
        extra = set(EMBLEMS) - ids
        if missing:
            print("MISSING emblems:", sorted(missing))
        if extra:
            print("EXTRA emblems  :", sorted(extra))
        if not missing and not extra:
            print(f"OK: {len(EMBLEMS)} emblems, all aligned with catalogue.")
