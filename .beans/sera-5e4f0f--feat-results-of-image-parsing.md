---
title: "feat: results of image parsing "
status: completed
type: task
priority: high
created_at: 2026-02-09T16:48:11Z
updated_at: 2026-03-22T16:54:22Z
parent: sera-mgb9
---

## Stage 6 of Epic #44: Figure Review & Selection UI

### Problem

Users need to review extracted figures before they're injected into slides. They should be able to exclude irrelevant images (logos, decorative elements that slipped through filtering), edit captions, and trigger vision model descriptions.

### UI Design

**Location:** New panel/tab within the document detail view in `mod_document_notebook.R`.

**Gallery view:**
- Grid of figure thumbnails (3-4 per row)
- Each card shows:
  - Thumbnail image
  - Page number badge
  - Figure label (if detected, e.g., "Figure 3")
  - Extracted caption (truncated, expandable)
  - LLM description (if available, with "not yet described" placeholder)
  - Include/exclude toggle (checkbox or switch)

**Actions:**
- **"Extract Figures" button** — triggers Stage 1-4 pipeline for the document. Shows progress. Disabled if already extracted.
- **"Describe Figures" button** — triggers Stage 5 vision model enrichment. Shows cost estimate first ("Describe 8 figures, est. cost: $0.12"). Disabled if all figures already described.
- **Per-figure caption edit** — inline text editing for `extracted_caption`. Allows manual correction when heuristics got it wrong.
- **Per-figure exclude toggle** — marks `is_excluded = TRUE`, figure won't appear in slide generation catalog.

**Empty state:** "No figures extracted. Click 'Extract Figures' to scan this PDF for images and charts."

### Deliverables

- [ ] Shiny module UI: figure gallery grid with cards
- [ ] Include/exclude toggle wired to `document_figures.is_excluded`
- [ ] Inline caption editing wired to `document_figures.extracted_caption`
- [ ] "Extract Figures" button triggering Stages 1-4
- [ ] "Describe Figures" button triggering Stage 5 with cost estimate modal
- [ ] Progress indicators for both extraction and description
- [ ] Responsive layout (works in sidebar and main panel widths)

### Depends On

- Stage 2 (storage) — needs DB schema and file storage
- Stage 1 (#38) — extraction pipeline to populate figures
- Stage 3 (#28) and Stage 4 — caption extraction and filtering to populate metadata

### Part of

Epic #44 — PDF Image Pipeline (extraction -> slides)

<!-- migrated from beads: `serapeum-1774459563866-28-5e4f0f4d` | github: https://github.com/seanthimons/serapeum/issues/37 -->
