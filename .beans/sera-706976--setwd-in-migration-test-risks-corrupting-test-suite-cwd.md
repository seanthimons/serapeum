---
title: setwd() in migration test risks corrupting test suite cwd
status: todo
type: task
priority: normal
tags:
  - db
  - pr-review
  - server
  - test
created_at: 2026-03-23T18:59:43Z
updated_at: 2026-03-25T21:44:34Z
parent: sera-dv61
---

**Source:** PR #241 review (round 1)
**Severity:** LOW
**File:** `tests/testthat/test-db-migrations.R:104-108`

Uses `setwd(tmp_dir)` with `on.exit()` cleanup. If the test fails before `on.exit()` registers, working directory is corrupted for subsequent tests.

**Suggested fix:** Prefer absolute paths instead of changing working directory.

<!-- migrated from beads: `serapeum-1774459568153-216-70697639` | github: https://github.com/seanthimons/serapeum/issues/249 -->
