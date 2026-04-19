---
title: mod_cost_tracker sparkline crashes when all latency values are NA
status: completed
type: task
priority: critical
tags:
  - pr-review
  - pre-existing
  - server
created_at: 2026-03-24T18:33:52Z
updated_at: 2026-04-07T16:55:06Z
---

**Source:** PR #253 review (round 1, Copilot finding)
**Severity:** MEDIUM
**File:** `R/mod_cost_tracker.R:317`

If `trend$avg_latency_ms` is all `NA`, `max(..., na.rm = TRUE)` returns `-Inf`, which flows into `bar_heights` and `as.integer()`/`sprintf()`, producing `NA` heights and potential errors.

**Suggested fix:** Handle the all-NA case explicitly:
```r
if (!is.finite(max_ms) || max_ms <= 0) return(NULL)
```

## Resolution

Fixed: build_latency_sparkline now guards against -Inf from all-NA latencies with is.finite() check. Added 5 unit tests.

<!-- migrated from beads: `serapeum-1774459568318-223-a6ca0ef4` | github: https://github.com/seanthimons/serapeum/issues/257 -->
