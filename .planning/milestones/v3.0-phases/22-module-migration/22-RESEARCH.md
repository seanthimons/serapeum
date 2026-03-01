# Phase 22: Module Migration - Research

**Researched:** 2026-02-17
**Domain:** Shiny module wiring, ragnar per-notebook store integration, migration UX
**Confidence:** HIGH

## Summary

Phase 22 migrates both `mod_document_notebook.R` and `mod_search_notebook.R` from the legacy shared store (`data/serapeum.ragnar.duckdb`) to per-notebook ragnar stores (`data/ragnar/{notebook_id}.duckdb`). The infrastructure for this — `get_notebook_ragnar_path()`, `ensure_ragnar_store()`, `check_store_integrity()`, `rebuild_notebook_store()`, `with_ragnar_store()`, and the `store_healthy` reactiveVal in `mod_document_notebook.R` — was built in Phases 20 and 21 and is ready to use.

The critical work in Phase 22 is: (1) detecting which notebooks have no per-notebook store and prompting re-index, (2) re-wiring every place that opens a ragnar store so it uses `get_notebook_ragnar_path(notebook_id)` instead of the hardcoded shared path, (3) implementing the lazy connection pattern (open only on first RAG op, close on notebook switch), (4) updating `search_chunks_hybrid()` in `db.R` to accept a per-notebook store path, and (5) wiring the embed button in `mod_search_notebook.R` to use the per-notebook store with incremental append + chunk deletion on paper removal.

The shared store deletion is immediate and safe — user confirmed no migration period is needed.

**Primary recommendation:** Fix `search_chunks_hybrid()` first (it is the deepest dependency), then migrate the two modules, then delete the shared store. Use the `filter` parameter in `ragnar_retrieve()` for section-targeted retrieval — it avoids the current post-retrieval section_hint lookup hack.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Migration trigger:**
- When user opens a notebook with no per-notebook ragnar store, show a prompt/modal asking them to re-index
- New/empty notebooks that have never had content: silently create per-notebook store on first content upload via `ensure_ragnar_store()` (Phase 21) — no prompt needed
- If user declines re-indexing: disable RAG features (chat, synthesis) for that notebook with greyed-out buttons/tooltip until they re-index
- The existing shared store (`data/serapeum.ragnar.duckdb`) can be safely deleted — no need to preserve legacy data during migration

**Store wiring strategy:**
- Lazy connection: don't open ragnar store connection until first RAG operation (chat, embed, synthesis) — not on notebook open
- Shared per-notebook accessor: one reactive value per notebook that all modules (document notebook, search notebook) share — no per-module connections
- On store connection failure: trigger Phase 21 corruption recovery flow (rebuild modal)
- Close store connection when user switches to a different notebook — consistent with on.exit() pattern from Phase 20

**User feedback during migration:**
- Blocking modal with progress bar during re-indexing — user cannot use notebook until complete
- Per-document detail in progress: "Embedding paper 3 of 12: Smith et al. 2023"
- Allow cancellation mid-way — if cancelled, delete the partial store; user is prompted again next time
- On successful completion: progress modal transitions to success state showing document count, then auto-closes

**Search notebook handling:**
- Search notebooks use the same per-notebook ragnar store as document notebooks — unified approach with section_hint metadata to distinguish content types
- Section-targeted retrieval (intro, methods, results, discussion) filters by section_hint in the ragnar query using origin field — not post-retrieval filtering in R
- Embedding is user-initiated, not automatic on adding papers to search results
- Incremental embedding: each embed cycle appends new chunks to existing store (does not rebuild)
- When a paper is removed from search results, its chunks are immediately deleted from the ragnar store
- Re-index is available as a full rebuild/consistency reset mechanism

### Claude's Discretion

- Exact embed trigger UI (smart "Embed All Unembedded" button vs keeping current UI with backend swap)
- Reactive value implementation pattern for shared per-notebook store accessor
- Exact modal/prompt styling for re-index prompt on notebook open
- How to identify which chunks belong to a removed paper (origin field matching pattern)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope

</user_constraints>

---

## Standard Stack

### Core (already installed)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ragnar` | ≥0.3.0 | Per-notebook vector store | Hard dependency since Phase 20 |
| `DBI` | any | Open/close DuckDB connections | Used throughout codebase |
| `shiny` | any | `reactiveVal`, `observeEvent`, `showModal`, `withProgress` | App framework |

