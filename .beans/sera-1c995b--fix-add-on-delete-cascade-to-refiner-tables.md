---
title: "fix: add ON DELETE CASCADE to refiner tables"
status: completed
type: bug
priority: high
tags:
  - pr-review
created_at: 2026-03-20T15:54:43Z
updated_at: 2026-03-24T18:36:54Z
---

**Source:** PR #161 review (item #9)

## Problem

`db.R:311` — `refiner_results` FK to `refiner_runs(id)` has no `ON DELETE CASCADE`. Deleting a run orphans result rows. Similarly, `refiner_runs.source_notebook_id` has no FK constraint — deleting a notebook leaves dangling references.

## Suggested fix

```sql
FOREIGN KEY (run_id) REFERENCES refiner_runs(id) ON DELETE CASCADE
```

Also add FK on `source_notebook_id` with cascade, or add cleanup logic to `delete_notebook()`.

## Impact

Database bloat from orphaned rows over time. Referential integrity violations when notebooks are deleted.

<!-- migrated from beads: `serapeum-1774459566746-157-1c995bef` | github: https://github.com/seanthimons/serapeum/issues/186 -->
