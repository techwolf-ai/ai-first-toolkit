---
name: techwolf-logo
description: Provides official TechWolf logo files in multiple variants (dark, white, monochrome) as SVG and PNG. Use when any output needs a TechWolf logo.
---

# TechWolf Logo Skill

This skill bundles the official TechWolf logo assets. **Always use these files** when a TechWolf logo is needed in any output.

## CRITICAL RULE

**NEVER generate, recreate, or approximate the TechWolf logo from memory.** The logo contains precise SVG paths that cannot be reproduced correctly by guessing. Always read and copy the exact files from this skill directory.

## Logo Variants

| File | Description | Use when |
|------|-------------|----------|
| `techwolf-logo-dark` | Dark text + aquamarine circle | Light backgrounds |
| `techwolf-logo-white` | White text + aquamarine circle | **Dark backgrounds (most common in TechWolf UI)** |
| `techwolf-logo-mono-dark` | All dark (single color) | Monochrome contexts on light backgrounds |
| `techwolf-logo-mono-white` | All white (single color) | Monochrome contexts on dark backgrounds |

Each variant is available as both `.svg` (vector, preferred for web) and `.png` (raster, for documents/images).

## How to Use

### In HTML / Web outputs

1. Read the appropriate SVG file from this skill directory
2. Embed the SVG content inline in your HTML

```html
<!-- Example: read techwolf-logo-white.svg and paste its content here -->
<div class="logo">
  <!-- paste exact SVG content from the file -->
</div>
```

### In documents, images, or other outputs

1. Copy the appropriate PNG file to your output directory
2. Reference it from your document

### currentColor version (for HTML where logo color should inherit from parent)

When you need the logo to inherit its color from a parent CSS `color` property (e.g., in slide decks or themed UIs), use this inline SVG. The text paths use `currentColor` and the "O" circle stays aquamarine (#63FFD9):

```html
<svg width="100" height="11" viewBox="0 0 151 16" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M13.7243 4.72539H9.288V15.5364H4.9785V4.72539H0.5V1.46289H13.7243V4.72539Z" fill="currentColor"/><path d="M31.4468 12.2739V15.5364H19.9336V1.46289H31.1722V4.72539H24.2431V7.00701H29.7779V10.035H24.2431V12.2739H31.4468Z" fill="currentColor"/><path d="M50.3094 11.3574C49.9292 12.8642 49.1898 13.973 48.0912 14.6838C47.0069 15.3946 45.6549 15.7499 44.0352 15.7499C42.5988 15.7499 41.3525 15.4657 40.2962 14.8971C39.254 14.3284 38.4512 13.4968 37.8879 12.4022C37.3245 11.3076 37.043 10.0069 37.043 8.5C37.043 6.99313 37.3245 5.6995 37.8879 4.61911C38.4512 3.5245 39.254 2.69289 40.2962 2.12427C41.3384 1.54142 42.5777 1.25 44.0142 1.25C45.5915 1.25 46.9365 1.59118 48.0491 2.27353C49.1616 2.94166 49.8728 3.95809 50.1827 5.32279L46.4435 6.83676C46.2887 5.96961 46.0352 5.37966 45.683 5.06691C45.3309 4.73995 44.8169 4.57647 44.141 4.57647C43.2818 4.57647 42.62 4.90344 42.1551 5.55735C41.7045 6.21127 41.4792 7.19215 41.4792 8.5C41.4792 11.1157 42.3524 12.4235 44.0987 12.4235C44.8028 12.4235 45.338 12.2601 45.7041 11.9331C46.0844 11.5919 46.3379 11.0517 46.4646 10.3125L50.3094 11.3574Z" fill="currentColor"/><path d="M69.5085 1.46289V15.5364H65.1779V10.0776H60.6572V15.5364H56.3477V1.46289H60.6572V6.8151H65.1779V1.46289H69.5085Z" fill="currentColor"/><path d="M84.0013 15.5364H79.2271L75.2344 1.46289H79.882L81.8465 12.1033L84.0436 1.46289H87.8461L90.1487 12.0607L92.0711 1.46289H96.5495L92.557 15.5364H87.9094L86.5574 9.52318L85.987 6.0048H85.9237L85.3532 9.52318L84.0013 15.5364Z" fill="currentColor"/><path d="M115.236 8.25098C115.236 12.3931 112.012 15.751 108.034 15.751C104.056 15.751 100.832 12.3931 100.832 8.25098C100.832 4.10885 104.056 0.750977 108.034 0.750977C112.012 0.750977 115.236 4.10885 115.236 8.25098Z" fill="#63FFD9"/><path d="M133.04 12.2739V15.5364H122.098V1.46289H126.407V12.2739H133.04Z" fill="currentColor"/><path d="M143.591 4.72539V7.17759H149.125V10.4401H143.591V15.5364H139.281V1.46289H150.499V4.72539H143.591Z" fill="currentColor"/></svg>
```

## Choosing the Right Variant

- **Building a web app with dark TechWolf theme?** Use `techwolf-logo-white` (SVG preferred)
- **Building a web app with light theme?** Use `techwolf-logo-dark` (SVG preferred)
- **Creating a slide deck?** Use the `currentColor` version above in the `.tw-logo` element
- **Generating a PDF or document?** Use the PNG variant matching your background
- **Need a watermark or subtle branding?** Use the mono variant matching your background
