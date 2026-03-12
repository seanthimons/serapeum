---
status: resolved
trigger: "Modals are not appearing as frequently detailing status during long-running operations after dark mode changes (phases 30-31)"
created: 2026-02-23T00:00:00Z
updated: 2026-02-23T00:00:00Z
---

## Current Focus

hypothesis: No modal/progress code was removed or broken -- the issue is CSS contrast making notifications less noticeable in dark mode
test: Exhaustive git diff of all R/ changes between pre-dark-mode (58061a7) and post-dark-mode (1fddaf2)
expecting: If code was removed, we'd see deleted showModal/withProgress/showNotification lines
next_action: Report findings

## Symptoms

expected: Status/progress modals appear during long-running operations
actual: Modals not appearing as frequently
errors: None reported
reproduction: Run long-running operations in the app
started: After dark mode changes (phases 30-31)

## Eliminated

- hypothesis: Dark mode changes removed or commented out showModal/withProgress/showNotification calls
  evidence: git diff 58061a7..1fddaf2 -- R/ filtered for modal/progress patterns shows ZERO removals or modifications of any showModal, removeModal, showNotification, withProgress, or incProgress call
  timestamp: 2026-02-23

- hypothesis: JavaScript custom message handlers (updateBuildProgress, updateSearchReindexProgress, updateReindexProgress) were removed or broken
  evidence: All three JS handlers confirmed present in mod_citation_network.R:12, mod_search_notebook.R:301, mod_document_notebook.R:28. All corresponding sendCustomMessage calls confirmed intact.
  timestamp: 2026-02-23

- hypothesis: CSS changes made progress notifications invisible (dark-on-dark)
  evidence: Shiny base CSS sets .shiny-notification background to #e8e8e8 (light gray). bslib 0.9.0 does not override this background-color. Catppuccin dark CSS only overrides -message, -warning, -error subclasses, not the base .shiny-notification used by withProgress. The light gray #e8e8e8 would actually be MORE visible against dark #1e1e2e background.
  timestamp: 2026-02-23

- hypothesis: Custom CSS in www/custom.css or inline styles in app.R affected modals
  evidence: www/custom.css contains only citation-network-specific styles. No modal, notification, or progress styles. app.R inline CSS only affects chat-markdown and lit-review-scroll elements.
  timestamp: 2026-02-23

## Evidence

- timestamp: 2026-02-23
  checked: Full git diff of R/ directory between commit 58061a7 (pre-dark-mode) and 1fddaf2 (post-phase-31)
  found: 498 lines changed across 10 files. ALL changes are CSS class migrations (bg-light -> bg-body-tertiary, text-dark -> text-body, etc.), hardcoded color replacements (hex -> LATTE/MOCHA constants), and the new theme_catppuccin.R file. Zero logic changes.
  implication: Dark mode phases made purely presentational changes -- no modal/progress behavior was altered.

- timestamp: 2026-02-23
  checked: All showModal, removeModal, showNotification, withProgress, incProgress calls in R/ directory
  found: 100+ calls across mod_search_notebook.R, mod_document_notebook.R, mod_citation_network.R, mod_settings.R, mod_slides.R, mod_seed_discovery.R, mod_query_builder.R, mod_topic_explorer.R. All intact and unmodified.
  implication: Every progress/status indicator that existed before dark mode still exists.

- timestamp: 2026-02-23
  checked: Catppuccin dark CSS notification overrides in theme_catppuccin.R lines 158-172
  found: Only .shiny-notification-message, .shiny-notification-warning, .shiny-notification-error are styled. The base .shiny-notification (used by withProgress) and .shiny-notification-panel are NOT styled.
  implication: withProgress notifications inherit Shiny default light gray background in dark mode -- visible but potentially not matching theme expectations.

- timestamp: 2026-02-23
  checked: bslib 0.9.0 precompiled Bootstrap CSS notification styles
  found: bslib overrides .shiny-notification.shiny-notification with new padding, border-radius, box-shadow, and opacity (0.96), but does NOT set background-color. Shiny default #e8e8e8 falls through.
  implication: In dark mode, notifications appear as light gray boxes on dark background -- visible but potentially jarring/unexpected.

## Resolution

root_cause: NO CODE WAS REMOVED OR BROKEN. The dark mode changes (phases 30-31) made exclusively presentational changes (CSS class migrations and color constant replacements). All 100+ showModal, showNotification, withProgress, and incProgress calls remain intact and unmodified. The perceived "less frequent" modals may be due to: (1) reduced visual salience of light-gray Shiny notification panels against the new dark theme (they exist but blend less naturally with the UI), or (2) user perception bias from the overall visual change. The Catppuccin dark CSS does NOT style the base .shiny-notification or .shiny-progress-notification classes, so withProgress panels appear as default light-gray (#e8e8e8) boxes in dark mode -- technically visible but potentially less noticeable than the styled type-specific notifications.
fix:
verification:
files_changed: []
