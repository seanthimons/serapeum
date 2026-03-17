---
title: "feat: Integrate PDF image pipeline into app modules"
type: feat
date: 2026-03-17
epic: "#44"
---

# Integrate PDF Image Pipeline into App Modules

## Overview

Move validated Stage 1/3/5 prototype code into app-integrated R modules so the Shiny app can extract figures from PDFs, associate captions, and generate structured vision descriptions — all with cost tracking and DB persistence.

This creates the backend plumbing. The UI trigger (Stage 6) and slide injection (Stage 7) are separate future work.

## Problem Statement

Working prototypes exist as standalone scripts (`prototype_extract_figures.R`, `prototype_vision_describe.R`) but cannot be called from the Shiny app. They use their own API client, have no DB persistence during extraction, no cost logging, and are not wired into the app's module system.

## Proposed Solution

Refactor prototype functions into three app modules:

1. **`R/pdf_extraction.R`** (new) — Figure extraction + caption logic from prototype
2. **`R/pdf_images.R`** (expand) — Vision description + high-level orchestrator
3. **`R/api_openrouter.R`** (extend) — Add optional params to `chat_completion()`
4. **`R/cost_tracking.R`** (update) — Register vision model pricing and operation type

## Technical Approach

### Phase 1: Extend `chat_completion()` in `R/api_openrouter.R`

Add backward-compatible optional parameters:

```r
chat_completion <- function(api_key, model, messages,
                            max_tokens = NULL, temperature = NULL,
                            timeout = 120) {
```

**Changes:**
- `max_tokens` and `temperature` added to request body only when non-NULL (existing callers unaffected)
- `timeout` default stays at 120 (current hardcoded value)
- Add robust content extraction after `body$choices[[1]]$message`:
  - Handle `content = NULL` from reasoning models (check `$reasoning` field)
  - Handle `content` as a list of parts (multipart responses)
  - Strip to a single string in all cases

**Files:** `R/api_openrouter.R:37-63`

**Risk:** Low — all new params have defaults matching current behavior.

**Verification:** Existing tests still pass; new unit test confirms multipart content extraction.

---

### Phase 2: Create `R/pdf_extraction.R`

New file containing all figure extraction logic, moved from `prototype_extract_figures.R`.

**Functions to include:**

| Function | Source (prototype lines) | Changes |
|----------|------------------------|---------|
| `extraction_config()` | CONFIG (lines 38-61) | Returns default config list; caller can override |
| `extract_figures_from_pdf(pdf_path, config)` | `extract_via_rendering()` (222-527) | Renamed; returns data.frame of figures with metadata |
| `extract_captions(text_data)` | lines 533-643 | No changes needed |
| `associate_captions(manifest, captions)` | lines 649-678 | No changes needed |
| `find_gaps(occupancy, total_length)` | lines 682-700 | No changes needed |
| `bitmap_to_array(bm)` | lines 706-713 | No changes needed |
| `is_mostly_blank(img_array, threshold)` | lines 717-720 | No changes needed |
| `filter_by_size(manifest, config)` | lines 724-737 | Accept config param instead of global CONFIG |
| `deduplicate(manifest)` | lines 741-756 | No changes needed |

**Functions to DROP:**
- `has_pdfimages()`, `poppler_version()`, `extract_via_poppler()` — no Poppler CLI
- `smoke_test()`, `parse_args()`, `main()`, `process_one_pdf()` — CLI scaffolding

**Key design decisions:**
- `extraction_config()` returns a named list with all tunables; callers can override individual fields
- `extract_figures_from_pdf()` is the single entry point — it orchestrates pre-scan, rendering, cropping, caption extraction, filtering, and dedup internally
- Returns a data.frame with columns: `page`, `figure_index`, `image_data` (raw PNG bytes), `width`, `height`, `file_size`, `method`, `figure_label`, `caption`, `caption_quality`
- Returns raw PNG bytes instead of writing files (the orchestrator in `pdf_images.R` handles persistence via `save_figure()`)
- Scanned-PDF guard: if ALL pages have zero text boxes, return empty data.frame with a warning

**Dependencies:** `pdftools`, `png`, `digest`

---

### Phase 3: Expand `R/pdf_images.R` — Vision + Orchestrator

Add vision description and the high-level pipeline orchestrator to the existing file utilities file.

**New functions:**

