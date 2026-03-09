---
phase: 51-pagination-state-management
plan: 01
subsystem: search-notebook
tags: [pagination, state-management, client-side-sort, result-count]
dependency_graph:
  requires: [Phase 50-01 (search_papers cursor/count API)]
  provides: [pagination_state reactiveValues, cursor reset logic, client-side sort]
  affects: [R/mod_search_notebook.R]
tech_stack:
  added: []
  patterns: [reactiveValues for pagination state, client-side array reordering]
key_files:
  created:
    - tests/testthat/test-pagination-state.R
  modified:
    - R/mod_search_notebook.R
decisions:
  - "Cursor resets only on Edit Search parameter changes, not on year slider or sort dropdown changes"
  - "Sort dropdown is client-side only (R reorder after DB fetch) to avoid cursor invalidation"
  - "Result count displays 'X of Y results' format in toolbar area"
  - "total_fetched syncs on paper_refresh to handle deletions and imports"
metrics:
  duration: 282s (4m 42s)
  completed: 2026-03-09
  tasks: 2
  files_modified: 2
  commits: 2
---

# Phase 51 Plan 01: Pagination State Management Summary

**Add server-side pagination state management to the search notebook module, enabling distinct Refresh vs Load More behaviors.**

## Implementation

### Task 1: Pagination State, Cursor Reset, Client-Side Sort, Result Count
**Commit:** 7a93920

Added pagination_state reactiveValues to track OpenAlex cursor-based pagination:
- `cursor`: NULL = page 1, string = continuation token
- `has_more`: TRUE if next_cursor was non-NULL in last API response
- `total_fetched`: Total papers in notebook (from DB count)
- `api_total`: Total matching papers from OpenAlex meta.count

**Changes:**
1. **format_result_count() helper** (line 36): Pure function to format "X of Y results" display
2. **pagination_state initialization** (line 367): reactiveValues with 4 fields
3. **papers_data reactive** (line 938): Always fetch with default DB sort, then re-sort in R if user selected different sort
4. **save_search observer** (line 2189): Reset cursor and has_more before triggering refresh
5. **do_search_refresh()** (line 2278): Update pagination_state after API call with cursor/has_more/api_total, then update total_fetched after saving papers
6. **Sync observer** (line 2399): Update total_fetched when paper_refresh changes (handles delete, import, etc.)
7. **result_count output** (line 2407): renderText using format_result_count helper
8. **UI result count** (line 111): textOutput in toolbar area after Refresh button

**Key decisions:**
- **Cursor reset trigger:** Only Edit Search parameter changes (query, year, type, OA, min citations, retracted, search field) reset the cursor. Year slider and sort dropdown do NOT reset cursor per CONTEXT.md decision.
- **Sort is client-side:** Sort dropdown reorders papers in R after DB fetch. This prevents cursor invalidation — sort order does not affect the API query.
- **total_fetched sync:** Observer watches paper_refresh to keep total_fetched accurate when papers are deleted or imported outside of the search flow.

**Verification:**
- Smoke test: App starts on port 3841 without errors

### Task 2: Unit Tests for Pagination State Helpers
**Commit:** 4b31ae3

Created `tests/testthat/test-pagination-state.R` with 6 test cases for `format_result_count()`:
- Empty result cases: (0, 0) → "", (0, NULL) → ""
- Partial results: (25, 100) → "25 of 100 results", (1, 500) → "1 of 500 results"
- All fetched: (100, 100) → "100 results", (150, 100) → "100 results"

**Verification:**
- All 6 tests pass
- Full test suite: 315 passed, 13 failures (pre-existing fixture failures per STATE.md)
- No regressions introduced

## Deviations from Plan

None - plan executed exactly as written.

## Technical Notes

**Cursor state lifecycle:**
1. **Page 1 fetch:** User clicks Refresh or Edit Search saves → cursor reset to NULL → do_search_refresh() calls search_papers(cursor=NULL) → API returns next_cursor → pagination_state updated
2. **Load More (Phase 52):** User clicks Load More → do_load_more() calls search_papers(cursor=pagination_state$cursor) → API returns new next_cursor → pagination_state updated → total_fetched incremented
3. **Query change:** User edits search params → save_search observer resets cursor to NULL → fresh page 1 fetch

**Why sort is client-side:**
OpenAlex API sorts by relevance_score only (locked in Phase 50). User's sort dropdown (year, citations, FWCI, refs) is a display preference. If we passed sort to the DB query and then loaded more pages, the cursor would become invalid because cursor is tied to the API query, not the DB query. By sorting in R, the cursor stays valid across Load More operations.

**Result count edge cases:**
- `api_total = 0`: Shows "" (empty string) — no results found
- `api_total = NULL`: Shows "" — API error or no search performed yet
- `fetched >= total`: Shows "{total} results" — all available results fetched

## Dependencies

**Requires:**
- Phase 50-01: search_papers() with cursor/next_cursor/count return values

**Provides:**
- pagination_state reactiveValues accessible to Phase 52 (Load More button)
- cursor reset logic that preserves Phase 52's Load More behavior
- client-side sort that doesn't invalidate cursor

**Affects:**
- Phase 52 will read pagination_state$cursor, pagination_state$has_more for Load More button visibility and behavior

## Success Criteria

- [x] pagination_state reactiveValues tracks cursor, has_more, total_fetched, api_total
- [x] Refresh always passes cursor=NULL (page 1 behavior preserved)
- [x] save_search observer resets cursor before triggering refresh
- [x] Sort dropdown does not affect cursor (client-side reorder only)
- [x] "X of Y results" text appears in toolbar area
- [x] All tests pass, app starts without errors
- [x] Phase 52 can read pagination_state$cursor and pagination_state$has_more for Load More button

## Next Steps

Phase 52 will:
1. Add "Load More" button to UI (visible when `pagination_state$has_more = TRUE`)
2. Implement `do_load_more()` function that calls `search_papers(cursor = pagination_state$cursor)`
3. Append new papers to notebook instead of replacing them
4. Update pagination_state after each Load More operation

## Self-Check: PASSED

- FOUND: tests/testthat/test-pagination-state.R
- FOUND: commit 7a93920
- FOUND: commit 4b31ae3
