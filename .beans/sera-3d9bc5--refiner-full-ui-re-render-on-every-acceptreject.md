---
title: "Refiner: full UI re-render on every accept/reject"
status: completed
type: task
priority: high
tags:
  - performance
  - v18
created_at: 2026-03-20T16:39:23Z
updated_at: 2026-03-22T17:03:00Z
---

From PR #161 review item #7.

Updating `scored_results()` triggers `renderUI` which rebuilds all 100 paper cards, destroying DOM nodes, rebinding JS handlers, and resetting scroll position.

Consider per-row state toggling via `shinyjs` or CSS class swaps instead of full re-render.

**File:** `R/mod_research_refiner.R` lines 624-739

<!-- migrated from beads: `serapeum-1774459566819-160-3d9bc51d` | github: https://github.com/seanthimons/serapeum/issues/189 -->
