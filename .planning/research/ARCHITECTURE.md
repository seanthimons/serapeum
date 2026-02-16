# Architecture Research: Per-Notebook Ragnar Stores

**Domain:** RAG (Retrieval-Augmented Generation) backend migration
**Researched:** 2026-02-16
**Confidence:** HIGH

## Current Architecture (Shared Store)

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Shiny Module Layer                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐           ┌──────────────────┐            │
│  │ mod_document_    │           │ mod_search_      │            │
│  │ notebook.R       │           │ notebook.R       │            │
│  │                  │           │                  │            │
│  │ - PDF upload     │           │ - Abstract embed │            │
│  │ - Ragnar index   │           │ - Ragnar index   │            │
│  └────────┬─────────┘           └─────────┬────────┘            │
├───────────┴───────────────────────────────┴──────────────────────┤
│                   Business Logic Layer                           │
├─────────────────────────────────────────────────────────────────┤
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────┐    │
│  │ R/pdf.R    │  │ R/rag.R    │  │ R/db.R     │  │ R/     │    │
│  │            │  │            │  │            │  │_ragnar.│    │
│  │ - process_ │  │ - rag_     │  │ - search_  │  │   R    │    │
│  │   pdf()    │  │   query()  │  │   chunks_  │  │        │    │
│  │ - detect_  │  │ - generate_│  │   hybrid() │  │ - get_ │    │
│  │   section_ │  │   preset() │  │            │  │   ragnar│    │
│  │   hint()   │  │            │  │            │  │   _store│    │
│  └──────┬─────┘  └──────┬─────┘  └──────┬─────┘  └────┬───┘    │
│         │                │                │             │        │
├─────────┴────────────────┴────────────────┴─────────────┴────────┤
│                      Data Storage Layer                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────┐   ┌─────────────────────────────┐  │
│  │ data/notebooks.duckdb   │   │ data/serapeum.ragnar.duckdb │  │
│  │                         │   │                             │  │
│  │ - notebooks table       │   │ SHARED ACROSS ALL           │  │
│  │ - documents table       │   │ NOTEBOOKS (current state)   │  │
│  │ - abstracts table       │   │                             │  │
│  │ - chunks table          │   │ - VSS + BM25 index          │  │
│  │   (with section_hint)   │   │ - Embedded chunks           │  │
│  └─────────────────────────┘   └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Current Store Lifecycle

**Creation:**
- `get_ragnar_store()` called in `mod_document_notebook.R` (line 246)
- `get_ragnar_store()` called in `mod_search_notebook.R` (line 1718)
- Path: `data/serapeum.ragnar.duckdb` (hardcoded, shared)

**Indexing:**
- Documents: `insert_chunks_to_ragnar(store, chunks, doc_id, "document")` (mod_document_notebook.R:251)
- Abstracts: `insert_chunks_to_ragnar(store, chunks, abstract_id, "abstract")` (mod_search_notebook.R:1732)
- Index built after insert: `build_ragnar_index(store)`

**Retrieval:**
- `search_chunks_hybrid()` in `R/db.R` (line 832)
- Calls `retrieve_with_ragnar(store, query, top_k)`
- Results filtered by notebook_id via metadata lookup (db.R:848-875)

**Deletion:**
- No ragnar-specific cleanup when notebooks deleted
- Orphaned chunks remain in shared store

### Current Problems

1. **Orphan accumulation:** Deleted notebooks leave chunks in shared store
2. **No isolation:** All notebooks share same index (potential cross-contamination)
3. **Brittle filtering:** Notebook scoping done via post-retrieval filtering (db.R:860-874)
4. **Metadata loss:** `section_hint` requires DB lookup after ragnar retrieval (db.R:892-914)
5. **Dual paths:** Legacy fallback complicates codebase (pdf.R:263-299, rag.R:94-121, db.R:964-982)

