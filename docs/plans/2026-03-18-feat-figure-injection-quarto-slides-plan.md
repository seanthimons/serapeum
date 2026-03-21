# Stage 7: Figure Injection into Quarto Slide Generation

**Epic:** #44 — PDF Image Pipeline
**Status:** Implemented
**Date:** 2026-03-18
**Depends on:** Stages 1-3, 5-6 (all complete)

## Goal

When generating slides, the LLM can reference extracted figures from the selected documents. Figures appear in the RevealJS deck with appropriate layout based on their aspect ratio. The user controls whether figures are included via a toggle in the slide configuration modal.

## Design

### Manifest Approach

The LLM receives a **text-only figure manifest** alongside the existing text chunks. No image bytes are sent to the slide-generation LLM — only metadata. The LLM decides which figures are relevant to the slide content and references them by ID.

**Manifest entry per figure:**
```
[FIGURE fig_abc123 | "Figure 3" from document.pdf, p.8 | wide (1200x400)]
Type: composite chart
Caption: "Comparison of spectral reflectance bands across Sentinel-2 and Landsat-8"
Description: Three overlaid line plots showing reflectance values across wavelength bands...
```

The LLM outputs standard Quarto image syntax referencing figure IDs:
```markdown
![Comparison of spectral bands](fig_abc123.png){width="90%"}
```

### Aspect Ratio Classification

Figures are classified by aspect ratio (`width / height`) and the manifest tells the LLM which layout to use:

| Aspect Ratio | Class | Layout Guidance |
|---|---|---|
| > 1.8 | `wide` | Dedicated full-width slide, or `{width="90%"}` below heading |
| 0.6 – 1.8 | `standard` | Column layout alongside text: `:::: {.columns}` with 50/50 or 60/40 split |
| < 0.6 | `tall` | Constrained height: `{height="70%"}`, or paired side-by-side with another figure |

### File Staging for Quarto

Quarto resolves image paths relative to the `.qmd` file. Since the QMD is written to `tempdir()`, figure PNGs must be copied (or symlinked) there before rendering.

```
{tempdir}/
  notebook-slides.qmd
  fig_abc123.png      ← copied from data/figures/{nb_id}/{doc_id}/fig_003_1.png
  fig_def456.png
  ...
```

File names use the figure's DB `id` (UUID) to avoid collisions across documents. The mapping from `id` → `file_path` comes from `db_get_slide_figures()`.

### Prompt Modifications

**System prompt additions** (appended to existing `build_slides_prompt()` system prompt):

```
Figure Integration:
- You have access to extracted figures from the source documents (listed below).
- Reference figures using: ![caption](FIGURE_ID.png){attributes}
- Only include figures that are directly relevant to your slide content.
- Do NOT reference figures that don't exist in the manifest.
- Layout guidance by figure shape:
  - "wide" figures: use full-width on a dedicated slide, {width="90%"}
  - "standard" figures: use in a two-column layout with text alongside
  - "tall" figures: constrain with {height="70%"} or pair with another figure
- Place figures near the content they illustrate.
- Use the figure's caption or description for the alt text / ![caption] field.
- Not every slide needs a figure. Use figures to reinforce key points, not to fill space.
```

**User prompt additions** (appended after "Source content:" section):

```
Available figures:

[FIGURE {id} | "{figure_label}" from {doc_name}, p.{page} | {aspect_class} ({width}x{height})]
Type: {image_type}
Caption: "{extracted_caption}"
Description: {llm_description_summary}

---

[FIGURE {id} | ...]
...
```

The `llm_description` field contains `summary\n\ndetails` — only the summary line is included in the manifest to save tokens.

### UI Changes

**Slide configuration modal** (`mod_slides_modal_ui`):

Add below the document selection panel:

```
☑ Include figures (12 available)
```

- Checkbox, default checked if figures exist for the selected documents
- Badge count updates reactively when document selection changes
- When unchecked, no manifest is sent and slides generate text-only (current behavior)
- No per-figure picker — the user already curated via Keep/Ban in the gallery

### Healing Awareness

The healing prompt (`build_healing_prompt`) needs no changes. If the healed QMD references figure images, they're already staged in tempdir from the initial generation. The healer sees the full QMD including `![caption](fig_id.png)` references and preserves or adjusts them.

## Implementation Plan

### Task 1: Build figure manifest builder
**File:** `R/slides.R`

New function `build_figure_manifest(figures)`:
- Input: data.frame from `db_get_slide_figures()` (joined with document filename)
- Classify each figure's aspect ratio → `wide` / `standard` / `tall`
- Extract summary line from `llm_description` (first paragraph before `\n\n`)
- Return formatted manifest string

### Task 2: Stage figure files to tempdir
**File:** `R/slides.R`

New function `stage_figures_for_quarto(figures, qmd_dir)`:
- Input: figures data.frame + target directory (dirname of qmd_path)
- Copy each figure's PNG from `file_path` to `{qmd_dir}/{figure_id}.png`
- Return named list mapping `figure_id` → staged filename
- Handle missing source files gracefully (warn, skip)

### Task 3: Extend `build_slides_prompt()` with figure manifest
**File:** `R/slides.R`

- Add `figures = NULL` parameter to `build_slides_prompt()`
- When non-NULL, append figure integration instructions to system prompt
- Append formatted manifest to user prompt
- When NULL, behavior is identical to current (text-only slides)

### Task 4: Wire figure fetching into `generate_slides()`
**File:** `R/slides.R`

