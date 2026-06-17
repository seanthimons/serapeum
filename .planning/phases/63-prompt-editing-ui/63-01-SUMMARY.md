---
phase: 63-prompt-editing-ui
plan: "01"
subsystem: database
tags: [duckdb, dbi, prompt-versioning, r, crud]

# Dependency graph
requires:
  - phase: 62-prompt-storage-schema
    provides: prompt_versions table with composite PK (preset_slug, version_date)
provides:
  - PROMPT_DEFAULTS named list with exact default text for all 11 AI preset slugs
  - PRESET_GROUPS grouping slugs into Quick (4) and Deep (7)
  - PRESET_DISPLAY_NAMES human-readable labels for UI
  - 6 CRUD functions: list_prompt_versions, get_prompt_version, get_active_prompt, save_prompt_version, reset_prompt_to_default, get_effective_prompt
  - Full test suite in tests/testthat/test-prompt-helpers.R (48 tests passing)
affects:
  - 63-02 (UI module will source prompt_helpers.R for CRUD operations)
  - 63-03 (server wiring will call get_effective_prompt and save_prompt_version)
  - R/rag.R (future refactor can call get_effective_prompt instead of hardcoded strings)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CRUD helper module pattern: data layer functions all take con as first arg, use parameterized DBI queries"
    - "TDD with in-memory DuckDB fixture: CREATE TABLE manually in test setup, no migration runner needed"
    - "get_effective_prompt fall-through: active custom > hardcoded default"

key-files:
  created:
    - R/prompt_helpers.R
    - tests/testthat/test-prompt-helpers.R
  modified: []

key-decisions:
  - "PROMPT_DEFAULTS stores editable portion only — role preamble lines and CITATION RULES blocks are excluded (non-user-editable structural instructions)"
  - "overview default keeps %s placeholder for depth_instruction — get_effective_prompt returns the template string; generators call sprintf() on it"
  - "PRESET_GROUPS keys are 'Quick' and 'Deep' (title case) to match planned UI tab labels"

patterns-established:
  - "Pattern 1: All CRUD helpers accept con as first argument — consistent with existing R/db.R conventions"
  - "Pattern 2: NULL return for missing rows (not character(0)) — callers can use is.null() without length checks"
  - "Pattern 3: save_prompt_version always saves as Sys.Date() — one version per preset per day, UPSERT replaces same-day edits"

requirements-completed: [PRMT-01, PRMT-02, PRMT-03, PRMT-05, PRMT-06]

# Metrics
duration: 3min
completed: "2026-03-21"
---

# Phase 63 Plan 01: Prompt Helpers Summary

**DuckDB CRUD data layer for prompt versioning: PROMPT_DEFAULTS registry (11 slugs), 6 helper functions, and 48 passing TDD tests**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-21T21:12:12Z
- **Completed:** 2026-03-21T21:14:54Z
- **Tasks:** 1 (TDD: RED + GREEN commits)
- **Files modified:** 2

## Accomplishments
- Created `R/prompt_helpers.R` with PROMPT_DEFAULTS (11 slugs), PRESET_GROUPS, PRESET_DISPLAY_NAMES, and 6 CRUD functions
- Default text for each slug extracted precisely from R/rag.R and R/slides.R — editable portions only (no role preamble, no CITATION RULES)
- Created `tests/testthat/test-prompt-helpers.R` with 48 tests covering all behaviors: UPSERT, NULL returns, descending order, cross-slug isolation, fallback to default, and reset
- All 48 tests pass with 0 failures

## Task Commits

Each TDD phase committed atomically:

1. **RED — Failing tests** - `d40a3d3` (test)
2. **GREEN — Implementation** - `be54010` (feat)

## Files Created/Modified
- `R/prompt_helpers.R` — PROMPT_DEFAULTS, PRESET_GROUPS, PRESET_DISPLAY_NAMES, and 6 CRUD functions
- `tests/testthat/test-prompt-helpers.R` — 48 tests for all behaviors

## Decisions Made
- PROMPT_DEFAULTS stores editable portion only: role preamble lines and CITATION RULES blocks excluded as non-user-editable
- The `overview` default retains the `%s` placeholder for `depth_instruction` — the generator calls `sprintf()` on the result of `get_effective_prompt()`
- PRESET_GROUPS uses title-case keys ("Quick", "Deep") matching planned UI tab labels

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## Next Phase Readiness
- `R/prompt_helpers.R` is the complete data layer for the prompt editing feature
- Plans 02 and 03 can source this file and call any of the 6 CRUD functions
- The `overview` %s placeholder convention is documented — plan 02/03 must account for sprintf() when building the UI editor

---
*Phase: 63-prompt-editing-ui*
*Completed: 2026-03-21*