#### `figure_vision_config()`
Returns default vision config list:
```r
list(
  primary_model = "openai/gpt-4.1-nano",
  fallback_model = "google/gemini-2.5-flash-lite",
  max_tokens = 500,
  temperature = 0.2,
  timeout = 60
)
```

#### `build_figure_system_prompt()`
Returns the system prompt string for academic figure description. Requests JSON with keys: `type`, `summary`, `details`, `suggested_caption`.

#### `build_vision_messages(image_path_or_raw, figure_label, extracted_caption)`
Builds multipart message list (system + user with text + base64 image). Accepts either a file path or raw bytes.

#### `describe_figure(api_key, image_path_or_raw, figure_label, extracted_caption, vision_config)`
- Calls `chat_completion()` with primary model
- On failure, retries with fallback model
- Parses JSON response (strips code fences first)
- Returns named list: `success`, `type`, `summary`, `details`, `suggested_caption`, `model_used`, `prompt_tokens`, `completion_tokens`

#### `extract_and_describe_figures(con, api_key, document_id, notebook_id, pdf_path, session_id, extraction_config, vision_config, progress)`

High-level orchestrator. Steps:

1. **Cleanup existing figures** (idempotent re-extraction):
   ```r
   db_delete_figures_for_document(con, document_id)
   ```

2. **Extract figures** from PDF:
   ```r
   figures_df <- extract_figures_from_pdf(pdf_path, extraction_config)
   ```
   If empty, return early with `list(n_extracted = 0, n_described = 0)`.

3. **Save PNGs and insert DB rows** — for each figure:
   ```r
   file_path <- save_figure(fig$image_data, notebook_id, document_id, fig$page, fig$figure_index)
   db_insert_figure(con, list(
     document_id = document_id,
     notebook_id = notebook_id,
     page_number = fig$page,
     file_path = file_path,
     extracted_caption = fig$caption,
     figure_label = fig$figure_label,
     width = fig$width,
     height = fig$height,
     file_size = fig$file_size,
     image_type = fig$method
   ))
   ```
   Update progress callback if provided.

4. **Describe via vision API** (skip if `api_key` is NULL):
   For each inserted figure:
   ```r
   desc <- describe_figure(api_key, file_path, fig$figure_label, fig$caption, vision_config)
   if (desc$success) {
     db_update_figure(con, figure_id,
       llm_description = desc$summary,
       image_type = desc$type
     )
     # Log cost
     cost <- estimate_cost(desc$model_used, desc$prompt_tokens, desc$completion_tokens)
     log_cost(con, "figure_description", desc$model_used,
              desc$prompt_tokens, desc$completion_tokens,
              desc$prompt_tokens + desc$completion_tokens,
              cost, session_id)
   }
   ```
   0.5s pause between API calls for rate limiting. Update progress callback.

5. **Return summary**:
   ```r
   list(
     n_extracted = nrow(figures_df),
     n_described = n_success,
     n_failed = n_fail,
     figures = db_get_figures_for_document(con, document_id)
   )
   ```

**Key design decisions:**
- Re-extraction deletes all existing figures first (simplest idempotency)
- Extraction runs even without an API key; vision step is skipped, leaving `llm_description = NULL`
- Each figure is persisted to DB immediately after PNG save (not batched) — partial failures leave partial results rather than nothing
- Vision failures are non-fatal — the figure row exists with `llm_description = NULL`, retry-able later
- Progress callback signature: `progress(value, detail)` where `value` is 0-1 fraction

---

### Phase 4: Register Vision Pricing in `R/cost_tracking.R`

**Add to `pricing_env$MODEL_PRICING`:**
```r
"openai/gpt-4.1-nano" = list(prompt = 0.10, completion = 0.40),
"google/gemini-2.5-flash-lite" = list(prompt = 0.10, completion = 0.40)
```

**Add to `COST_OPERATION_META`:**
```r
"figure_description" = list(
  label = "Figure Description",
  icon_fun = "icon_image",
  accent_class = "text-success"
)
```

**Add to `KNOWN_MODEL_LABELS`:**
```r
"openai/gpt-4.1-nano" = "GPT-4.1 Nano",
"google/gemini-2.5-flash-lite" = "Gemini 2.5 Flash Lite"
```

**Files:** `R/cost_tracking.R:12-54`

---

### Phase 5: Tests

**New test file:** `tests/testthat/test-pdf-extraction.R`

