---
phase: 02-query-builder-sorting
plan: 01
subsystem: ui
tags: [shiny, duckdb, sql, sorting, ui-controls]

# Dependency graph
requires:
  - phase: 01-seed-paper-discovery
    provides: search notebook with paper list display
provides:
  - Multi-criteria sort controls for search results
  - SQL-backed sorting with NULL handling
  - User-selectable sort by citations, impact, references, or year
affects: [03-advanced-filters, search-ui, paper-discovery]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - SQL ORDER BY with NULLS LAST for metric sorting
    - Inline radioButtons for sort controls
    - Session-only UI state (no DB persistence for sort preference)

key-files:
  created: []
  modified:
    - R/db.R
    - R/mod_search_notebook.R

key-decisions:
  - "Sort preference is session-only (not persisted to database)"
  - "All metric sorts use NULLS LAST to sink papers with missing data"
  - "Year sort maintains secondary sort by created_at for stable ordering"

patterns-established:
  - "Enum validation for sort_by parameter prevents SQL injection"
  - "Switch statement for ORDER BY clause construction"
  - "Inline radio buttons for sort options in paper list header"

# Metrics
duration: 4min
completed: 2026-02-10
---

# Phase 02 Plan 01: Sort Controls Summary

**Search notebook paper list with 4-way sort: citations, FWCI impact, outgoing references, or year - all with SQL NULLS LAST handling**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-10T23:33:59Z
- **Completed:** 2026-02-10T23:37:31Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added sort_by parameter to list_abstracts with enum validation
- Implemented SQL ORDER BY with NULLS LAST for all metric sorts
- Added inline radio buttons for sort selection in search notebook UI
- Wired input$sort_by into papers_data reactive for automatic re-sorting

## Task Commits

Each task was committed atomically:

1. **Task 1: Add sort_by parameter to list_abstracts and sort UI controls** - `4758768` (feat)
2. **Task 2: Ensure graceful display of missing metrics** - `63f97bb` (chore)

## Files Created/Modified
- `R/db.R` - Added sort_by parameter to list_abstracts with 4 sort options and SQL NULLS LAST handling
- `R/mod_search_notebook.R` - Added inline radioButtons for sort selection and wired to papers_data reactive

## Decisions Made

**Sort preference is session-only:**
- Rationale: Simplifies implementation, avoids database writes on every sort change. Users typically sort once per search session. If persistence becomes a pain point, can add to search_filters JSON later.

**NULLS LAST on all metric sorts:**
- Rationale: Papers with missing citation metrics should sink to bottom when sorting by those metrics. Prevents confusion where NULL values appear at top of descending sorts.

**Year sort maintains secondary sort by created_at:**
- Rationale: Preserves stable ordering for papers with same year. Uses created_at (insertion time) as tiebreaker to avoid random reordering.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Existing format_citation_metrics function already handled NULL/NA gracefully:
- `cited_by_count` and `referenced_works_count` use `%||% 0`
- `fwci` conditionally displayed only when available
- No code changes needed for Task 2

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Sort controls complete and functional
- Ready for advanced filters implementation
- Papers with missing metrics display gracefully
- SQL sorting infrastructure in place for future query builder features

## Self-Check: PASSED

**Files:**
- FOUND: R/db.R
- FOUND: R/mod_search_notebook.R

**Commits:**
- FOUND: 4758768 (feat(02-01): add sort controls to search notebook paper list)
- FOUND: 63f97bb (chore(02-01): verify graceful display of missing metrics)

---
*Phase: 02-query-builder-sorting*
*Completed: 2026-02-10*
