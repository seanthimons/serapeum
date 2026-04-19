---
title: "ragnar: Migrate existing PDF chunks to ragnar store"
status: completed
type: task
priority: high
created_at: 2026-02-15T20:45:17Z
updated_at: 2026-02-18T17:08:00Z
---

## Context
Part of ragnar migration Phase 5 (parent: #77). Phases 1-4 are complete.

## Problem
Existing documents uploaded before ragnar integration have chunks in the legacy DuckDB `chunks` table with comma-separated embedding strings, but nothing in the ragnar store (`serapeum.ragnar.duckdb`). These documents are only searchable via the legacy brute-force path.

## Solution
Write a migration function that:
1. Queries `chunks` table for documents not yet in the ragnar store
2. Re-chunks existing documents via `chunk_with_ragnar()` (semantic chunking)
3. Inserts into ragnar store via `insert_chunks_to_ragnar()`
4. Triggers re-embedding (costs API credits — requires OpenRouter API key)
5. Builds ragnar index after insertion

Should be callable from app startup (with user confirmation) or as a manual migration command.

## Acceptance Criteria
- [ ] All pre-existing PDF chunks are searchable via ragnar hybrid search
- [ ] Migration is idempotent (safe to run multiple times)
- [ ] User is warned about re-embedding costs before migration starts

<!-- migrated from beads: `serapeum-1774459564926-74-6653f300` | github: https://github.com/seanthimons/serapeum/issues/91 -->
