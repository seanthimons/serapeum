---
title: Test comment/name mismatch in test-db-migrations.R
status: todo
type: task
priority: normal
tags:
  - db
  - pr-review
  - server
  - test
created_at: 2026-03-23T18:59:41Z
updated_at: 2026-03-25T21:44:34Z
parent: sera-dv61
---

**Source:** PR #241 review (round 1)
**Severity:** LOW
**File:** `tests/testthat/test-db-migrations.R:205`

Test is named "prompt_versions table created by migration 011" but actually tests migration 018.

**Suggested fix:** Rename test to reference migration 018.

<!-- migrated from beads: `serapeum-1774459568127-215-9530a8a1` | github: https://github.com/seanthimons/serapeum/issues/248 -->
