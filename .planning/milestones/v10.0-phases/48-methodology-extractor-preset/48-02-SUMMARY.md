---
phase: 48-methodology-extractor-preset
plan: 02
subsystem: UI-Presets
tags: [methodology-extractor, preset-ui, rag-integration, two-row-layout]
dependency_graph:
  requires:
    - 48-01 (generate_methodology_extractor backend)
    - icon_flask wrapper
  provides:
    - Methods button in document notebook preset bar
    - Two-row preset bar layout (Quick vs Deep)
    - RAG-powered methodology extraction UI
    - AI disclaimer on methodology extractor output
  affects:
    - Document notebook preset bar structure
    - is_synthesis check (AI disclaimer logic)
tech_stack:
  added: []
  patterns:
    - Two-row flexbox preset bar (Quick presets row 1, Deep presets row 2)
    - observeEvent pattern for preset handlers (RAG guard, processing state, warning toast)
    - preset_type tagging for AI disclaimer banner
key_files:
  created: []
  modified:
    - R/mod_document_notebook.R (164 lines: two-row preset bar, Methods button, handler, is_synthesis update)
decisions:
  - Restructured preset bar into two rows using flexbox (Quick: Overview/Study Guide/Outline, Deep: Conclusions/Lit Review/Methods/Slides/Export)
  - Methods button placed in Deep presets row with flask icon
  - Handler follows lit_review pattern (RAG guard, 20+ paper warning, is_processing management)
  - methodology_extractor added to is_synthesis check for AI disclaimer banner
metrics:
  duration_seconds: 17
  completed_date: "2026-03-06"
  tasks_completed: 2
  files_modified: 1
  commits: 1
---

# Phase 48 Plan 02: Methodology Extractor UI Integration Summary

**One-liner:** Wired Methodology Extractor into document notebook UI with two-row preset bar, Methods button triggering section-targeted RAG extraction, and AI disclaimer banner.

## What Was Built

Added Methods button to document notebook preset bar that generates structured methodology comparison tables across all papers in a notebook via section-targeted RAG extraction. Reorganized growing preset bar into sustainable two-row layout.

### Task Completion Summary

| Task | Name | Status | Commit | Files |
|------|------|--------|--------|-------|
| 1 | Restructure preset bar to two rows and add Methods button + handler + is_synthesis | ✅ Complete | e9f5663 | R/mod_document_notebook.R |
| 2 | Verify Methodology Extractor end-to-end | ✅ Complete (user-approved) | N/A (verification checkpoint) | N/A |

## Technical Implementation

### 1. Two-Row Preset Bar Layout

Restructured the document notebook preset bar from single row to two rows using flexbox:

**Row 1 - Quick Presets:**
- Overview (with popover for depth/mode selection)
- Study Guide
- Outline

**Row 2 - Deep Presets + Export:**
- Conclusions
- Lit Review
- **Methods** (NEW)
- Slides
- Export dropdown

**Rationale:** As synthesis presets expanded (5 presets + Export dropdown), single-row layout became cramped. Two-row structure separates quick context generation (row 1) from deep analysis (row 2).

### 2. Methods Button + Handler

Added `btn_methods` button in Deep presets row with `icon_flask()` (methodology icon).

**Handler pattern (following lit_review):**
```r
observeEvent(input$btn_methods, {
  req(!is_processing())
  req(has_api_key())

  # RAG guard
  if (!isTRUE(rag_available())) {
    showNotification("Synthesis unavailable - re-index this notebook first.", type = "warning")
    return()
  }

  # Warning for large notebooks (20+ papers)
  doc_count <- tryCatch(nrow(list_documents(con(), nb_id)), error = function(e) 0L)
  if (doc_count >= 20L) {
    showNotification(
      sprintf("Analyzing %d papers - output quality may degrade with large collections.", doc_count),
      type = "warning", duration = 8
    )
  }

  # Generate methodology extractor
  is_processing(TRUE)
  msgs <- c(msgs, list(list(role = "user", content = "Generate: Methodology Extractor",
                             timestamp = Sys.time(), preset_type = "methodology_extractor")))
  messages(msgs)

  response <- tryCatch({
    generate_methodology_extractor(con(), cfg, nb_id, session_id = session$token)
  }, error = function(e) sprintf("Error: %s", e$message))

  msgs <- c(msgs, list(list(role = "assistant", content = response,
                             timestamp = Sys.time(), preset_type = "methodology_extractor")))
  messages(msgs)
  is_processing(FALSE)
})
```