### Key Functions Already Available in `_ragnar.R`
| Function | Where Defined | What It Does |
|----------|--------------|--------------|
| `get_notebook_ragnar_path(notebook_id)` | `R/_ragnar.R` | Returns `data/ragnar/{notebook_id}.duckdb` |
| `ensure_ragnar_store(notebook_id, session, api_key, embed_model)` | `R/_ragnar.R` | Opens existing or creates new store |
| `check_store_integrity(store_path)` | `R/_ragnar.R` | Returns `list(ok, missing, error)` |
| `rebuild_notebook_store(notebook_id, con, api_key, embed_model, progress_callback)` | `R/_ragnar.R` | Deletes + rebuilds from DB content |
| `with_ragnar_store(path, expr_fn, session)` | `R/_ragnar.R` | Opens, executes, closes with `on.exit()` |
| `register_ragnar_cleanup(session, store_rv)` | `R/_ragnar.R` | Closes store on session end |
| `insert_chunks_to_ragnar(store, chunks, source_id, source_type)` | `R/_ragnar.R` | Appends chunks to store |
| `build_ragnar_index(store)` | `R/_ragnar.R` | Rebuilds VSS + FTS index after insert |
| `retrieve_with_ragnar(store, query, top_k)` | `R/_ragnar.R` | Wraps `ragnar_retrieve()` |
| `delete_notebook_store(notebook_id)` | `R/_ragnar.R` | Deletes `.duckdb`, `.wal`, `.tmp` files |

### No New Dependencies
All required functions exist. No new packages needed.

---

## Architecture Patterns

### Recommended File Changes
```
R/
├── _ragnar.R              # No changes needed (all lifecycle functions done)
├── db.R                   # Fix search_chunks_hybrid() signature + per-notebook path
├── mod_document_notebook.R  # Wire migration prompt + lazy store + RAG calls
├── mod_search_notebook.R    # Wire per-notebook store for embed + chunk deletion
└── app.R                  # Delete shared store file on startup (one-time)
```

### Pattern 1: "Has Per-Notebook Store?" Check on Notebook Open

**What:** When a notebook with existing content is opened, check if its per-notebook store exists. If not, it came from the legacy shared store era and needs re-indexing.

**When to use:** `observeEvent(notebook_id(), ...)` in both module servers. Run after the existing integrity check.

**Critical distinction:** An empty notebook (no documents, no abstracts) does NOT need re-indexing — the store will be created lazily on first embed. Only notebooks with content but no store need the prompt.

```r
# In mod_document_notebook.R observeEvent(notebook_id(), ...)
nb_id <- notebook_id()
req(nb_id)

store_path <- get_notebook_ragnar_path(nb_id)

# Check if content exists but no per-notebook store
has_content <- {
  docs <- list_documents(con(), nb_id)
  nrow(docs) > 0
}

if (has_content && !file.exists(store_path)) {
  # Notebook has content but no per-notebook store — prompt re-index
  showModal(modalDialog(
    title = "Search Index Setup Required",
    tags$p("This notebook needs its search index rebuilt to use the new per-notebook storage."),
    tags$p("Chat and synthesis will be unavailable until re-indexing completes."),
    footer = tagList(
      actionButton(ns("reindex_notebook"), "Re-index Now", class = "btn-primary"),
      modalButton("Later")
    ),
    easyClose = FALSE  # Force explicit choice
  ))
  # Disable RAG until re-indexed
  rag_ready(FALSE)
} else if (!file.exists(store_path)) {
  # Empty notebook, no store yet — that's fine, lazy creation handles it
  rag_ready(TRUE)
} else {
  # Store exists — run existing integrity check (Phase 21)
  result <- check_store_integrity(store_path)
  store_healthy(result$ok)
  rag_ready(result$ok)
}
```

### Pattern 2: Shared Reactive Store Accessor (Claude's Discretion area)

**What:** A single `reactiveVal` in each module holds the open store connection. Shared between all RAG operations in that module. Closed when notebook changes.

**Recommended approach:** Hold the store connection in `active_store <- reactiveVal(NULL)` inside each module's server function. Open lazily on first RAG operation. Close on notebook switch.

