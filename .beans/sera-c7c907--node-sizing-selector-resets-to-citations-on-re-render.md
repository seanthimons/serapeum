---
title: "Node sizing selector resets to \"citations\" on re-render"
status: todo
type: feature
priority: critical
tags:
  - pr-review
  - server
  - ui
created_at: 2026-03-19T17:43:55Z
updated_at: 2026-03-25T21:43:54Z
parent: sera-c879
---

**Source:** PR #168 review (Copilot comment)

The sizing `selectInput` in `mod_citation_network.R` always initializes with `selected = "citations"`. When the `renderUI` re-fires (e.g., reactive dependency changes), the user's selection is lost. Year filter is also reset to floor

**Fix:** Use `net_data$metadata$size_by %||% "citations"` as the `selected` value so it persists across re-renders.

**File:** `R/mod_citation_network.R` — `output$sizing_control_panel`

<!-- migrated from beads: `serapeum-1774459566350-140-c7c90705` | github: https://github.com/seanthimons/serapeum/issues/169 -->
