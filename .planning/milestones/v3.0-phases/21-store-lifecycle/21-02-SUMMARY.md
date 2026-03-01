---
phase: 21-store-lifecycle
plan: 02
subsystem: ui
tags: [shiny, ragnar, duckdb, store-lifecycle, corruption-detection, modal, progress-bar]

# Dependency graph
requires:
  - phase: 21-01
    provides: check_store_integrity, rebuild_notebook_store, find_orphaned_stores, delete_notebook_store, get_notebook_ragnar_path

provides:
  - Proactive store integrity check on notebook open (mod_document_notebook.R)
  - Rebuild modal with progress bar and item count (mod_document_notebook.R)
  - store_healthy reactiveVal tracking corruption state (mod_document_notebook.R)
  - Orphan cleanup button and status display in settings (mod_settings.R)

affects: [phase-22-rag-retrieval]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - reactiveVal(NULL) for tri-state health tracking (NULL=unchecked, TRUE=ok, FALSE=corrupted)
    - observeEvent on notebook_id() for proactive checks on tab switch
    - withProgress + progress_callback for multi-item rebuild progress
    - modalDialog with easyClose=FALSE for actionable error modals

key-files:
  created: []
  modified:
    - R/mod_document_notebook.R
    - R/mod_settings.R

key-decisions:
  - "Rebuild index action appears only in error context (not always-visible)"
  - "Proactive integrity check fires when user switches to/opens a notebook"
  - "Rebuild shows progress bar with item count (documents + abstracts)"
  - "Notebook remains fully usable during rebuild - only search/RAG disabled"
  - "Orphan cleanup in settings is a simple button under Maintenance header"

patterns-established:
  - "Store health tri-state: NULL=unchecked, TRUE=healthy, FALSE=corrupted — avoids false positives on startup"
  - "Persistent errors (corruption) show modal; transient errors show toast notification"
  - "Phase 22 placeholder comment marks where RAG retrieval will check store_healthy()"

# Metrics
duration: ~5min
completed: 2026-02-17
---

# Phase 21 Plan 02: Store Lifecycle UI Summary

**Proactive DuckDB store corruption detection on notebook open with rebuild modal + progress bar, and orphan store cleanup button wired into app settings**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-02-17
- **Completed:** 2026-02-17
- **Tasks:** 2 of 3 (checkpoint:human-verify at Task 3)
- **Files modified:** 2

## Accomplishments
- `mod_document_notebook.R` gains `store_healthy` reactiveVal plus `observeEvent(notebook_id(), ...)` that calls `check_store_integrity()` on every notebook open, showing a rebuild modal on failure
- Rebuild handler (`observeEvent(input$rebuild_index, ...)`) calls `rebuild_notebook_store()` with `withProgress` + `progress_callback` to display "Re-embedding X/Y items" during recovery
- Phase 22 placeholder comment marks where future RAG retrieval will check `store_healthy()` before queries
- `mod_settings.R` gains a "Maintenance" subsection with "Clean Up Orphaned Indexes" button calling `find_orphaned_stores()` and removing matches with sidecar file cleanup

## Task Commits

Each task was committed atomically:

1. **Task 1: Add corruption detection and rebuild flow to mod_document_notebook.R** - `95c40d2` (feat)
2. **Task 2: Add orphan cleanup to mod_settings.R** - `4d13a5c` (feat)
3. **Task 3: Verify store lifecycle UI** - CHECKPOINT (awaiting human verification)

## Files Created/Modified
- `R/mod_document_notebook.R` - Added store_healthy reactiveVal, proactive integrity check on notebook open, rebuild modal + progress flow, Phase 22 RAG placeholder comment
- `R/mod_settings.R` - Added Maintenance section UI (hr, h5, p, actionButton, textOutput) and observeEvent server handler for orphan cleanup

## Decisions Made
- Proactive integrity check fires on `notebook_id()` change — catches corruption at the moment of navigation, not on startup (avoids penalizing users who don't use RAG)
- Rebuild modal uses `easyClose = FALSE` so users must explicitly choose Rebuild or Later
- `store_healthy` uses tri-state NULL/TRUE/FALSE — NULL means unchecked (freshly opened app), avoids showing stale health status
- Orphan cleanup deletes `.wal` and `.tmp` sidecar files alongside main `.duckdb` — matches `delete_notebook_store()` behavior from Plan 01

## Deviations from Plan

None - plan executed exactly as written. Both files already had the Phase 21 code committed prior to this execution session (verified by checking git log). Parse verification confirmed no syntax errors.

## Issues Encountered
None - both task commits were already present from a prior execution session. Verified file content, parse correctness, and function references before marking tasks complete.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Store lifecycle UI is complete pending human verification (Task 3 checkpoint)
- After user approves the UI in-app, Phase 21 is fully done
- Phase 22 (RAG retrieval) can wire into `store_healthy()` reactiveVal via the placeholder comment in `mod_document_notebook.R`

---
*Phase: 21-store-lifecycle*
*Completed: 2026-02-17*