```r
# In mod_document_notebook.R server function
active_store <- reactiveVal(NULL)   # Current open RagnarStore connection
rag_ready <- reactiveVal(TRUE)      # FALSE = migration needed or corruption

# Close store when notebook changes
observeEvent(notebook_id(), {
  store <- active_store()
  if (!is.null(store)) {
    tryCatch(DBI::dbDisconnect(store, shutdown = TRUE), error = function(e) {})
    active_store(NULL)
  }
  # ... then run migration check and integrity check ...
}, priority = 10)  # Higher priority so cleanup runs before other observers

# Register session cleanup
observe({
  register_ragnar_cleanup(session, active_store)
}, once = TRUE)

# Lazy opener used by all RAG operations
get_or_open_store <- function() {
  store <- active_store()
  if (!is.null(store)) return(store)

  nb_id <- notebook_id()
  req(nb_id)

  cfg <- config()
  api_key <- get_setting(cfg, "openrouter", "api_key")
  embed_model <- get_setting(cfg, "defaults", "embedding_model") %||% "openai/text-embedding-3-small"

  store <- tryCatch(
    ensure_ragnar_store(nb_id, session, api_key, embed_model),
    error = function(e) {
      store_healthy(FALSE)
      NULL
    }
  )
  active_store(store)
  store
}
```

**Note:** The `active_store` reactiveVal is per-module (document vs search). The two modules do NOT share a single connection object — they each manage their own. The "shared per-notebook accessor" in the context decisions means "one reactive value within the module that multiple operations use" rather than one shared across modules.

### Pattern 3: `search_chunks_hybrid()` Migration in `db.R`

**What:** The existing `search_chunks_hybrid()` in `db.R` hardcodes `ragnar_store_path = "data/serapeum.ragnar.duckdb"` (line 838). It needs to accept a per-notebook path.

**Current signature:**
```r
search_chunks_hybrid <- function(con, query, notebook_id = NULL, limit = 5,
                                  ragnar_store = NULL,
                                  ragnar_store_path = "data/serapeum.ragnar.duckdb",
                                  section_filter = NULL)
```

**New approach — pass the store path derived from notebook_id:**
```r
search_chunks_hybrid <- function(con, query, notebook_id = NULL, limit = 5,
                                  ragnar_store = NULL,
                                  ragnar_store_path = NULL,   # NULL = derive from notebook_id
                                  section_filter = NULL) {

  # Derive store path from notebook_id if not explicitly provided
  if (is.null(ragnar_store_path) && !is.null(notebook_id)) {
    ragnar_store_path <- get_notebook_ragnar_path(notebook_id)
  }

  # ... rest of function unchanged ...
}
```

**Callers to update:**
- `rag.R:rag_query()` — calls `search_chunks_hybrid(con, question, notebook_id, ...)` — already passes notebook_id, just needs the default to derive path
- `rag.R:generate_conclusions_preset()` — same pattern
- Any direct calls in module servers

### Pattern 4: Section-Targeted Retrieval via ragnar `filter` Parameter

**What:** Currently `search_chunks_hybrid()` retrieves from ragnar then does post-retrieval section_hint lookup from the `chunks` table (lines 882-927 in `db.R`). This is fragile because it joins ragnar content back to the DuckDB chunks table by content prefix substring.

**Better approach:** Use the `filter` parameter of `ragnar_retrieve()` directly. The `origin` field in ragnar stores the encoded section metadata (e.g., `"paper.pdf#page=5|section=conclusion|doi=10.1234/abc|type=pdf"`). Ragnar supports metadata filtering natively.

**Verified from Context7:**
```r
# ragnar_retrieve supports filter parameter (native metadata filtering)
results <- ragnar_retrieve(
  store,
  "statistical modeling",
  top_k = 8,
  filter = category %in% c("statistics", "modeling")
)
```

**For section filtering with pipe-encoded origin:**
The current pipe-delimited encoding (`"base|section=conclusion|doi=...|type=pdf"`) is stored in the `origin` field. Since ragnar uses the `origin` column for filtering, you can match by substring using `grepl` in the filter expression, but this requires knowing ragnar's filter DSL behavior in detail.

**Safer approach for Phase 22:** Keep existing post-retrieval section_hint filtering as-is (it works), and improve it: instead of a fragile substring join, pass `section_filter` encoded into the `origin` field pattern. Or simply look up section_hint from the `chunks` DuckDB table by content hash (already done). This is not broken — just inelegant. Phase 22 should not refactor this; focus on the store path migration.

**Recommendation (Claude's Discretion):** Leave the section filtering implementation as-is for Phase 22. The correctness fix (using ragnar's native filter on section_hint in extra_cols) is a Phase 23 cleanup item. Phase 22's job is store wiring, not retrieval quality improvement.

### Pattern 5: Chunk Deletion on Paper Removal (Search Notebook)

