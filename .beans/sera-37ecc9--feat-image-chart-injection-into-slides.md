---
title: "feat: image /chart injection into slides"
status: completed
type: task
priority: high
created_at: 2026-02-06T22:29:45Z
updated_at: 2026-03-22T16:54:24Z
parent: sera-mgb9
---

## Stage 7 of Epic #44: Figure Injection into Quarto Slides

### Problem

Generated slide decks are text-only. Users want real figures from their source papers embedded in the slides, positioned contextually by the LLM.

### Approach: Figure Catalog in LLM Context

Extend the existing slide generation pipeline (`mod_slides.R` / `slides.R`) to include a figure catalog in the LLM prompt.

**Step 1 — Build catalog:**
Query `document_figures` for all non-excluded figures across selected documents. Format as a structured list:

```
## Available Figures from Source Papers

You may reference these figures in your slides using [fig:ID] syntax.
Choose figures that directly support the slide content. Not every slide needs a figure.

- [fig:abc123] From "Smith et al 2024", page 3
  Label: Figure 1
  Caption: UMAP embedding of 100k chemicals colored by predicted toxicity
  Description: A scatter plot with orange (toxic) and blue (non-toxic) clusters...

- [fig:def456] From "Jones 2025", page 7
  Label: Figure 3
  Caption: Comparison of neighborhood preservation across embedding methods
  Description: Line chart showing k-neighbors recall for PCA, t-SNE, UMAP, and GTM...
```

**Step 2 — LLM generates slides with references:**
The LLM outputs standard Quarto markdown, using `[fig:ID]` placeholders where it wants figures.

**Step 3 — Post-process:**
Replace `[fig:ID]` references with proper Quarto image syntax:
```markdown
![Figure 1: UMAP embedding of 100k chemicals](figures/fig_abc123.png){width=70% fig-align="center"}
```

**Step 4 — Stage files:**
Copy all referenced image files into the Quarto render temp directory so paths resolve correctly.

### Edge Cases

- **No figures extracted:** Slide generation works exactly as today (text-only). No regression.
- **LLM references a figure that doesn't exist:** Post-processor logs a warning and skips. Slide renders without that image.
- **Too many figures for context window:** Truncate catalog to top N figures by quality_score. Show warning.
- **Large images:** Resize to max 1920px wide before copying to render dir. Keeps HTML/PDF output reasonable.

### Deliverables

- [ ] `build_figure_catalog(notebook_id, document_ids)` — generates catalog text block
- [ ] Updated system prompt in `slides.R` with figure injection instructions
- [ ] `resolve_figure_references(qmd_text, figures_df)` — replaces `[fig:ID]` with Quarto image markdown
- [ ] `stage_figure_files(referenced_ids, render_dir)` — copies + resizes images to render directory
- [ ] Integration with existing slide generation modal (shows figure count: "12 figures available from 3 documents")
- [ ] Unit tests for catalog building, reference resolution, and edge cases
- [ ] No regression: slides generate normally when no figures are available

### Depends On

- All previous stages (1-6), but minimally only needs Stage 1 + 2
- Existing `mod_slides.R` / `slides.R` (the slide generation pipeline to extend)

### Part of

Epic #44 — PDF Image Pipeline (extraction -> slides)

<!-- migrated from beads: `serapeum-1774459563756-23-37ecc958` | github: https://github.com/seanthimons/serapeum/issues/29 -->
