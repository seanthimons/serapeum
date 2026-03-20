# Slide Image Layout & Context-Aware Placement

**Epic:** #44 — PDF Image Pipeline
**Status:** Plan
**Date:** 2026-03-20
**Depends on:** Stage 7 (figure injection — complete)
**Brainstorm:** `docs/brainstorms/2026-03-20-slide-image-layout-brainstorm.md`

## Goal

Figures injected into Quarto slides should use context-appropriate layouts instead of uniform `{width="90%"}`. The LLM should produce hero image slides, two-column layouts, and height-constrained placements based on figure shape and content.

## Observed Problems (Chemo_pic.qmd)

1. All 7 figures use identical `{width="90%"}` — no layout variation
2. Every figure is appended below bullet points — no "hero image" slides
3. Full-page captures (1240x1630, ratio 0.75) classified as "standard" — same as actual charts
4. Vision descriptions are content-accurate but don't inform presentation placement

## Three Changes

### Change 1: Recalibrate Aspect Ratio Classification

**File:** `R/slides.R` — `classify_aspect_ratio()`

Current (3 buckets):
| Ratio | Class |
|---|---|
| > 1.8 | wide |
| 0.6 – 1.8 | standard |
| < 0.6 | tall |

Proposed (5 buckets):
| Ratio | Class | Slide Treatment |
|---|---|---|
| > 1.8 | wide | Full-width, dedicated slide |
| 1.2 – 1.8 | landscape | Full-width below heading, or 60/40 columns |
| 0.8 – 1.2 | square | Two-column 50/50 with text |
| 0.6 – 0.8 | portrait | Height-constrained `{height="70%"}` in column, or hero slide |
| < 0.6 | tall | Side-by-side pair, or skip |

This reclassifies 1240x1630 full-page figures (ratio 0.75) as "portrait" instead of "standard".

**Tests to update:** `test-slide-figures.R` — `classify_aspect_ratio` tests need new boundary values and new classes.

### Change 2: Add `presentation_hint` to Vision Pipeline

**Purpose:** Tell the slide LLM whether a figure deserves its own slide, works alongside text, or is too dense.

#### 2a. Vision system prompt
**File:** `R/pdf_images.R` — `build_figure_system_prompt()`

Add a 5th field to the JSON response:
```
5. **presentation_hint**: One of: "hero", "supporting", "reference"
   - "hero": Complex, detailed, or visually striking — deserves a dedicated slide
   - "supporting": Simple chart/diagram that works alongside text in a column layout
   - "reference": Dense data table, methodology diagram, or supplementary — better as appendix or omit from slides
```

#### 2b. Parse the new field
**File:** `R/pdf_images.R` — `parse_vision_response()`

Add `presentation_hint` to the parsed output (default: "supporting" if missing).

#### 2c. Store in DB
**File:** `R/db.R`

- Migration: `ALTER TABLE document_figures ADD COLUMN presentation_hint VARCHAR`
- Add `"presentation_hint"` to `db_update_figure()` allowed_fields list

#### 2d. Write to DB after vision call
**File:** `R/pdf_images.R` — `extract_and_describe_figures()` loop

After `db_update_figure(con, fig_id, llm_description = ..., image_type = ...)`, also pass `presentation_hint = desc$presentation_hint`.

#### 2e. Expose in slide figures query
**File:** `R/db.R` — `db_get_slide_figures()`

The column is already `SELECT *` so it will appear automatically. Just verify it's present.

**Tests:**
- `test-vision-describe.R`: `parse_vision_response()` returns `presentation_hint`
- `test-document-figures.R`: `db_update_figure()` accepts `presentation_hint`

### Change 3: Richer Slide Prompt with Concrete Examples

**File:** `R/slides.R` — `build_slides_prompt()` system prompt figure section

Replace the abstract layout rules with concrete QMD examples for each layout pattern.

#### 3a. New system prompt figure section

