---
title: "dev: PDF image extraction process"
status: completed
type: task
priority: high
created_at: 2026-02-09T16:51:08Z
updated_at: 2026-03-22T16:54:16Z
parent: sera-mgb9
---

## Stage 1 of Epic #44: PDF Image Pipeline

### Problem

Need to extract individual figures/images from academic PDFs. PR #39 (pdfimager approach) was closed without merge.

### Approach: pdftools (already in renv)

Use the existing `pdftools` package rather than adding new system dependencies.

**Available functions:**
- `pdftools::pdf_render_page(pdf, page, dpi)` — renders a full page as a raster bitmap. Useful as input for vision model (Stage 5) and as a fallback for cropping figure regions.
- `pdftools::pdf_data(pdf)` — returns a data frame per page with positioned text boxes (x, y, width, height, font_size, font_name, text). Essential for Stage 3 caption heuristics.

**Open question: embedded image extraction**

`pdftools` wraps Poppler but doesn't expose Poppler's `pdfimages` functionality (which extracts embedded image streams directly). Two paths:

1. **Page rendering + crop** — render full pages at high DPI, identify figure regions via text-gap heuristics (large rectangular areas with no text boxes), crop those regions. Pure R, no new deps, but lower quality (re-rasterized).
2. **Optional Poppler CLI** — check for `pdfimages` on PATH, use it if available, fall back to page rendering if not. Better quality (original resolution), but adds an optional system dependency.

**Recommendation:** Start with option 2 (Poppler preferred, page-render fallback). Document Poppler installation for each platform.

### Deliverables

- [ ] `R/pdf_images.R` with `extract_figures(pdf_path)` returning a data frame: `{page, index, file_path, width, height, file_size}`
- [ ] Poppler detection: `has_pdfimages()` check
- [ ] Fallback: page rendering + text-gap crop when Poppler unavailable
- [ ] Unit tests with a sample academic PDF
- [ ] Installation docs for Poppler (Windows: `choco install poppler` or Scoop; Mac: `brew install poppler`; Linux: `apt install poppler-utils`)

### Blocks

- Stage 2 (storage) depends on this
- All downstream stages depend on extracted images existing

### Part of

Epic #44 — PDF Image Pipeline (extraction -> slides)

<!-- migrated from beads: `serapeum-1774459563889-29-4364aa54` | github: https://github.com/seanthimons/serapeum/issues/38 -->
