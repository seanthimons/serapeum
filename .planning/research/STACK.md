# Stack Research

**Domain:** Per-notebook RAG stores (ragnar migration)
**Researched:** 2026-02-16
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| ragnar | 0.3.0 | Vector store management with VSS + BM25 hybrid retrieval | Posit's purpose-built RAG package for R, uses DuckDB backend with automatic VSS extension loading, supports both version 1 (flat chunks) and version 2 (documents with chunk ranges) stores |
| DuckDB | 1.3.2 (via ragnar dependency) | Embedded database for vector storage | Lightweight, no-server database with native VSS extension support, automatic extension installation via ragnar |
| digest | 0.6.37 | Content hashing for deduplication (version 1 stores) | Currently used in `_ragnar.R` for chunk hash generation in version 1 stores; NOT needed for version 2 stores (ragnar handles hashing internally via `rlang::hash`) |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| DBI | 1.2.3 | Database interface for DuckDB operations | Required for all DuckDB connections, accessing store internals, and metadata queries |
| uuid | (current) | Generate unique store identifiers | Creating per-notebook ragnar store paths and notebook IDs |
| jsonlite | (current) | Serialize notebook-to-store mappings | Storing notebook metadata that links to ragnar store locations |

## Ragnar Store Management API

### Store Lifecycle

| Function | Signature | Purpose |
|----------|-----------|---------|
| `ragnar_store_create()` | `ragnar_store_create(location, embed, version = 2, overwrite = FALSE, extra_cols = NULL, ...)` | Create new store with embedding function |
| `ragnar_store_connect()` | `ragnar_store_connect(location, read_only = TRUE)` | Connect to existing store (retrieval only) |
| `ragnar_store_insert()` | `ragnar_store_insert(store, chunks)` | Insert chunks (version 2: MarkdownDocumentChunks; version 1: data.frame with origin/hash/text) |
| `ragnar_store_build_index()` | `ragnar_store_build_index(store, type = c("vss", "fts"))` | Build search index (required before retrieval) |
| `ragnar_retrieve()` | `ragnar_retrieve(store, text, top_k = 3L, deoverlap = TRUE)` | Hybrid VSS + BM25 search |

### Store Deletion

**No dedicated deletion function.** To delete a ragnar store:

1. Close DuckDB connection: `DBI::dbDisconnect(store@con, shutdown = TRUE)`
2. Delete store file: `unlink(store_path)`
3. Remove notebook metadata linking to deleted store

Ragnar stores are self-contained DuckDB files. Deletion is a file system operation.

### Version Differences

**Version 2 (Recommended for new stores):**
- Stores full documents with chunk ranges
- Supports overlapping chunks with de-overlapping at retrieval
- Input: `MarkdownDocumentChunks` from `markdown_chunk()`
- Use `markdown_chunk(MarkdownDocument(...))` to prepare chunks
- Ragnar handles hashing internally

**Version 1 (Legacy, used in current implementation):**
- Stores flat chunks with user-provided hashes
- Input: data.frame with `origin`, `hash`, `text` columns
- User must provide `digest::digest()` hash for each chunk
- No de-overlapping support

**Migration path:** Continue using version 1 for existing shared store, use version 2 for new per-notebook stores.

## DuckDB VSS Extension

### Automatic Loading

Ragnar automatically loads the DuckDB VSS extension when:
- `ragnar_store_create()` is called with non-NULL `embed` parameter
- `ragnar_store_build_index(store, type = "vss")` is called

Verified via test: ragnar loads `vss` extension automatically alongside `core_functions` and `parquet`.

### Extension Details

- Extension name: `vss` (Vector Similarity Search)
- Index type: HNSW (Hierarchical Navigable Small Worlds)
- Distance metrics: array_distance, array_cosine_distance, array_negative_inner_product
- Status: Experimental (not production-ready according to DuckDB docs)
- Limitation: Index must fit in RAM (persisted to disk-backed database file)
- Installation: Automatic via ragnar (no manual INSTALL/LOAD required)

**No manual extension management needed.** Ragnar handles VSS extension lifecycle transparently.

## Installation

```r
# Core (already installed via renv)
install.packages("ragnar")  # Version 0.3.0
install.packages("duckdb")  # Version 1.3.2 (via ragnar dependency)

# Currently used (can be removed for version 2 stores)
install.packages("digest")  # Version 0.6.37 (only needed for version 1 hash generation)

# Already available
# DBI, uuid, jsonlite (existing dependencies)
```

## Migration Strategy

### Current State (Phase 1-4)
- Single shared ragnar store: `data/serapeum.ragnar.duckdb`
- Version 1 store format
- Uses `digest::digest()` for chunk hashing
- Chunks from all notebooks in one store

### Target State (This Milestone)
- Per-notebook stores: `data/ragnar/notebook-{id}.duckdb`
- Version 2 store format (for new stores)
- Ragnar handles hashing internally
- Isolated stores enable notebook deletion without affecting others

