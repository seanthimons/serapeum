---
phase: 31-component-styling-visual-consistency
plan: 05
status: complete
commit: 0c765d0
gap_closure: true
---

## What was done

Replaced custom JavaScript theme toggle with `bslib::input_dark_mode()` to enable thematic auto-theming for plots.

### Changes to app.R:
1. **Removed** custom `dark_mode_toggle` button (13 lines of inline JS)
2. **Added** `bslib::input_dark_mode(id = "dark_mode")` in navbar title div
3. **Added** `observeEvent(input$dark_mode, ...)` server observer to persist theme to localStorage
4. **Added** `set-theme-storage` custom message handler and DOMContentLoaded theme restoration script
5. **Removed** old sidebar theme restoration script that referenced the deleted toggle button

### Why this works:
`input_dark_mode()` calls `session$setCurrentTheme()` internally, which updates reactive values that `getCurrentOutputInfo()` reads. When user toggles theme, thematic detects the change and re-renders plots with appropriate backgrounds.

## Files modified

- `app.R` — Replaced JS toggle with bslib widget, added persistence observer

## Verification

Manually verified: barplot backgrounds adapt correctly to theme changes. User approved.
