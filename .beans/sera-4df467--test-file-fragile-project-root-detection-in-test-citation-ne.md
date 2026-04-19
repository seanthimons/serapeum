---
title: "Test file: fragile project root detection in test-citation-network.R"
status: todo
type: task
priority: normal
tags:
  - pr-review
  - test
created_at: 2026-03-20T16:59:41Z
updated_at: 2026-03-25T21:44:19Z
---

**Source:** PR #168 review (round 1, item #7)

`tests/testthat/test-citation-network.R:4-7` uses `dirname(dirname(getwd()))` to find the project root, which assumes tests run from `tests/testthat/`. Running from project root or via `devtools::test()` may fail. Consider using `testthat::test_path()` or `here::here()` for robust path resolution.

<!-- migrated from beads: `serapeum-1774459567054-170-4df467e3` | github: https://github.com/seanthimons/serapeum/issues/199 -->
