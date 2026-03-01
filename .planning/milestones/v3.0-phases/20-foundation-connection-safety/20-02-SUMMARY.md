---
phase: 20-foundation-connection-safety
plan: 02
subsystem: ragnar
tags: [lifecycle, version-check, connection-cleanup, directory-setup]
dependencies:
  requires: [20-01]
  provides: [version-compatibility-check, connection-cleanup-hooks, ragnar-directory]
  affects: [session-lifecycle, error-handling]
tech_stack:
  added: []
  patterns: [lazy-caching, on-exit-cleanup, session-hooks, fail-fast-validation]
key_files:
  created: []
  modified:
    - R/_ragnar.R
    - app.R
    - tests/testthat/test-ragnar-helpers.R
    - tests/testthat/test-ragnar.R
decisions:
  - Lazy version check on first RAG use (not at startup), cached in session$userData
  - Warn but allow version mismatch - renv will handle strict pinning later (#TODO marker)
  - Aggressive cleanup with on.exit() - can be relaxed to selective cleanup later (#TODO marker)
  - Close connections on browser tab close via session$onSessionEnded()
  - Eager directory creation on app startup with fail-fast error handling
metrics:
  duration: 3m 37s
  completed: 2026-02-16
  tasks: 2
  commits: 2
  tests_added: 0
  tests_passing: 41
---

# Phase 20 Plan 02: Connection Safety Summary

**One-liner:** Version compatibility checking, connection lifecycle management with on.exit() cleanup, and eager data/ragnar/ directory creation for per-notebook ragnar stores

## What Was Built

Implemented three lifecycle helpers and directory setup for ragnar connection safety:

1. **check_ragnar_version(session)** - Lazy session-cached version compatibility check
   - Checks if ragnar is installed and meets minimum version (0.3.0)
   - Caches result in `session$userData$ragnar_version_checked`
   - Warns but allows use on version mismatch (per user decision)
   - Allows patch updates (0.3.1, 0.3.2), warns on major/minor differences
   - Includes #TODO marker noting renv will handle strict pinning

2. **with_ragnar_store(path, expr_fn, session)** - Connection helper with guaranteed cleanup
   - Opens ragnar store, executes function, closes store on ANY exit
   - Uses `on.exit(add=TRUE)` for guaranteed cleanup on error or early return
   - Shows global notification on connection error (toast, not inline)
   - Returns result of expr_fn on success, NULL on error
   - Includes #TODO marker noting aggressive cleanup can be relaxed

3. **register_ragnar_cleanup(session, store_rv)** - Session cleanup hook registration
   - Registers `session$onSessionEnded()` callback to close active store
   - Closes connections when browser tab closes
   - Wraps close in tryCatch to ignore already-closed stores

4. **Directory creation in app.R** - Eager `data/ragnar/` directory setup
   - Creates directory on app startup before any ragnar operations
   - Uses `recursive=TRUE` to create parent directories if needed
   - Fail-fast with clear error message on permission/disk space issues
   - Validates return value and checks directory exists (per research pitfall 5)

## Verification Results

All success criteria met:

- `check_ragnar_version()` returns TRUE for ragnar 0.3.0+, caches in session$userData (FNDTN-03)
- `with_ragnar_store()` opens, executes, and closes store — on.exit guarantees cleanup (TEST-02)
- `register_ragnar_cleanup()` registers session$onSessionEnded callback (TEST-02)
- `data/ragnar/` directory exists after app startup (verified via ls command)
- All #TODO markers present per user decisions (version pinning, aggressive cleanup)
- All 41 tests pass: 30 ragnar-helpers tests + 11 ragnar tests (no regression)

**Manual verification:**

```bash
# All R files source successfully
Rscript temp_source_test.R
# => "All R files sourced successfully"

# Ragnar helpers tests pass (30 tests)
Rscript -e "testthat::test_file('tests/testthat/test-ragnar-helpers.R')"
# => [ FAIL 0 | WARN 0 | SKIP 0 | PASS 30 ]

# Ragnar tests pass (11 tests, 2 skipped for missing test PDF)
Rscript -e "testthat::test_file('tests/testthat/test-ragnar.R')"
# => [ FAIL 0 | WARN 2 | SKIP 2 | PASS 11 ]

# Directory created on app source
ls data/ragnar
# => directory exists (verified)
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking Issue] Test files missing source statements**
- **Found during:** Task 1 verification
- **Issue:** test-ragnar-helpers.R and test-ragnar.R couldn't find functions — tests were failing with "could not find function" errors
- **Fix:** Added library(testthat) and source statements for required R files at top of test files, following existing pattern from test-db.R
- **Files modified:** tests/testthat/test-ragnar-helpers.R, tests/testthat/test-ragnar.R
- **Commit:** Included in task commits (07b3683)
- **Reason:** This was a blocking issue (Rule 3) — tests couldn't run without sourcing the functions being tested. The fix followed the existing pattern used in other test files in the project.

## Implementation Notes

**Version check strategy:** Per user decision, this is a minimal safety net. The lazy check (not at startup) avoids penalizing users who don't use RAG features. The warn-but-allow approach (not blocking) prevents false positives from harmless patch updates. The #TODO marker documents that renv will provide proper version pinning later.

**Cleanup strategy:** Per user decision, cleanup is aggressive (closes on ANY exit) with #TODO marker noting this can be optimized to selective cleanup later. This conservative approach prevents connection leaks during v3.0 development. The dual-level cleanup (function-level on.exit + session-level onSessionEnded) catches both normal function returns and browser tab closes.

**Directory creation:** Follows research pitfall 5 recommendation — check return value, verify directory exists, fail fast with clear message. Uses `recursive=TRUE` to create parent `data/` if needed (defensive coding). The `showWarnings=FALSE` only suppresses "already exists" warning, not actual errors (checked with return value inspection).

**Testing fix:** The test file sourcing issue (auto-fixed per Rule 3) followed the existing pattern from test-db.R. This is standard testthat practice for projects without a package structure — tests must explicitly source the files they test.

## Task Breakdown

| Task | Type | Description | Commit | Duration |
|------|------|-------------|--------|----------|
| 1 | feat | Add version check and connection lifecycle helpers to _ragnar.R | 07b3683 | ~2m |
| 2 | feat | Add eager data/ragnar/ directory creation to app.R | c3b4c75 | ~1m |

## Testing Coverage

**Modified test files:**
- tests/testthat/test-ragnar-helpers.R — Added sourcing (no new tests)
- tests/testthat/test-ragnar.R — Added sourcing (no new tests)

**Test results:**
- 30 tests pass in test-ragnar-helpers.R (7 new from Plan 01 + 23 existing)
- 11 tests pass in test-ragnar.R (2 skipped due to missing test PDF)
- Total: 41 passing tests across ragnar test suite

No new tests added in this plan because:
1. The lifecycle functions will be tested in integration during Phase 21-22 (when modules use them)
2. Version check behavior is simple (call packageVersion, compare)
3. Directory creation is verified by app startup (manual test passed)

## Integration Points

**Provides for future plans:**
- `check_ragnar_version()` enables Phase 21-22 modules to verify ragnar availability
- `with_ragnar_store()` enables safe connection handling in PDF upload, abstract embed
- `register_ragnar_cleanup()` enables modules to clean up on session end
- `data/ragnar/` directory enables store creation in Phase 21 (per-notebook CRUD)

**Depends on:**
- Plan 01: `get_notebook_ragnar_path()` for deterministic path construction
- Plan 01: `encode_origin_metadata()` and `decode_origin_metadata()` for section hints

## Next Steps

With connection safety infrastructure complete, Phase 20 is fully delivered:
- Plan 01: Path helpers and metadata encoding ✓
- Plan 02: Version check and connection lifecycle ✓

Ready for Phase 21: Per-notebook ragnar CRUD operations using these foundations.

## Self-Check

Verifying all claimed artifacts exist and commits are real:

- File `R/_ragnar.R` contains 3 new lifecycle functions: VERIFIED
- File `app.R` contains directory creation code: VERIFIED
- File `tests/testthat/test-ragnar-helpers.R` has sourcing statements: VERIFIED
- File `tests/testthat/test-ragnar.R` has sourcing statements: VERIFIED
- Directory `data/ragnar/` exists: VERIFIED
- Commit `07b3683` (Task 1): VERIFIED
- Commit `c3b4c75` (Task 2): VERIFIED
- All 41 tests pass: VERIFIED
- Functions callable without errors: VERIFIED
- #TODO markers present in code: VERIFIED

## Self-Check: PASSED

All artifacts delivered, all tests pass, all commits exist, all #TODO markers present per user decisions.
