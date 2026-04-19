---
title: nchar check in api_openrouter may fail on multi-element content
status: completed
type: task
priority: normal
tags:
  - pr-review
  - pre-existing
  - server
created_at: 2026-03-24T18:33:50Z
updated_at: 2026-04-07T16:55:26Z
---

**Source:** PR #253 review (round 1, Copilot finding)
**Severity:** LOW
**File:** `R/api_openrouter.R:97`

If `msg$content` is a character vector with length > 1, `nchar(content) == 0` yields a logical vector and `if (...)` will throw "condition has length > 1".

**Suggested fix:** Make the condition explicitly scalar — e.g., check `length(content) == 1` before calling `nchar`, or use `all(nchar(content) == 0)`.

## Resolution

Fixed: wrapped nchar() == 0 in all() to handle multi-element character vectors. Added 8 unit tests.

<!-- migrated from beads: `serapeum-1774459568295-222-2b7147ca` | github: https://github.com/seanthimons/serapeum/issues/256 -->
