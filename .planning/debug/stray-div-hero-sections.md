---
status: diagnosed
trigger: "stray div element bleeding through hero sections on splash/landing page after dark mode changes"
created: 2026-02-23T00:00:00Z
updated: 2026-02-23T00:00:00Z
---

## Current Focus

hypothesis: The --bs-card-bg CSS variable set in catppuccin_dark_css() makes the border-0 card on the welcome page visible in dark mode because card background (#313244) differs from body background (#1e1e2e)
test: Check if card-bg override is the cause; the card wrapping the welcome/about page becomes visible in dark mode
expecting: Removing or aligning card-bg with body-bg would eliminate the visible div
next_action: Confirm root cause and return diagnosis

## Symptoms

expected: Clean hero sections on splash page with no stray elements
actual: A div element bleeds through three hero sections
errors: Visual regression - stray div visible on splash page
reproduction: Load the splash/landing page
started: After dark mode changes (phases 30-31)

## Eliminated

## Evidence

- timestamp: 2026-02-23T00:01:00Z
  checked: git diff of all dark mode phases (30-31) across all R files
  found: No structural HTML changes to welcome page or about page - only CSS class replacements and theme variable changes
  implication: The bug is CSS-driven, not HTML structure

- timestamp: 2026-02-23T00:02:00Z
  checked: catppuccin_dark_css() in R/theme_catppuccin.R lines 85 and 116
  found: --bs-body-bg is set to #1e1e2e (Mocha base) while --bs-card-bg is set to #313244 (Mocha surface0) - a visible 2-tone difference
  implication: Any card element shows as a distinct rectangle in dark mode even with border-0 class

- timestamp: 2026-02-23T00:03:00Z
  checked: Welcome page in app.R lines 931-968 and about page in R/mod_about.R lines 6-252
  found: Both wrap content in card(class = "border-0", card_body(...)) which removes the border but not the background
  implication: The card background color difference (#313244 vs #1e1e2e) creates a visible "stray div" around the three feature columns

## Resolution

root_cause: The catppuccin_dark_css() function in R/theme_catppuccin.R line 116 sets --bs-card-bg to MOCHA$surface0 (#313244), which is visibly different from --bs-body-bg (#1e1e2e). The welcome page and about page both use card(class = "border-0") which hides the border but not the background. In dark mode, the card renders as a visible lighter rectangle spanning across the three feature sections ("hero sections"), appearing as a stray div.
fix:
verification:
files_changed: []