## Recommended Architecture (Per-Notebook Stores)

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Shiny Module Layer                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐           ┌──────────────────┐            │
│  │ mod_document_    │           │ mod_search_      │            │
│  │ notebook.R       │           │ notebook.R       │            │
│  │                  │           │                  │            │
│  │ - PDF upload     │           │ - Abstract embed │            │
│  │ - Ragnar index   │           │ - Ragnar index   │            │
│  │   (notebook-     │           │   (notebook-     │            │
│  │    scoped)       │           │    scoped)       │            │
│  └────────┬─────────┘           └─────────┬────────┘            │
├───────────┴───────────────────────────────┴──────────────────────┤
│                   Business Logic Layer                           │
├─────────────────────────────────────────────────────────────────┤
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────┐    │
│  │ R/pdf.R    │  │ R/rag.R    │  │ R/db.R     │  │ R/     │    │
│  │            │  │            │  │            │  │_ragnar.│    │
│  │ - process_ │  │ - rag_     │  │ - REMOVED: │  │   R    │    │
│  │   pdf()    │  │   query()  │  │   search_  │  │        │    │
│  │ - detect_  │  │ - REMOVED: │  │   chunks   │  │ - get_ │    │
│  │   section_ │  │   legacy   │  │   (legacy) │  │   ragnar│    │
│  │   hint()   │  │   fallback │  │            │  │   _store│    │
│  │            │  │            │  │ - ADDED:   │  │   (per- │    │
│  │            │  │            │  │   delete_  │  │   notebook)│  │
│  │            │  │            │  │   ragnar_  │  │        │    │
│  │            │  │            │  │   store()  │  │        │    │
│  └──────┬─────┘  └──────┬─────┘  └──────┬─────┘  └────┬───┘    │
│         │                │                │             │        │
├─────────┴────────────────┴────────────────┴─────────────┴────────┤
│                      Data Storage Layer                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────┐   ┌─────────────────────────────┐  │
│  │ data/notebooks.duckdb   │   │ data/ragnar/                │  │
│  │                         │   │                             │  │
│  │ - notebooks table       │   │ {notebook_id}.duckdb        │  │
│  │ - documents table       │   │ {notebook_id}.duckdb        │  │
│  │ - abstracts table       │   │ {notebook_id}.duckdb        │  │
│  │ - REMOVED: chunks table │   │ ...                         │  │
│  │   (ragnar owns chunks)  │   │                             │  │
│  │                         │   │ ONE STORE PER NOTEBOOK      │  │
│  │                         │   │ - Automatic scoping         │  │
│  │                         │   │ - Clean deletion            │  │
│  └─────────────────────────┘   └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Current Responsibility | New Responsibility |
|-----------|------------------------|---------------------|
| **mod_document_notebook.R** | Upload PDF → chunk → insert to shared ragnar | Upload PDF → chunk → insert to **notebook-scoped** ragnar |
| **mod_search_notebook.R** | Embed abstract → insert to shared ragnar | Embed abstract → insert to **notebook-scoped** ragnar |
| **R/_ragnar.R** | Manage shared store lifecycle | Manage **per-notebook** store lifecycle, add `delete_ragnar_store()` |
| **R/db.R** | Filter ragnar results by notebook, manage legacy chunks table | **Remove filtering logic**, **remove legacy chunks CRUD** |
| **R/rag.R** | Dual retrieval path (ragnar-first, legacy fallback) | **Ragnar-only retrieval**, no fallback |
| **R/pdf.R** | Dual embedding path (ragnar-first, legacy fallback) | **Ragnar-only embedding**, no fallback |
| **app.R** | Notebook CRUD (create, delete), no ragnar cleanup | Notebook CRUD + **ragnar store cleanup on delete** |

## Recommended Project Structure

### File Layout

```
data/
├── notebooks.duckdb              # Metadata only (notebooks, documents, abstracts)
└── ragnar/                       # NEW: Per-notebook stores directory
    ├── {notebook_id_1}.duckdb    # Store for notebook 1
    ├── {notebook_id_2}.duckdb    # Store for notebook 2
    └── {notebook_id_n}.duckdb    # Store for notebook n
```

### Structure Rationale

- **`data/ragnar/`:** Isolates ragnar stores from metadata DB, enables clean batch operations (e.g., delete all orphans)
- **`{notebook_id}.duckdb`:** 1:1 mapping between notebook and store, automatic scoping, no filtering needed
- **No chunks table in `notebooks.duckdb`:** Ragnar owns chunk storage, eliminating dual persistence

## Architectural Patterns

### Pattern 1: Store Path Construction

**What:** Deterministic path generation from notebook ID

**When to use:** Whenever accessing a notebook's ragnar store

**Implementation:**
```r
# R/_ragnar.R
get_notebook_ragnar_path <- function(notebook_id, base_dir = "data/ragnar") {
  file.path(base_dir, paste0(notebook_id, ".duckdb"))
}
```

**Trade-offs:**
- ✅ Predictable, no need to store path in DB
- ✅ Easy to discover/clean orphans
- ⚠️ Notebook ID must be filesystem-safe (UUID format is safe)