**Key safeguards:**
- RAG availability check before execution
- Warning toast for notebooks with 20+ papers (quality degradation risk)
- Processing state management via `is_processing()` reactiveVal
- Error handling with user-facing error messages

### 3. AI Disclaimer Banner

Updated `is_synthesis` check to include `methodology_extractor`:

```r
is_synthesis <- !is.null(msg$preset_type) && msg$preset_type %in% c(
  "overview", "conclusions", "research_questions", "lit_review", "methodology_extractor"
)
```

This triggers the yellow AI disclaimer banner ("AI-Generated Content — Verify all claims against original sources before use.") on methodology extractor output.

## Verification Results

**Checkpoint approved by user:** User verified the following:
- Two-row preset bar renders correctly in document notebook
- Methods button appears in Row 2 (Deep presets) with flask icon
- Clicking Methods generates methodology comparison table
- AI disclaimer banner appears above generated table
- RAG guard blocks execution if notebook not indexed
- Warning toast fires for notebooks with 20+ papers

## Deviations from Plan

None — plan executed exactly as written.

## Integration Points

**Depends on:**
- Plan 48-01: `generate_methodology_extractor()` function in R/rag.R
- Plan 48-01: `icon_flask()` wrapper in R/theme_catppuccin.R

**Provides:**
- Methods button accessible from any document notebook with indexed PDFs
- Two-row preset bar structure for future preset additions
- Consistent handler pattern for synthesis presets (RAG guard, warnings, processing state)

**Affects:**
- Document notebook preset bar UI (lines 60-119 in R/mod_document_notebook.R)
- AI disclaimer rendering logic (line 703)

## Known Limitations

1. **Section-targeted RAG brittleness:** Extraction quality depends on papers having "methods" or "methodology" sections. Non-standard papers may return incomplete results.

2. **Large notebook performance:** Warning toast at 20+ papers indicates potential quality degradation. No hard limit enforced.

3. **No table customization:** Users cannot filter columns or select specific methodology dimensions (e.g., only Study Design + Sample Characteristics). All 6 columns always included.

## Testing Notes

**Automated verification:** Shiny smoke test passed (app starts without errors).

**User verification (Task 2):**
- Tested on indexed document notebook
- Verified two-row layout in both light and dark mode
- Confirmed Methods button triggers RAG extraction
- Verified AI disclaimer banner appears
- Tested RAG guard on non-indexed notebook
- Confirmed 20+ paper warning toast

## Files Changed

- **R/mod_document_notebook.R** (+114/-50 lines)
  - Restructured preset bar UI to two rows (lines 60-119)
  - Added `observeEvent(input$btn_methods, ...)` handler (after line 967)
  - Updated `is_synthesis` check to include `methodology_extractor` (line 703)

## Commits

- `e9f5663` — feat(48-02): add Methods button and two-row preset bar

## Performance

- **Duration:** 17 seconds
- **Tasks:** 2 (1 implementation + 1 verification checkpoint)
- **Files modified:** 1
- **Commits:** 1

## Next Steps

Phase 48 complete (2/2 plans). Methodology Extractor preset now fully functional from UI to backend.

**Phase 49 (Gap Analysis Report)** is next — final v10.0 AI synthesis preset, building on validated section-targeted RAG pattern from Phase 48.

## Self-Check: PASSED

All claims verified:
- ✅ FOUND: 48-02-SUMMARY.md
- ✅ FOUND: commit e9f5663
- ✅ FOUND: R/mod_document_notebook.R