- Add `figures = NULL` parameter to `generate_slides()`
- When non-NULL:
  - Call `stage_figures_for_quarto(figures, dirname(qmd_path))` after writing QMD
  - Actually: stage figures BEFORE `render_qmd_to_html()` so Quarto can find them
- Pass figures through to `build_slides_prompt()`

### Task 5: Add "Include figures" toggle to slide config modal
**File:** `R/mod_slides.R`

- In `mod_slides_modal_ui()`: add `checkboxInput(ns("include_figures"), ...)` with reactive badge count
- In generation observer: when checked, call `db_get_slide_figures(con, notebook_id, doc_ids)` and pass to `generate_slides()`
- Join with document filename for manifest display

### Task 6: Handle figure staging in healing + regeneration paths
**File:** `R/mod_slides.R`

- Store figures in `generation_state$figures` so they persist across heal/regenerate
- Re-stage figures before each `render_qmd_to_html()` call (healing writes to different temp paths)
- Fallback template (`build_fallback_qmd`) does not include figures

### Task 7: Tests
**File:** `tests/testthat/test-slide-figures.R`

- `build_figure_manifest()` — correct aspect classification, summary extraction, format
- `stage_figures_for_quarto()` — files copied, missing files handled, collision-free naming
- `build_slides_prompt()` with figures — manifest appears in user prompt, instructions in system prompt
- `build_slides_prompt()` without figures — identical to current behavior (regression)
- Aspect ratio edge cases: square images (1:1), extreme aspect ratios

### Task 8: Integration smoke test
- Upload a PDF, extract figures, Keep some / Ban some
- Generate slides with "Include figures" checked
- Verify: figures appear in preview, layout matches aspect ratio guidance
- Generate slides with "Include figures" unchecked → text-only (regression)

## Data Flow

```
User clicks "Generate Slides"
  → mod_slides_server checks include_figures toggle
  → db_get_slide_figures(con, notebook_id, selected_doc_ids)
  → build_slides_prompt(chunks, options, figures = figures_df)
      → manifest appended to user prompt
      → layout instructions appended to system prompt
  → LLM generates Quarto markdown with ![caption](fig_id.png) references
  → stage_figures_for_quarto(figures, tempdir)
      → copies PNGs to tempdir as {id}.png
  → render_qmd_to_html(qmd_path)
      → Quarto resolves image paths relative to QMD → finds staged PNGs
  → Preview shows slides with embedded figures
```

## Edge Cases

| Scenario | Handling |
|---|---|
| No figures extracted for selected docs | Checkbox disabled with "(0 available)" — generates text-only |
| All figures banned | Same as no figures — checkbox shows "(0 available)" |
| Figure PNG missing from disk | `stage_figures_for_quarto` warns and skips; LLM reference becomes broken image (acceptable — user can re-extract) |
| LLM references a figure ID not in manifest | Broken image in rendered slides; mitigated by prompt instruction "Do NOT reference figures that don't exist" |
| LLM ignores all figures | Valid outcome — not every presentation needs images |
| 30+ figures in manifest | Token cost increases; consider truncating manifest to top ~15 by page order if > 20 figures. Add `max_manifest_figures` config. |
| Healing changes figure references | Acceptable — healer sees full QMD with image syntax, figures already staged |
| PDF export with figures | `render_qmd_to_pdf()` uses same tempdir — figures are already staged, should work |

## Failed Approaches (Image Embedding)

- **Relative paths + `embed-resources: true`**: Quarto copies QMD to its own temp dir during rendering, so relative `uuid.png` references can't be resolved by Pandoc.
- **`wd = dirname(qmd_path)` on processx::run**: Didn't help — Quarto still couldn't find the co-located PNGs.
- **Absolute filesystem paths in QMD**: Fixed embed-resources but broke the Shiny preview iframe (browser can't access `C:/...` paths from an HTTP context).
- **Working solution: base64 data URIs**: `inline_figure_data_uris()` reads each PNG, base64-encodes it, and replaces `uuid.png` references with `data:image/png;base64,...` directly in the QMD. Self-contained everywhere.
- **LLM prepending `FIGURE_` to UUIDs**: Prompt instruction `![caption](FIGURE_ID.png)` was interpreted literally. Fixed by showing an explicit UUID example and adding "Do NOT add any prefix".

## Non-Goals

- Per-figure picker in the slide modal (the gallery Keep/Ban is sufficient)
- Sending figure images to the slide LLM (only metadata — keeps tokens low)
- Automatic cropping/resizing of figures for slides (RevealJS handles scaling)
- Figure captions as formal Quarto figure environments (`:::{#fig-id}`) — too fragile for LLM output
- Stage 4 quality scoring — orthogonal concern

## Acceptance Criteria

### Functional Requirements
- [x] "Include figures" checkbox appears in slide config modal with count badge
- [x] Checkbox disabled when no non-excluded figures exist
- [x] LLM receives figure manifest with ID, label, document, page, aspect class, type, caption, description
- [x] LLM-generated QMD contains `![caption](fig_id.png)` references for relevant figures
- [x] Figure PNGs staged to tempdir before Quarto render
- [x] Figures render correctly in RevealJS HTML preview
- [ ] Wide figures appear full-width; standard figures in column layouts (needs manual UAT)
- [x] Unchecking "Include figures" produces text-only slides (regression)
- [x] Healing preserves or adjusts figure references
- [x] PDF export includes figures (figures staged in same tempdir)

### Non-Functional Requirements
- [x] Manifest adds < 200 tokens per figure to prompt
- [x] File staging completes in < 2s for 20 figures
- [x] No regression in text-only slide generation (61 tests pass)
