---
title: Hard-coded cost_usd = 0.01 magic number in import_paper
status: completed
type: task
priority: normal
tags:
  - pr-review
  - pre-existing
  - server
created_at: 2026-03-24T18:33:54Z
updated_at: 2026-04-07T16:55:17Z
---

**Source:** PR #253 review (round 1, Copilot finding)
**Severity:** LOW
**File:** `R/import_paper.R:64`

`cost_usd = 0.01` is a hard-coded magic number inside the import path. If this represents a real cost/budget unit, it should be defined centrally with a comment explaining what it represents.

**Suggested fix:** Extract to a named constant in `config.R` (e.g., `OPENALEX_IMPORT_COST_USD <- 0.01`) with a comment explaining the unit.

## Resolution

Fixed: extracted magic number to OA_CONTENT_DOWNLOAD_COST_USD constant in config.R.

<!-- migrated from beads: `serapeum-1774459568342-224-72451d2e` | github: https://github.com/seanthimons/serapeum/issues/258 -->
