---
title: NA guard missing on provider$api_key check in mod_query_builder
status: completed
type: task
priority: critical
tags:
  - pr-review
  - pre-existing
  - server
created_at: 2026-03-24T18:33:44Z
updated_at: 2026-04-07T16:55:17Z
---

**Source:** PR #253 review (round 1, Copilot finding)
**Severity:** MEDIUM
**File:** `R/mod_query_builder.R:81`

`nchar(provider$api_key)` errors when `api_key` is `NA` because `nchar(NA)` returns `NA`, and `if (NA && ...)` is invalid in R.

**Suggested fix:** Use `isTRUE(nzchar(...))` or explicitly guard `is.na(provider$api_key)`:
```r
if ((is.null(provider$api_key) || is.na(provider$api_key) || !isTRUE(nzchar(provider$api_key))) && !is_local_provider(provider)) {
```

## Resolution

Fixed: added is.na() guard before nchar() check on provider$api_key.

<!-- migrated from beads: `serapeum-1774459568245-220-b763db78` | github: https://github.com/seanthimons/serapeum/issues/254 -->
