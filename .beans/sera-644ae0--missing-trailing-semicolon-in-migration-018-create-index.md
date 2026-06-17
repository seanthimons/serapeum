---
title: Missing trailing semicolon in migration 018 CREATE INDEX
status: completed
type: task
priority: high
tags:
  - pr-review
created_at: 2026-03-22T15:32:32Z
updated_at: 2026-03-24T18:36:36Z
---

**Source:** PR #233 review (round 1)
**Severity:** MEDIUM
**File:** `migrations/018_create_prompt_versions.sql:16`

The `idx_prompt_versions_slug_date` index statement lacks a terminating semicolon. DuckDB tolerates this for single-statement execution, but if the migration runner concatenates or batches statements, it may fail.

**Suggested fix:** Add `;` at end of line 16.

<!-- migrated from beads: `serapeum-1774459567877-204-644ae063` | github: https://github.com/seanthimons/serapeum/issues/235 -->
