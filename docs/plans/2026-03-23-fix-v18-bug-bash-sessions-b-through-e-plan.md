---
title: "fix: v18 Bug Bash — Sessions B through E"
type: fix
date: 2026-03-23
milestone: v18
depends_on: docs/plans/2026-03-22-fix-v18-bug-bash-session-a-surgical-fixes-plan.md
---

# fix: v18 Bug Bash — Sessions B through E

## Overview

Complete the remaining 7 issues from the v18 Bug Bash milestone across 4 sessions. Session A (7 surgical fixes) is already merged. The remaining sessions progress from test infrastructure → data integrity → reactivity → RAG quality, with explicit dependency ordering.

## Problem Statement

The v18 milestone accumulated 13 bugs across test infrastructure, data integrity, UI reactivity, and RAG quality. Session A addressed 7 one-line fixes. The remaining 7 issues require deeper investigation and have inter-session dependencies (B must complete before C).

## Session B: Test Infrastructure (#213, #214)

**Why first:** 29 of 37 test files use a `getwd()` anti-pattern that makes tests fail under `devtools::test()` or CI runners. All downstream sessions rely on tests passing reliably.

### Issue #213: `getwd()` Anti-Pattern in Test Files

**Root cause:** Test files resolve the project root via `normalizePath(file.path(dirname(dirname(getwd()))))`. This only works when `getwd()` is the project root, not when testthat sets it to `tests/testthat/`.

**Scope decision:** Fix ALL 29 affected test files, not just `test-config.R`. The anti-pattern is identical across files — a systematic find-and-replace approach.

**Fix:**
1. Create a shared test helper `tests/testthat/helper-source.R` that testthat auto-loads
2. Define a `source_app()` helper using `testthat::test_path()` to resolve paths reliably:
   ```r
   # tests/testthat/helper-source.R
   source_app <- function(...) {
     # test_path() always resolves relative to tests/testthat/
     app_root <- normalizePath(file.path(test_path(), "..", ".."), mustWork = TRUE)
     files <- c(...)
     for (f in files) {
       source(file.path(app_root, "R", f), local = FALSE)
     }
   }
   ```
3. Replace the boilerplate in each test file:
   ```r
   # BEFORE (29 files)
   project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
   if (!file.exists(file.path(project_root, "R", "config.R"))) {
     project_root <- getwd()
   }
   source(file.path(project_root, "R", "config.R"))

   # AFTER
   source_app("config.R")
   ```

**Acceptance criteria:**
- [x] All 29 test files use `source_app()` or `test_path()` — zero `getwd()` calls remain
- [x] `testthat::test_dir("tests/testthat")` passes from project root
- [x] Tests also pass when working directory is `tests/testthat/` (simulating `devtools::test()`)
- [x] `helper-source.R` auto-loaded by testthat (no explicit `source()` needed)

### Issue #214: `test-db.R` Schema Drift + Missing Source

**Root cause:** `test-db.R` calls `init_schema()` but does not call `run_pending_migrations()`, so columns added by migrations 001–019 are missing. Additionally, `pdf_images.R` is not sourced, causing "function not found" errors for any test touching PDF image functions.

**Fix:**
1. Add `pdf_images.R` to the source list in `test-db.R`
2. After `init_schema(con)`, call `run_pending_migrations(con)` so the test DB has the full schema
3. Verify all test assertions match the current schema (columns added by migrations exist)

**Acceptance criteria:**
- [x] `test-db.R` sources all required files including `pdf_images.R`
- [x] Test DB gets full schema via `init_schema()` + `run_pending_migrations()`
- [x] All tests in `test-db.R` pass with no schema-related failures
- [x] No manual `ALTER TABLE` needed — migrations handle everything

**Edge case:** Migration files use relative path `"migrations"` which also depends on the `getwd()` fix from #213. The helper must resolve migration paths correctly too.

---

## Session C: Refiner Data Integrity (#177, #185, #186)

**Depends on:** Session B (test infrastructure must be reliable before writing data integrity tests).

### Issue #177: Double JSON Encoding of Authors on Import

**Root cause analysis from SpecFlow:** Two code paths feed authors into the refiner:
1. **API path** (`fetch_candidates_from_seeds()`): `parse_openalex_work()` returns `authors` as `c("Smith", "Jones")` → `toJSON()` → `'["Smith","Jones"]'` ✅ correct
2. **DB path** (`prepare_candidates_from_notebook()`): reads `authors` column from `abstracts` table where it's already `'["Smith","Jones"]'` → if this feeds into `toJSON()` again → `'"[\\"Smith\\",\\"Jones\\"]"'` ❌ double-encoded

