---
phase: 59-theme-swatches-upload-and-management
plan: "01"
subsystem: ui
tags: [r, themes, scss, revealjs, quarto, tdd, parsing]

# Dependency graph
requires:
  - phase: 58-theme-infrastructure
    provides: custom_scss=NULL placeholder in last_options and basename(custom_scss) YAML pattern
provides:
  - BUILTIN_THEME_SWATCHES constant with 11 RevealJS themes
  - parse_scss_swatches function with variable indirection resolution
  - validate_scss_file function for upload validation
  - list_custom_themes function for data/themes/ directory scanning
  - build_theme_choices_df function returning UI picker data.frame
affects: [59-02-ui-wiring, 60-color-picker-ui, 61-ai-theme-generation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SCSS variable indirection resolution: build resolution table of $var -> #hex, then resolve target variables one level deep"
    - "Theme choices data.frame: value/label/bg/fg/accent/group columns; custom value is filename not full path"
    - "Test path resolution: use dirname(dirname(getwd())) fallback pattern for project-root-relative sourcing"

key-files:
  created:
    - R/themes.R
    - tests/testthat/test-themes.R
  modified: []

key-decisions:
  - "Custom value in build_theme_choices_df is the filename (e.g. epa-owm.scss), not the full path — Plan 02 server wiring prepends data/themes/ when setting custom_scss"
  - "validate_scss_file uses fixed=TRUE grepl with literal marker strings to avoid regex escaping pitfalls"
  - "parse_scss_swatches resolves variable references one level deep, which is sufficient for all real RevealJS themes"

patterns-established:
  - "Theme module pattern: pure functions with no Shiny dependencies, fully testable in isolation"

requirements-completed: [THME-01, THME-02, THME-03, THME-04, THME-09]

# Metrics
duration: 4min
completed: 2026-03-19
---

# Phase 59 Plan 01: Theme Helper Module Summary

**Pure R/themes.R module with 5 exports covering swatch table, SCSS variable-resolution parsing, file validation, directory scanning, and UI data.frame building — 87 tests all passing**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-19T18:23:05Z
- **Completed:** 2026-03-19T18:27:19Z
- **Tasks:** 1 (TDD: RED commit + GREEN commit)
- **Files modified:** 2

## Accomplishments
- `BUILTIN_THEME_SWATCHES` hardcoded list with correct hex values for all 11 RevealJS themes
- `parse_scss_swatches` correctly resolves SCSS variable indirection (`$body-bg: $epa-white` where `$epa-white: #FFFFFF`) by building a resolution table before looking up target variables
- `validate_scss_file`, `list_custom_themes`, and `build_theme_choices_df` implemented with no external dependencies

## Task Commits

Each task was committed atomically:

1. **RED — Failing tests** - `81eb440` (test)
2. **GREEN — Implementation** - `fd0dd27` (feat)

## Files Created/Modified
- `R/themes.R` - 5 exported functions; pure, no Shiny or side-effect dependencies
- `tests/testthat/test-themes.R` - 87 assertions covering all 10 specified behaviors

## Decisions Made
- Custom value in `build_theme_choices_df` is the filename only (`epa-owm.scss`), not a full path. The Plan 02 server wiring layer is responsible for prepending `data/themes/` when constructing the `custom_scss` argument.
- `validate_scss_file` uses `grepl(..., fixed = TRUE)` with the literal marker strings to sidestep backslash escaping bugs in regex mode.
- One-level variable reference resolution is sufficient: real RevealJS themes never chain variables more than one level deep.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed validate_scss_file using escaped regex pattern with fixed=TRUE**
- **Found during:** GREEN phase (running tests)
- **Issue:** Initial implementation used `"/\\*-- scss:defaults --\\*/"` as the pattern with `fixed = TRUE`, causing the backslash-star literals to not match the actual marker string
- **Fix:** Changed to `"/*-- scss:defaults --*/"` (literal string) — correct for `fixed = TRUE` mode
- **Files modified:** `R/themes.R`
- **Verification:** `validate_scss_file` test now passes; all 87 tests green
- **Committed in:** `fd0dd27` (GREEN implementation commit)

**2. [Rule 3 - Blocking] Added project-root resolution in test file**
- **Found during:** GREEN phase (first test run)
- **Issue:** `testthat::test_file` changes `getwd()` to the test file's directory, so `file.path(getwd(), "R", "themes.R")` resolved to `.../tests/testthat/R/themes.R` (non-existent)
- **Fix:** Used `dirname(dirname(getwd()))` fallback pattern (matching existing `test-ragnar-helpers.R` convention) to reliably resolve project root
- **Files modified:** `tests/testthat/test-themes.R`
- **Verification:** All tests pass with both `test_file` and `test_dir` invocations
- **Committed in:** `fd0dd27` (GREEN implementation commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both fixes necessary for correctness. No scope creep.

## Issues Encountered
- `testthat::test_file` sets cwd to the test file's directory (unlike `test_dir` which preserves project root) — resolved by adopting the project's existing `dirname(dirname(getwd()))` pattern from `test-ragnar-helpers.R`

## Next Phase Readiness
- All 5 exports from `R/themes.R` are ready for Plan 02 UI wiring
- `build_theme_choices_df` returns exactly the shape Plan 02's picker needs: value/label/bg/fg/accent/group columns
- Custom value is filename-only — Plan 02 must prepend `data/themes/` when setting `custom_scss`
- `data/themes/` directory does not yet exist; Plan 02 or upload handler should create it on first upload

---
*Phase: 59-theme-swatches-upload-and-management*
*Completed: 2026-03-19*
