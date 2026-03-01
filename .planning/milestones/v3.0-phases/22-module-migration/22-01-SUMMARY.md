---
phase: 22-module-migration
plan: 01
subsystem: database
tags: [ragnar, duckdb, rag, embeddings, async, mirai, per-notebook-stores]

# Dependency graph
requires:
  - phase: 21-store-lifecycle
    provides: rebuild_notebook_store, delete_notebook_store, find_orphaned_stores, check_store_integrity
  - phase: 20-foundation-connection-safety
    provides: with_ragnar_store, check_ragnar_version, register_ragnar_cleanup, get_notebook_ragnar_path

provides:
  - search_chunks_hybrid with per-notebook path derivation (ragnar_store_path=NULL derives from notebook_id)
  - rebuild_notebook_store enhanced with interrupt_flag, progress_file, db_path for async mirai workers
  - write_reindex_progress / read_reindex_progress for cross-process progress polling
  - delete_abstract_chunks_from_ragnar for chunk cleanup by abstract ID
  - mark_as_ragnar_indexed sentinel value tracking in chunks table
  - Legacy data/serapeum.ragnar.duckdb shared store deleted on app startup

affects:
  - 22-02 (document notebook module migration uses delete_abstract_chunks_from_ragnar, mark_as_ragnar_indexed)
  - 22-03 (search notebook module migration uses same helpers)
  - rag.R callers (search_chunks_hybrid automatically uses per-notebook stores via notebook_id)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-notebook ragnar path derivation: NULL default + get_notebook_ragnar_path(notebook_id)"
    - "Mirai worker pattern: db_path param opens own DBI connection (serialized con not transferable)"
    - "Cross-process progress: pipe-delimited file format count|total|pct|message"
    - "Interrupt pattern: check_interrupt(flag_file) before each item in rebuild loop"

key-files:
  created: []
  modified:
    - R/db.R
    - R/_ragnar.R
    - app.R

key-decisions:
  - "NULL default for ragnar_store_path enables callers to omit path; derivation happens inside function"
  - "Structured return list(success, count, partial, error) enables async callers to distinguish cancelled vs errored"
  - "delete_abstract_chunks_from_ragnar uses LIKE with % suffix for origin prefix matching (compatible across DuckDB versions)"

patterns-established:
  - "Write/read_reindex_progress: pipe-delimited file for cross-process async progress (reuse pattern from citation network)"
  - "db_path param pattern: mirai workers pass path not connection; function opens own connection with on.exit cleanup"

# Metrics
duration: 2min
completed: 2026-02-17
---

# Phase 22 Plan 01: Module Migration Backend Wiring Summary

**Per-notebook ragnar path derivation in search_chunks_hybrid, async-safe rebuild_notebook_store with interrupt/progress/db_path, and four new helper functions (write/read_reindex_progress, delete_abstract_chunks_from_ragnar, mark_as_ragnar_indexed)**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-17T20:37:29Z
- **Completed:** 2026-02-17T20:40:04Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Fixed `search_chunks_hybrid()` to derive per-notebook store path from `notebook_id` when `ragnar_store_path` is NULL — all existing callers in rag.R automatically use per-notebook stores without any changes to rag.R
- Enhanced `rebuild_notebook_store()` for async mirai worker use: `db_path` param opens own DBI connection, `interrupt_flag` enables cross-process cancellation, `progress_file` enables cross-process polling
- Added `write_reindex_progress` / `read_reindex_progress` helpers for Plans 02/03 progress polling
- Added `delete_abstract_chunks_from_ragnar` for Plan 02/03 chunk cleanup on abstract removal
- Added `mark_as_ragnar_indexed` sentinel tracking for chunks table
- app.R now deletes legacy `data/serapeum.ragnar.duckdb` shared store on startup

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix search_chunks_hybrid() path default and add per-notebook derivation** - `9a4b4b9` (feat)
2. **Task 2: Enhance rebuild_notebook_store for async, add helpers to _ragnar.R, delete shared store in app.R** - `3b4d0d7` (feat)

## Files Created/Modified
- `R/db.R` - search_chunks_hybrid ragnar_store_path default changed from hardcoded path to NULL, path derivation logic added
- `R/_ragnar.R` - rebuild_notebook_store enhanced with interrupt_flag/progress_file/db_path; write_reindex_progress, read_reindex_progress, delete_abstract_chunks_from_ragnar, mark_as_ragnar_indexed added
- `app.R` - Legacy shared store cleanup block added after ragnar directory creation

## Decisions Made
- NULL default for ragnar_store_path: cleaner than requiring callers to know the path; derivation is now encapsulated inside the function
- Structured return from rebuild_notebook_store: list(success, count, partial, error) so async callers can distinguish user cancellation (partial=TRUE) from errors
- LIKE with % suffix for abstract chunk deletion: safer than DuckDB-specific starts_with() across versions

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None - all files parsed cleanly and verification checks passed.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All backend wiring in place for Plans 02 and 03
- Plan 02 can now migrate mod_document_notebook.R to use per-notebook stores using ensure_ragnar_store, delete_abstract_chunks_from_ragnar, mark_as_ragnar_indexed
- Plan 03 can migrate mod_search_notebook.R similarly
- rag.R (rag_query, generate_conclusions_preset) already calls search_chunks_hybrid with notebook_id — automatically benefits from per-notebook paths with zero changes

---
*Phase: 22-module-migration*
*Completed: 2026-02-17*
