---
status: diagnosed
phase: 31-component-styling-visual-consistency
source: 31-01-SUMMARY.md, 31-02-SUMMARY.md, 31-03-SUMMARY.md
started: 2026-02-23T17:00:00Z
updated: 2026-02-23T17:30:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Dark mode panel backgrounds
expected: Toggle dark mode ON. All card/panel backgrounds across modules should show dark gray tones — no white panels on dark background.
result: pass

### 2. Cost tracker value boxes render at proper height
expected: Open Cost Tracker. The green (OpenRouter Balance) and purple (Session Cost) value boxes should display as proper cards with readable title and value text — not crushed into thin horizontal strips.
result: issue
reported: "Grey text is hard to discriminate against green background of balance card"
severity: cosmetic

### 3. Cost tracker value box text in dark mode
expected: Toggle dark mode ON, open Cost Tracker. Value box text (title and dollar amount) should be readable dark text on the bright pastel backgrounds — not invisible or same-color-as-background.
result: pass

### 4. Cost tracker barplot background in dark mode
expected: Open Cost Tracker with cost history data. Toggle dark mode ON. The bar chart should have a dark background matching the page — not a white rectangle.
result: issue
reported: "plot has dark background on lite-mode"
severity: major

### 5. Dissertation badge styling
expected: Find a paper marked as dissertation. The badge should use a subtle blue/info style (bg-info-subtle) that adapts to both light and dark mode.
result: pass

### 6. Alert warnings in dark mode
expected: Trigger a warning alert (e.g., invalid input). In dark mode, should show subtle yellow-tinted background with readable text — not a bright yellow box.
result: issue
reported: "Modals are not colored"
severity: major

### 7. Search notebook badges and highlights
expected: In search notebook results, badges (viewed items, metadata tags) should use theme-aware backgrounds that adapt to dark mode — no bg-light remnants.
result: pass

### 8. About page layout — no section overlap
expected: Navigate to About page. "Built With" / "Key Packages" and "Source Code / Inspiration / Data Sources" sections should stack properly without overlapping each other.
result: pass

### 9. About page scrolls to bottom
expected: On About page, scroll down. The "Important Disclaimer" section and "MIT License" footer should both be fully visible — content not clipped at viewport edge.
result: issue
reported: "Disclaimer is in grey, not yellow"
severity: cosmetic

### 10. Splash page — no visible card rectangle in dark mode
expected: Toggle dark mode ON, navigate to Welcome/splash page. The hero content should display cleanly without a visible lighter rectangle (card background) bleeding through.
result: pass

### 11. Progress notifications visible in dark mode
expected: Toggle dark mode ON, trigger a long operation (e.g., search, embedding). Progress/status notification should appear with a dark surface background and readable text — not a light gray box.
result: pass

### 12. Settings page spacing consistency
expected: Open Settings page. Spacing between form groups and sections should be even and consistent — no cramped or uneven gaps.
result: pass

### 13. Typography hierarchy consistency
expected: Across modules, headings should follow a consistent pattern: h2 for page titles, h4 for sections, h5 for sub-sections, h6 for labels.
result: pass

## Summary

total: 13
passed: 9
issues: 4
pending: 0
skipped: 0

## Gaps

- truth: "Cost tracker green value box has readable text on green background"
  status: failed
  reason: "User reported: Grey text is hard to discriminate against green background of balance card"
  severity: cosmetic
  test: 2
  root_cause: "p tag inside value_box uses class 'text-muted' which overrides to grey on the green bg-success background. text-muted is for neutral backgrounds, not colored value boxes."
  artifacts:
    - path: "R/mod_cost_tracker.R"
      issue: "Line 85: class='small text-muted mb-0' inside bg-success value_box"
  missing:
    - "Remove text-muted class from the subtitle p tag"
  debug_session: ""

- truth: "Cost tracker barplot has appropriate background for current theme mode"
  status: failed
  reason: "User reported: plot has dark background on lite-mode"
  severity: major
  test: 4
  root_cause: "Custom JS dark mode toggle only changes client DOM data-bs-theme attribute. thematic_shiny() relies on server-side getCurrentOutputInfo() which never gets notified of theme changes. Server stays stuck on whatever theme was active at startup."
  artifacts:
    - path: "app.R"
      issue: "Lines 54-66: JS toggle bypasses Shiny reactive system, thematic never updates"
  missing:
    - "Replace custom JS toggle with bslib::input_dark_mode() OR send theme changes to server via Shiny.setInputValue + session$setCurrentTheme()"
  debug_session: ".planning/debug/resolved/cost-tracker-barplot-dark-bg.md"

- truth: "Shiny notification modals are themed for dark mode"
  status: failed
  reason: "User reported: Modals are not colored"
  severity: major
  test: 6
  root_cause: "Shiny default notification CSS has higher specificity than Catppuccin dark mode rules. Missing !important flags on background-color, color, border-color properties."
  artifacts:
    - path: "R/theme_catppuccin.R"
      issue: "Lines 159-172, 220-224: notification rules lacked !important flags"
  missing:
    - "Add !important to notification dark mode CSS properties (ALREADY FIXED by debug agent in commit 64b2cbb)"
  debug_session: ".planning/debug/resolved/shiny-notification-dark-mode.md"

- truth: "About page disclaimer shows yellow-tinted alert-warning background in dark mode"
  status: failed
  reason: "User reported: Disclaimer is in grey, not yellow"
  severity: cosmetic
  test: 9
  root_cause: "alert-warning dark mode CSS uses rgba(249,226,175, 0.15) — 15% opacity is too subtle on dark background (#1e1e2e), appears grey."
  artifacts:
    - path: "R/theme_catppuccin.R"
      issue: "Line 186: background-color opacity 0.15 insufficient contrast"
  missing:
    - "Increase background opacity to 0.20-0.25 and border opacity to 0.5"
  debug_session: ".planning/debug/about-disclaimer-grey-in-dark-mode.md"

- truth: "Document notebook content text is readable in dark mode"
  status: failed
  reason: "User reported: chat window on document notebook has faded/low-contrast text in dark mode"
  severity: major
  test: 11
  root_cause: "Assistant messages in mod_document_notebook.R use class='bg-white'. Dark mode safety net covers .bg-light but NOT .bg-white — no override for text color, so text stays faded."
  artifacts:
    - path: "R/mod_document_notebook.R"
      issue: "Line 706: class='bg-white border p-2 rounded chat-markdown' missing dark mode override"
    - path: "R/theme_catppuccin.R"
      issue: "Safety net covers .bg-light but not .bg-white"
  missing:
    - "Add [data-bs-theme='dark'] .bg-white { background-color: var(--bs-secondary-bg) !important; color: var(--bs-body-color) !important; } to catppuccin_dark_css()"
  debug_session: ""