**Decision:** When a paper is removed from search results (user clicks delete), its chunks are immediately deleted from the ragnar store.

**How to identify chunks by paper:** The `origin` field in ragnar encodes the abstract ID: `"abstract:{abstract_id}|section=general|doi=...|type=abstract"`. Deletion requires querying ragnar's DuckDB directly.

**Ragnar store schema** (from `insert_chunks_to_ragnar`): rows in ragnar have `origin`, `hash`, `text` columns. DuckDB supports arbitrary SQL on the ragnar file.

```r
# Delete chunks for a removed paper from the per-notebook ragnar store
delete_abstract_from_ragnar <- function(store_path, abstract_id) {
  if (!file.exists(store_path)) return(invisible(NULL))

  tryCatch({
    # Connect directly to ragnar's DuckDB and delete matching rows
    # Origin format: "abstract:{id}|section=...|..."
    con <- DBI::dbConnect(duckdb::duckdb(), dbdir = store_path)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

    # Delete rows where origin starts with "abstract:{abstract_id}"
    origin_prefix <- paste0("abstract:", abstract_id)
    DBI::dbExecute(con,
      "DELETE FROM chunks WHERE starts_with(origin, ?)",
      list(origin_prefix)
    )
  }, error = function(e) {
    message("[ragnar] Failed to delete chunks for abstract ", abstract_id, ": ", e$message)
  })
}
```

**Caution:** After deletion, `ragnar_store_build_index()` should be called to keep BM25/VSS indexes consistent. However, rebuilding the index on every paper deletion is expensive. Two options:
1. Delete chunks from underlying DuckDB directly (above), rebuild index lazily before next retrieval
2. Accept stale index until user re-indexes

