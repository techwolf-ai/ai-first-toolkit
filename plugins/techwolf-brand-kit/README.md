# Brand Kit

Official TechWolf brand assets for AI-generated outputs.

## Philosophy

AI agents frequently need to include brand assets in their outputs: web apps, slide decks, documents, PDFs. This plugin provides the official source files so agents never need to guess, approximate, or recreate logos from memory.

## Skills

| Skill | What it does |
|-------|--------------|
| **TechWolf Logo** | Provides official TechWolf logo files in 4 variants (dark, white, mono-dark, mono-white) as both SVG and PNG. Includes a `currentColor` inline SVG for themed contexts. |

## Logo Variants

| Variant | Use when |
|---------|----------|
| `techwolf-logo-dark` | Light backgrounds |
| `techwolf-logo-white` | Dark backgrounds (most common in TechWolf UI) |
| `techwolf-logo-mono-dark` | Monochrome contexts on light backgrounds |
| `techwolf-logo-mono-white` | Monochrome contexts on dark backgrounds |

Each variant is available as `.svg` (vector, preferred for web) and `.png` (raster, for documents/images).

## Quick Start

1. Install the plugin
2. Use `/techwolf-logo` in any conversation where an output needs a TechWolf logo
3. The skill will guide you to the right variant for your context
