---
title: log_cost returns stale ID when INSERT fails
status: completed
type: task
priority: high
tags:
  - pr-review
created_at: 2026-03-22T15:32:30Z
updated_at: 2026-03-24T18:36:42Z
---

**Source:** PR #233 review (round 1)
**Severity:** MEDIUM
**File:** `R/cost_tracking.R:229`

The tryCatch wraps the INSERT, but `return(invisible(NULL))` in the error handler returns from the anonymous function, not from `log_cost`. The next line (`id`) always executes, returning a UUID with no corresponding DB row. While callers generally don't use the return value, the function contract is violated.

**Suggested fix:** Capture the tryCatch result and return conditionally, or move the `id` return inside the tryCatch success path.

<!-- migrated from beads: `serapeum-1774459567850-203-c771ae57` | github: https://github.com/seanthimons/serapeum/issues/234 -->
