# Phase 44: Tech Debt Cleanup - Research

**Researched:** 2026-03-04
**Domain:** R/DuckDB connection lifecycle, dead code removal, test infrastructure
**Confidence:** HIGH

## Summary

Phase 44 addresses connection leak and dead code issues that were **already implemented** in Phase 25 (v4.0) via commit 9c16371 on 2026-02-18, but are tracked in v10.0 requirements as foundational cleanup before AI synthesis features.

The technical work is complete:
- DEBT-01: `search_chunks_hybrid()` connection leak was fixed with `own_store` tracking and `on.exit()` cleanup
- DEBT-02: Dead code (`with_ragnar_store()`, `register_ragnar_cleanup()`) was removed (83 lines deleted)

**Primary recommendation:** This phase is a documentation/verification phase. Create a minimal plan that validates the existing fixes, adds missing connection leak detection tests, and marks DEBT-01/DEBT-02 as satisfied in REQUIREMENTS.md.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| DBI | 1.2.x | Database interface | R standard for DB connections |
| duckdb | 1.1.x | Database backend | Project's embedded database |
| testthat | 3.x | Unit testing | R standard test framework |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| withr | 3.x | Resource cleanup testing | Verify on.exit() behavior |

**Installation:**
```r
# Already in project renv.lock
renv::restore()
```

## Architecture Patterns

### Recommended Project Structure
```
tests/testthat/
├── test-db.R              # Database connection tests
├── test-ragnar.R          # Ragnar store lifecycle tests
└── test-db-leak.R         # NEW: Connection leak detection test
```

### Pattern 1: Resource Ownership Tracking
**What:** Track whether a function created a resource vs. received it from caller, and only clean up self-created resources.

**When to use:** When a function can either create a new connection or accept an existing one from the caller.

**Example:**
```r
# Source: R/db.R:search_chunks_hybrid (commit 9c16371)
search_chunks_hybrid <- function(con, query, notebook_id = NULL, limit = 5,
                                  ragnar_store = NULL,
                                  ragnar_store_path = NULL, ...) {
  # Track ownership: did WE create this store?
  own_store <- is.null(ragnar_store)
  store <- ragnar_store %||% connect_ragnar_store(ragnar_store_path)

  # Only close if we created it
  if (!is.null(store) && own_store) {
    on.exit(
      tryCatch(DBI::dbDisconnect(store@con, shutdown = TRUE), error = function(e) NULL),
      add = TRUE
    )
  }

  # ... use store ...
}
```

**Why this works:**
- Callers passing a `ragnar_store` retain full lifecycle control (they opened it, they close it)
- Internal calls passing `NULL` get a new store that is auto-closed via `on.exit()`
- `add = TRUE` ensures cleanup stacks correctly with other `on.exit()` handlers

### Pattern 2: Graceful Error Handling in Cleanup
**What:** Wrap `on.exit()` cleanup in `tryCatch()` to prevent cleanup errors from masking original errors.

**When to use:** Always, for cleanup operations that might fail (network, filesystem, database).

**Example:**
```r
on.exit(
  tryCatch(DBI::dbDisconnect(store@con, shutdown = TRUE), error = function(e) NULL),
  add = TRUE
)
```

**Why:** If the store connection is already invalid, `dbDisconnect()` will error. Using `tryCatch(..., error = function(e) NULL)` silences this so the original error (if any) is preserved.

