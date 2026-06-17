---
title: "feat: image/ table/ chart extraction"
status: completed
type: task
priority: high
created_at: 2026-02-06T22:27:52Z
updated_at: 2026-03-22T16:54:19Z
parent: sera-mgb9
---

## Stage 3 of Epic #44: Caption Extraction (Heuristic Pass)

### Problem

Extracted figures need associated captions to be useful in slide generation. The LLM needs to know what each figure shows to decide where to place it.

### Approach: Pure R heuristics with pdftools::pdf_data()

No new dependencies. Two-layer extraction:

**Layer 1 — Regex pattern matching on positioned text:**
```r
# Patterns to detect figure labels
caption_patterns <- c(
  "^Fig(ure)?\\.?\\s*\\d+[a-z]?\\s*[:.\u2014-]",
  "^Table\\s+\\d+\\s*[:.\u2014-]",
  "^Scheme\\s+\\d+\\s*[:.\u2014-]",
  "^Chart\\s+\\d+\\s*[:.\u2014-]"
)
```

- Run `pdf_data()` to get all text boxes with coordinates
- Identify text boxes whose content matches caption patterns
- Reconstruct multi-line captions by following continuation lines (same x-offset, same/similar font_size, sequential y positions)

**Layer 2 — Spatial association:**
- For each detected caption, find the nearest extracted figure on the same page
- Captions are typically directly below figures (most common) or above
- Use y-coordinate distance as primary signal
- Use font metadata as secondary signal (captions often use smaller or italic fonts)

### Expected Performance

| Publisher type | Estimated recall |
|---------------|-----------------|
| Major publishers (Elsevier, Springer, Nature) | 50-70% |
| IEEE, ACM | 50-65% |
| arXiv preprints | 30-50% |
| Scanned/OCR PDFs | 10-30% |

This is the **free pass**. Figures without heuristic captions get enriched in Stage 5 (vision model, user-triggered, costs money).

### Deliverables

- [ ] `extract_captions(pdf_path)` — returns data frame: `{page, label, caption_text, x, y, width, height, font_size}`
- [ ] `associate_captions_to_figures(figures_df, captions_df)` — spatial matching, returns updated figures_df with `extracted_caption` and `figure_label` populated
- [ ] Handle edge cases: captions spanning columns, captions on different page than figure, subfigure labels (a, b, c)
- [ ] Unit tests with PDFs from at least 3 different publishers
- [ ] Update `document_figures` table rows with extracted captions

### Depends On

- Stage 1 (#38) — needs extracted figures with page numbers and bounding boxes
- Stage 2 — needs storage schema to write results to

### Part of

Epic #44 — PDF Image Pipeline (extraction -> slides)

<!-- migrated from beads: `serapeum-1774459563735-22-ce52e166` | github: https://github.com/seanthimons/serapeum/issues/28 -->