Test extraction helpers that don't require a real PDF:
- `find_gaps()` — known occupancy vectors produce expected gaps
- `bitmap_to_array()` — correct dimension transposition
- `is_mostly_blank()` — white vs non-white detection
- `filter_by_size()` — size threshold filtering
- `extraction_config()` — returns expected defaults
- `extract_captions()` — mock `pdf_data()` output produces correct captions

**New test file:** `tests/testthat/test-vision-describe.R`

- `build_figure_system_prompt()` — returns non-empty string with required JSON keys
- `build_vision_messages()` — produces correct multipart structure
- `figure_vision_config()` — returns expected defaults
- JSON parsing robustness — handles code-fenced JSON, bare JSON, malformed JSON

**Extend existing:** `tests/testthat/test-document-figures.R`

- Test `extract_and_describe_figures()` with mocked `extract_figures_from_pdf()` and `chat_completion()` — verify DB rows created, cost logged, summary correct
- Test re-extraction cleans up old figures first

**Extend existing:** `tests/testthat/test-api-openrouter.R` (if exists)

- Test `chat_completion()` with new optional params (verify request body includes them only when non-NULL)

---

## Acceptance Criteria

### Functional Requirements

- [x] `extract_figures_from_pdf(pdf_path)` extracts figures and captions from a PDF, returns data.frame
- [x] `describe_figure(api_key, image_path)` sends a figure to the vision model and returns structured JSON
- [x] `extract_and_describe_figures()` orchestrates the full pipeline: extract -> save -> DB insert -> describe -> DB update -> log cost
- [x] `chat_completion()` accepts optional `max_tokens`, `temperature`, `timeout` without breaking existing callers
- [x] Vision API costs appear in the cost tracker dashboard with correct pricing
- [x] Re-calling `extract_and_describe_figures()` on the same document cleanly replaces old figures
- [x] Pipeline works without an API key (extraction only, vision skipped)
- [x] Scanned/image-only PDFs (all pages have 0 text boxes) return empty with a warning

### Quality Gates

- [x] All existing tests pass (no regressions in `chat_completion()` callers)
- [x] New unit tests for extraction helpers, vision message building, and orchestrator flow
- [ ] Prototype test data (43 figures from 4 PDFs) still extracts correctly via the new module

---

## Edge Cases and Mitigations

| Edge Case | Mitigation |
|-----------|------------|
| Reasoning model returns NULL content | `chat_completion()` checks `$reasoning` field as fallback |
| Vision model returns non-JSON | Strip code fences; fall back to raw text as summary |
| Primary model fails | Automatic fallback to `gemini-2.5-flash-lite` |
| Both models fail | Figure row persists with `llm_description = NULL`; non-fatal |
| Scanned PDF (0 text boxes on all pages) | Early return with warning message |
| Very large figures (>2MB PNG) | 150 DPI cap keeps sizes reasonable; no explicit limit needed |
| PDF read error | `tryCatch` wraps `pdf_length()`/`pdf_data()` — returns empty with error message |
| Document already has figures | `db_delete_figures_for_document()` at start of orchestrator |
| No API key | Extraction-only mode; vision step skipped |

## Dependencies

- `pdftools` (already in renv.lock)
- `png` (already in renv.lock)
- `digest` (already in renv.lock)
- `base64enc` (already in renv.lock)
- Existing app modules: `R/api_openrouter.R`, `R/cost_tracking.R`, `R/db.R`

## Out of Scope (Future Stages)

- **Stage 4:** Quality scoring beyond basic size filtering (needs ML or heuristics TBD)
- **Stage 6:** Figure review UI in `mod_document_notebook.R` (button trigger, gallery view, exclude/include toggle)
- **Stage 7:** Figure injection into Quarto slide generation
- **Async execution:** Current plan is synchronous with progress callback; `future`/`promises` can be added when the UI trigger is built
- **PDF persistence:** Assumes `pdf_path` points to an accessible file; permanent storage is a separate concern

## References

- Epic #44 on GitHub — full pipeline architecture
- `prototype_extract_figures.R` — validated extraction logic (Stage 1+3)
- `prototype_vision_describe.R` — validated vision description (Stage 5)
- `R/db.R:2003-2105` — `document_figures` schema and CRUD helpers
- `R/rag.R` — canonical pattern for `chat_completion()` + `log_cost()` wiring
- `HANDOFF.md` — failed approaches and key decisions from prototype phase
