---
phase: 33-doi-parsing-utilities
plan: 01
subsystem: api
tags: [doi, parsing, validation, normalization, batch-processing]

requires:
  - phase: none
    provides: existing normalize_doi_bare() and is_valid_doi() in R/utils_doi.R
provides:
  - parse_doi_list() for batch DOI parsing with categorized errors
  - split_doi_input() for delimiter splitting
  - categorize_doi_error() for error classification
  - Enhanced normalize_doi_bare() with URL decoding and query param stripping
affects: [35-bulk-doi-import, 36-bibtex-import, 37-citation-audit]

tech-stack:
  added: []
  patterns: [structured-list-return, categorized-error-reporting, tdd-red-green]

key-files:
  created:
    - tests/testthat/test-utils_doi.R
  modified:
    - R/utils_doi.R

key-decisions:
  - "Used vapply over sapply for type-safe boolean vector from is_valid_doi"
  - "Added is_valid_doi structural validation after normalize_doi_bare to catch invalid registrants and empty suffixes"
  - "Categorize errors using normalized form when available for accurate detection"

patterns-established:
  - "Batch parsing pattern: split -> preprocess -> normalize -> validate -> categorize errors -> deduplicate -> structured return"
  - "Error categorization: 4 specific reasons instead of generic invalid flag"

requirements-completed:
  - "Foundation for BULK-01"
  - "Foundation for BULK-02"
  - "Foundation for BULK-03"
  - "Foundation for AUDIT-06"

duration: 8min
completed: 2026-02-25
---

# Phase 33-01: DOI Parsing Utilities Summary

**Batch DOI parser with URL decoding, 4-category error classification, and deduplication using base R**

## Performance

- **Duration:** 8 min
- **Completed:** 2026-02-25
- **Tasks:** 2 (TDD: RED + GREEN)
- **Files modified:** 2

## Accomplishments
- parse_doi_list() handles mixed-format DOI input (bare, URL, doi: prefix, comma/newline-separated)
- Categorized error reporting with 4 specific reasons (missing_prefix, invalid_registrant, empty_suffix, unrecognized_format)
- Deduplication with count reporting in structured return format
- Enhanced normalize_doi_bare() with URL decoding (%2F) and query parameter stripping

## Task Commits

Each task was committed atomically:

1. **Task 1: RED - Write failing tests** - `7e9fe28` (test)
2. **Task 2: GREEN - Implement parse_doi_list** - `894f5c6` (feat)

## Files Created/Modified
- `tests/testthat/test-utils_doi.R` - 59 test assertions across 17 test blocks covering all DOI parsing edge cases
- `R/utils_doi.R` - Added parse_doi_list(), split_doi_input(), categorize_doi_error(); enhanced normalize_doi_bare()

## Decisions Made
- Used `vapply` over `sapply` for `is_valid_doi` calls to ensure type-safe boolean vector (prevents list return on single elements)
- Added `is_valid_doi()` structural validation as second pass after `normalize_doi_bare()` to catch DOIs that start with "10." but have invalid registrants or empty suffixes
- Error categorization uses the normalized form (lowercase, prefix-stripped) when available for more accurate regex matching

## Deviations from Plan

### Auto-fixed Issues

**1. Added is_valid_doi structural validation pass**
- **Found during:** Task 2 (GREEN implementation)
- **Issue:** normalize_doi_bare() accepts any string starting with "10." including "10.12/abc" (invalid registrant) and "10.1234/" (empty suffix)
- **Fix:** Added second validation pass using is_valid_doi() Crossref regex after normalization
- **Files modified:** R/utils_doi.R
- **Verification:** All 59 tests pass including invalid_registrant and empty_suffix categorization
- **Committed in:** 894f5c6

---

**Total deviations:** 1 auto-fixed (structural validation gap)
**Impact on plan:** Essential for correct error categorization. No scope creep.

## Issues Encountered
- `sapply` returns a list instead of vector when applied to single-element input -- fixed by using `vapply` with `logical(1)` type specification
- Segfault on Windows when passing R code via `-e` flag with complex quoting -- worked around by using temp script files

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- parse_doi_list() ready for consumption by Phase 35 (Bulk DOI Import), Phase 36 (BibTeX Import), Phase 37 (Citation Audit)
- All downstream phases feed DOI strings into this parser
- No blockers

---
*Phase: 33-doi-parsing-utilities*
*Completed: 2026-02-25*
