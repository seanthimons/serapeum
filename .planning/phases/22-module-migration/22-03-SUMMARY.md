---
phase: 22-module-migration
plan: 03
subsystem: ui
tags: [ragnar, rag, embeddings, shiny, async, mirai, per-notebook-stores, search-notebook]

# Dependency graph
requires:
  - phase: 22-module-migration
    plan: 01
    provides: ensure_ragnar_store, delete_abstract_chunks_from_ragnar, mark_as_ragnar_indexed, get_notebook_ragnar_path, check_store_integrity, read_reindex_progress, rebuild_notebook_store
  - phase: 21-store-lifecycle
    provides: rebuild_notebook_store, delete_notebook_store, check_store_integrity
  - phase: 20-foundation-connection-safety
    provides: get_notebook_ragnar_path, encode_origin_metadata, insert_chunks_to_ragnar

provides:
  - Search notebook per-notebook ragnar store wiring (embed handler uses ensure_ragnar_store)
  - Migration prompt for search notebooks with abstracts but no per-notebook store
  - Async cancellable re-index with ExtendedTask + mirai pattern (same as doc notebook)
  - Chunk deletion from ragnar store on paper removal
  - Sentinel marking (mark_as_ragnar_indexed) after embedding
  - encode_origin_metadata applied to abstract chunks (section_hint=general)
  - rag_ready/store_healthy/rag_available reactive state tracking
  - Disabled send/conclusions buttons with tooltips when rag_available=FALSE
  - Early-return guards in send and btn_conclusions handlers

affects:
  - 22-04+ (any further migration work builds on this pattern)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Search notebook migration prompt: observeEvent(notebook_id()) checks store existence vs. content"
    - "Async re-index reuse: same ExtendedTask pattern handles both migration and corruption recovery"
    - "rag_available = isTRUE(store_healthy()) && isTRUE(rag_ready()) — tri-state guards all RAG features"
    - "uiOutput disabled buttons: renderUI checks rag_available() to render enabled or disabled HTML button"

key-files:
  created: []
  modified:
    - R/mod_search_notebook.R

key-decisions:
  - "Store_healthy NULL=unchecked on open, set by migration check observeEvent — avoids false blocks before check completes"
  - "Send/conclusions buttons replaced with uiOutput + renderUI for rag_available-aware rendering"
  - "Embed handler keeps ragnar_available() guard — embed IS the mechanism to build the store (not blocked by rag_available)"
  - "encode_origin_metadata applied in embed handler for section_hint metadata (enables future section filtering)"

patterns-established:
  - "JS progress handler via tags$script(HTML(...)): placed in tagList of UI function for module-scoped message handler"
  - "Migration check fires on notebook_id() change: reset rag_ready(TRUE)/store_healthy(NULL), then check and set based on store state"

# Metrics
duration: 3min
completed: 2026-02-17
---

# Phase 22 Plan 03: Module Migration (Search Notebook) Summary

**Per-notebook ragnar store wiring for search notebook: embed handler uses ensure_ragnar_store, paper deletion purges chunks, migration prompt with async cancellable re-index (ExtendedTask + mirai), and rag_available-gated chat/synthesis buttons**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-17T20:42:16Z
- **Completed:** 2026-02-17T20:46:02Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Added `rag_ready`, `store_healthy`, `rag_available` reactive state to track per-notebook store health
- Added async re-index with ExtendedTask + mirai, progress polling, and Stop button (same pattern as doc notebook)
- Migration prompt fires on notebook open when abstracts exist but no per-notebook store
- Corruption recovery reuses same ExtendedTask (one handler for both migration and rebuild)
- Rewired embed handler: `ensure_ragnar_store` instead of hardcoded `serapeum.ragnar.duckdb` shared store
- Added `encode_origin_metadata` in abstract chunk data.frame (enables future section filtering)
- Paper delete handler now calls `delete_abstract_chunks_from_ragnar` to keep ragnar store in sync
- `send` and `btn_conclusions` buttons replaced with `uiOutput` that renders disabled state when `rag_available=FALSE`
- Early-return guards in both send handlers as defense-in-depth

## Task Commits

Each task was committed atomically:

1. **Task 1: Add migration detection, rag_ready state, async re-index** - `4083a6d` (feat)
2. **Task 2: Rewire embed handler to per-notebook store, add chunk deletion** - `895ea37` (feat)

## Files Created/Modified
- `R/mod_search_notebook.R` - Full per-notebook store wiring: migration detection, async re-index, embed handler rewired, chunk deletion on paper remove, disabled UI buttons

## Decisions Made
- `store_healthy` starts as NULL (not TRUE) on notebook open so the migration check can set it accurately — avoids false positives before the check completes
- Embed button itself is NOT blocked by `rag_available` (embed is the mechanism to create the store for new papers; blocking it would create a chicken-and-egg situation)
- Both migration prompt and corruption recovery reuse the same `reindex_task` ExtendedTask — avoids code duplication
- JS custom message handler placed in tagList of UI function (not server) to register once per page load

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Missing closing brace after adding `if (!is.null(store))` guard inside the embed handler's `if (nrow(abstracts_to_index) > 0)` block — caught by parse check and corrected before commit.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Both search notebook and document notebook modules now use per-notebook ragnar stores
- Phase 22 module migration wave 2 complete — all three plans (22-01, 22-02, 22-03) done
- Phase 23-24 can proceed with legacy embedding cleanup and final validation

---
*Phase: 22-module-migration*
*Completed: 2026-02-17*
