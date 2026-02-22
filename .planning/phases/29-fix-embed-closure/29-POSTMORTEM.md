# Phase 29 Post-Mortem: Fix Embed Function Closure Bug

## Summary

Fixed the critical ragnar embed closure serialization bug that broke all embedding and RAG chat operations. The fix required 6 commits across 5 files, addressing a cascade of issues discovered during live testing.

## Timeline

1. **Initial fix** — `make_embed_function()` + runtime `@embed` attachment on `get_ragnar_store()` and `ensure_ragnar_store()` (planned scope)
2. **Chat spinner** — Added client-side JS spinner on send button since Shiny can't flush UI during synchronous R handlers
3. **Retrieval path missed** — `ragnar_retrieve()` needs embed to vectorize the *query*, not just for insertion. Plan incorrectly assumed `connect_ragnar_store` was "retrieval-only" and didn't need embed. Updated `search_chunks_hybrid` to accept and attach embed credentials.
4. **Spinner stuck** — `Shiny.addCustomMessageHandler` silently fails on re-registration when module UI re-renders. Fixed with `window._*Registered` guards.
5. **Origin parsing broken** — `encode_origin_metadata()` (Phase 22) appends `|section=...|type=pdf` to origins, but `retrieve_with_ragnar()` parsed with `sub("#page=\\d+$", ...)` which didn't account for the suffix. Same issue with abstract ID extraction. All 20 retrieved rows were being filtered out.
6. **Stale ragnar chunks** — `delete_document()` cleaned main DB but not the ragnar store. Added `delete_document_chunks_from_ragnar()`.

## Root Causes

| Issue | Root Cause | Detection |
|-------|-----------|-----------|
| Embed broken | ragnar serializes closures; deserialized env is empty | Known bug, design doc existed |
| Retrieval broken | Plan assumed retrieval doesn't embed (wrong — query vectorization) | Live testing after "fix" |
| Origin filter drops all rows | `encode_origin_metadata` added pipe-delimited suffix; parsers used `$` anchor | Debug logging showed 20 rows retrieved, 0 kept |
| Stale chunks | `delete_document` only cleans main DB tables | User noticed deleted paper appearing in results |
| Spinner stuck | `addCustomMessageHandler` can only register once per name; module UI re-renders | Visual — button never restored |

## Lessons Learned

1. **ragnar_retrieve embeds the query** — Any path that calls `ragnar_retrieve` needs a working embed function, not just insertion paths. "Retrieval-only" is a misnomer for hybrid (VSS+BM25) search.

2. **Origin format coupling** — `encode_origin_metadata()` and `retrieve_with_ragnar()` are tightly coupled but live in different functions with no shared contract. When one changed (Phase 22 added metadata), the other silently broke. Need to parse origins through `decode_origin_metadata()` consistently.

3. **Silent tryCatch swallowing** — `error = function(e) NULL` in `search_chunks_hybrid` hid the real error for multiple debugging rounds. Always log before returning NULL.

4. **Shiny custom message handler registration** — Handlers registered in module UI `tagList()` re-execute on every render. Must guard with a window-level flag.

5. **Dual-store consistency** — When data exists in both main DB and ragnar store, deletes must clean both. The ragnar store is not just a cache — it has its own chunk data that diverges from the main DB.

## Files Changed

| File | Changes |
|------|---------|
| `R/_ragnar.R` | `make_embed_function()`, updated `get_ragnar_store()`, `ensure_ragnar_store()`, origin parsing fix, `delete_document_chunks_from_ragnar()` |
| `R/db.R` | `search_chunks_hybrid` embed attachment + abstract ID parsing fix |
| `R/rag.R` | Pass embed credentials to all `search_chunks_hybrid` callers |
| `R/mod_document_notebook.R` | Chat spinner JS, ragnar cleanup on doc delete |
| `R/mod_search_notebook.R` | Chat spinner JS |
| `tests/testthat/test-ragnar.R` | `make_embed_function` unit test |

## Status: CLOSED
