---
# g3yt
title: Show embedding model used per notebook store in UI
status: todo
type: feature
priority: normal
tags:
    - embeddings
    - ui
created_at: 2026-05-18T15:39:59Z
updated_at: 2026-05-18T15:39:59Z
---

## Problem

Users have no visibility into which embedding model was used to build a notebook's ragnar store. When they change the embedding model in settings, they don't know that existing notebooks need re-indexing to match — they just get degraded search results.

## Context

- The model ID is already stored in the DB as `index_embed_model_{notebook_id}` (written by `mark_ragnar_store_current()` in `R/_ragnar.R`).
- The document notebook panel shows index status (brain icons) but not the model used.

## Proposed Solution

Add a small indicator in the document notebook panel showing the model the store was indexed with, e.g. "Indexed with: text-embedding-3-small". If the current configured model differs from the indexed model, show a visual warning (e.g., amber badge or tooltip) indicating the index is stale.

## Files

- `R/mod_document_notebook.R` — notebook panel UI
- `R/_ragnar.R` — `mark_ragnar_store_current()` (data source)