### Pattern 2: Store Lifecycle Binding

**What:** Tie ragnar store CRUD to notebook CRUD

**When to use:** Notebook create/delete operations

**Implementation:**
```r
# app.R (notebook creation)
create_notebook <- function(con, name, type, ...) {
  id <- uuid::UUIDgenerate()

  # Create DB record
  dbExecute(con, "INSERT INTO notebooks (...) VALUES (?)", list(id, ...))

  # Create ragnar store (if ragnar available)
  if (ragnar_available()) {
    store_path <- get_notebook_ragnar_path(id)
    tryCatch({
      store <- get_ragnar_store(store_path, api_key, embed_model)
    }, error = function(e) {
      message("Warning: Ragnar store creation failed: ", e$message)
    })
  }

  id
}

# app.R (notebook deletion)
delete_notebook <- function(con, id) {
  # Delete DB records (documents, abstracts)
  dbExecute(con, "DELETE FROM documents WHERE notebook_id = ?", list(id))
  dbExecute(con, "DELETE FROM abstracts WHERE notebook_id = ?", list(id))
  dbExecute(con, "DELETE FROM notebooks WHERE id = ?", list(id))

  # Delete ragnar store
  delete_ragnar_store(id)
}

# R/_ragnar.R (NEW function)
delete_ragnar_store <- function(notebook_id, base_dir = "data/ragnar") {
  store_path <- get_notebook_ragnar_path(notebook_id, base_dir)
  if (file.exists(store_path)) {
    unlink(store_path)
    message("Deleted ragnar store: ", store_path)
  }
}
```

**Trade-offs:**
- ✅ No orphans, automatic cleanup
- ✅ Clear ownership model
- ⚠️ Store creation requires API key (need to handle missing key gracefully)

### Pattern 3: Section Hint Metadata Encoding

**What:** Encode `section_hint` in ragnar's `origin` field instead of separate DB lookup

**When to use:** When inserting chunks to ragnar

**Current (lossy):**
```r
# R/_ragnar.R (insert_chunks_to_ragnar)
ragnar_chunks <- data.frame(
  origin = chunks$origin,  # "filename#page=N"
  hash = ...,
  text = chunks$content
)

# Metadata stored as R attribute (doesn't persist!)
attr(ragnar_chunks, "serapeum_metadata") <- list(
  section_hint = chunks$section_hint  # LOST after insert
)
```

**New (preserved):**
```r
# R/_ragnar.R (insert_chunks_to_ragnar)
ragnar_chunks <- data.frame(
  origin = paste0(chunks$origin, "|section=", chunks$section_hint),  # Encode in origin
  hash = ...,
  text = chunks$content
)

# R/_ragnar.R (retrieve_with_ragnar - parsing)
results$section_hint <- vapply(results$origin, function(o) {
  match <- regmatches(o, regexec("\\|section=([^|]+)", o))[[1]]
  if (length(match) >= 2) match[2] else "general"
}, character(1))
```

**Trade-offs:**
- ✅ No DB lookup required, metadata co-located with chunk
- ✅ Survives ragnar persistence
- ⚠️ Origin field grows slightly (acceptable: `|section=conclusion` is ~20 chars)

### Pattern 4: Ragnar-Only Retrieval (Remove Fallback)

**What:** Simplify retrieval by removing legacy cosine similarity path

**When to use:** After migration completes

**Current (dual path):**
```r
# R/rag.R (rag_query)
chunks <- NULL

# Try ragnar first
if (use_ragnar && ragnar_available()) {
  chunks <- search_chunks_hybrid(con, query, notebook_id)
}

# Fallback to legacy
if (is.null(chunks) || nrow(chunks) == 0) {
  question_embedding <- get_embeddings(...)  # Extra API call
  chunks <- search_chunks(con, question_embedding, notebook_id)  # Legacy
}
```

**New (ragnar-only):**
```r
# R/rag.R (rag_query)
if (!ragnar_available()) {
  stop("Ragnar is required. Install with: install.packages('ragnar')")
}

store_path <- get_notebook_ragnar_path(notebook_id)
if (!file.exists(store_path)) {
  return("No indexed content found in this notebook.")
}

store <- connect_ragnar_store(store_path)
chunks <- retrieve_with_ragnar(store, query, top_k = limit)
```

