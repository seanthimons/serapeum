---
title: "Refiner: weight preset sums exceed 1.0"
status: completed
type: task
priority: high
tags:
  - ux
  - v18
  - wontfix
created_at: 2026-03-20T16:39:37Z
updated_at: 2026-03-22T23:14:42Z
---

From PR #161 review item #14.

Discovery preset sums to 1.50, Comprehensive to 1.20, Emerging to 1.30. `compute_utility_score()` re-normalizes correctly (line 141), but preset values are misleading to readers and UI slider labels.

**File:** `R/utils_scoring.R` lines 70-99

<!-- migrated from beads: `serapeum-1774459566913-164-bf443608` | github: https://github.com/seanthimons/serapeum/issues/193 -->
