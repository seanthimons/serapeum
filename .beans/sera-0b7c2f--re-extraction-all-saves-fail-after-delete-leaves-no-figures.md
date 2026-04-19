---
title: "Re-extraction: all-saves-fail after delete leaves no figures"
status: todo
type: task
priority: high
tags:
  - db
  - pr-review
created_at: 2026-03-21T21:46:02Z
updated_at: 2026-03-22T17:15:56Z
parent: sera-mgb9
---

## Context
Discovered during PR #163 round 3 review.

**File:** `R/pdf_images.R:330-368`

## Problem
If extraction succeeds but every `save_figure()`/`db_insert_figure()` call fails (disk full, DB locked), old figures are already deleted (line 331) and no new ones exist. The `save_failures` counter is tracked but not returned or surfaced to the user.

## Fix
Options:
1. Wrap delete + save in a transaction — rollback if no saves succeed
2. Defer delete until at least one save succeeds
3. Return `save_failures` count and surface it in the UI notification

## Severity
MEDIUM — very narrow edge case requiring disk/DB failure during write. User can re-extract after resolving the underlying issue.

<!-- migrated from beads: `serapeum-1774459567607-193-0b7c2fab` | github: https://github.com/seanthimons/serapeum/issues/223 -->
