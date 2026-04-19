---
title: Duplicate error notification code in mod_research_refiner.R
status: todo
type: task
priority: normal
tags:
  - pr-review
  - ui
created_at: 2026-03-23T18:59:44Z
updated_at: 2026-03-25T21:44:35Z
parent: sera-dv61
---

**Source:** PR #241 review (round 1)
**Severity:** LOW
**File:** `R/mod_research_refiner.R:432-447, 456-471`

Identical 12-line error notification block is copy-pasted for "seeds" and "both" source types.

**Suggested fix:** Extract to a helper function to avoid drift.

<!-- migrated from beads: `serapeum-1774459568175-217-ae1c6dec` | github: https://github.com/seanthimons/serapeum/issues/250 -->