**Trade-offs:**
- ✅ Simpler code, no branching
- ✅ No redundant API calls
- ✅ No dual persistence maintenance
- ⚠️ Hard dependency on ragnar (acceptable: it's a design goal)

## Data Flow Changes

### Current Flow: Document Upload → Retrieval

```
User uploads PDF (mod_document_notebook.R)
    ↓
process_pdf() → chunks with section_hint (R/pdf.R)
    ↓
create_chunk() → INSERT INTO chunks table (R/db.R) [DUAL PERSISTENCE]
    ↓
insert_chunks_to_ragnar() → INSERT INTO shared store (R/_ragnar.R)
    ↓
User asks question (mod_document_notebook.R)
    ↓
search_chunks_hybrid() → retrieve from shared store (R/db.R)
    ↓
Filter by notebook_id (db.R:860-874) [POST-RETRIEVAL FILTERING]
    ↓
Lookup section_hint from chunks table (db.R:892-914) [METADATA LOOKUP]
    ↓
Return results
```

### New Flow: Document Upload → Retrieval

```
User uploads PDF (mod_document_notebook.R)
    ↓
process_pdf() → chunks with section_hint (R/pdf.R)
    ↓
get_notebook_ragnar_path(notebook_id) → "data/ragnar/{notebook_id}.duckdb"
    ↓
insert_chunks_to_ragnar() → INSERT INTO notebook-scoped store (R/_ragnar.R)
    (with section_hint encoded in origin field)
    ↓
User asks question (mod_document_notebook.R)
    ↓
connect_ragnar_store(notebook_ragnar_path) → notebook-scoped store
    ↓
retrieve_with_ragnar() → retrieve (already scoped, no filtering needed)
    ↓
Parse section_hint from origin field (R/_ragnar.R:retrieve_with_ragnar)
    ↓
Return results
```

### State Management Changes

**Removed:**
- Legacy chunks table state (embedding column, chunk content duplication)
- search_chunks() and search_chunks_hybrid() filtering logic
- Dual embedding path in pdf.R and mod_document_notebook.R

**Added:**
- Per-notebook ragnar store paths (deterministic, no state to manage)
- delete_ragnar_store() cleanup in notebook deletion path
- Section hint encoding/decoding in ragnar origin field

## Integration Points

### New Components

| Component | Purpose | Integration Pattern |
|-----------|---------|---------------------|
| **get_notebook_ragnar_path()** | Path construction | Called before every ragnar operation (insert, retrieve, delete) |
| **delete_ragnar_store()** | Cleanup | Called in `delete_notebook()` (app.R) |
| **Section hint encoding** | Metadata preservation | Encode in `insert_chunks_to_ragnar()`, decode in `retrieve_with_ragnar()` |

### Modified Components

| Component | Changes | Integration Impact |
|-----------|---------|---------------------|
| **R/_ragnar.R** | Add path helpers, metadata encoding, delete function | All modules now pass `notebook_id` to get store path |
| **R/db.R** | Remove `chunks` table CRUD, remove `search_chunks_hybrid()` filtering | Modules call ragnar directly instead of db.R wrapper |
| **R/rag.R** | Remove legacy fallback, require ragnar | Fails fast if ragnar not available |
| **R/pdf.R** | Remove legacy embedding path | Only ragnar indexing path remains |
| **mod_document_notebook.R** | Use notebook-scoped store path | Pass `notebook_id` to ragnar functions |
| **mod_search_notebook.R** | Use notebook-scoped store path | Pass `notebook_id` to ragnar functions |
| **app.R** | Add ragnar cleanup to `delete_notebook()` | Lifecycle binding |

### Build Order (Dependency-Aware)

**Phase 1: Foundation (No Breaking Changes)**
1. Add `get_notebook_ragnar_path()` to R/_ragnar.R
2. Add `delete_ragnar_store()` to R/_ragnar.R
3. Update `insert_chunks_to_ragnar()` to encode section_hint in origin
4. Update `retrieve_with_ragnar()` to decode section_hint from origin

**Phase 2: Module Updates (Parallel-Safe)**
5. Update `mod_document_notebook.R` to use notebook-scoped paths
6. Update `mod_search_notebook.R` to use notebook-scoped paths
7. Update `app.R` to call `delete_ragnar_store()` in notebook deletion

**Phase 3: Simplification (Breaking Changes)**
8. Remove legacy embedding path from `R/pdf.R` (lines 263-299)
9. Remove legacy retrieval fallback from `R/rag.R` (lines 94-121)
10. Remove `search_chunks_hybrid()` filtering logic from `R/db.R` (lines 848-875)
11. Mark `chunks` table as deprecated (migration: copy existing chunks to per-notebook stores)

**Phase 4: Cleanup**
12. Drop `chunks` table from schema (after migration)
13. Delete shared `data/serapeum.ragnar.duckdb`

## Migration Strategy

### Data Migration (Existing Chunks → Per-Notebook Stores)

```r
# Migration script
migrate_to_per_notebook_stores <- function(con, api_key, embed_model) {
  # Get all notebooks
  notebooks <- dbGetQuery(con, "SELECT id FROM notebooks")

  for (nb_id in notebooks$id) {
    message("Migrating notebook: ", nb_id)

    # Create notebook-scoped store
    store_path <- get_notebook_ragnar_path(nb_id)
    store <- get_ragnar_store(store_path, api_key, embed_model)

    # Get chunks for this notebook (documents)
    doc_chunks <- dbGetQuery(con, "
      SELECT c.*, d.filename
      FROM chunks c
      JOIN documents d ON c.source_id = d.id
      WHERE d.notebook_id = ? AND c.source_type = 'document'
    ", list(nb_id))

    if (nrow(doc_chunks) > 0) {
      # Convert to ragnar format
      ragnar_chunks <- data.frame(
        origin = paste0(doc_chunks$filename, "#page=", doc_chunks$page_number,
                       "|section=", doc_chunks$section_hint %||% "general"),
        hash = vapply(seq_len(nrow(doc_chunks)), function(i) {
          digest::digest(paste(doc_chunks$content[i], doc_chunks$page_number[i], sep = "|"))
        }, character(1)),
        text = doc_chunks$content,
        stringsAsFactors = FALSE
      )

      ragnar::ragnar_store_insert(store, ragnar_chunks)
    }

    # Get chunks for this notebook (abstracts)
    abs_chunks <- dbGetQuery(con, "
      SELECT c.*, a.title
      FROM chunks c
      JOIN abstracts a ON c.source_id = a.id
      WHERE a.notebook_id = ? AND c.source_type = 'abstract'
    ", list(nb_id))

    if (nrow(abs_chunks) > 0) {
      ragnar_chunks <- data.frame(
        origin = paste0("abstract:", abs_chunks$source_id, "|section=general"),
        hash = vapply(seq_len(nrow(abs_chunks)), function(i) {
          digest::digest(abs_chunks$content[i])
        }, character(1)),
        text = abs_chunks$content,
        stringsAsFactors = FALSE
      )

      ragnar::ragnar_store_insert(store, ragnar_chunks)
    }

    # Build index
    ragnar::ragnar_store_build_index(store)
    message("Migrated ", nrow(doc_chunks) + nrow(abs_chunks), " chunks")
  }
}
```

### Rollback Strategy

- Keep `chunks` table until migration verified
- Store migration timestamp in settings table
- Provide rollback script that restores from chunks table

## Anti-Patterns to Avoid

### Anti-Pattern 1: Global Store Fallback

**What people might do:** Keep shared store as fallback when per-notebook store fails

**Why it's wrong:**
- Defeats isolation purpose
- Complicates retrieval (which store to query?)
- Perpetuates orphan accumulation problem

**Do this instead:**
- Fail fast with clear error message
- Require ragnar store creation during notebook creation
- Log failures to help debug API key issues

### Anti-Pattern 2: Store Path in Database

**What people might do:** Add `ragnar_store_path` column to notebooks table

**Why it's wrong:**
- Redundant (path is deterministic from notebook_id)
- Risk of path drift (DB says one path, filesystem has another)
- Adds unnecessary state

**Do this instead:**
- Use deterministic path construction
- Treat store path as derived value, not stored state

### Anti-Pattern 3: Partial Migration

**What people might do:** Support both old chunks table AND new ragnar stores

**Why it's wrong:**
- Dual maintenance burden
- Ambiguous source of truth
- Query path branching complexity

**Do this instead:**
- Complete migration in one milestone
- Deprecate chunks table immediately after migration
- Remove legacy code once migration verified

## Scaling Considerations

| Scale | Approach |
|-------|----------|
| **1-10 notebooks** | Current approach works (negligible overhead per store) |
| **10-100 notebooks** | Per-notebook stores remain performant (DuckDB handles 100 files easily) |
| **100+ notebooks** | Consider store pooling (multiple notebooks per store) or periodic compaction |

### Scaling Priorities

1. **Disk space:** Per-notebook stores use more inodes, but DuckDB compression keeps size reasonable
2. **Index build time:** Building index per-notebook is slower than shared, but parallelizable during migration
3. **Open file handles:** DuckDB uses memory-mapped files, may hit OS limits with many concurrent stores (mitigate with connection pooling)

## Section Hint Handling

### Current State (Lossy)

**Problem:** `section_hint` column exists in chunks table, but ragnar doesn't preserve it

**Evidence:**
- `detect_section_hint()` in R/pdf.R (lines 70-112) generates hints
- `create_chunk()` stores hint in chunks.section_hint (db.R:357-369)
- `insert_chunks_to_ragnar()` tries to preserve via R attributes (DOESN'T PERSIST)
- `search_chunks_hybrid()` has to look up section_hint from chunks table after retrieval (db.R:892-914)

### New State (Preserved)

**Solution:** Encode in ragnar's `origin` field

**Format:**
```
Documents:   "{filename}#page={N}|section={hint}"
Abstracts:   "abstract:{id}|section={hint}"
```

**Example:**
```
"paper.pdf#page=23|section=conclusion"
"abstract:abc-123|section=general"
```

**Parsing:**
```r
# R/_ragnar.R (retrieve_with_ragnar)
results$section_hint <- vapply(results$origin, function(o) {
  match <- regmatches(o, regexec("\\|section=([^|]+)", o))[[1]]
  if (length(match) >= 2) match[2] else "general"
}, character(1))
```

**Filtering by section:**
```r
# R/rag.R (generate_conclusions_preset)
chunks <- retrieve_with_ragnar(store, query, top_k = 20)

# Filter to conclusion-related sections
target_sections <- c("conclusion", "limitations", "future_work", "discussion", "late_section")
chunks <- chunks[chunks$section_hint %in% target_sections, ]
```

## Summary of Changes

### Files to Modify

| File | Changes | Lines Affected |
|------|---------|----------------|
| **R/_ragnar.R** | Add path helpers, delete function, metadata encoding | +60 lines, modify insert/retrieve |
| **R/db.R** | Remove search_chunks_hybrid filtering, mark chunks table deprecated | -150 lines (filtering logic) |
| **R/rag.R** | Remove legacy fallback | -30 lines |
| **R/pdf.R** | Remove legacy embedding | -40 lines |
| **mod_document_notebook.R** | Use notebook-scoped paths | ~10 lines modified |
| **mod_search_notebook.R** | Use notebook-scoped paths | ~10 lines modified |
| **app.R** | Add ragnar cleanup to delete_notebook | +5 lines |

### New Functions

- `get_notebook_ragnar_path(notebook_id, base_dir = "data/ragnar")`
- `delete_ragnar_store(notebook_id, base_dir = "data/ragnar")`

### Removed Functions

- None (existing functions simplified, not removed)

### Database Schema Changes

- `chunks` table: Mark as deprecated (eventual removal after migration)
- No new tables (ragnar owns chunk storage)

## Build Order Rationale

**Why Phase 1 first:**
- Path helpers have no dependencies, can be tested independently
- Metadata encoding is backward-compatible (old code ignores extra origin data)

**Why Phase 2 parallelizable:**
- Module updates are independent (document vs search notebooks)
- Each module only touches its own ragnar interaction points

**Why Phase 3 requires Phase 2 complete:**
- Removing fallback code breaks modules that haven't migrated to scoped paths
- Filtering removal requires all retrieval to use scoped stores

**Why Phase 4 last:**
- Need to verify migration before dropping chunks table
- Shared store deletion is final, irreversible

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| **Path construction** | HIGH | Deterministic, filesystem-safe (UUID format) |
| **Lifecycle binding** | HIGH | Clear ownership model, matches Shiny patterns |
| **Section hint encoding** | HIGH | Ragnar's origin field is designed for metadata |
| **Simplification benefits** | HIGH | Removes 220+ lines of fallback code |
| **Migration risk** | MEDIUM | Depends on API key availability during migration |
| **Performance impact** | HIGH | Per-notebook isolation improves retrieval (no filtering overhead) |

## Sources

- Ragnar package documentation (package vignette, function signatures)
- Serapeum codebase analysis (R/_ragnar.R, R/db.R, R/rag.R, R/pdf.R, mod_*.R)
- DuckDB file handling patterns (connection pooling, memory-mapped files)
- Existing architecture documentation (.planning/codebase/ARCHITECTURE.md)

---
*Architecture research for: Ragnar RAG Overhaul*
*Researched: 2026-02-16*
