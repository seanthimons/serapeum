---
title: "dev: Figure quality filtering & deduplication (Stage 4)"
status: todo
type: task
priority: high
tags:
  - server
  - ui
created_at: 2026-03-09T14:41:17Z
updated_at: 2026-03-22T17:15:57Z
parent: sera-mgb9
---

## Stage 4 of Epic #44: Figure Quality Filtering

### Problem

Raw image extraction pulls everything from the PDF: actual figures, but also journal logos, publisher watermarks, header icons, decorative bars, and other non-content images. These need to be filtered before they pollute the figure catalog and waste vision model API calls in Stage 5.

### Approach: Rule-Based Filtering (Pure R)

No ML models or new dependencies. Deterministic rules that can be tuned.

**Filter 1 — Minimum size:**
- Reject images below 100x100 px (icons, bullets, small decorative elements)
- Configurable threshold in settings

**Filter 2 — Aspect ratio:**
- Reject images with extreme aspect ratios (> 10:1 or < 1:10) — likely decorative lines, banners, or separator bars
- Configurable threshold

**Filter 3 — Position heuristics:**
- Images in the top 8% or bottom 8% of the page are likely headers/footers/logos
- Images smaller than 5% of page area in corner positions are likely publisher badges

**Filter 4 — Deduplication:**
- Compute a simple byte hash (or perceptual hash via downscaled comparison) for each image
- If the same hash appears on 3+ pages, it's almost certainly a logo/watermark — auto-exclude
- Cross-document dedup within a notebook (same journal logo across papers)

**Filter 5 — Optional type classification (deferred to Stage 5):**
- If vision model descriptions are available, use `image_type` to filter decorative elements
- This filter only applies after Stage 5 runs

### Quality Score

Each figure gets a `quality_score` (0.0 to 1.0) based on:
- Size (larger = higher)
- Aspect ratio (closer to typical figure ratios = higher)
- Position (center of page = higher)
- Has caption match (from Stage 3 = bonus)
- Not a duplicate (= bonus)

Score is stored in `document_figures.quality_score` and used for catalog truncation in Stage 7 when there are too many figures for the context window.

### Deliverables

- [ ] `filter_figures(figures_df)` — applies all rule-based filters, returns filtered df with scores
- [ ] `compute_quality_score(figure_row)` — scoring function
- [ ] `deduplicate_figures(figures_df)` — hash-based dedup, marks duplicates as excluded
- [ ] Configurable thresholds (min_size, min_aspect, max_aspect, header_zone_pct)
- [ ] Unit tests with known good figures and known junk images
- [ ] Update `document_figures` rows with `quality_score` and `is_excluded` for filtered images

### Depends On

- Stage 2 — needs stored figures with dimensions and page positions

### Part of

Epic #44 — PDF Image Pipeline (extraction -> slides)

<!-- migrated from beads: `serapeum-1774459566026-125-8d7234f2` | github: https://github.com/seanthimons/serapeum/issues/147 -->
