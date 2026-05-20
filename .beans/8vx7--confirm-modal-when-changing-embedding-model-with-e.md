---
# 8vx7
title: Confirm modal when changing embedding model with existing stores
status: todo
type: feature
priority: high
tags:
    - embeddings
    - ui
    - settings
created_at: 2026-05-18T15:59:27Z
updated_at: 2026-05-18T15:59:27Z
---

## Problem

When a user changes their embedding model in Settings and clicks Save, the new model is written immediately (`mod_settings.R:2004`) with no warning. Existing ragnar stores (built with the old model) silently become incompatible — queries will use the new model to vectorize against old-model embeddings, returning garbage results.

There is already an inline dimension-mismatch warning (`mod_settings.R:1533`), but it only fires when vector dimensions differ. Two models with the same dimensionality (e.g., `gemini-embedding-001` and `text-embedding-3-large`, both 3072) would pass that check while still being completely incompatible.

## Proposed Fix

In the `observeEvent(input$save, ...)` handler at `mod_settings.R:1970`:

1. Before saving `embedding_model`, compare `input$embed_model` against the currently stored value (`get_db_setting(con(), "embedding_model")`).
2. If they differ, count ragnar store files in `data/ragnar/` (or query notebooks that have `index_embed_model_*` settings).
3. If stores exist, show a `modalDialog` explaining:
   - Which model the existing indexes were built with
   - How many notebooks are affected
   - That search will be broken until those notebooks are re-indexed
   - "Save & Re-index Later" / "Cancel" buttons
4. Only persist the new embedding model on confirmation. Save all other settings immediately regardless.

## Files

- `R/mod_settings.R` — `observeEvent(input$save, ...)` (~line 1970), existing dimension warning (~line 1533)
- `R/_ragnar.R` — `find_orphaned_stores()` pattern for counting store files

## Related

- `4a6m` — Guard against model mismatch at query time (runtime defense)
- `g3yt` — Show indexed model per notebook (visibility)