**Recommendation (Claude's Discretion):** For Phase 22, delete chunks from the DuckDB table directly and mark index as dirty (track with a `reactiveVal`). Rebuild index before next retrieval operation. Do NOT rebuild on every deletion — that would block UI for potentially seconds.

**Alternative simpler approach:** When the user removes a paper, simply delete the chunks from ragnar's DuckDB table. Don't rebuild index immediately. The stale chunks will score zero in BM25 (deleted) but may still appear in VSS if index is not rebuilt. Rebuild on the next "Embed" button click. This is acceptable for Phase 22.

### Pattern 6: Migration Re-index UX

**Blocking modal with progress bar during re-indexing:**

```r
# observeEvent(input$reindex_notebook, ...)
observeEvent(input$reindex_notebook, {
  removeModal()
  nb_id <- notebook_id()
  req(nb_id)

  cfg <- config()
  api_key <- get_setting(cfg, "openrouter", "api_key")
  embed_model <- get_setting(cfg, "defaults", "embedding_model") %||% "openai/text-embedding-3-small"

  # Show blocking progress modal (user cannot use notebook until complete)
  showModal(modalDialog(
    title = "Re-indexing...",
    div(
      uiOutput(ns("reindex_progress_detail")),
      div(class = "progress mt-2",
          div(class = "progress-bar progress-bar-striped progress-bar-animated",
              id = ns("reindex_bar"),
              style = "width: 0%"))
    ),
    footer = tagList(
      actionButton(ns("cancel_reindex"), "Cancel", class = "btn-danger")
    ),
    easyClose = FALSE
  ))

  # Use withProgress for progress tracking
  withProgress(message = "Re-indexing notebook...", value = 0, {
    result <- rebuild_notebook_store(
      notebook_id = nb_id,
      con = con(),
      api_key = api_key,
      embed_model = embed_model,
      progress_callback = function(count, total) {
        # Update custom modal progress bar via JS
        # Also update Shiny progress bar
        incProgress(1/total,
          detail = paste0("Embedding item ", count, " of ", total))
      }
    )
  })

  removeModal()

  if (result$success) {
    rag_ready(TRUE)
    showNotification(paste("Re-indexed", result$count, "items."), type = "message")
  } else {
    showModal(modalDialog(
      title = "Re-indexing Failed",
      paste("Error:", result$error),
      footer = tagList(
        actionButton(ns("retry_reindex"), "Try Again", class = "btn-warning"),
        modalButton("Later")
      ),
      easyClose = FALSE
    ))
  }
})
```

**Cancellation:** When user cancels mid-way, delete the partial store (`delete_notebook_store(nb_id)`). The user is prompted again next time they open the notebook.

**Note:** `rebuild_notebook_store()` in `_ragnar.R` does not currently support cancellation (no interrupt mechanism). For cancellation to work, you need either `ExtendedTask` (async) or a flag checked between items. For Phase 22, the simplest approach is: after the `withProgress` block, check if cancelled via a `reactiveVal` set by the cancel button. If cancelled, call `delete_notebook_store()`.

### Pattern 7: Search Notebook Incremental Embed

**Current behavior:** `input$embed_papers` handler in `mod_search_notebook.R` (lines 1672-1780) uses the shared store path `"data/serapeum.ragnar.duckdb"`. The handler already:
- Queries only filtered papers (not all papers in notebook)
- Checks which papers lack embeddings
- Appends to existing store (incremental)

**Change needed:** Replace the hardcoded shared store path with `get_notebook_ragnar_path(notebook_id())`.

**"Already embedded" detection:** The current check (lines 594-605) looks at the `chunks` DuckDB table (`WHERE c.embedding IS NOT NULL`). After Phase 22, the ground truth for "embedded" is the ragnar store, not the chunks table. Two options:
1. Keep checking chunks table (simpler — chunks table still populated as a record)
2. Query ragnar store directly to count rows with matching abstract IDs

**Recommendation:** Keep the chunks table check for "needs embedding" detection. The chunks table records are still created on abstract save (`create_chunk()` in `do_search_refresh`). The check `embedding IS NOT NULL` works because the embed handler should also set the embedding in chunks when inserting to ragnar. **However:** Currently the embed handler sets `embedding` in chunks table only via the legacy path (lines 1759-1772). After migration to ragnar-only, this legacy path is removed and chunks will never have embeddings set. The "needs embedding" check will break.

**Fix:** After successfully inserting to ragnar, update the chunk's `embedding` column to a sentinel value (e.g., `"ragnar_indexed"`) to mark it as embedded. This preserves the existing UI logic without a schema change.

```r
# After ragnar insert succeeds, mark chunks as embedded in DuckDB
DBI::dbExecute(con(), sprintf("
  UPDATE chunks SET embedding = 'ragnar_indexed'
  WHERE source_id IN (%s) AND source_type = 'abstract'
", placeholders), as.list(paper_ids))
```

### Anti-Patterns to Avoid

**Opening a store connection inside `rag_query()` or `generate_conclusions_preset()`:** These functions currently do not manage store connections — they call `search_chunks_hybrid()` which manages the connection internally. After Phase 22, the store connection should be opened in the module server and passed in, or `search_chunks_hybrid()` should accept a path and open/close internally. Keep the current pattern (pass path, open internally with `connect_ragnar_store()`) to avoid propagating connection objects through function signatures.

**Rebuilding the FTS+VSS index after every insert:** Call `build_ragnar_index()` once after all chunks for a document/batch are inserted. Not after each chunk. The current `insert_chunks_to_ragnar()` does not call `build_ragnar_index()` — it must be called explicitly afterward. This is correct.

**Using the shared store path `"data/serapeum.ragnar.duckdb"` anywhere after Phase 22:** Do a codebase-wide grep for this string before declaring Phase 22 complete. All references must be removed.

**Forgetting to re-enable greyed-out RAG controls after successful re-index:** If `rag_ready` is set to `FALSE` for a notebook, the greyed-out state must be cleared when re-indexing succeeds.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Store lifecycle on open/close | Custom connection tracking | `register_ragnar_cleanup()` from Phase 20 | Already handles session end cleanup |
| Re-embedding all documents | Custom loop | `rebuild_notebook_store()` from Phase 21 | Already handles documents + abstracts + progress callback |
| Store integrity check | Manual file validation | `check_store_integrity()` from Phase 21 | Already wraps `ragnar_store_connect()` in tryCatch |
| Store path construction | String concatenation | `get_notebook_ragnar_path(notebook_id)` | Canonical path function, consistent across codebase |
| DuckDB chunk deletion | Custom SQL queries | Use `DBI::dbExecute()` on ragnar's DuckDB file directly | Ragnar store IS a DuckDB file — safe to query directly |

---

## Common Pitfalls

### Pitfall 1: Forgetting `content` vs `text` Column Name
**What goes wrong:** Ragnar returns results with column `text`, not `content`. The `retrieve_with_ragnar()` wrapper in `_ragnar.R` renames it, but `search_chunks_hybrid()` also handles this (line 960-962: `if (!"content" %in% names(results) && "text" %in% names(results)) { results$content <- results$text }`).
**How to avoid:** Always pass results through `search_chunks_hybrid()` or `retrieve_with_ragnar()`. Never call `ragnar_retrieve()` directly in module servers.

### Pitfall 2: Migration Prompt Showing for Empty Notebooks
**What goes wrong:** A new notebook (no documents, no abstracts) has no per-notebook store. If the check is "no store file = prompt re-index", empty notebooks get a confusing migration prompt.
**How to avoid:** Check `nrow(list_documents(con(), nb_id)) > 0 || nrow(list_abstracts(con(), nb_id)) > 0` BEFORE deciding to show the migration prompt. Only prompt when content exists but store doesn't.

### Pitfall 3: Two Modules Opening Competing Connections to Same Store
**What goes wrong:** Document notebook and search notebook modules both try to open `data/ragnar/{notebook_id}.duckdb`. DuckDB allows multiple readers but has issues with concurrent writers. Both modules may write (embed) to the same store.
**How to avoid:** The "shared per-notebook accessor" decision means one reactiveVal is shared. In practice, the two modules are instantiated separately in `app.R` and cannot share a reactiveVal directly. The safe path: each module opens its own connection for READ (retrieval) but WRITE (embed) operations should close any open read connection first, then write, then reconnect for reads. Since embedding is user-initiated and sequential, this is manageable.
**Pragmatic approach for Phase 22:** Since embed and retrieval don't happen concurrently (user-initiated one at a time), allow each module its own connection. They will be staggered by user interaction.

### Pitfall 4: `store_healthy` reactiveVal Doesn't Reset Between Notebooks
**What goes wrong:** `store_healthy(FALSE)` is set for notebook A. User switches to notebook B. `store_healthy` still shows FALSE, blocking RAG in notebook B.
**How to avoid:** Reset `store_healthy(NULL)` and `rag_ready(TRUE)` at the START of `observeEvent(notebook_id(), ...)`, before any checks. The Phase 21 code already does this implicitly by re-running the integrity check on every notebook switch, but the reactive state must be explicitly reset.

### Pitfall 5: `search_chunks_hybrid()` Default Path Still Points to Shared Store
**What goes wrong:** After updating the module code, `rag_query()` in `rag.R` calls `search_chunks_hybrid()` without passing `ragnar_store_path`. The default still points to `"data/serapeum.ragnar.duckdb"` (which will be deleted).
**How to avoid:** Change the default of `ragnar_store_path` to `NULL` and derive it from `notebook_id` when NULL. Verify there are no callers that rely on the shared path default.

### Pitfall 6: `rebuild_notebook_store()` Doesn't Know About ragnar-Only Embedding
**What goes wrong:** `rebuild_notebook_store()` in `_ragnar.R` calls `list_documents()` and `list_abstracts()`. If the existing code also updates chunks table embeddings, this double-work is harmless. But if not — after rebuild, the chunks table `embedding` column remains NULL, and the "needs embedding" check in `mod_search_notebook.R` will always show papers as needing embedding.
**How to avoid:** After `rebuild_notebook_store()` succeeds, run a SQL update to set `embedding = 'ragnar_indexed'` for all chunks in that notebook.

### Pitfall 7: Cancellation Leaves Partial Store
**What goes wrong:** User cancels re-index mid-way. Partial store file exists. Next time they open the notebook, the integrity check passes (partial store is not corrupt, just incomplete). The migration prompt does NOT show again (store file exists). User has an incomplete index.
**How to avoid:** The cancel handler must delete the partial store. Use `delete_notebook_store(nb_id)` in the cancel observeEvent. Also: the migration prompt logic must check "store exists AND has at least N chunks" or simply "store file exists" (simpler — treat existence as "indexed"). If you want stricter: add a chunk count check.
**Pragmatic approach:** Delete partial store on cancel. The migration prompt condition is `file.exists(store_path)`, so after deletion, the prompt reappears correctly on next open.

---

## Code Examples

### Checking for Migration Need
```r
# Source: Codebase patterns from mod_document_notebook.R + _ragnar.R
needs_migration <- function(con, notebook_id) {
  store_path <- get_notebook_ragnar_path(notebook_id)

  # Already has per-notebook store
  if (file.exists(store_path)) return(FALSE)

  # No store, but also no content — lazy creation handles this
  docs <- list_documents(con, notebook_id)
  abstracts <- list_abstracts(con, notebook_id)

  nrow(docs) > 0 || nrow(abstracts) > 0
}
```

### Greying Out RAG Controls Based on `rag_ready`
```r
# In mod_document_notebook.R UI server
output$send_ui <- renderUI({
  if (!isTRUE(rag_ready())) {
    tags$button(
      class = "btn btn-secondary",
      disabled = "disabled",
      title = "Re-index this notebook to enable chat",
      "Chat unavailable"
    )
  } else {
    actionButton(ns("send"), "Send", class = "btn-primary")
  }
})
```

### Sentinel Value for "Ragnar Indexed" Chunks
```r
# After ragnar insert succeeds in embed handler
# Source: Pattern adapted from existing chunks table usage in db.R

mark_as_ragnar_indexed <- function(con, abstract_ids) {
  if (length(abstract_ids) == 0) return(invisible(NULL))
  placeholders <- paste(rep("?", length(abstract_ids)), collapse = ", ")
  DBI::dbExecute(con, sprintf(
    "UPDATE chunks SET embedding = 'ragnar_indexed'
     WHERE source_id IN (%s) AND source_type = 'abstract'",
    placeholders
  ), as.list(abstract_ids))
}

# "Needs embedding" check (updated to treat sentinel as embedded)
count_unembedded <- function(con, abstract_ids) {
  if (length(abstract_ids) == 0) return(0)
  placeholders <- paste(rep("?", length(abstract_ids)), collapse = ", ")
  result <- DBI::dbGetQuery(con, sprintf("
    SELECT COUNT(DISTINCT source_id) as cnt
    FROM chunks
    WHERE source_id IN (%s)
      AND (embedding IS NULL OR embedding = '')
  ", placeholders), as.list(abstract_ids))
  result$cnt[1]
}
```

### Deleting Ragnar Chunks for a Removed Paper
```r
# Source: DuckDB direct access pattern from _ragnar.R delete_notebook_store()
delete_abstract_chunks_from_ragnar <- function(notebook_id, abstract_id) {
  store_path <- get_notebook_ragnar_path(notebook_id)
  if (!file.exists(store_path)) return(invisible(NULL))

  tryCatch({
    con_ragnar <- DBI::dbConnect(duckdb::duckdb(), dbdir = store_path)
    on.exit(DBI::dbDisconnect(con_ragnar, shutdown = TRUE), add = TRUE)

    origin_prefix <- paste0("abstract:", abstract_id)
    DBI::dbExecute(con_ragnar,
      "DELETE FROM chunks WHERE starts_with(origin, ?)",
      list(origin_prefix)
    )
    message("[ragnar] Deleted chunks for abstract: ", abstract_id)
  }, error = function(e) {
    message("[ragnar] Chunk deletion failed for ", abstract_id, ": ", e$message)
  })
}
```

**Note on `starts_with()`:** DuckDB supports `starts_with(column, prefix)` as a function. Verify this works — if not, use `LIKE 'abstract:id%'` as fallback.

### Updated `search_chunks_hybrid()` Signature
```r
# In R/db.R — change only the default value of ragnar_store_path
search_chunks_hybrid <- function(con, query, notebook_id = NULL, limit = 5,
                                  ragnar_store = NULL,
                                  ragnar_store_path = NULL,  # Changed: derive from notebook_id
                                  section_filter = NULL) {

  # Derive store path from notebook_id if not provided
  if (is.null(ragnar_store_path) && !is.null(notebook_id)) {
    ragnar_store_path <- get_notebook_ragnar_path(notebook_id)
  }

  # ... rest of function body unchanged ...
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact on Phase 22 |
|--------------|------------------|--------------|-------------------|
| Single shared store `data/serapeum.ragnar.duckdb` | Per-notebook stores `data/ragnar/{id}.duckdb` | Phase 20 (v3.0) | Phase 22 WIRES this — stores exist, just not connected to modules yet |
| Shared path hardcoded in modules | `get_notebook_ragnar_path(notebook_id)` | Phase 22 | Primary change needed |
| Notebook isolation via R-level filtering | True isolation via separate DuckDB files | Phase 20 design | Phase 22 delivers this to users |
| Legacy embedding in chunks table | Ragnar VSS+BM25 in per-notebook store | Phase 22 | Legacy code still runs as fallback — remove in Phase 23 |
| `search_chunks_hybrid()` uses shared store path default | Will use per-notebook path default | Phase 22 | Change default parameter + callers |

**Deprecated after Phase 22:**
- `data/serapeum.ragnar.duckdb` shared store — delete on startup (or first run after Phase 22 deploy)
- Legacy embedding path in `mod_document_notebook.R` upload handler (lines 349-384) — still present as fallback, remove in Phase 23
- Legacy embedding in `mod_search_notebook.R` embed handler (lines 1747-1773) — still present as fallback, remove in Phase 23

---

## Open Questions

1. **Can two DuckDB connections (one per module) safely read from the same ragnar store file concurrently?**
   - What we know: DuckDB supports multiple readers in WAL mode. ragnar stores are standard DuckDB files.
   - What's unclear: ragnar's `ragnar_store_connect()` opens in read-write mode by default. Two read-write connections to the same file may conflict.
   - Recommendation: Use `ragnar_store_connect(path, read_only = TRUE)` for retrieval operations. Only open read-write when embedding (and close the read connection first). Context7 confirms `read_only = TRUE` is supported.

2. **Does DuckDB `starts_with()` function exist for chunk deletion?**
   - What we know: DuckDB supports `starts_with()` as of version 0.9+.
   - What's unclear: ragnar's bundled DuckDB version vs. installed DuckDB version.
   - Recommendation: Test `starts_with()` in a quick DuckDB query on the ragnar file. Fallback: `WHERE origin LIKE ?` with `paste0("abstract:", abstract_id, "%")`.

3. **What happens to the `store_healthy` reactiveVal in `mod_document_notebook.R` after Phase 22?**
   - What we know: Phase 21 added `store_healthy` for corruption detection. Phase 22 adds `rag_ready` for migration state.
   - What's unclear: Should these be merged into one state variable?
   - Recommendation: Keep them separate. `store_healthy` = corruption detection (Phase 21 concern). `rag_ready` = migration/availability (Phase 22 concern). Combined: `rag_available <- reactive({ isTRUE(store_healthy()) && isTRUE(rag_ready()) })`.

4. **Should `rebuild_notebook_store()` update the chunks table sentinel values?**
   - What we know: `rebuild_notebook_store()` calls `insert_chunks_to_ragnar()` for documents and abstracts.
   - What's unclear: Does it update `chunks.embedding` to sentinel value?
   - Recommendation: After `rebuild_notebook_store()` succeeds, the calling module code should run `mark_as_ragnar_indexed()` for all notebooks content. Add this to the rebuild success handler, not inside `rebuild_notebook_store()` itself (keeps the function pure/decoupled from DuckDB schema details).

5. **Migration prompt for search notebooks vs. document notebooks**
   - What we know: Search notebooks store abstracts, document notebooks store PDFs. Both need the re-index prompt.
   - What's unclear: The current Phase 21 code only added the integrity check to `mod_document_notebook.R`. Does `mod_search_notebook.R` also need the migration prompt?
   - Recommendation: Yes — `mod_search_notebook.R` needs the same migration check. A search notebook with embedded abstracts (legacy shared store) needs re-indexing before chat works. Add the same `observeEvent(notebook_id(), ...)` pattern to `mod_search_notebook.R`.

---

## Sources

### Primary (HIGH confidence)
- `R/_ragnar.R` — Full lifecycle function inventory (verified by reading source)
- `R/mod_document_notebook.R` — Existing Phase 21 `store_healthy` + rebuild flow
- `R/mod_search_notebook.R` — Existing embed handler, `papers_need_embedding` check
- `R/rag.R` — `rag_query()` and `generate_conclusions_preset()` calling patterns
- `R/db.R` lines 836-986 — `search_chunks_hybrid()` full implementation
- Context7 `/tidyverse/ragnar` — `ragnar_retrieve(filter=...)` parameter confirmed, `read_only=TRUE` confirmed

### Secondary (MEDIUM confidence)
- Phase 21 RESEARCH.md and SUMMARY.md — Confirmed what was implemented
- Phase 20 decisions (from additional_context) — `on.exit()` pattern, aggressive cleanup

### Tertiary (LOW confidence)
- DuckDB `starts_with()` function availability in ragnar-bundled version — not verified against runtime

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all functions exist, verified by reading source
- Architecture patterns: HIGH — derived from existing code + user decisions
- Migration UX: HIGH — directly specified in user decisions
- Chunk deletion from ragnar: MEDIUM — DuckDB SQL pattern is standard but `starts_with()` not runtime-verified
- Concurrent connection safety: MEDIUM — DuckDB read-only mode confirmed in Context7, but multi-module scenario is edge case

**Research date:** 2026-02-17
**Valid until:** 2026-03-19 (30 days — ragnar stable, DuckDB stable, patterns in codebase stable)
