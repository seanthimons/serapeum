---
phase: 31-component-styling-visual-consistency
plan: 03
subsystem: ui-theming
tags: [gap-closure, dark-mode, css, uat-fixes]
started: 2026-02-23T16:07:55Z
completed: 2026-02-23T16:10:26Z
duration_minutes: 2.5
requirements: [COMP-01, COMP-04, UIPX-03]

dependency_graph:
  requires: [31-01, 31-02, 31-UAT]
  provides: [dark-mode-value-boxes, dark-mode-notifications, scrollable-about, transparent-splash, themed-plots]
  affects: [cost-tracker, about-page, welcome-page, progress-modals]

tech_stack:
  added:
    - thematic (0.1.8) - auto-theming for R graphics
  patterns:
    - CSS !important overrides for Sass-compiled text colors
    - bslib fill=FALSE for scrollable cards in fillable layouts
    - bg-transparent for invisible card backgrounds
    - thematic_shiny() for plot device theming

key_files:
  created: []
  modified:
    - R/theme_catppuccin.R: Added value box text overrides and progress notification styling
    - R/mod_about.R: Added fill=FALSE to card for full scrolling
    - app.R: Added bg-transparent to welcome card, enabled thematic_shiny()

decisions:
  - what: "Use Mocha Crust (#11111b) for value box text color in dark mode"
    why: "Sass compiles .bg-primary/.bg-success with black text at build time. CSS vars update backgrounds to bright pastels but can't change compiled text color. Crust provides soft dark contrast."
    alternatives: ["Use text-bg-primary classes instead", "Override at value_box() call site"]

  - what: "Style base .shiny-notification class, not just typed variants"
    why: "Existing CSS only covered .shiny-notification-message/-warning/-error. Progress panels use base class and were invisible on dark backgrounds."
    alternatives: ["Wrap withProgress calls to add custom classes"]

  - what: "Enable thematic_shiny() globally in server function"
    why: "Intercepts R graphics device to use bslib theme colors for plot backgrounds. Single call themes all renderPlot outputs automatically."
    alternatives: ["Add thematic_on() to each renderPlot", "Manual bg parameter in barplot()"]

metrics:
  tasks_completed: 2
  tasks_planned: 2
  commits: 2
  files_modified: 3
  lines_added: 51
  lines_removed: 1
---

# Phase 31 Plan 03: UAT Gap Closure — Value Boxes, Notifications, and Layout Fixes

**One-liner:** Fixed 5 UAT dark mode regressions: value box text readable on pastel backgrounds, progress notifications visible, splash card transparent, about page fully scrollable, plots themed

## What Was Built

### Task 1: Dark Mode CSS — Value Boxes, Notifications, Splash Card

**Files:** `R/theme_catppuccin.R`

**Problem:** Three categories of dark mode visibility issues:

