---
title: "Vision description loop: no error context for failed figures"
status: todo
type: task
priority: normal
tags:
  - pr-review
  - server
created_at: 2026-03-20T20:06:30Z
updated_at: 2026-03-25T21:44:23Z
---

**Source:** PR #163 review (round 1, item 3)

When vision API fails for a figure in `extract_and_describe_figures()`, only `n_failed` is incremented (`pdf_images.R:393-394`). The user sees "5 failed" but gets no diagnostic info about which figures failed or why.

**Suggested fix:** Log or return the figure page number and error reason so users can diagnose batch failures.

```r
} else {
  n_failed <- n_failed + 1L
  warning(sprintf("[vision] Figure %d (page %d) failed", i, fig$page_number))
}
```

<!-- migrated from beads: `serapeum-1774459567295-180-4c616eb1` | github: https://github.com/seanthimons/serapeum/issues/209 -->
