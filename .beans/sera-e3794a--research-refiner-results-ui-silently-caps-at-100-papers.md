---
title: "Research Refiner: results UI silently caps at 100 papers"
status: completed
type: feature
priority: high
created_at: 2026-03-19T19:23:27Z
updated_at: 2026-03-19T19:55:31Z
---

The results section in `mod_research_refiner.R` uses `lapply(seq_len(min(nrow(results), 100)), ...)` which silently truncates the display at 100 papers. The pre-created accept/reject handlers also cap at 100 slots.

This works fine for typical usage but could confuse users with large candidate pools (e.g., "From Notebook" anchor with many seeds) who don't realize papers beyond #100 exist but aren't shown.

**Suggestion:** Add a note in the UI when results are truncated (e.g., "Showing top 100 of 247 papers") or add pagination.

<!-- migrated from beads: `serapeum-1774459566447-144-e3794a40` | github: https://github.com/seanthimons/serapeum/issues/173 -->