1. **Value boxes (UAT 10+11):** Cost tracker value_box with theme="primary"/"success" rendered as bright pastel backgrounds (Mocha Lavender #b4befe, Mocha Green #a6e3a1) with black text. Sass compiles `.bg-primary` text color to black at build time. CSS variables can update backgrounds but cannot override compiled text colors. Result: unreadable bright-on-black that looked broken.

2. **Progress notifications (UAT 9):** Existing `catppuccin_dark_css()` styled `.shiny-notification-message/-warning/-error` but NOT base `.shiny-notification` or `.shiny-progress-notification`. Progress panels appeared as light gray boxes (#e8e8e8) on dark backgrounds, making them nearly invisible.

3. **Implementation approach:** Added CSS rules to `catppuccin_dark_css()` function using MOCHA color constants.

**Changes:**

Added to `catppuccin_dark_css()` before closing:

```css
/* Value box text overrides */
[data-bs-theme="dark"] .bg-primary,
[data-bs-theme="dark"] .bg-success,
[data-bs-theme="dark"] .bg-danger,
[data-bs-theme="dark"] .bg-warning,
[data-bs-theme="dark"] .bg-info {
  color: #11111b !important;  /* Mocha Crust */
}

/* Target bslib value_box specifically */
[data-bs-theme="dark"] .value-box.bg-primary .value-box-title,
[data-bs-theme="dark"] .value-box.bg-primary .value-box-value,
[data-bs-theme="dark"] .value-box.bg-success .value-box-title,
[data-bs-theme="dark"] .value-box.bg-success .value-box-value,
/* ... all semantic colors ... */
{
  color: #11111b !important;
}

/* Progress/notification base styling */
[data-bs-theme="dark"] .shiny-notification {
  background-color: #313244;  /* Surface0 */
  color: #cdd6f4;             /* Text */
  border-color: #45475a;      /* Surface1 */
}

[data-bs-theme="dark"] .shiny-progress-notification .progress {
  background-color: #45475a;  /* Surface1 */
}

[data-bs-theme="dark"] .shiny-progress-notification .progress-bar {
  background-color: #b4befe;  /* Lavender */
}

[data-bs-theme="dark"] .shiny-progress-notification .progress-text {
  color: #cdd6f4;
}
```

All hex values use `MOCHA$*` constants via paste0 interpolation for consistency.

**Commit:** `c1597dc`

### Task 2: About Page Clipping + Splash Card + Barplot Theming

**Files:** `R/mod_about.R`, `app.R`

**Problem:** Three separate layout/theming issues:

1. **About page clipping (UAT 13):** Card in `mod_about_ui()` missing `fill=FALSE`. `page_sidebar()` creates fillable layout that constrains cards to viewport height. About page content extends below fold (disclaimer, MIT license) but was clipped. Same bug fixed for settings in commit 537f890.

2. **Splash card visibility (UAT 12):** Welcome page card wrapper has `class="border-0"` which removes border but NOT background. In dark mode, `--bs-card-bg` (#313244 Surface0) contrasts against `--bs-body-bg` (#1e1e2e Base), creating visible lighter rectangle spanning hero sections.

3. **Barplot white background (UAT 10):** Cost tracker barplot renders with white background in dark mode because R graphics device ignores CSS. The thematic package intercepts graphics device and applies bslib theme colors automatically.

**Changes:**

1. **About page:** Added `fill = FALSE` to `card()` call in `R/mod_about.R` line 7
2. **Splash card:** Changed `class = "border-0"` to `class = "border-0 bg-transparent"` in `app.R` line 936
3. **Barplot theming:** Added `thematic::thematic_shiny()` as first line in server function (line 233)
4. **Package installation:** Installed thematic 0.1.8 via renv (already in renv.lock but not in library)

**Commit:** `161cc49`

## Verification

All 5 UAT gaps addressed:

- **Test 9 (progress panels):** Base `.shiny-notification` now styled with Surface0 background and Text color
- **Test 10 (value boxes):** `.bg-primary/.bg-success` text overridden to Mocha Crust in dark mode
- **Test 10 (barplot):** `thematic::thematic_shiny()` auto-themes plot backgrounds
- **Test 11 (purple element):** Same value box text fix applies to .bg-primary
- **Test 12 (splash card):** `bg-transparent` prevents card-bg contrast with body-bg
- **Test 13 (about clipping):** `fill=FALSE` allows card to extend past viewport height

R syntax validated: CSS generation produces 4515 characters without errors.

## Deviations from Plan

**Auto-fixed Issues:**

**1. [Rule 3 - Blocking] thematic package not in renv library**
- **Found during:** Task 2, verification step 4
- **Issue:** thematic listed in renv.lock but not installed in project library. `library(thematic)` failed with "no package called 'thematic'"
- **Fix:** Ran `renv::install('thematic')` to install thematic 0.1.8 and rstudioapi 0.18.0 from CRAN
- **Files modified:** renv library (installation directory)
- **Commit:** Included in 161cc49 (plan stated package already available)

## Known Limitations

1. **Value box text contrast:** Mocha Crust (#11111b) is "softer" dark text than pure black, but still relatively dark. Works on all Catppuccin pastel backgrounds (Lavender, Green, Yellow, Red, Blue) with WCAG AA contrast. If user switches to custom semantic colors with darker tones, contrast may degrade.

2. **Plot theming specificity:** `thematic_shiny()` themes all `renderPlot` outputs globally. If future plots need different themes, would require `thematic_on()` per-plot or conditional logic.

3. **Card background transparency:** `bg-transparent` on splash card removes ALL background. If bslib adds default card shadows or other visual effects in future versions, those may also become invisible.

## Testing Notes

**Manual verification required:**

1. Toggle dark mode ON
2. Navigate to Cost Tracker → verify value boxes show readable dark text on pastel backgrounds
3. Trigger long operation (e.g., Build Network) → verify progress panel visible with dark background
4. View cost tracker barplot → verify dark background (not white)
5. Navigate to Welcome page → verify no visible card rectangle around hero sections
6. Navigate to About page → scroll to bottom → verify disclaimer and MIT license sections visible

**R package verification:**

```r
# Verify CSS generation
source("R/theme_catppuccin.R")
nchar(catppuccin_dark_css())  # 4515 chars

# Verify thematic loads
library(thematic)
```

## Lessons Learned

1. **Sass compilation vs CSS variables:** Bootstrap 5 compiles semantic color text colors at build time. CSS variables can update backgrounds but cannot override compiled properties. Need `!important` overrides for dark mode text colors on semantic backgrounds.

2. **Shiny notification class hierarchy:** `.shiny-notification-message/-warning/-error` inherit from base `.shiny-notification`, but base class also needs dark mode styling for progress panels and generic notifications.

3. **renv library vs lockfile:** Package appearing in `renv.lock` does not guarantee installation in project library. Always check with `renv::status()` and install explicitly if needed.

4. **Fillable layouts clip content:** `page_sidebar()` with `fillable=TRUE` (default) constrains cards to viewport height. Use `fill=FALSE` on cards with content taller than viewport to enable scrolling.

5. **R graphics ignore CSS:** Plot backgrounds rendered by R graphics device do not inherit CSS theme. Use thematic package to intercept device and apply theme colors automatically.

## Related Files

**Context:**
- `.planning/phases/31-component-styling-visual-consistency/31-UAT.md` - User acceptance test results with 6 failures
- `.planning/phases/31-component-styling-visual-consistency/31-01-SUMMARY.md` - Initial dark mode implementation
- `.planning/phases/31-component-styling-visual-consistency/31-02-SUMMARY.md` - Panel and badge styling

**Modified:**
- `R/theme_catppuccin.R` - Central dark mode CSS with value box and notification overrides
- `R/mod_about.R` - About page module with scrollable card
- `app.R` - Server function with thematic, welcome card with transparent background

**Testing:**
- Manual UAT verification required (no automated tests for CSS rendering)

## Self-Check: PASSED

✓ Created files exist: None (no new files)
✓ Modified files exist:
  - R/theme_catppuccin.R: FOUND
  - R/mod_about.R: FOUND
  - app.R: FOUND
✓ Commits exist:
  - c1597dc: FOUND - "fix(31-03): add dark mode CSS for value boxes and progress notifications"
  - 161cc49: FOUND - "fix(31-03): fix about page clipping, splash card visibility, and barplot theming"
✓ R syntax valid: CSS generation produces 4515 chars
✓ thematic package installed: library(thematic) succeeds
