---
title: "Citation audit: unfiltered_network_data mutated by sizing observer"
status: todo
type: task
priority: high
tags:
  - pr-review
  - server
created_at: 2026-03-20T16:59:34Z
updated_at: 2026-03-22T17:16:03Z
parent: sera-c879
---

**Source:** PR #168 review (round 1, item #3)

The `observeEvent(input$size_by)` in `mod_citation_network.R:478-498` updates `unfiltered_network_data()` with recomputed node sizes. However, `unfiltered_network_data` is the canonical snapshot that should never be mutated by filters/controls — it's the baseline for year filtering.

Mutating it means year filter resets use the last sizing instead of the original. Fix: store `size_by` in metadata only and recompute sizes lazily when applying filters.

<!-- migrated from beads: `serapeum-1774459566960-166-1dbb792e` | github: https://github.com/seanthimons/serapeum/issues/195 -->
