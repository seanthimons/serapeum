---
phase: 22-module-migration
plan: 02
subsystem: ui
tags: [ragnar, shiny, migration, async, mirai, extendedtask, per-notebook-stores, rag-ready]

# Dependency graph
requires:
  - phase: 22-01
    provides: rebuild_notebook_store (async-safe), write_reindex_progress, read_reindex_progress, delete_notebook_store, ensure_ragnar_store, mark_as_ragnar_indexed
  - phase: 21-store-lifecycle
    provides: check_store_integrity, get_notebook_ragnar_path
  - phase: 20-foundation-connection-safety
    provides: create_interrupt_flag, signal_interrupt, clear_interrupt_flag, create_progress_file, clear_progress_file

provides:
  - mod_document_notebook_ui with JS updateReindexProgress handler and uiOutput send button
  - Migration detection: notebooks with content but no per-notebook store show async re-index prompt
  - rag_ready reactiveVal for RAG feature gating (separate concern from store_healthy corruption tracking)
  - rag_available reactive combining store_healthy AND rag_ready
  - Async re-index via ExtendedTask + mirai with interrupt/progress file pattern
  - Send button visually disabled (greyed out, tooltip) when rag_available() is FALSE
  - Defense-in-depth guard in send handler
  - PDF upload uses ensure_ragnar_store() for per-notebook isolation (no shared store)
  - Empty notebooks: no migration prompt shown (lazy creation path preserved)

affects:
  - 22-03 (search notebook module migration uses same rag_ready + ExtendedTask pattern)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "rag_ready + store_healthy separation: two independent concerns (migration vs. corruption)"
    - "ExtendedTask + mirai async re-index: same pattern as mod_citation_network.R network builds"
    - "uiOutput send button: renderUI swaps actionButton vs disabled tags$button based on rag_available()"
    - "Migration prompt only for has_content AND no store file: empty notebooks skip prompt"

key-files:
  created: []
  modified:
    - R/mod_document_notebook.R

key-decisions:
  - "rag_ready separate from store_healthy: store_healthy tracks corruption recovery (Phase 21), rag_ready tracks migration need (Phase 22) — different lifecycles, different triggers"
  - "JS handler updateReindexProgress in UI (not modal): avoids re-registration on each modal show, consistent with citation network pattern"
  - "rag_available = store_healthy AND rag_ready: both must be TRUE for chat/RAG to work"

patterns-established:
  - "Migration detection pattern: list_documents() to check content, get_notebook_ragnar_path() to check store existence — show prompt only when content exists and store does not"
  - "Async cancellable operation pattern: ExtendedTask$new, observeEvent(input$cancel_*), observe(result) with poller lifecycle matching mod_citation_network.R"

# Metrics
duration: 4min
completed: 2026-02-17
---

# Phase 22 Plan 02: Module Migration (Document Notebook) Summary

**Per-notebook store migration in mod_document_notebook.R: rag_ready state, async cancellable re-index with progress modal, greyed-out send button, and per-notebook PDF upload via ensure_ragnar_store()**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-17T20:42:34Z
- **Completed:** 2026-02-17T20:46:34Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Rewired mod_document_notebook.R to detect migration need on notebook open: notebooks with existing documents but no per-notebook ragnar store show an async re-index prompt; empty notebooks skip the prompt (no false positives)
- Added ExtendedTask + mirai async re-index following the mod_citation_network.R pattern: interrupt flag, progress file, 1s poller, animated progress bar, Stop button — all wired to rebuild_notebook_store() from 22-01
- Chat send button is now a dynamic uiOutput: renders as greyed-out disabled button with tooltip when rag_available() is FALSE, renders as a normal actionButton when available; send handler has defense-in-depth guard
- PDF upload path rewired from shared serapeum.ragnar.duckdb to ensure_ragnar_store(nb_id) — all new documents go into per-notebook stores automatically
- Added rag_ready reactiveVal (Phase 22 concern) alongside store_healthy (Phase 21 concern) — each tracks its own lifecycle independently

## Task Commits

Each task was committed atomically:

1. **Task 1: Add migration detection, rag_ready state, and re-index UX to mod_document_notebook.R** - `64770d8` (feat)

## Files Created/Modified
- `R/mod_document_notebook.R` - Full per-notebook store wiring: JS handler in UI, rag_ready + async state reactiveVals, ExtendedTask for async re-index, migration detection observeEvent, reindex/cancel/result handlers, rag_available reactive, dynamic send button uiOutput, per-notebook ensure_ragnar_store in upload handler

## Decisions Made
- `rag_ready` and `store_healthy` as separate reactiveVals: they represent different concerns with different triggers (migration vs. corruption recovery) and different resolution paths (async rebuild vs. synchronous rebuild)
- JS handler placed in module UI function (not emitted per modal show): avoids duplicate handler registration bug documented in Phase 18 research
- `rag_available = isTRUE(store_healthy()) && isTRUE(rag_ready())`: requires both healthy AND ready — user can't accidentally chat without a working index

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None - all changes parsed cleanly and all verification checks passed.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- 22-02 complete: document notebook fully wired for per-notebook stores
- 22-03 can now migrate mod_search_notebook.R using the same rag_ready + ExtendedTask pattern established here
- The rag_available pattern and dynamic send button approach are ready to reuse in 22-03

---
*Phase: 22-module-migration*
*Completed: 2026-02-17*
