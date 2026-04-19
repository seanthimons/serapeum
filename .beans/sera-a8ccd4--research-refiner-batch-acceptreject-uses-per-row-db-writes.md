---
title: "Research Refiner: batch accept/reject uses per-row DB writes"
status: completed
type: task
priority: high
tags:
  - performance
created_at: 2026-03-19T19:23:31Z
updated_at: 2026-03-19T19:55:29Z
---

In `mod_research_refiner.R`, the batch accept (`accept_top_n`) and batch reject (`reject_below_median`) handlers loop over papers and issue individual `dbExecute()` calls per paper.

For larger candidate pools this could be noticeably slow on DuckDB. A single parameterized UPDATE (e.g., `UPDATE refiner_results SET user_action = ? WHERE run_id = ? AND paper_id IN (...)`) would be more efficient.

Not blocking — current pools are small enough — but worth optimizing if candidate counts grow.

<!-- migrated from beads: `serapeum-1774459566468-145-a8ccd4b2` | github: https://github.com/seanthimons/serapeum/issues/174 -->
