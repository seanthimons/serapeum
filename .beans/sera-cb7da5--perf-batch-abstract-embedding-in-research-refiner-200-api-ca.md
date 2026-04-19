---
title: "perf: batch abstract embedding in research refiner (200 API calls → ~1)"
status: todo
type: task
priority: high
tags:
  - db
  - performance
  - pr-review
  - server
  - ui
created_at: 2026-03-20T15:54:28Z
updated_at: 2026-03-22T17:15:43Z
parent: sera-dast
---

**Source:** PR #161 review (item #6)

## Problem

`research_refiner.R:316-331` embeds candidate abstracts one at a time. For 200 candidates, this means 200 separate API calls (~100s latency).

## Suggested fix

Collect all chunks and batch-insert into the ragnar store, reducing to a single embedding API call (or a small number of batched calls).

## Impact

Major UX bottleneck — scoring workflow blocks for ~100 seconds on a typical run. Batching could reduce this to single-digit seconds.

<!-- migrated from beads: `serapeum-1774459566677-154-cb7da585` | github: https://github.com/seanthimons/serapeum/issues/183 -->
