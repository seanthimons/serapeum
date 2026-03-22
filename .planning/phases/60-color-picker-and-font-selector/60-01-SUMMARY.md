---
phase: 60-color-picker-and-font-selector
plan: 01
subsystem: ui
tags: [r, themes, scss, tdd, testthat, font-selector, color-picker]

# Dependency graph
requires:
  - phase: 59-theme-swatches-upload-and-management
    provides: "BUILTIN_THEME_SWATCHES, parse_scss_swatches, validate_scss_file, list_custom_themes, build_theme_choices_df in R/themes.R"
provides:
  - "generate_custom_scss() — writes 5-variable .scss file with section markers and heading rules block"
  - "parse_scss_colors_full() — extracts bg/fg/accent/link/font from both generated and built-in SCSS styles"
  - "CURATED_FONTS — named list of 11 fonts across Sans-serif/Serif/Monospace groups"
affects:
  - 60-02 (color picker UI module — consumes all three exports)
  - 61 (AI theme generation — generates .scss via generate_custom_scss)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "TDD RED/GREEN: failing tests committed before implementation"
    - "SCSS font value uses double-quoted first name + sans-serif fallback: \"Font Name\", sans-serif"
    - "Filename sanitization via gsub(\"[^a-zA-Z0-9_-]\", \"-\", name)"
    - "tryCatch wraps writeLines so generate_custom_scss returns NULL on I/O error"

key-files:
  created: []
  modified:
    - R/themes.R
    - tests/testthat/test-themes.R

key-decisions:
  - "accent variable in parse_scss_colors_full prioritizes $accentColor over $linkColor to correctly distinguish heading color from link color in generated SCSS"
  - "generate_custom_scss always appends sans-serif fallback regardless of font category — safe default for RevealJS"

patterns-established:
  - "parse_scss_colors_full extends parse_scss_swatches pattern (resolve_value + extract_color helpers) without modifying the existing function"
  - "CURATED_FONTS is a module-level constant at the top of themes.R before BUILTIN_THEME_SWATCHES"

requirements-completed: [THME-08, THME-11]

# Metrics
duration: 2min
completed: 2026-03-20
---

# Phase 60 Plan 01: Theme Helper Functions Summary

**Pure-R SCSS generation and parsing foundation — generate_custom_scss(), parse_scss_colors_full(), and CURATED_FONTS constant added to themes.R via TDD**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-20T17:18:25Z
- **Completed:** 2026-03-20T17:20:29Z
- **Tasks:** 1 (TDD — RED + GREEN phases)
- **Files modified:** 2

## Accomplishments
- CURATED_FONTS constant with 11 fonts across Sans-serif, Serif, and Monospace groups ready for font selector UI
- parse_scss_colors_full() extracts all 5 fields (bg, fg, accent, link, font) from both generated ($backgroundColor/$mainColor style) and built-in ($body-bg/$body-color style) SCSS variable naming
- generate_custom_scss() writes valid .scss with 5 variables, both section markers, heading rules block, filename sanitization, and multi-word font quoting

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: failing tests** - `211a2bc` (test)
2. **Task 1 GREEN: implementation** - `c669093` (feat)

_Note: TDD task split into two commits per TDD protocol (RED then GREEN)_

## Files Created/Modified
- `R/themes.R` — Added CURATED_FONTS constant, parse_scss_colors_full(), generate_custom_scss()
- `tests/testthat/test-themes.R` — Added 17 new tests covering all three exports

## Decisions Made
- `parse_scss_colors_full` prioritizes `$accentColor` over `$linkColor` for the `accent` field — generated SCSS uses separate accentColor and linkColor variables, and the accent field should capture the heading color, not the link color
- `generate_custom_scss` always appends `sans-serif` as fallback in the font value regardless of font category — safe and conventional for RevealJS slides

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- The "returns NULL when directory does not exist" test produces an expected R warning (`cannot open file... No such file or directory`) from `writeLines` before tryCatch catches it. This is correct behavior — tryCatch catches the error and returns NULL. Test passes with WARN 1.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All three exports are tested and verified: generate_custom_scss(), parse_scss_colors_full(), CURATED_FONTS
- Plan 02 (color picker UI module) can immediately wire CURATED_FONTS into the font selectInput and call generate_custom_scss() on save
- Phase 61 (AI theme generation) can call generate_custom_scss() to persist AI-suggested themes

---
*Phase: 60-color-picker-and-font-selector*
*Completed: 2026-03-20*
