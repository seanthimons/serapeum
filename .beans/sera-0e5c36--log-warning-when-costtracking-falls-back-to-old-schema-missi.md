---
title: Log warning when cost_tracking falls back to old schema (missing duration_ms)
status: todo
type: task
priority: normal
tags:
  - db
  - pr-review
  - server
created_at: 2026-03-20T17:40:22Z
updated_at: 2026-03-25T21:44:22Z
---

**Source:** PR #162 review (round 1, item #9)

**File:** `R/cost_tracking.R` lines 196-199

**Problem:** `log_cost()` silently falls back to old INSERT schema if migration 012 hasn't run. Duration data is silently dropped with no feedback.

**Fix:** Add `warning()` or `message()` when falling back so users know duration tracking is inactive.

<!-- migrated from beads: `serapeum-1774459567222-177-0e5c3680` | github: https://github.com/seanthimons/serapeum/issues/206 -->
