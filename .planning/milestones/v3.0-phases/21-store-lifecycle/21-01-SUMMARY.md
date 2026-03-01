---
phase: 21-store-lifecycle
plan: 01
subsystem: backend
tags: [ragnar, lifecycle, database, file-management]

dependency_graph:
  requires:
    - "20-01: get_notebook_ragnar_path, encode_origin_metadata"
    - "20-02: with_ragnar_store pattern, version check"
  provides:
    - "ensure_ragnar_store: lazy store creation with notifications"
    - "check_store_integrity: pure function for health verification"
    - "delete_notebook_store: safe file removal with WAL cleanup"
    - "find_orphaned_stores: orphan detection for manual cleanup"
    - "rebuild_notebook_store: full re-chunk/re-embed pipeline"
  affects:
    - "db.R delete_notebook: cascades to delete_notebook_store"

tech_stack:
  added: []
  patterns:
    - "tryCatch for file operations with error logging"
    - "file.exists for path validation"
    - "file.remove with return value inspection"
    - "progress_callback pattern for rebuild UX"
    - "DB-first, file-second deletion ordering"

key_files:
  created: []
  modified:
    - path: "R/_ragnar.R"
      changes: "Added 5 lifecycle functions in Store Lifecycle section"
      loc: +292
    - path: "R/db.R"
      changes: "delete_notebook now calls delete_notebook_store"
      loc: +3
    - path: "tests/testthat/test-ragnar-helpers.R"
      changes: "Added lifecycle tests (integrity check, deletion, orphan detection)"
      loc: +154

decisions: []

metrics:
  duration_seconds: 148
  completed_date: "2026-02-16"
  tasks: 2
  commits: 2
  files_modified: 3
---

# Phase 21 Plan 01: Store Lifecycle Backend Summary

**One-liner:** Lifecycle functions for per-notebook ragnar stores with lazy creation, integrity checking, deletion cascade, orphan detection, and rebuild capability.

## Execution Summary

Created 5 backend lifecycle functions in `_ragnar.R` to manage per-notebook ragnar stores across their full lifecycle. Modified `delete_notebook()` to cascade store deletion after DB cleanup. Added comprehensive tests for pure/testable functions.

All functions follow defensive patterns from Phase 20 research: tryCatch for errors, file.exists for validation, explicit return value inspection for file.remove, and DB-first/file-second ordering for deletion resilience.

## Tasks Completed

### Task 1: Add lifecycle functions to _ragnar.R
**Commit:** `46e8768`

Added new `# ---- Store Lifecycle ----` section with 5 functions:

1. **ensure_ragnar_store(notebook_id, session, api_key, embed_model)**
   - Lazy creation pattern: connects if exists, creates if missing
   - Shows brief notification during creation (3s duration)
   - Blocks embedding on creation failure with persistent error notification
   - Returns connection or NULL on error

2. **check_store_integrity(store_path)**
   - Pure function: no UI side effects
   - Returns structured result: `list(ok, missing, error)`
   - Tests both file existence and DuckDB connection validity

3. **delete_notebook_store(notebook_id)**
   - Safe deletion with tryCatch fallback
   - Removes main `.duckdb` file plus `.wal` and `.tmp` files
   - Logs warnings but returns TRUE/FALSE (non-blocking)

4. **find_orphaned_stores(con)**
   - Compares disk files against DB notebook IDs
   - Returns character vector of orphaned store paths
   - Excludes `.wal` and `.tmp` files from results

5. **rebuild_notebook_store(notebook_id, con, api_key, embed_model, progress_callback)**
   - Deletes old store, re-chunks all documents, re-embeds all abstracts
   - Calls progress_callback(current, total) after each item
   - Returns `list(success, count, error)` with partial progress on failure

All functions documented with roxygen2 comments and examples.

### Task 2: Add store deletion cascade and tests
**Commit:** `566498a`

**Part A: Modified delete_notebook() in db.R**
- Added call to `delete_notebook_store(id)` after all DB operations
- Comment documents Phase 21 intent and failure recovery strategy
- DB-first, file-second ordering per research pitfall 4

**Part B: Added lifecycle tests**
Created `describe("Store Lifecycle")` block with:

- **check_store_integrity tests:**
  - Returns `ok=FALSE, missing=TRUE` for non-existent files
  - Returns `ok=FALSE` for corrupted files (garbage content)

- **delete_notebook_store tests:**
  - Returns TRUE for non-existent stores (idempotent)
  - Removes existing files and returns TRUE
  - Cleans up WAL files alongside main store

- **find_orphaned_stores tests:**
  - Creates in-memory DuckDB with notebooks table
  - Creates temp ragnar directory with valid + orphan stores
  - Verifies only orphans are returned

Tests use `withr::local_tempdir()` for cleanup and `skip_if_not()` for dependencies.

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

✓ All 5 lifecycle functions exist in R/_ragnar.R
✓ File sources without errors (verified with Rscript)
✓ delete_notebook() calls delete_notebook_store() after DB cleanup
✓ Test file syntax validates successfully
✓ db.R parses without errors

**Note:** Test execution was blocked by renv environment issues (missing DESCRIPTION files), but test syntax was validated using R's parse function. Tests follow existing patterns from test-ragnar-helpers.R and use proper withr/testthat constructs.

## Key Patterns Established

1. **Lazy creation**: Stores created on first use, not on notebook creation
2. **Graceful degradation**: File deletion failures don't block notebook deletion
3. **Orphan cleanup**: Manual control via settings, not automatic on startup
4. **Progress callbacks**: Rebuild operation reports progress for UI integration
5. **Structured results**: Pure functions return `list(ok, error, ...)` for programmatic decisions

## Files Modified

- `R/_ragnar.R`: +292 lines (5 new functions)
- `R/db.R`: +3 lines (delete cascade)
- `tests/testthat/test-ragnar-helpers.R`: +154 lines (lifecycle tests)

## Integration Points for Plan 02

Plan 02 (UI layer) will call:
- `check_store_integrity()` on notebook open (proactive corruption detection)
- `rebuild_notebook_store()` from "Rebuild Index" action with progress UI
- `find_orphaned_stores()` from settings panel cleanup button

`ensure_ragnar_store()` designed for Phase 22 (Module Migration) when embedding code paths switch to per-notebook stores.

## Self-Check: PASSED

**Created files exist:**
✓ .planning/phases/21-store-lifecycle/21-01-SUMMARY.md

**Modified files confirmed:**
✓ R/_ragnar.R (contains ensure_ragnar_store, check_store_integrity, delete_notebook_store, find_orphaned_stores, rebuild_notebook_store)
✓ R/db.R (delete_notebook calls delete_notebook_store)
✓ tests/testthat/test-ragnar-helpers.R (Store Lifecycle describe block)

**Commits exist:**
✓ 46e8768: feat(21-01): add store lifecycle functions to _ragnar.R
✓ 566498a: feat(21-01): add store deletion cascade and lifecycle tests

All task deliverables verified successfully.
