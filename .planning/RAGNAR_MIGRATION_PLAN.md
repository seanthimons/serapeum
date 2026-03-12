# Ragnar Migration Plan

## Goal
Integrate ragnar's improved chunking and VSS-powered retrieval while preserving the existing schema for notebooks, documents, and abstracts.

## Architecture Decision: Hybrid Approach

**Keep existing DuckDB** for:
- `notebooks` table (unchanged)
- `documents` table (unchanged)
- `abstracts` table (unchanged)
- `settings` table (unchanged)

**Use ragnar** for:
- Semantic chunking via `markdown_chunk()`
- Embeddings via `embed_openai()` (or keep OpenRouter)
- VSS + BM25 retrieval via `ragnar_retrieve()`

**Two options for chunk storage:**

### Option A: Separate RagnarStore (Recommended)
- Keep `chunks` table in main DB for metadata/linking
- Create separate `serapeum.ragnar.duckdb` for embeddings + VSS
- Link via `chunk_id` or `source_id`
- Pros: Clean separation, ragnar handles VSS complexity
- Cons: Two database files, need to keep in sync

### Option B: Add VSS to Existing DuckDB
- Modify existing `chunks` table to use FLOAT[] for embeddings
- Manually install/load VSS extension
- Write custom VSS queries
- Pros: Single database file
- Cons: More manual work, may conflict with ragnar expectations

---

## Migration Steps

### Phase 1: Add ragnar dependency ✅ DONE
- [x] Add ragnar_available() checks throughout codebase
- [x] Graceful fallback when ragnar not installed
- [ ] Add ragnar to DESCRIPTION or install script (optional - works without)
- [ ] Verify VSS extension loads on target platforms (Windows/Mac/Linux)

### Phase 2: Improve chunking (R/pdf.R) ✅ DONE
- [x] Add `chunk_with_ragnar()` wrapper in R/ragnar_store.R
- [x] Keep pdftools for page-aware extraction (ragnar doesn't preserve page boundaries)
- [x] Preserve page number association via page-specific origins
- [x] Update `process_pdf()` with `use_ragnar` parameter and fallback
- [x] Return `chunking_method` in result for debugging

### Phase 3: Migrate embedding/retrieval (R/db.R, R/rag.R) ✅ DONE
- [x] Create `get_ragnar_store()` for store management
- [x] Add `search_chunks_hybrid()` using ragnar retrieval
- [x] Fallback to legacy `search_chunks()` when ragnar unavailable
- [x] Wire up PDF upload to insert into ragnar store (mod_document_notebook.R)
- [x] Wire up abstract save to insert into ragnar store (mod_search_notebook.R)
- [x] Build ragnar index after document/abstract upload

### Phase 4: Update RAG queries (R/rag.R) ✅ DONE
- [x] Update `rag_query()` to try ragnar first, fallback to legacy
- [x] No need to pre-embed query when using ragnar (handles internally)
- [x] Preserve source attribution (doc_name, page_number parsed from origin)
- [ ] Test hybrid VSS + BM25 retrieval quality (needs testing)

### Phase 5: Handle existing data migration (TODO)
- [ ] Write migration script for existing chunks
- [ ] Re-embed existing documents with new chunking
- [ ] Validate retrieval quality before/after

### Phase 6: Integration Testing (TODO)
- [ ] Test full workflow: upload PDF → chunk → embed → query
- [ ] Benchmark retrieval speed: ragnar vs legacy
- [ ] Compare answer quality with identical questions

---

## How to Test

### Prerequisites
```r
# Install ragnar (if not already installed)
install.packages("ragnar")

# Install digest (for hashing)
install.packages("digest")

# No separate OpenAI key needed - ragnar uses your existing OpenRouter API key!
```

### Test Steps

1. **Start the app** from the project directory:
   ```r
   # Navigate to the serapeum project directory
   shiny::runApp()
   ```

2. **Upload a PDF** to a document notebook:
   - Should see "Building search index" in progress
   - Check for `data/serapeum.ragnar.duckdb` file created

3. **Ask a question** in the chat:
   - Should use ragnar hybrid search if available
   - Check console for "Ragnar search" vs "legacy embedding search" messages

4. **Compare results** with main branch:
   - Open main in separate R session
   - Ask same question
   - Compare answer quality and speed

### Troubleshooting

- If ragnar isn't being used, check:
  - `ragnar_available()` returns TRUE
  - OpenRouter API key is configured in Settings
  - `data/serapeum.ragnar.duckdb` exists and has data

- View ragnar store contents:
  ```r
  store <- ragnar::ragnar_store_connect("data/serapeum.ragnar.duckdb")
  dplyr::tbl(store@con, "chunks")
  ```

---

## Key Code Changes

### R/pdf.R - Chunking

**Before:**
```r
chunk_text <- function(text, chunk_size = 500, overlap = 50) {
  words <- unlist(strsplit(text, "\\s+"))
  # ... word-count based splitting
}
```

**After:**
```r
chunk_document <- function(text, origin = NULL) {
  # Convert to markdown document
  md_doc <- ragnar::MarkdownDocument(text, origin = origin)

  # Semantic chunking with heading context
  chunks <- ragnar::markdown_chunk(md_doc)

  chunks
}
```

### R/db.R - Store Management

**Add:**
```r
#' Get or create RagnarStore for chunk embeddings
get_ragnar_store <- function(path = "data/serapeum.ragnar.duckdb") {
  if (file.exists(path)) {
    ragnar::ragnar_store_connect(path)
  } else {
    ragnar::ragnar_store_create(
      path,
      embed = \(x) ragnar::embed_openai(x, model = "text-embedding-3-small")
    )
  }
}
```

### R/rag.R - Retrieval

**Before:**
```r
# Embed query
question_embedding <- get_embeddings(api_key, embed_model, question)

# Search (R-side cosine similarity)
chunks <- search_chunks(con, question_embedding, notebook_id, limit = 5)
```

**After:**
```r
# Retrieve with VSS + BM25
store <- get_ragnar_store()
chunks <- ragnar::ragnar_retrieve(store, question, top_k = 5)

# Filter to notebook (may need custom metadata handling)
chunks <- filter_by_notebook(chunks, notebook_id)
```

---

## Open Questions

1. **Page number preservation**: ragnar's `markdown_chunk()` tracks heading context but not page numbers. Need custom metadata or post-processing.

2. **Notebook filtering**: RagnarStore doesn't know about our notebook concept. Options:
   - Store notebook_id in chunk metadata
   - Post-filter retrieval results
   - Maintain separate stores per notebook (not recommended)

3. **OpenRouter vs direct embedding**: ragnar has `embed_openai()` but not OpenRouter. Options:
   - Use OpenAI directly for embeddings (ragnar)
   - Keep OpenRouter for chat, use ragnar for embeddings
   - Write custom `embed_openrouter()` wrapper

4. **Existing data**: Users with existing notebooks need migration path. Options:
   - Auto-migrate on app startup
   - Manual migration command
   - Support both old and new retrieval during transition

---

## Testing Strategy

1. **Unit tests**: Update test-slides.R, add test-ragnar.R
2. **Integration test**: End-to-end PDF upload → RAG query
3. **Performance benchmark**: Compare retrieval speed old vs new
4. **Quality evaluation**: Compare answer quality with same questions

---

## Rollback Plan

If integration fails:
1. Git checkout main in original worktree
2. Delete ragnar worktree: `git worktree remove ../serapeum-ragnar-experiment`
3. Delete branch: `git branch -D feature/ragnar-integration`

All existing functionality preserved in main branch.
