---
phase: 53-toolbar-restructuring
plan: 01
subsystem: search-notebook
tags: [toolbar, UX, layout, visual-design]
dependency_graph:
  requires: [phase-52-01]
  provides: [3x2-grid-toolbar, remaining-count-in-keywords-panel]
  affects: [R/mod_search_notebook.R, R/mod_keyword_filter.R]
tech_stack:
  added: []
  patterns: [css-grid-layout, flex-gap-spacing, reactive-data-passing]
key_files:
  created: []
  modified:
    - R/mod_search_notebook.R
    - R/mod_keyword_filter.R
decisions:
  - CSS Grid for perfect column alignment (switched from two flex rows after checkpoint feedback)
  - format_large_number() helper for K/M suffixes on remaining count
  - Panel split changed from 4/8 to 5/7 for better paper title visibility
  - Remaining count passed as reactive parameter to keyword filter module
metrics:
  duration: 4s
  tasks_completed: 3
  commits: 3
  files_modified: 2
  completed_date: 2026-03-10
---

# Phase 53 Plan 01: Toolbar Restructuring Summary

**One-liner:** Restructured search notebook toolbar from single-row horizontal strip to 3x2 CSS grid with icon+text labels, semantic colors (lavender/gray), and relocated remaining count to keywords panel

## Objective

Improve toolbar usability by making buttons discoverable (icon+text), logically grouped (input/discovery vs output/data), and visually harmonized (lavender for actions, gray for support). Remove "Papers" header label, relocate result count to keywords panel, and widen paper list panel from 4/12 to 5/12.

## Tasks Completed

### Task 1: Restructure toolbar to 3x2 grid with icon+text labels and semantic colors
**Status:** Complete
**Commit:** b4fdce9
**Files Modified:** R/mod_search_notebook.R

- Changed panel split from `c(4, 8)` to `c(5, 7)` for better paper title visibility
- Replaced single-row button strip with 3x2 grid using two flex rows
- All 6 buttons now display icon + text labels (Import, Edit Search, Citation Network, Export, Refresh, Load More)
- Applied semantic colors: lavender (btn-outline-primary) on Import, Citation Network, Export, Load More; gray (btn-outline-secondary) on Edit Search, Refresh
- Removed "Papers" span from card header
- Removed result_count textOutput from card header (relocated to keywords panel)
- Added format_large_number() helper function for K/M suffix formatting
- Wrapped sort radio buttons in justify-content-around container for even spacing
- Created remaining_count reactive and passed to keyword filter module
- Smoke test passed: app starts without errors

### Task 2: Add remaining count to keywords panel summary
**Status:** Complete
**Commit:** e2316c0
**Files Modified:** R/mod_keyword_filter.R

- Updated mod_keyword_filter_server() signature to accept optional `remaining_count` reactive parameter
- Modified output$summary to display "X papers | Y keywords | **Z remaining**" when remaining count available
- Remaining count rendered as bold with format_large_number() formatting (e.g., "1.6M remaining", "234K remaining")
- Falls back to "X papers | Y keywords" when no remaining count
- Smoke test passed: app starts without errors

### Task 3: Human verification checkpoint
**Status:** Complete
**Commit:** 1598972 (grid alignment fix)
**Files Modified:** R/mod_search_notebook.R

- User requested perfect column alignment between toolbar rows
- Switched from two flex rows to single CSS Grid with `grid-template-columns: repeat(3, 1fr)` and `grid-template-rows: repeat(2, auto)`
- Result: buttons now perfectly aligned in columns across both rows
- User approved checkpoint after this fix

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Grid alignment enhancement**
- **Found during:** Task 3 checkpoint review
- **Issue:** Original implementation used two separate flex rows, which caused slight column misalignment between Row 1 and Row 2
- **Fix:** Switched to CSS Grid with explicit column/row template for perfect alignment
- **Files modified:** R/mod_search_notebook.R
- **Commit:** 1598972

## Verification

All verification criteria met:
- [x] App starts without errors (smoke test)
- [x] All 6 toolbar buttons visible with icon+text labels
- [x] 3x2 grid layout renders correctly with perfect column alignment
- [x] Export dropdown functional
- [x] Keywords panel shows remaining count when available
- [x] Load More button still shows/hides based on pagination state
- [x] Both light and dark modes render properly (verified by user at checkpoint)

## Success Criteria

All success criteria met:
- [x] TOOL-01: All 6 buttons have icon+text labels (no icon-only buttons)
- [x] TOOL-02: Buttons ordered Import, Edit Search, Citation Network, Export, Refresh, Load More
- [x] TOOL-03: Primary actions use lavender (btn-outline-primary), support actions use gray (btn-outline-secondary)
- [x] TOOL-04: 3x2 grid provides visual grouping (row 1 = input/discovery, row 2 = output/data)
- [x] TOOL-06: "Papers" label removed, result count relocated to keywords panel
- [x] Panel widths changed to c(5, 7) for better paper title display

## Key Files

**Modified:**
- `R/mod_search_notebook.R` - Toolbar restructure, CSS Grid layout, remaining_count reactive, format_large_number() helper
- `R/mod_keyword_filter.R` - Remaining count display in panel summary

## Commits

1. b4fdce9 - feat(53-01): restructure toolbar to 3x2 grid with icon+text labels
2. e2316c0 - feat(53-01): add remaining count to keywords panel summary
3. 1598972 - fix(53): use CSS grid for perfect column alignment in toolbar

## Self-Check: PASSED

**Files:**
- FOUND: R/mod_search_notebook.R
- FOUND: R/mod_keyword_filter.R

**Commits:**
- FOUND: b4fdce9
- FOUND: e2316c0
- FOUND: 1598972

All claimed files and commits verified successfully.
