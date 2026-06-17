---
title: "Refiner: duplicated origin parsing logic"
status: completed
type: task
priority: high
tags:
  - tech-debt
  - v18
created_at: 2026-03-20T16:39:29Z
updated_at: 2026-03-22T17:03:02Z
---

From PR #161 review item #10.

Inline regex (`sub("^abstract:", "", o)`) in `research_refiner.R:243-246` duplicates `decode_origin_metadata()` from `_ragnar.R:74-123`. If origin format changes, both locations must be updated independently.

Consolidate to use `decode_origin_metadata()` in both places.

<!-- migrated from beads: `serapeum-1774459566865-162-357682ad` | github: https://github.com/seanthimons/serapeum/issues/191 -->
