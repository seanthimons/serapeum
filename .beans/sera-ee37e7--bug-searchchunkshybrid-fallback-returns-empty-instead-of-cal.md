---
title: "bug: search_chunks_hybrid fallback returns empty instead of calling legacy search"
status: completed
type: bug
priority: high
created_at: 2026-02-15T20:45:29Z
updated_at: 2026-02-18T17:08:07Z
---

## Bug Description
`search_chunks_hybrid()` in `R/db.R` (lines 965-981) has a broken fallback path. When ragnar is unavailable or the store doesn't exist, the function logs a message and returns an **empty data frame** instead of calling `search_chunks()`.

This means any user without ragnar installed gets **zero search results** from RAG queries.

## Expected Behavior
When ragnar is unavailable, should fall back to the legacy `search_chunks(con, query_embedding, notebook_id, limit)` function which does brute-force cosine similarity search.

## Actual Behavior
Returns empty frame with a message "Ragnar search not available, using legacy embedding search" — but never actually calls the legacy search.

## Root Cause
The fallback block at L965-981 was written as a placeholder that returns an empty data frame. It needs to actually embed the query and call `search_chunks()`.

## Fix
Replace the empty-frame return with actual legacy search: embed the query via `get_embeddings()`, then call `search_chunks(con, query_embedding, notebook_id, limit)`.

<!-- migrated from beads: `serapeum-1774459564971-76-ee37e723` | github: https://github.com/seanthimons/serapeum/issues/93 -->
