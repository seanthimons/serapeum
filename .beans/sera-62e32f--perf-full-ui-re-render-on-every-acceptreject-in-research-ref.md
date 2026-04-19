---
title: "perf: full UI re-render on every accept/reject in research refiner"
status: todo
type: task
priority: high
tags:
  - performance
  - pr-review
  - server
  - ui
created_at: 2026-03-20T15:54:33Z
updated_at: 2026-03-22T17:15:44Z
parent: sera-dast
---

**Source:** PR #161 review (item #7)

## Problem

`mod_research_refiner.R:624-739` — updating `scored_results()` triggers `renderUI` which rebuilds all 100 paper cards, destroying DOM nodes, rebinding JS handlers, and resetting scroll position.

## Suggested fix

Use per-row state rendering via `shinyjs::addClass/removeClass` or CSS class swaps instead of full `renderUI` re-render. Alternatively, use `DT::datatable` with row-level updates.

## Impact

UI thrashing on every accept/reject click. Scroll position resets. Poor perceived performance.

<!-- migrated from beads: `serapeum-1774459566700-155-62e32f8c` | github: https://github.com/seanthimons/serapeum/issues/184 -->
