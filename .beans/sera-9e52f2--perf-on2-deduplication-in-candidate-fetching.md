---
title: "perf: O(n^2) deduplication in candidate fetching"
status: todo
type: task
priority: critical
tags:
  - performance
  - pr-review
  - server
created_at: 2026-03-20T15:54:53Z
updated_at: 2026-03-25T21:43:55Z
parent: sera-dast
---

**Source:** PR #161 review (item #11)

## Problem

`research_refiner.R:151` — `seen_ids <- c(seen_ids, paper$paper_id)` grows a character vector by one element per iteration (O(n) copy each time). Combined with `%in%` membership check (also O(n)), total cost is O(n^2).

## Suggested fix

Use an environment as a hash set:
```r
seen_ids <- new.env(hash = TRUE, parent = emptyenv())
# Check: !is.null(seen_ids[[paper$paper_id]])
# Insert: seen_ids[[paper$paper_id]] <- TRUE
```

## Impact

Noticeable slowdown with large candidate pools (1000+ papers). Currently tolerable at 100-200 papers but won't scale.

<!-- migrated from beads: `serapeum-1774459566796-159-9e52f20b` | github: https://github.com/seanthimons/serapeum/issues/188 -->
