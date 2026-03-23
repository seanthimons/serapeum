---
title: "fix: v18 Bug Bash Session C — Refiner Data Integrity"
type: fix
date: 2026-03-23
issues: [177, 185, 186]
depends_on: "Session B (test infrastructure)"
---

# fix: v18 Bug Bash Session C — Refiner Data Integrity

## Overview

Three Refiner-adjacent bugs touching similar code paths in `R/research_refiner.R`, `R/mod_research_refiner.R`, and `R/db.R`. Batched together because they share files, require the same test infrastructure (from Session B), and interact at import time.

## Problem Statement

1. **#177 — Double JSON encoding of authors on import:** Authors stored as `'["Smith","Jones"]'` can become `'"[\\"Smith\\",\\"Jones\\"]"'` when round-tripped through the refiner import pipeline. Two code paths feed authors into refiner results (API fetch vs. notebook source), and `create_abstract()` unconditionally calls `toJSON()` even if input is already a JSON string.

2. **#185 — Silent API failure swallowing:** `fetch_candidates_from_seeds()` wraps API calls in `tryCatch` and emits `warning()`/`message()` — both invisible in Shiny. Users see "No candidates found" or incomplete results with no explanation. Six error-handling sites use the wrong pattern; only one uses `showNotification()` correctly.

3. **#186 — Missing refiner cleanup on notebook deletion:** `delete_notebook()` cleans up 10 entity types but skips `refiner_results` and `refiner_runs`, leaving orphaned rows when a source notebook is deleted.

## Technical Approach

### Implementation Order: #186 → #185 → #177

**Rationale:** #186 is simplest and most clearly defined (two DELETE statements + a helper function). #185 requires changing a function's return type and updating callers. #177 requires understanding the exact reproduction case and adding a defensive guard.

---

### Issue #186: Missing ON DELETE CASCADE on Refiner Tables

**Files:** `R/db.R`

**Fix — Add refiner cleanup to `delete_notebook()` (db.R:415-466):**

Insert after the citation audit cleanup block (line 434) and before the chunks block (line 437):

```r
# Delete refiner results for runs sourced from this notebook
dbExecute(con, "
  DELETE FROM refiner_results WHERE run_id IN (
    SELECT id FROM refiner_runs WHERE source_notebook_id = ?
  )
", list(id))

# Delete refiner runs sourced from this notebook
dbExecute(con, "DELETE FROM refiner_runs WHERE source_notebook_id = ?", list(id))
```

This follows the exact pattern of `citation_audit_results`/`citation_audit_runs` cleanup at lines 426-434.

**Fix — Add standalone `delete_refiner_run()` (db.R, near refiner helpers ~line 2326):**

```r
#' Delete a refiner run and its results
#' @param con DuckDB connection
#' @param run_id Refiner run ID
delete_refiner_run <- function(con, run_id) {
  DBI::dbExecute(con, "DELETE FROM refiner_results WHERE run_id = ?", list(run_id))
  DBI::dbExecute(con, "DELETE FROM refiner_runs WHERE id = ?", list(run_id))
}
```

**No migration needed.** DuckDB doesn't enforce FK constraints or CASCADE. Application-level deletion is the project's established pattern (see `delete_network()` at db.R:1836). A belt-and-suspenders migration would require table recreation in DuckDB for FK changes — not worth the risk for a constraint that won't be enforced.

**Scope note:** Runs with `source_type = "fetch"` have `source_notebook_id = NULL` and are not tied to any notebook. These are not orphaned by notebook deletion — they're standalone. The `delete_refiner_run()` function handles their cleanup when needed.

**Tests:**

```r
# tests/testthat/test-refiner.R

test_that("delete_notebook cleans up refiner runs and results", {
  # Setup: create notebook, create refiner_run with source_notebook_id, create refiner_results
  # Act: delete_notebook(con, notebook_id)
  # Assert: 0 rows in refiner_runs and refiner_results for that run
})

test_that("delete_refiner_run removes results before run", {
  # Setup: create run + results
  # Act: delete_refiner_run(con, run_id)
  # Assert: 0 rows in both tables for that run_id
})
```

---

### Issue #185: Silent API Failure Swallowing in Refiner

**Files:** `R/research_refiner.R`, `R/mod_research_refiner.R`

**Fix Part 1 — Change `fetch_candidates_from_seeds()` return type (research_refiner.R:115-204):**

Current signature returns a data frame. Change to return a list with candidates and errors:

```r
fetch_candidates_from_seeds <- function(seed_ids, email, api_key, per_page = 50,
                                         progress_callback = NULL) {
  errors <- character(0)   # <-- NEW: accumulate error messages
  # ... existing code ...

  # Replace each warning() with error accumulation:
  citing <- tryCatch(
    get_citing_papers(sid, email, api_key, per_page = per_page),
    error = function(e) {
      errors[length(errors) + 1] <<- paste0("Seed ", sid, " citing: ", e$message)
      list()
    }
  )
  # ... same for cited and related ...

  # Return list instead of bare data frame:
  list(
    candidates = candidates_df,
    errors = errors
  )
}
```

