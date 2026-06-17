---
title: "Refiner: observer fragility in seed removal (index-based IDs)"
status: todo
type: task
priority: high
tags:
  - db
  - server
  - tech-debt
  - v18
created_at: 2026-03-20T16:39:40Z
updated_at: 2026-03-22T17:15:42Z
parent: sera-dast
---

From PR #161 review item #15.

Index-based observer IDs (`remove_seed_1`, etc.) are fragile under rapid add/remove. `once = TRUE` mitigates but doesn't eliminate the race window. ID-based keying would be more robust.

**File:** `R/mod_research_refiner.R` lines 308-326

<!-- migrated from beads: `serapeum-1774459566937-165-46c45c33` | github: https://github.com/seanthimons/serapeum/issues/194 -->
