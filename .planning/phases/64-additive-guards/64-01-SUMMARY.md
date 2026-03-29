---
phase: 64-additive-guards
plan: 01
subsystem: reactive-safety
tags: [guards, req, isolate, validation, defensive]
dependency_graph:
  requires: []
  provides: [GARD-01, GARD-02, GARD-03]
  affects: [R/mod_query_builder.R, R/api_artificialanalysis.R, R/db.R]
tech_stack:
  added: []
  patterns: [req()-guard, input-validation, NA-normalization, TDD]
key_files:
  created:
    []
  modified:
    - R/mod_query_builder.R
    - R/api_artificialanalysis.R
    - R/db.R
    - tests/testthat/test-api-artificialanalysis.R
key_decisions:
  - "Added is.na() check explicitly alongside nzchar() — nzchar(NA_character_) returns TRUE not NA, so plan's 'falsy in || context' note was incorrect; explicit is.na() guard required"
  - "GARD-02 audit: no code changes needed — all fig_refresh reads in mod_document_notebook.R are inside observeEvent() (auto-isolated) or have explicit isolate(); mod_search_notebook.R has no fig_refresh usage"
metrics:
  duration: "~15 minutes"
  completed: "2026-03-27"
  tasks_completed: 2
  files_modified: 4
---

# Phase 64 Plan 01: Additive Guards Summary

**One-liner:** Three additive NULL/NA/isolate guards across query builder, match_aa_model, and section_filter with unit test coverage.

## What Was Built

Three defensive guards added to prevent NULL crashes and reactive loops, plus a fig_refresh isolate audit confirming no code changes needed.

### Guard 1 — req(provider, model) in Query Builder (GARD-01)

In `R/mod_query_builder.R` line 80, added `req(provider, model)` after `resolve_model_for_operation()` and before any side effects (the `is.null(provider$api_key)` check and `withProgress()`). This prevents a NULL crash when the app opens with no provider or model configured and the user clicks the generate button.

### Guard 2 — fig_refresh isolate() audit (GARD-02)

Audit confirmed existing code is correct — no changes required:
- Lines 790, 940, 948, 952 in `mod_document_notebook.R`: inside `observeEvent()` bodies (auto-isolated, safe)
- Lines 1033, 1039, 1094 in `mod_document_notebook.R`: inside `observeEvent()` with explicit `isolate()` (belt-and-suspenders, safe)
- Line 992: read-only in `renderUI` (no write, no loop risk)
- `mod_search_notebook.R`: no fig_refresh usage at all

### Guard 3 — Input validation in match_aa_model and section_filter (GARD-03)

**match_aa_model** (`R/api_artificialanalysis.R` line 164): Added early-return guard:
```r
if (is.null(openrouter_id) || is.na(openrouter_id) || !nzchar(openrouter_id)) return(NULL)
```
This prevents the error `argument is of length zero` when `input$quality_model` is NULL on startup. Explicit `is.na()` was required because `nzchar(NA_character_)` returns `TRUE` (not `NA` as the plan suggested), so the plan's guard `!nzchar(openrouter_id)` alone would have missed NA inputs.

**section_filter** (`R/db.R` line 1113): Added normalization block before the existing filter check:
```r
if (!is.null(section_filter)) {
  section_filter <- section_filter[!is.na(section_filter) & nzchar(section_filter)]
  if (length(section_filter) == 0) section_filter <- NULL
}
```
This ensures NA or empty-string values in section_filter are dropped, and if nothing remains the filter falls back to unfiltered retrieval.

### Unit Tests

Added to `tests/testthat/test-api-artificialanalysis.R`:
```r
test_that("match_aa_model returns NULL for NULL openrouter_id", {
  data <- load_bundled_aa_data(app_root())
  expect_null(match_aa_model(NULL, data))
  expect_null(match_aa_model("", data))
  expect_null(match_aa_model(NA_character_, data))
})
```

All 39 test assertions pass (0 failures, 2 pre-existing package version warnings unrelated to these changes).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] is.na() guard required for NA_character_ input**
- **Found during:** Task 2, GREEN phase (tests still failing after initial implementation)
- **Issue:** Plan stated `nzchar(NA_character_)` "returns NA which is falsy in || context" — this is incorrect. In R, `nzchar(NA_character_)` returns `TRUE`, not `NA`. So `!nzchar(NA_character_)` evaluates to `FALSE`, and the guard would not catch NA inputs.
- **Fix:** Added explicit `is.na(openrouter_id)` check: `if (is.null(openrouter_id) || is.na(openrouter_id) || !nzchar(openrouter_id)) return(NULL)`
- **Files modified:** R/api_artificialanalysis.R
- **Commit:** eb873a7

## Verification Results

1. **Shiny smoke test:** App reached "Listening on http://127.0.0.1:3839" — PASS
2. **Unit tests:** 39 assertions, 0 failures — PASS
3. **Code grep confirms all guards:**
   - `grep -n "req(provider, model)" R/mod_query_builder.R` → line 80 — PASS
   - `grep -n "is.null(openrouter_id)" R/api_artificialanalysis.R` → line 164 — PASS
   - `grep -n "is.na(section_filter)" R/db.R` → line 1114 — PASS

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | 14565db | feat(64-01): add req(provider, model) guard in query builder generate handler |
| Task 2 | eb873a7 | feat(64-01): add input validation guards to match_aa_model and section_filter (GARD-03) |

## Self-Check: PASSED

- FOUND: R/mod_query_builder.R
- FOUND: R/api_artificialanalysis.R
- FOUND: R/db.R
- FOUND: tests/testthat/test-api-artificialanalysis.R
- FOUND: .planning/phases/64-additive-guards/64-01-SUMMARY.md
- FOUND commit 14565db in git log
- FOUND commit eb873a7 in git log
