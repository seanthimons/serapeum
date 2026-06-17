---
title: Defensive NA check for docs$filepath in text file generation
status: todo
type: task
priority: high
tags:
  - db
  - pr-review
  - server
created_at: 2026-03-23T16:57:14Z
updated_at: 2026-03-23T16:57:14Z
parent: sera-dv61
---

**Source:** PR #237 review (round 1)
**Severity:** MEDIUM
**File:** `R/mod_document_notebook.R:657`

`nchar(docs$filepath) == 0` returns `NA` (not `FALSE`) when `filepath` is `NA`. The `filepath` column has a `NOT NULL` constraint so current data stores `""`, but a defensive check would be safer:

```r
(is.na(docs$filepath) | nchar(docs$filepath) == 0)
```

**Suggested fix:** Replace `nchar(docs$filepath) == 0` with `(is.na(docs$filepath) | nchar(docs$filepath) == 0)`.

<!-- migrated from beads: `serapeum-1774459567923-206-6eaf3d66` | github: https://github.com/seanthimons/serapeum/issues/238 -->