**Fix:**
1. In `prepare_candidates_from_notebook()`: detect if `authors` is already a JSON string before serializing
2. Guard: `if (is.character(x) && startsWith(x, "[")) return(x)` — skip `toJSON()` for pre-serialized values
3. Alternatively, always deserialize first, then re-serialize consistently

**Test:**
```r
test_that("authors are not double-encoded from DB path", {
  # Insert a paper with JSON-encoded authors
  # Run prepare_candidates_from_notebook()
  # Assert authors column is valid JSON with no escape sequences
  parsed <- jsonlite::fromJSON(result$authors)
  expect_type(parsed, "character")  # Should be c("Smith", "Jones"), not a JSON string
})
```

**Acceptance criteria:**
- [ ] Authors from API path display correctly (no change)
- [ ] Authors from DB path (notebook anchor) display correctly (no double encoding)
- [ ] `fromJSON(result$authors)` returns a character vector, not a nested JSON string
- [ ] Unit test covers both code paths

### Issue #185: Silent API Failure Swallowing in Refiner

**Current behavior:** `fetch_candidates_from_seeds()` wraps API calls in `tryCatch`, emits `warning()`, returns empty list. Shiny does not surface `warning()` to users.

**Fix:**
1. Accumulate errors during the fetch loop: `errors <- list()` + append on each failure
2. After all seeds processed, return both results and errors: `list(candidates = ..., errors = ...)`
3. In `mod_research_refiner.R` server, check for errors and show a summary notification:
   ```r
   if (length(result$errors) > 0) {
     showNotification(
       sprintf("%d of %d seeds failed: %s",
               length(result$errors), total_seeds,
               paste(result$errors, collapse = "; ")),
       type = "warning",
       duration = 10
     )
   }
   ```

**Acceptance criteria:**
- [ ] Partial success: if 3 of 5 seeds succeed, user sees results + warning notification
- [ ] Total failure: if all seeds fail, user sees error notification with details
- [ ] Full success: no notification (current behavior preserved)
- [ ] Error messages include the seed title/ID for context
- [ ] Unit test verifies error accumulation with simulated API failure

### Issue #186: Missing ON DELETE CASCADE on Refiner Tables

**⚠️ Pre-implementation check:** Run `duckdb::duckdb_version()` to verify FK enforcement support. DuckDB < 0.10.0 does NOT enforce foreign keys, making CASCADE a no-op.

**Strategy (application-level, safe regardless of DuckDB version):**
1. Create `delete_refiner_run()` function in `db.R`:
   ```r
   delete_refiner_run <- function(con, run_id) {
     # Delete children first, then parent
     DBI::dbExecute(con, "DELETE FROM refiner_results WHERE run_id = ?", list(run_id))
     DBI::dbExecute(con, "DELETE FROM refiner_runs WHERE id = ?", list(run_id))
   }
   ```
2. Add a new migration (020) that adds `ON DELETE CASCADE` to the FK constraint — this is belt-and-suspenders even if DuckDB doesn't enforce it today
3. If DuckDB requires table recreation for FK changes, use `CREATE TABLE new ... AS SELECT * FROM old; DROP old; ALTER TABLE new RENAME TO old;`

**Acceptance criteria:**
- [ ] `delete_refiner_run()` function exists and deletes results before run
- [ ] Unit test: create run with results → delete run → assert both tables are clean
- [ ] Migration 020 adds CASCADE constraint (even if DuckDB ignores it today)
- [ ] No orphaned `refiner_results` rows after run deletion

---

## Session D: Import Badge Reactivity (#154)

**Independent of B/C.** Requires a running app for verification.

### Issue #154: Import Badge Doesn't Update on Citation Mapping

**Investigation needed:** The term "citation mapping" doesn't appear in `mod_search_notebook.R`. Likely refers to an action in `mod_citation_audit.R` or `mod_research_refiner.R` that adds papers to a notebook without incrementing `notebook_refresh`.

**Investigation steps:**
1. Search all modules for operations that modify notebook contents (INSERT into `abstracts`, `documents`)
2. Cross-reference with `notebook_refresh` increment calls
3. Identify any mutation path that does NOT increment `notebook_refresh`
4. The missing increment is the bug

**Fix pattern:**
```r
# After the mutation that's missing the refresh trigger:
notebook_refresh(notebook_refresh() + 1)
```

**Acceptance criteria:**
- [ ] Identify the exact code path where citation mapping occurs
- [ ] After citation mapping, `notebook_refresh` is incremented
- [ ] Badge updates immediately without page refresh
- [ ] Manual verification in running app: map citation → badge updates
- [ ] No double-increment on paths that already refresh

