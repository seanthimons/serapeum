---
title: "Research Refiner: add index on refiner_results(run_id)"
status: completed
type: task
priority: high
tags:
  - performance
created_at: 2026-03-19T19:23:40Z
updated_at: 2026-03-19T19:55:26Z
---

The `refiner_results` table has a foreign key on `run_id` but no index. All result queries filter by `run_id` (`get_refiner_results`, individual accept/reject updates).

With many refiner runs, these queries will degrade without an index.

**Fix:** Add `CREATE INDEX IF NOT EXISTS idx_refiner_results_run_id ON refiner_results(run_id)` to `init_schema()`.

<!-- migrated from beads: `serapeum-1774459566506-147-18fc6ff7` | github: https://github.com/seanthimons/serapeum/issues/176 -->
