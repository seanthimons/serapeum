---
title: Error accumulation uses fragile index assignment in research_refiner.R
status: todo
type: task
priority: normal
tags:
  - db
  - pr-review
  - server
created_at: 2026-03-23T18:59:31Z
updated_at: 2026-03-25T21:44:31Z
parent: sera-dv61
---

**Source:** PR #241 review (round 1)
**Severity:** MEDIUM
**File:** `R/research_refiner.R:30,152,159,166`

`errors[length(errors) + 1] <<-` inside `tryCatch` closures works but is non-idiomatic R. The standard pattern is `errors <<- c(errors, "message")`.

**Suggested fix:** Replace all 4 occurrences with `errors <<- c(errors, paste0(...))`.

<!-- migrated from beads: `serapeum-1774459568010-210-8c6d0574` | github: https://github.com/seanthimons/serapeum/issues/243 -->
