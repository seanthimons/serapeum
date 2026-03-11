---
description: "Enhance cost tracker chart interactivity and operation table"
date: 2026-03-11
status: planned
mode: quick-full
must_haves:
  truths:
    - "Cost history chart is interactive without Plotly"
    - "Hovering a bar section reveals detailed spend plus model/operation context"
    - "Cost-by-operation table shows normalized names and models used"
    - "Icons use the existing app icon language where practical"
  artifacts:
    - "Interactive cost history chart output in R/mod_cost_tracker.R"
    - "Richer cost aggregation helpers in R/cost_tracking.R"
    - "HTML-capable cost-by-operation table in R/mod_cost_tracker.R"
    - "Supporting styles for tooltip/table polish in www/custom.css"
  key_links:
    - "R/mod_cost_tracker.R"
    - "R/cost_tracking.R"
    - "R/theme_catppuccin.R"
    - "www/custom.css"
---

# Quick Task 1 Plan

## Task 1
files: ["R/cost_tracking.R"]
action: "Add centralized operation/model display helpers and richer aggregation helpers for stacked daily segments, per-operation model summaries, and tooltip-ready detail."
verify: "Source-level review confirms helpers cover all logged operation names and new queries return date, operation, model, cost, request, and token fields needed by the UI."
done: "Cost data layer exposes interactive-chart and enriched-table inputs without duplicating label logic in the UI."

## Task 2
files: ["R/mod_cost_tracker.R", "www/custom.css"]
action: "Replace the static base plot with a stacked ggplot/Shiny hover chart and custom HTML tooltip, then replace the old renderTable operation summary with an HTML-capable table that includes icons, names, models used, and metrics."
verify: "UI code no longer uses base barplot/tableOutput for the cost history section; hover state drives a tooltip panel and the operation table renders rich cells."
done: "Cost tracker page is interactive, visually aligned with the app, and surfaces model/operation detail on hover."

## Task 3
files: ["tests/testthat/test-cost-tracking.R"]
action: "Add focused tests for cost metadata normalization and enriched aggregation helpers."
verify: "Tests cover human labels for current operations plus the new history/table helper outputs on representative sample data."
done: "Interactive cost tracker logic has regression coverage at the formatter/data-contract layer."