**Six sites to fix:**

| # | File:Line | Current | Fix |
|---|-----------|---------|-----|
| 1 | `research_refiner.R:142` | `warning("Failed to fetch citing...")` | Accumulate to `errors` |
| 2 | `research_refiner.R:149` | `warning("Failed to fetch cited...")` | Accumulate to `errors` |
| 3 | `research_refiner.R:156` | `warning("Failed to fetch related...")` | Accumulate to `errors` |
| 4 | `research_refiner.R:251` | `message("Ragnar retrieval failed...")` | Accumulate to return value |
| 5 | `mod_research_refiner.R:502` | `message("[refiner] Failed to open ragnar store...")` | `showNotification(..., type = "warning")` |
| 6 | `mod_research_refiner.R:517` | `message("[refiner] Ragnar scoring failed...")` | `showNotification(..., type = "warning")` |

Sites 5 and 6 are already in the Shiny server process — convert directly to `showNotification()`.

**Fix Part 2 — Update caller in mod_research_refiner.R:442-449:**

```r
# Current:
candidates <- fetch_candidates_from_seeds(seed_ids, email, api_key, per_page = 50)

# New:
fetch_result <- fetch_candidates_from_seeds(seed_ids, email, api_key, per_page = 50)
candidates <- fetch_result$candidates

if (length(fetch_result$errors) > 0) {
  showNotification(
    sprintf("%d API error(s) during fetch: %s",
            length(fetch_result$errors),
            paste(head(fetch_result$errors, 3), collapse = "; ")),
    type = "warning",
    duration = 10
  )
}
```

**Fix Part 3 — Also fix `fetch_anchor_refs()` (research_refiner.R:27-29):**

Same pattern — currently uses `warning()`. Change to accumulate errors and return `list(anchor_refs=..., anchor_ids=..., anchor_papers=..., errors=...)`. Update the caller at mod_research_refiner.R:455-460 to surface errors.

**UX decisions (from SpecFlow analysis):**

- **Partial failure:** Show results + warning notification with count of failures. Do NOT block the run.
- **Total failure:** Show "No candidates found" + error notification listing the API errors.
- **Error aggregation:** Cap at 3 error messages in the notification, append "+ N more" if exceeded.
- **No retry logic:** Out of scope. Users can re-run.
- **No persistent error storage:** Errors are ephemeral (notification only). Out of scope for this bug bash.

**Tests:**

```r
test_that("fetch_candidates_from_seeds returns errors on API failure", {
  # Mock get_citing_papers etc. to throw errors
  # Assert result$errors has entries
  # Assert result$candidates is a data frame (possibly empty)
})

test_that("partial API failure still returns successful candidates", {
  # Mock: seed 1 succeeds, seed 2 fails
  # Assert: candidates from seed 1 are present, error for seed 2 is accumulated
})
```

---

### Issue #177: Double JSON Encoding of Authors on Import

**Files:** `R/db.R`, `R/research_refiner.R`

**Root cause — static analysis inconclusive:** Both the API path (fetch_candidates_from_seeds → toJSON at line 185) and the notebook path (prepare_candidates_from_notebook reads pre-encoded string) produce correct results when traced through the standard import pipeline (fromJSON at mod_research_refiner.R:919 → create_abstract → toJSON at db.R:601). The round-trip decode-then-reencode should be idempotent.

**Likely trigger:** The issue manifests when `create_abstract()` receives a pre-encoded JSON string instead of a character vector — this bypasses `fromJSON` decoding (e.g., if the `tryCatch` at line 918-927 silently passes through, or if a caller outside the refiner import path passes pre-encoded authors directly).

**Fix — Defensive guard in `create_abstract()` (db.R:598-602):**

```r
# Current:
authors_json <- if (is.null(authors) || length(authors) == 0) {
  "[]"
} else {
  jsonlite::toJSON(authors, auto_unbox = TRUE)
}

# New:
authors_json <- if (is.null(authors) || length(authors) == 0) {
  "[]"
} else if (is.character(authors) && length(authors) == 1 && jsonlite::validate(authors)) {
  authors  # Already a valid JSON string — pass through
} else {
  jsonlite::toJSON(authors, auto_unbox = TRUE)
}
```

This guard is safe because:
- A single-author character vector like `c("Smith")` is NOT valid JSON (no brackets/quotes)
- A pre-encoded JSON array `'["Smith","Jones"]'` IS valid JSON and passes through
- `jsonlite::validate()` is fast (string-only check, no parsing)

**Fix — Ensure `prepare_candidates_from_notebook()` consistently decodes (research_refiner.R:57-83):**

The notebook path reads `authors` as a JSON string from the DB but does not decode it. When this flows through `save_refiner_results()` → `refiner_results.authors` → import → `fromJSON()` → `create_abstract()`, the chain works. But add a comment documenting this intentional non-decoding to prevent future confusion:

