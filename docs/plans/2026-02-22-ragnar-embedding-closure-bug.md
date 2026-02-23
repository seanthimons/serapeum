# Bug: Ragnar Embedding Closure — `get_embeddings` not found

**Date:** 2026-02-22
**Priority:** Critical — blocks all document embedding (brain icon never appears)
**Error:** `could not find function "get_embeddings"` (or `.get_embeddings`)

## Situation Report

### What's broken
When uploading a PDF to a document notebook, the ragnar store creation fails because the embed function closure can't find `get_embeddings` at call time. The error occurs in `R/_ragnar.R` inside `get_ragnar_store()` → `embed_via_openrouter()`.

This affects:
- Document notebook PDF uploads (embedding step silently skipped)
- Search notebook "Embed Papers" button (same code path via `ensure_ragnar_store`)
- Async re-index tasks (mirai workers)

### Root cause analysis

`ragnar::ragnar_store_create()` receives an `embed` function and **serializes it to disk** as part of the store's DuckDB file. When `ragnar_store_connect()` later deserializes the function, the closure's environment is lost. Any captured variables or function references that aren't self-contained primitives become unresolvable.

#### Attempts so far (all failed)

1. **Direct reference** (`get_embeddings(...)` inside closure):
   - Fails because ragnar deserializes the closure in its own package namespace, where `get_embeddings` doesn't exist.

2. **Capture at closure creation** (`.get_embeddings <- get_embeddings`):
   - Works at creation time, but after serialization/deserialization the captured reference is gone.

3. **`get()` from globalenv** (`get("get_embeddings", envir = globalenv())`):
   - Should work in theory but the serialized `globalenv()` reference may not resolve correctly after deserialization.

### What needs to happen

The fix needs to ensure the embed function works **after ragnar serializes and deserializes it**. Options to investigate:

1. **Inline the HTTP call entirely** — don't reference `get_embeddings` at all. Copy the httr2 request logic directly into the closure so it's fully self-contained (no external function references). This is the most robust but duplicates code.

2. **Check how ragnar stores the embed function** — read ragnar's source to understand serialization. If it uses `serialize()`/`saveRDS()`, closures lose their environments. If it stores just the function body, we need a different approach.

3. **Pass embed function at connect time, not create time** — if ragnar supports providing the embed function when connecting (not just creating), we could skip serialization entirely. Check `ragnar_store_connect()` API.

4. **Use a package-level function** — if `get_embeddings` were in an installed R package namespace (not just sourced), ragnar's deserialization might resolve it. But this would require packaging the app.

### Files involved

- `R/_ragnar.R` — `get_ragnar_store()` (line ~146-174) where embed closure is created
- `R/_ragnar.R` — `ensure_ragnar_store()` (line ~301) entry point
- `R/_ragnar.R` — `rebuild_notebook_store()` (line ~527) async path
- `R/api_openrouter.R` — `get_embeddings()` (line ~70) the target function
- `R/mod_document_notebook.R` — upload handler (line ~598) where embedding triggers
- `R/mod_search_notebook.R` — embed button handler (line ~2086)

### Other fixes applied in this session (already working)

These were fixed in the same session and should be committed separately:

1. **Fresh DB migration crash** — `init_schema()` now runs before migrations in `get_db_connection()`
2. **`newly_added` scoping bug** — variable moved outside `withProgress` closure
3. **Auto-search on new notebook** — observer triggers search when notebook has query but zero papers
4. **Settings UI empty on first visit** — observer waits for UI render before populating
5. **Credentials overwritten by empty save** — save handler skips empty credentials; `non_empty()` helper in effective_config
6. **Document delete button** — added X button to document list items
7. **Brain icon on documents** — shows embedded status per document