```
Figure Integration:
- You have access to extracted figures from the source documents (listed in the user prompt).
- Each figure has an ID (a UUID). Reference figures using: ![caption](uuid.png){attributes}
- Do NOT add any prefix to the filename — use the bare UUID with .png extension.
- Do NOT reference figure IDs that don't appear in the Available Figures list.
- Each figure in the manifest has a `hint` field: "hero", "supporting", or "reference".

LAYOUT PATTERNS — use the pattern matching the figure's shape and hint:

**Pattern 1: Hero Image Slide** (for "hero" hint, or wide/portrait figures)
The figure IS the slide. Title + image + optional caption. Put explanation in speaker notes or the NEXT slide.

## Embedding Visualizations

![PCA, UMAP, and VAE comparison of molecular fingerprints](uuid.png){width="90%" fig-align="center"}

::: {.notes}
This figure shows three distinct clustering patterns across dimensionality reduction methods...
:::

**Pattern 2: Two-Column Layout** (for "supporting" hint with square/landscape figures)
Figure alongside bullet points in a 50/50 or 40/60 split.

## Classification Performance

:::: {.columns}
::: {.column width="50%"}
- VAE shows highest MCC scores
- PCA filters noise but misses nonlinear structure
- UMAP captures local topology effectively
:::
::: {.column width="50%"}
![MCC scores by classifier](uuid.png){width="100%"}
:::
::::

**Pattern 3: Height-Constrained** (for portrait figures that would overflow)
Constrain height and center, or use in a column.

## Prediction Calibration

:::: {.columns}
::: {.column width="55%"}
- Uncertainty-aware models provide calibrated confidence intervals
- Distance-based calibration aligns RMU with prediction error
:::
::: {.column width="45%"}
![Calibration results](uuid.png){height="500px"}
:::
::::

**Pattern 4: Full-Width Below Heading** (for landscape figures with "supporting" hint)

## Neighborhood Preservation

![Average preservation metrics across DR methods](uuid.png){width="85%" fig-align="center"}

- Nonlinear methods outperform PCA across all feature sets
- t-SNE excels at nearest-neighbor preservation

**Pattern 5: Skip / Speaker Notes Only** (for "reference" hint figures)
Dense methodology diagrams or supplementary figures — mention in notes, don't embed.

RULES:
- Vary your layouts! Do not use the same pattern for every figure.
- Hero slides are powerful — use them for the most impactful figures.
- Not every slide needs a figure. Use figures to reinforce key points.
- Place figures near the content they illustrate.
- Use the figure's caption or description for the ![caption] alt text.
```

#### 3b. Updated manifest format

Add `hint` field to each manifest entry:

```
[ID: {id} | "{figure_label}" from {doc_name}, p.{page} | {aspect_class} ({width}x{height})]
Hint: {presentation_hint}
Type: {image_type}
Caption: "{extracted_caption}"
Description: {llm_description_summary}
```

**File:** `R/slides.R` — `build_figure_manifest()` — add hint line after header.

**Tests:** `test-slide-figures.R` — manifest contains "Hint:" line, system prompt contains all 5 patterns.

## Implementation Order

| # | Task | File(s) | Risk |
|---|---|---|---|
| 1 | Recalibrate `classify_aspect_ratio()` | `R/slides.R` | Low — pure function |
| 2 | Add `presentation_hint` to vision prompt + parser | `R/pdf_images.R` | Low — additive |
| 3 | DB migration for `presentation_hint` column | `R/db.R` | Low — same pattern as existing migrations |
| 4 | Wire `presentation_hint` through pipeline | `R/pdf_images.R` | Low — one extra field in db_update_figure |
| 5 | Add `presentation_hint` to `db_update_figure` allowed_fields | `R/db.R` | Low — one string addition |
| 6 | Update `build_figure_manifest()` with hint field | `R/slides.R` | Low — one extra line |
| 7 | Rewrite `build_slides_prompt()` figure section | `R/slides.R` | Medium — prompt engineering |
| 8 | Update tests | `tests/testthat/` | Medium — several test files |
| 9 | Re-extract test figures to populate `presentation_hint` | Manual UAT | N/A |
| 10 | Generate slides, compare with Chemo_pic.qmd | Manual UAT | N/A |

Tasks 1-6 are independent and can be done in any order. Task 7 depends on 1 and 6 (needs new aspect classes and hint in manifest). Task 8 follows all code changes.

## Edge Cases

| Scenario | Handling |
|---|---|
| Existing figures without `presentation_hint` | NULL → manifest shows no Hint line; slide LLM uses aspect ratio alone |
| Vision model doesn't return `presentation_hint` | `parse_vision_response()` defaults to "supporting" |
| All figures are "reference" hint | LLM may skip all figures — valid outcome |
| Portrait figure + "supporting" hint | Two-column with height constraint (Pattern 3) |
| Wide figure + "hero" hint | Hero slide (Pattern 1) — most impactful layout |

## Acceptance Criteria

- [x] `classify_aspect_ratio()` returns 5 classes: wide, landscape, square, portrait, tall
- [x] Vision prompt requests `presentation_hint` field in JSON response
- [x] `parse_vision_response()` extracts `presentation_hint` (defaults to "supporting")
- [x] `presentation_hint` column exists in `document_figures` table
- [x] `db_update_figure()` accepts `presentation_hint`
- [x] Figure manifest includes "Hint:" line per figure
- [x] System prompt includes 5 concrete QMD layout patterns
- [ ] Generated slides use varied layouts (not all `{width="90%"}`) — needs UAT
- [ ] Hero image slides appear for "hero" hint figures — needs UAT
- [ ] Portrait/tall figures use height constraints or column layouts — needs UAT
- [x] All existing tests pass (regression) — 82 slide + 46 vision tests pass
- [x] New tests cover 5 aspect classes, presentation_hint parsing, manifest hint field
