---
title: "epic: PDF Image Pipeline (extraction → slides)"
status: completed
type: task
priority: high
created_at: 2026-02-10T04:46:48Z
updated_at: 2026-03-22T16:54:15Z
parent: sera-mgb9
---

## Overview

End-to-end pipeline for extracting figures from academic PDFs, associating them with captions and context, and injecting them into generated Quarto slide decks.

**Competitive context:** NotebookLM generates full slide decks with embedded visuals derived from source papers. Rather than competing on AI image *generation* (which requires expensive pixel models and produces non-editable rasters), Serapeum's strategy is to extract *real figures from real papers* and inject them into editable Quarto RevealJS decks. This produces output that is faithful by construction, editable, and built on the existing R stack.

**Key architectural decisions:**
- **Pure R stack** — no Python (MinerU), no JVM (PDFFigures2). Uses `pdftools` (already in renv) for extraction and heuristics, with optional vision model calls via existing OpenRouter integration.
- **No image embeddings** — DuckDB stores text metadata (captions, descriptions), not CLIP vectors. The slide-generating LLM selects figures by reading text descriptions, not by vector similarity.
- **Two-pass enrichment** — cheap heuristic pass first (free), optional vision model pass second (user-triggered, costs money).

---

## Pipeline Architecture

```
PDF upload (existing)
  -> Stage 1: Image extraction (pdftools::pdf_render_page + pdftools::pdf_data)
  -> Stage 2: Storage in DuckDB + filesystem
  -> Stage 3: Caption extraction via heuristics (regex + spatial + font)
  -> Stage 4: Quality filtering (size, type, deduplication)
  -> Stage 5: Vision model enrichment (optional, user-triggered)
  -> Stage 6: UI for review/selection
  -> Stage 7: Injection into Quarto slide generation

Slide generation (existing mod_slides.R):
  -> LLM receives image catalog as context (caption + description + file_path)
  -> LLM emits Quarto markdown with ![caption](path){width=X%} references
  -> Quarto renders deck with real paper figures embedded
```

---

## Stage 1: Image Extraction — #38

