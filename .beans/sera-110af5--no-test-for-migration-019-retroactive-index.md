---
title: No test for migration 019 (retroactive index)
status: todo
type: task
priority: normal
tags:
  - db
  - pr-review
  - test
created_at: 2026-03-23T18:59:40Z
updated_at: 2026-03-25T21:44:33Z
parent: sera-dv61
---

**Source:** PR #241 review (round 1)
**Severity:** MEDIUM
**File:** `migrations/019_retroactive_prompt_versions_index.sql`

Migration 019 has no dedicated test verifying it executes successfully and the index exists afterward. Test file `test-db-migrations.R` covers 018 but not 019.

**Suggested fix:** Add test that runs migration 019 and verifies `idx_prompt_versions_slug_date` index exists.

<!-- migrated from beads: `serapeum-1774459568104-214-110af5d7` | github: https://github.com/seanthimons/serapeum/issues/247 -->
