---
title: "test-config.R fails: cannot open R/config.R (path resolution)"
status: completed
type: bug
priority: high
tags:
  - pr-review
created_at: 2026-03-20T20:16:54Z
updated_at: 2026-03-24T18:36:45Z
---

**Source:** PR #163 review — test suite run (2026-03-20)

`test-config.R:4` calls `source(file.path(getwd(), "R", "config.R"))` but the working directory during `testthat::test_dir()` is `tests/testthat/`, not the project root. This causes a "cannot open the connection" error.

**Error:**
```
Error in file(filename, "r", encoding = encoding): cannot open the connection
```

**Fix:** Use `testthat::test_path()` or `here::here()` to resolve relative to the project root, or use `source(test_path("../../R/config.R"))`.

**Pre-existing:** This failure exists on the branch prior to the PR #163 fixes.

<!-- migrated from beads: `serapeum-1774459567386-184-af27645a` | github: https://github.com/seanthimons/serapeum/issues/213 -->