### Anti-Patterns to Avoid
- **Global cleanup registries:** Tried in Phase 20 (`register_ragnar_cleanup()`), removed in Phase 25. Brittle across Shiny sessions.
- **Always closing regardless of ownership:** Breaks when callers pass a shared connection used elsewhere.
- **No ownership tracking:** Leads to either leaks (never close) or crashes (close someone else's resource).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Resource cleanup | Custom finalizers, reference counting | `on.exit(..., add = TRUE)` | R's on.exit is stack-based, handles exceptions, and is testable |
| Connection leak detection | Manual polling of open connections | testthat + withr::defer() | Existing test infrastructure validates cleanup behavior |
| Dead code detection | Manual grep through codebase | Git grep + static analysis | Zero-caller confirmation is mechanical, no custom tooling needed |

**Key insight:** R's `on.exit()` is purpose-built for exception-safe resource cleanup. Adding custom cleanup registries (as attempted in v3.0 Phase 20) introduces state management complexity without benefit.

## Common Pitfalls

### Pitfall 1: Secondary Connection Leaks from ensure_ragnar_store()
**What goes wrong:** `ensure_ragnar_store()` returns an open store; callers forget to close it after indexing.

**Why it happens:** The function signature doesn't make ownership clear — caller assumes auto-cleanup.

**How to avoid:**
- Document that `ensure_ragnar_store()` returns a caller-owned resource
- Add `on.exit()` immediately after assignment in caller code
- Audit all callers as part of verification (already done in Phase 25)

**Warning signs:**
```r
# LEAK: store opened but never closed
store <- ensure_ragnar_store(nb_id, session, api_key, embed_model)
build_ragnar_index(store)
# Missing: on.exit(DBI::dbDisconnect(store@con, shutdown = TRUE))
```

**Current status:** Identified in Phase 25 audit (mod_search_notebook.R:2061), logged as deferred for future fix. NOT in Phase 44 scope.

### Pitfall 2: Forgetting add = TRUE in on.exit()
**What goes wrong:** Multiple `on.exit()` calls without `add = TRUE` overwrite each other. Only the last one runs.

**Why it happens:** Default `on.exit(expr)` replaces the exit handler; `add = TRUE` appends instead.

**How to avoid:** Always use `on.exit(..., add = TRUE)` unless you explicitly want to replace.

**Warning signs:** Cleanup code not running when you expect it to.

### Pitfall 3: Testing Connection Leaks Without Isolation
**What goes wrong:** Test suite shows false negatives because R garbage collector closes leaked connections eventually.

**Why it happens:** DuckDB connections are closed when objects are GC'd, masking leaks in short-lived test functions.

**How to avoid:**
- Explicitly count open connections before/after operations
- Use `gc()` to force collection between test phases
- Test under load (many sequential operations) to exhaust connection pool

**Warning signs:** Manual testing shows exhaustion but tests pass.

## Code Examples

Verified patterns from official sources:

### Ownership-Aware Resource Cleanup
```r
# Source: R/db.R:search_chunks_hybrid (commit 9c16371)
# CORRECT: Only close if we opened it
own_store <- is.null(ragnar_store)
store <- ragnar_store %||% connect_ragnar_store(ragnar_store_path)

if (!is.null(store) && own_store) {
  on.exit(
    tryCatch(DBI::dbDisconnect(store@con, shutdown = TRUE), error = function(e) NULL),
    add = TRUE
  )
}
```

### Dead Code Removal (Commit Evidence)
```bash
# Source: commit 9c16371 (Phase 25-02)
# Removed: with_ragnar_store(), register_ragnar_cleanup()
# Confirmed zero callers via git grep before deletion
git log --oneline -S "with_ragnar_store" | head -5
# Returns: 9c16371 fix(25-02): DEBT-01/02/03
```

### Connection Leak Test Pattern (NEW for Phase 44)
```r
# NOT YET IMPLEMENTED — proposed for Plan 44-01
test_that("search_chunks_hybrid closes self-opened stores", {
  tmp_db <- tempfile(fileext = ".duckdb")
  con <- get_db_connection(tmp_db)
  on.exit({ close_db_connection(con); unlink(tmp_db) })

  # Query without passing ragnar_store — function must open & close internally
  result <- search_chunks_hybrid(con, "test query", limit = 5)

  # Verify: no leaked DuckDB connections remain
  # (Implementation detail: need to check duckdb connection pool or OS file handles)
  expect_true(TRUE) # Placeholder — real check needs DuckDB introspection
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Global cleanup registry (`register_ragnar_cleanup()`) | Ownership tracking + `on.exit()` | Phase 25 (2026-02-18) | Removed 83 lines of brittle state management; cleanup now automatic |
| Caller assumes auto-close everywhere | Explicit ownership via `own_store` flag | Phase 25 (2026-02-18) | Enables shared connections without leaks |

**Deprecated/outdated:**
- `with_ragnar_store()`: Connection scoping helper — deleted in commit 9c16371 (zero callers)
- `register_ragnar_cleanup()`: Global cleanup list — deleted in commit 9c16371 (Shiny session isolation issues)

## Open Questions

1. **Connection leak detection test**
   - What we know: No existing test validates that `search_chunks_hybrid()` cleanup works correctly
   - What's unclear: Best way to observe DuckDB connection state in tests (file handles? duckdb package introspection?)
   - Recommendation: Research DuckDB connection pool APIs or use OS-level file handle counting as proxy

2. **Secondary leak in mod_search_notebook.R**
   - What we know: `ensure_ragnar_store()` call on line ~2061 leaves store open after indexing (logged in Phase 25 SUMMARY)
   - What's unclear: Whether this is in scope for Phase 44 or deferred to future phase
   - Recommendation: REQUIREMENTS.md only lists DEBT-01/DEBT-02; secondary leak is NOT in scope per current requirements

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.x |
| Config file | tests/testthat.R |
| Quick run command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat', filter = 'db-leak')"` |
| Full suite command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEBT-01 | search_chunks_hybrid closes self-opened connections | unit | `testthat::test_file('tests/testthat/test-db-leak.R')` | ❌ Wave 0 |
| DEBT-02 | with_ragnar_store, register_ragnar_cleanup removed | manual | `git grep "with_ragnar_store\|register_ragnar_cleanup" R/` returns empty | ✅ Manual check |

**Note:** Success criterion #3 ("Connection leak detection test added to CI") requires creating `test-db-leak.R` with connection lifecycle validation.

### Sampling Rate
- **Per task commit:** `testthat::test_file('tests/testthat/test-db-leak.R')` (once created)
- **Per wave merge:** `testthat::test_dir('tests/testthat')`
- **Phase gate:** Full suite green + manual git grep verification before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/testthat/test-db-leak.R` — covers DEBT-01 (validate search_chunks_hybrid cleanup)

**Rationale:** DEBT-02 (dead code removal) was already done in commit 9c16371 and can be verified via git grep. DEBT-01 fix exists but lacks automated test coverage.

## Sources

### Primary (HIGH confidence)
- Commit 9c16371 (2026-02-18): "fix(25-02): DEBT-01/02/03 - connection leak, section_hint encoding, dead code" — direct implementation evidence
- .planning/milestones/v4.0-phases/25-stabilize/25-02-SUMMARY.md — detailed postmortem of DEBT-01/02 fixes
- R/db.R:search_chunks_hybrid (lines 794-974) — current implementation with `own_store` pattern
- GitHub issue #117 (CLOSED): tech-debt connection leak — original bug report
- GitHub issue #119 (CLOSED): tech-debt dead code removal — original bug report

### Secondary (MEDIUM confidence)
- .planning/STATE.md (lines 62, 68-69) — notes secondary leak in ensure_ragnar_store() as known deferred item
- testthat documentation (https://testthat.r-lib.org/) — test framework patterns

### Tertiary (LOW confidence)
- None — all findings confirmed via primary sources (git history, source code)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - DBI/duckdb/testthat are project dependencies in renv.lock
- Architecture: HIGH - Implementation already exists in codebase (commit 9c16371)
- Pitfalls: HIGH - Documented in Phase 25 postmortem from actual implementation experience

**Research date:** 2026-03-04
**Valid until:** 2026-04-04 (30 days — stable domain, existing implementation)

---

## IMPLEMENTATION STATUS

**CRITICAL:** DEBT-01 and DEBT-02 requirements were **already satisfied** in Phase 25 (commit 9c16371, 2026-02-18). This phase exists in v10.0 roadmap as foundational cleanup before AI synthesis features.

**What Phase 44 needs to do:**
1. Create connection leak detection test (`tests/testthat/test-db-leak.R`) to cover DEBT-01
2. Verify dead code removal persists (git grep for `with_ragnar_store`, `register_ragnar_cleanup`)
3. Update REQUIREMENTS.md to mark DEBT-01, DEBT-02 as satisfied
4. Mark Phase 44 complete in ROADMAP.md

**What Phase 44 does NOT need to do:**
- Implement connection leak fix (already done)
- Remove dead code (already done)
- Fix secondary leak in ensure_ragnar_store() (not in current requirements)
