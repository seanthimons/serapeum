---
title: "save_network: paper_title/title fallback can produce zero-length vector"
status: todo
type: task
priority: normal
tags:
  - db
  - pr-review
  - pre-existing
  - server
created_at: 2026-03-25T15:30:08Z
updated_at: 2026-03-25T21:44:38Z
parent: sera-c879
---

**Source:** PR #262 review (round 1)
**Severity:** LOW (pre-existing)
**File:** `R/db.R:1753`

In `save_network()`, the title column is constructed as:
```r
title = as.character(nodes_df$paper_title %||% nodes_df$title)
```

If a `nodes_df` has neither `paper_title` nor `title` column, both return `NULL`, and `as.character(NULL)` produces `character(0)` — a zero-length vector. This would cause the same `rapi_bind: Bind parameter values need to have the same length` error fixed in PR #262.

Currently safe because all code paths provide one of these columns, but it's the same fragile `%||%` pattern that PR #262 fixes for `is_overlap`/`community`.

**Suggested fix:** Use the same defensive pattern as the hotfix:
```r
title = as.character(if (!is.null(nodes_df$paper_title)) nodes_df$paper_title
                     else if (!is.null(nodes_df$title)) nodes_df$title
                     else rep(NA_character_, nrow(nodes_df)))
```

<!-- migrated from beads: `serapeum-1774459568388-226-b76f53b6` | github: https://github.com/seanthimons/serapeum/issues/263 -->