**Testing:** This requires `shinytest2` or manual verification. Recommend manual smoke test via `shiny::runApp()`.

---

## Session E: RAG Citation Quality (#159)

**Independent.** Deepest investigation — may require prompt engineering iteration.

### Issue #159: Abstract Chat Doesn't Reference Papers Correctly

**Root cause analysis:**
- `build_context()` produces labels: `Source [test.pdf, p.5]:` or `Source [Paper Title]:`
- System prompt instructs: "Cite using (Author, Year, p.X) format"
- **Mismatch:** Source labels contain filenames/titles but NOT author names or publication years
- The LLM must infer author/year from chunk content — often impossible, leading to hallucinated citations

**Two possible approaches:**

**Approach A: Enrich source labels with metadata (recommended)**
- Modify `build_context()` to include author/year in source labels when available
- For abstracts: `Source [Smith et al., 2024, abstract]:`
- For documents: `Source [test.pdf, p.5]:` (unchanged — documents may not have structured metadata)
- Requires looking up paper metadata from the `abstracts` table for each chunk

**Approach B: Relax citation instructions**
- Change system prompt to: "Reference sources using the labels provided (e.g., [Paper Title] or [filename, p.X])"
- Simpler but lower citation quality

**Recommended fix (Approach A):**
1. In `build_context()`, when source is an abstract, look up first author + year from the `abstracts` table
2. Format as `Source [Author, Year, abstract]:` instead of `Source [Paper Title]:`
3. Update system prompt citation rules to match the new label format
4. Also check `build_context_by_paper()` for consistency

**Acceptance criteria:**
- [ ] Abstract chunks have author/year in source labels
- [ ] System prompt citation instructions match the source label format
- [ ] Manual test: ask a question → LLM cites papers with author/year format
- [ ] No regression for document chunks (still use filename/page)
- [ ] build_context() and build_context_by_paper() use consistent labeling

**Risk:** LLM output is non-deterministic. Define "done" as: source labels contain the right metadata AND prompt instructions are consistent with labels. Whether the LLM follows instructions perfectly is out of scope.

---

## Verification Protocol (All Sessions)

Each session follows a **fix → review → UAT** cycle before marking issues as squashed:

### 1. Post-Implementation Review
After implementing fixes for a session:
- [ ] Run `/pr-review` or `/compound-engineering:\workflows:review` on the diff
- [ ] Address any HIGH/MEDIUM findings before proceeding
- [ ] Verify no regressions introduced (full test suite pass)

### 2. Bug Confirmation (UAT)
For each issue in the session, confirm the original bug is squashed:
- [ ] **Reproduce the original bug** — verify it existed before the fix (git stash / branch comparison)
- [ ] **Verify the fix** — run the exact scenario that triggered the bug and confirm it no longer occurs
- [ ] **Edge case check** — test at least one boundary condition per fix
- [ ] **Regression sweep** — run full `testthat::test_dir("tests/testthat")` to confirm nothing else broke

### 3. Session Sign-Off
- [ ] All issue acceptance criteria met
- [ ] Review findings addressed
- [ ] UAT passed for every issue in the session
- [ ] Commit with descriptive message referencing issue numbers

---

## Execution Order

```
Session B (#213, #214) ──→ Session C (#177, #185, #186) ──→ commit
     ↓ (parallel)                                              ↓
Session D (#154) ────────────────────────────────────────→ commit
Session E (#159) ────────────────────────────────────────→ commit
```

- **B → C** is sequential (test infra before data integrity)
- **D and E** can run in parallel with C (different code paths, different testing approaches)
- Each session gets its own commit for clean git history

## Pre-Flight Checks

Before starting any session:
- [ ] Verify current branch is `v18-bug-bash`
- [ ] Run `duckdb::duckdb_version()` to determine FK enforcement support (#186)
- [ ] Run existing tests to establish baseline pass/fail count
- [ ] Confirm Session A commit (`65324e6`) is in the branch history

## Success Metrics

- All 7 issues resolved with tests
- Full test suite passes under both `Rscript` and `devtools::test()`
- No regressions in existing functionality
- Clean commit history with one commit per session

## References

- Brainstorm: `docs/brainstorms/2026-03-22-v18-bug-bash-brainstorm.md`
- Session A plan: `docs/plans/2026-03-22-fix-v18-bug-bash-session-a-surgical-fixes-plan.md`
- Session A commit: `65324e6`
- PR #233 review findings (reactive observer patterns, prompt instruction loss)
- Key files: `R/db.R`, `R/db_migrations.R`, `R/rag.R`, `R/research_refiner.R`, `R/mod_research_refiner.R`, `R/api_openalex.R`, `R/utils_scoring.R`
