---
title: "ragnar: Fix lossy metadata persistence in ragnar store"
status: completed
type: task
priority: high
created_at: 2026-02-15T20:45:36Z
updated_at: 2026-02-18T17:08:10Z
---

## Context
Part of ragnar migration Phase 5 (parent: #77).

## Problem
`insert_chunks_to_ragnar()` in `R/_ragnar.R` (line 193) stores Serapeum metadata (source_id, source_type, page_numbers, contexts) as an R `attr()` on the data frame. This is an in-memory-only attribute — it does not persist to the ragnar DuckDB store.

Additionally, `retrieve_with_ragnar()` returns `"[Abstract]"` as a placeholder for abstract titles, requiring a cross-database lookup to resolve the actual title (which adds complexity in `search_chunks_hybrid`).

## Solution Options
1. **Encode richer metadata in the `origin` field** — e.g., `"abstract:{id}:{title_slug}"` or `"filename#page=N#section=conclusion"`
2. **Maintain a mapping table** in the main DuckDB that links ragnar chunk hashes to Serapeum metadata
3. **Wait for ragnar to support custom metadata** (ragnar is pre-1.0, may add this)

## Acceptance Criteria
- [ ] Source metadata (type, page number, section hint) survives ragnar store round-trip
- [ ] Abstract titles are retrievable without separate DB lookup

<!-- migrated from beads: `serapeum-1774459564993-77-793bd75d` | github: https://github.com/seanthimons/serapeum/issues/94 -->