```r
# Note: authors column from abstracts table is already JSON-encoded.
# It flows as a string through refiner_results.authors, then is decoded
# by fromJSON() during import (mod_research_refiner.R:919).
```

**Tests:**

```r
test_that("create_abstract handles pre-encoded JSON authors", {
  # Pass '["Smith","Jones"]' as authors to create_abstract
  # Read back from DB, parse, assert c("Smith", "Jones")
})

test_that("create_abstract handles character vector authors", {
  # Pass c("Smith", "Jones") as authors
  # Read back, parse, assert same result as above
})

test_that("authors survive full refiner round-trip (API path)", {
  # Create abstract with c("A", "B")
  # Read via prepare_candidates_from_notebook
  # Simulate save_refiner_results
  # Simulate import (fromJSON -> create_abstract)
  # Assert no double encoding
})

test_that("authors survive full refiner round-trip (fetch path)", {
  # Simulate fetch_candidates_from_seeds output with toJSON authors
  # Simulate save_refiner_results
  # Simulate import
  # Assert no double encoding
})

test_that("single author is not double-encoded", {
  # Edge case: authors = c("Solo Author")
  # toJSON with auto_unbox = TRUE produces '"Solo Author"' (bare string)
  # Ensure fromJSON -> create_abstract round-trip preserves correctly
})
```

---

## Acceptance Criteria

### #186 — Refiner Cleanup
- [x] `delete_notebook()` removes `refiner_results` and `refiner_runs` for the deleted notebook
- [x] `delete_refiner_run()` function exists and deletes results before run
- [x] No orphaned rows after notebook deletion (verified by unit test)

### #185 — Error Surfacing
- [x] `fetch_candidates_from_seeds()` returns `list(candidates=..., errors=...)`
- [x] Partial API failure: user sees results + warning notification
- [x] Total API failure: user sees error notification with details
- [x] Full success: no notification (preserve current behavior)
- [x] `fetch_anchor_refs()` also surfaces errors
- [x] `message()` calls in module server converted to `showNotification()`

### #185 — Error Surfacing (cont.)
- [x] Error messages include seed ID for context
- [x] Notifications capped at 3 errors + "N more" overflow

### #177 — Author Encoding
- [x] `create_abstract()` detects and passes through pre-encoded JSON authors
- [x] Character vector authors are encoded correctly (existing behavior)
- [x] Single-author edge case handled correctly
- [x] Round-trip test passes for both API and notebook paths
- [x] Comment documents the intentional non-decoding in `prepare_candidates_from_notebook()`

### All Issues
- [x] New test file `tests/testthat/test-refiner.R` covers all three fixes
- [x] Shiny smoke test passes after all changes
- [x] No regressions in existing `test-db.R` tests

## Dependencies & Risks

**Depends on Session B:** Test infrastructure must be reliable (`test_path()` resolution, migration runner) before writing new DB-backed tests.

**Risk — #177 root cause uncertainty:** Static analysis suggests the standard paths are correct. The defensive guard in `create_abstract()` is good hardening regardless, but if the actual bug has a different trigger, it may persist. **Mitigation:** Write the round-trip tests first (TDD). If they pass without the fix, the reproduction case differs from what we expect — investigate further before applying the guard.

**Risk — #185 return type change is a breaking API change:** `fetch_candidates_from_seeds()` currently returns a data frame; changing to a list breaks any caller that treats it as a data frame. **Mitigation:** Search for all callers (should be only `mod_research_refiner.R:442`). Verify no other modules or scripts call this function.

**Risk — #186 deletion during active refiner run:** If a notebook is deleted while a refiner run is in progress against it, the run gets empty candidates. **Mitigation:** Out of scope for this fix. Document as a known edge case.

## References

### Internal
- `R/research_refiner.R:57-204` — `prepare_candidates_from_notebook()`, `fetch_candidates_from_seeds()`
- `R/research_refiner.R:245-258` — `score_from_ragnar_store()` silent failure
- `R/mod_research_refiner.R:440-540` — Scoring pipeline with silent catches
- `R/mod_research_refiner.R:906-956` — Import pipeline (fromJSON → create_abstract)
- `R/db.R:296-339` — Refiner table DDL (init_schema)
- `R/db.R:415-466` — `delete_notebook()` missing refiner cleanup
- `R/db.R:589-637` — `create_abstract()` author encoding
- `R/db.R:2326-2465` — Refiner CRUD helpers
- `tests/testthat/test-db.R` — Existing DB test patterns to follow
- `docs/brainstorms/2026-03-22-v18-bug-bash-brainstorm.md` — Session plan

### Issues
- [#177](https://github.com/seanthimons/serapeum/issues/177) — Double JSON encoding of authors on import
- [#185](https://github.com/seanthimons/serapeum/issues/185) — Silent API failure swallowing in Refiner
- [#186](https://github.com/seanthimons/serapeum/issues/186) — Missing ON DELETE CASCADE on refiner tables