### Breaking Changes
- **digest dependency:** Can be removed once all stores migrate to version 2
- **Legacy embedding fallback:** Remove `search_chunks()` and cosine similarity functions from `db.R`
- **Store path convention:** Migrate from single `ragnar_store_path` to per-notebook path generation

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| ragnar 0.3.0 | DuckDB 1.3.2 | Ragnar depends on DuckDB, version pinned via renv |
| ragnar 0.3.0 | R >= 4.3.0 | Minimum R version per ragnar DESCRIPTION |
| VSS extension | DuckDB 1.3.2+ | Loaded automatically by ragnar, no version conflicts |
| digest 0.6.37 | All R versions | Only needed for version 1 stores; version 2 uses `rlang::hash()` |

## Per-Notebook Store Implementation

### Store Path Convention

```r
# Recommended pattern
get_notebook_ragnar_store_path <- function(notebook_id) {
  sprintf("data/ragnar/notebook-%s.duckdb", notebook_id)
}
```

### Store Creation (Version 2)

```r
# Create store for new notebook
store <- ragnar_store_create(
  location = get_notebook_ragnar_store_path(notebook_id),
  embed = embed_via_openrouter,  # Custom OpenRouter embed function
  version = 2,  # Use version 2 for new stores
  overwrite = FALSE
)

# Prepare chunks
doc <- MarkdownDocument(text, origin = sprintf("%s#page=%d", filename, page))
chunks <- markdown_chunk(doc, target_size = 1600, target_overlap = 0.5)

# Insert and build index
ragnar_store_insert(store, chunks)
ragnar_store_build_index(store, type = "vss")
ragnar_store_build_index(store, type = "fts")
```

### Store Retrieval

```r
# Connect to existing store (read-only)
store <- ragnar_store_connect(get_notebook_ragnar_store_path(notebook_id))

if (!is.null(store)) {
  results <- ragnar_retrieve(store, query, top_k = 5, deoverlap = TRUE)
  # results: data.frame with text, origin, score columns
}
```

### Store Deletion

```r
# When deleting a notebook
delete_notebook_ragnar_store <- function(notebook_id) {
  store_path <- get_notebook_ragnar_store_path(notebook_id)

  if (file.exists(store_path)) {
    # Connect to close cleanly
    store <- tryCatch({
      ragnar_store_connect(store_path)
    }, error = function(e) NULL)

    if (!is.null(store)) {
      DBI::dbDisconnect(store@con, shutdown = TRUE)
    }

    # Delete file
    unlink(store_path)
  }
}
```

## Metadata Schema Extension

Add notebook-to-store mapping in `notebooks` table:

```sql
ALTER TABLE notebooks ADD COLUMN ragnar_store_path VARCHAR;
```

Store path: `data/ragnar/notebook-{id}.duckdb`

On notebook creation:
```r
ragnar_store_path <- get_notebook_ragnar_store_path(notebook_id)
dbExecute(con, "UPDATE notebooks SET ragnar_store_path = ? WHERE id = ?",
          list(ragnar_store_path, notebook_id))
```

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Manual VSS extension loading | Ragnar handles this automatically; manual loading causes conflicts | Let ragnar load VSS via `ragnar_store_create()` |
| Version 1 stores for new notebooks | Doesn't support de-overlapping, requires manual hashing | Version 2 stores with `markdown_chunk()` |
| Single shared store | Prevents notebook isolation, deletion requires complex cleanup | Per-notebook stores in `data/ragnar/` directory |
| Legacy `search_chunks()` with cosine similarity | Inferior to hybrid VSS + BM25, requires pre-computed embeddings | `ragnar_retrieve()` with hybrid search |
| `digest::digest()` for version 2 stores | Version 2 uses `rlang::hash()` internally | Let ragnar handle hashing |

## Ragnar Store Internals

### Tables (Version 2)

Verified via inspection of ragnar store:
- `documents` - Full document storage
- `chunks` - Chunk ranges referencing documents
- `embeddings` - Vector embeddings for VSS
- `metadata` - Store configuration and embed function

Access via `DBI::dbListTables(store@con)` and `DBI::dbGetQuery(store@con, "SELECT ...")`.

### Store Object Structure

```r
# RagnarStore S4 object (class: DuckDBRagnarStore)
store@location    # File path
store@embed       # Embedding function (or NULL)
store@schema      # Extra columns schema
store@name        # Store name
store@title       # Store title
store@con         # DuckDB connection
store@version     # Store version (1 or 2)
```

## Sources

- ragnar 0.3.0 package documentation (via `help()`) - HIGH confidence
- DuckDB 1.3.2 renv.lock entry - HIGH confidence
- [DuckDB VSS Extension Docs](https://duckdb.org/docs/stable/core_extensions/vss) - MEDIUM confidence (WebFetch failed, used WebSearch)
- [ragnar tidyverse.org](https://ragnar.tidyverse.org/) - MEDIUM confidence (current version confirmed)
- Existing codebase: `R/_ragnar.R`, `R/db.R` - HIGH confidence (implementation verified)
- Live testing of ragnar store creation and VSS extension loading - HIGH confidence

---
*Stack research for: ragnar RAG overhaul (per-notebook stores)*
*Researched: 2026-02-16*
