---
title: "refactor: deduplicate origin parsing in research_refiner.R"
status: todo
type: task
priority: normal
tags:
  - pr-review
  - server
  - tech-debt
created_at: 2026-03-20T15:54:47Z
updated_at: 2026-03-25T21:44:18Z
parent: sera-dast
---

**Source:** PR #161 review (item #10)

## Problem

`research_refiner.R:243-246` uses inline regex (`sub("^abstract:", "", o)`) to parse origin metadata. This duplicates `decode_origin_metadata()` from `_ragnar.R:74-123`, which handles the same format plus section hints, DOI, and source type with proper error handling.

## Suggested fix

Replace inline regex with a call to `decode_origin_metadata()`.

## Impact

If origin format changes, both locations must be updated independently. The inline version lacks the error handling and completeness of the canonical function.

<!-- migrated from beads: `serapeum-1774459566772-158-c9953a14` | github: https://github.com/seanthimons/serapeum/issues/187 -->
