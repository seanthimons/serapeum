---
title: "Refiner: no cascade delete on refiner tables"
status: completed
type: task
priority: high
tags:
  - data-integrity
  - v18
created_at: 2026-03-20T16:39:26Z
updated_at: 2026-03-22T17:02:59Z
---

From PR #161 review item #9.

`refiner_results` FK to `refiner_runs(id)` has no `ON DELETE CASCADE`. Deleting a run orphans result rows. Similarly, `refiner_runs.source_notebook_id` has no FK constraint — deleting a notebook leaves dangling references.

**File:** `R/db.R` line 311

<!-- migrated from beads: `serapeum-1774459566841-161-0c94fb7e` | github: https://github.com/seanthimons/serapeum/issues/190 -->
