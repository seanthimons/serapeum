---
# 4a6m
title: Guard against embedding model mismatch at query time
status: todo
type: bug
priority: high
tags:
    - embeddings
    - ragnar
created_at: 2026-05-18T15:39:54Z
updated_at: 2026-05-18T15:39:54Z
---

## Problem

`search_chunks_hybrid()` in `R/db.R` attaches whatever embedding model is currently configured via `resolve_model_for_operation(cfg, "embedding")` to vectorize the query. It does **not** check whether the ragnar store was built with the same model.

Embedding vectors from different models are incompatible — cosine similarity between them is meaningless. If a user changes their embedding model in settings between indexing and querying (without triggering a re-index), search silently returns garbage results with no error or warning.

## Context

- `is_ragnar_store_stale()` in `R/_ragnar.R` already detects model mismatches and is called during indexing flows.
- `mark_ragnar_store_current()` records the model used at index time in a DB setting (`index_embed_model_{notebook_id}`).
- But `search_chunks_hybrid()` never consults either of these.

## Proposed Fix

Before attaching the embed function in `search_chunks_hybrid()`, compare the current embedding model against the stored `index_embed_model_{notebook_id}`. If they differ:

1. Log a warning with both model IDs.
2. Either refuse the VSS portion of the search (fall back to BM25-only) or surface a user-facing notification that the index is stale and needs re-indexing.

## Files

- `R/db.R` — `search_chunks_hybrid()` (~line 1096)
- `R/_ragnar.R` — `is_ragnar_store_stale()`, `mark_ragnar_store_current()`
