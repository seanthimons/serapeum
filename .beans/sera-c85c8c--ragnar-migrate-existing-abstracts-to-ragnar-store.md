---
title: "ragnar: Migrate existing abstracts to ragnar store"
status: completed
type: task
priority: high
created_at: 2026-02-15T20:45:21Z
updated_at: 2026-02-18T17:08:03Z
---

## Context
Part of ragnar migration Phase 5 (parent: #77). Phases 1-4 are complete.

## Problem
Existing abstracts saved before ragnar integration have embeddings in the legacy `chunks` table but are not indexed in the ragnar store. They are only searchable via the legacy brute-force cosine similarity path.

## Solution
Write a migration function that:
1. Queries abstracts with chunks in legacy DB but not in ragnar store
2. Inserts abstract text into ragnar store with `abstract:{id}` origin format
3. Re-embeds via ragnar's embedding pipeline
4. Builds ragnar index

## Acceptance Criteria
- [ ] All pre-existing abstracts are searchable via ragnar hybrid search
- [ ] Migration is idempotent
- [ ] Abstract titles resolve correctly after migration (not just "[Abstract]")

<!-- migrated from beads: `serapeum-1774459564948-75-c85c8c9e` | github: https://github.com/seanthimons/serapeum/issues/92 -->
