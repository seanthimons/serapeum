---
title: Add req() guard for NULL provider/model in query builder
status: todo
type: task
priority: critical
tags:
  - pr-review
  - server
created_at: 2026-03-20T17:40:15Z
updated_at: 2026-03-25T21:43:58Z
parent: sera-cpjh
---

**Source:** PR #162 review (round 1, item #7)

**File:** `R/mod_query_builder.R` lines 74-75

**Problem:** `resolve_model_for_operation()` can return NULL but no `req()` guard exists. Produces cryptic downstream errors.

**Fix:** Add `req(provider, model, cancelOutput = TRUE)` after resolution.

<!-- migrated from beads: `serapeum-1774459567174-175-cf812140` | github: https://github.com/seanthimons/serapeum/issues/204 -->