**Status:** Needs reimplementation (PR #39 closed without merge)

**Approach:** Use `pdftools` (already in renv.lock) instead of external `pdfimager`/Poppler dependency.

- `pdftools::pdf_render_page()` — renders full page as raster (for vision model input later)
- `pdftools::pdf_data()` — extracts positioned text boxes with x, y, width, height, font_size, font_name, text
- Image extraction from PDF internals — investigate `pdftools::pdf_attachments()` or raw stream extraction

**Key question to resolve:** `pdftools` can render pages to images but may not extract *embedded* figure images directly (unlike Poppler's `pdfimages` CLI). Two options:
1. Render full pages, use spatial heuristics to crop figure regions
2. Add Poppler as an *optional* system dependency, document installation, graceful fallback

**Deliverables:**
- [ ] `R/pdf_images.R` — `extract_figures(pdf_path)` function
- [ ] Unit tests with a sample PDF
- [ ] Documentation of system dependencies (if any)
- [ ] Graceful error if dependencies missing

---

## Stage 2: Storage & Association — NEW

**Approach:** Filesystem for image files, DuckDB for metadata.

**Database schema:**
```sql
CREATE TABLE IF NOT EXISTS document_figures (
  id VARCHAR PRIMARY KEY,
  document_id VARCHAR NOT NULL,
  notebook_id VARCHAR NOT NULL,
  page_number INTEGER NOT NULL,
  file_path VARCHAR NOT NULL,
  extracted_caption VARCHAR,
  llm_description VARCHAR,
  figure_label VARCHAR,
  width INTEGER,
  height INTEGER,
  file_size INTEGER,
  image_type VARCHAR,
  quality_score REAL,
  is_excluded BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (document_id) REFERENCES documents(id),
  FOREIGN KEY (notebook_id) REFERENCES notebooks(id)
);
```

**File storage:** `data/figures/{notebook_id}/{document_id}/fig_{page}_{index}.png`

**Deliverables:**
- [ ] Migration in `db.R` — `init_db()` creates `document_figures` table
- [ ] `db_insert_figure()`, `db_get_figures_for_document()`, `db_get_figures_for_notebook()` helpers
- [ ] File storage utilities (create dirs, save images, cleanup on document deletion)
- [ ] Cascade delete: removing a document removes its figures from DB + filesystem

---

## Stage 3: Caption Extraction (Heuristic Pass) — #28

**Approach:** Pure R, zero new dependencies. Two-layer heuristic using `pdftools::pdf_data()`.

**Layer 1 — Regex pattern matching:**
- Detect text blocks matching `^Fig(ure)?\.?\s*\d+[a-z]?\s*[:.\-]` patterns
- Also match: `^Table\s+\d+`, `^Scheme\s+\d+`, `^Chart\s+\d+`
- Capture everything from the label to the next paragraph break as the caption
- Handle multi-line captions (continuation lines at similar x-offset and font size)

**Layer 2 — Spatial association:**
- Using `pdf_data()` bounding boxes, associate detected captions with the nearest extracted figure on the same page
- Captions typically appear directly below or above figures
- Use y-coordinate proximity + font metadata (captions are often smaller or italic)

**Expected recall:** 40-60% on well-formatted journal PDFs. Higher for major publishers (Elsevier, Springer, Nature), lower for preprints and scanned documents.

**Deliverables:**
- [ ] `extract_captions(pdf_path)` — returns data frame of {page, label, caption_text, bbox}
- [ ] `associate_captions_to_figures(figures_df, captions_df)` — spatial matching
- [ ] Unit tests with sample PDFs from different publishers
- [ ] Populate `extracted_caption` and `figure_label` columns in `document_figures`

---

## Stage 4: Quality Filtering — NEW

**Approach:** Rule-based filtering to remove logos, headers, decorative elements.

**Filters:**
- **Minimum size threshold:** reject images below 100x100 px (icons, bullets)
- **Aspect ratio filtering:** reject extreme ratios (likely decorative bars/lines)
- **Deduplication:** hash-based detection of identical images across pages (journal logos, watermarks)
- **Position heuristics:** images in header/footer zones (top/bottom 10% of page) are likely logos
- **Optional: type classification** — if vision model is available, classify as chart/diagram/photo/table/decorative

**Deliverables:**
- [ ] `filter_figures(figures_df)` — applies rule-based filters, sets `quality_score`
- [ ] `deduplicate_figures(figures_df)` — perceptual hash or byte-hash dedup
- [ ] Sensible defaults that can be overridden in settings
- [ ] Unit tests

---

## Stage 5: Vision Model Enrichment (Optional) — NEW

**Approach:** User-triggered, costs money. Same opt-in pattern as "Embed Papers" button.

**Flow:**
1. User clicks "Describe Figures" button (similar to existing "Embed Papers")
2. For each figure without an `llm_description`, send the image to a multimodal model via OpenRouter
3. Prompt asks for: description of figure content, data shown, key findings, figure type classification
4. Store response in `llm_description` column
5. Log cost in existing `cost_log` table

**Model selection:** Use whatever multimodal model the user has configured. `google/gemini-2.0-flash` is cheap and capable for this. Falls back to any vision-capable model on OpenRouter.

**Alternative/addition:** Instead of sending individual extracted figures, send the full rendered page image and ask the model to describe all figures on the page. May be cheaper (fewer API calls) and better at capturing context.

**Deliverables:**
- [ ] `describe_figure(image_path, model)` — single figure description via OpenRouter
- [ ] `describe_figures_batch(document_id)` — batch process all un-described figures
- [ ] Cost estimation before processing ("This will process N images, estimated cost: $X")
- [ ] Progress indicator during processing
- [ ] Populate `llm_description` and `image_type` columns

---

## Stage 6: UI & Selection — #37

**Approach:** Image review panel in document detail view.

**UI elements:**
- Grid/gallery view of extracted figures for a document
- Each figure shows: thumbnail, page number, extracted caption (if any), LLM description (if any)
- Checkbox to include/exclude from slide generation (`is_excluded` column)
- "Describe Figures" button to trigger Stage 5
- Manual caption override (edit `extracted_caption` inline)

**Deliverables:**
- [ ] UI component in `mod_document_notebook.R` — figure gallery panel
- [ ] Include/exclude toggle per figure
- [ ] Manual caption editing
- [ ] "Describe Figures" button wired to Stage 5
- [ ] Figures displayed with contextual metadata

---

## Stage 7: Slide Integration — #29

**Approach:** Extend existing `mod_slides.R` / `slides.R` to include figure catalog in LLM context.

**Flow:**
1. When generating slides, query `document_figures` for all non-excluded figures in selected documents
2. Build an image catalog section in the prompt:
   ```
   Available figures from source papers:
   - [fig_id: fig_001] Page 3 of "Smith et al 2024" -- Figure 1: UMAP embedding of chemical space
     showing toxicity clusters. (Description: A scatter plot with orange and blue dots...)
   - [fig_id: fig_002] Page 7 of "Smith et al 2024" -- Figure 3: Comparison of PCA vs t-SNE
     neighborhood preservation...
   ```
3. Instruct the LLM to reference figures by ID when appropriate
4. Post-process LLM output to replace `[fig_id: fig_001]` references with proper Quarto image syntax:
   ```markdown
   ![Figure 1: UMAP embedding of chemical space](data/figures/nb_abc/doc_123/fig_003.png){width=70%}
   ```
5. Copy referenced images to the Quarto temp directory before rendering

**Deliverables:**
- [ ] `build_figure_catalog(notebook_id, document_ids)` — generates catalog text for LLM prompt
- [ ] Updated prompt template in `slides.R` with figure injection instructions
- [ ] Post-processor to convert figure references to Quarto image markdown
- [ ] Copy referenced image files to Quarto render directory
- [ ] Handle missing/broken images gracefully (skip with warning)
- [ ] Unit tests for catalog building and reference post-processing

---

## Dependencies Between Stages

```
Stage 1 (extraction)
  -> Stage 2 (storage) -- needs images to store
    -> Stage 3 (captions) -- needs stored figures to annotate
    -> Stage 4 (filtering) -- needs stored figures to filter
      -> Stage 5 (vision model) -- needs filtered figures to describe
      -> Stage 6 (UI) -- needs figures + metadata to display
        -> Stage 7 (slide injection) -- needs the full catalog
```

Stages 3 and 4 can run in parallel after Stage 2. Stage 5 is optional and can happen at any point after Stage 2. Stage 6 can ship with partial data (no LLM descriptions). Stage 7 requires at minimum Stages 1-2 to be useful, and benefits from 3-5.

---

## Rejected Approaches

| Approach | Reason |
|----------|--------|
| MinerU (Python) | GPU requirement, uncertain provenance, heavy dependency |
| PDFFigures2 (Scala/JVM) | Cannot deploy JVM dependency |
| CLIP/image embeddings in DuckDB | DuckDB has no vision vector support; text descriptions suffice for LLM-based figure selection |
| AI-generated figures (PaperBanana) | Expensive per generation ($1-3+), faithfulness issues, non-editable raster output, orthogonal to local-first strategy |
| PDF accessibility tags / alt-text | 75% of academic PDFs meet zero accessibility criteria; only ~15% have meaningful alt-text |

---

## Related Issues

| Stage | Issue | Title |
|-------|-------|-------|
| 1 | #38 | PDF image extraction process |
| 2 | #146 | Figure storage schema & DB helpers |
| 3 | #28 | Caption extraction (heuristic pass) |
| 4 | #147 | Figure quality filtering & deduplication |
| 5 | #148 | Vision model figure enrichment (optional) |
| 6 | #37 | Figure review & selection UI |
| 7 | #29 | Figure injection into Quarto slides |

<!-- migrated from beads: `serapeum-1774459564028-34-d6386cb9` | github: https://github.com/seanthimons/serapeum/issues/44 -->
