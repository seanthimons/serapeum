# Codebase Concerns

**Analysis Date:** 2026-02-10

## Tech Debt

**Large Module: Search Notebook**
- Issue: `R/mod_search_notebook.R` is 1,760 lines - exceeds single responsibility principle
- Files: `R/mod_search_notebook.R`
- Impact: Difficult to maintain, test, and debug. Contains paper filtering, keyword extraction, embedding logic, chat, RAG, and quality filtering all in one module
- Fix approach: Split into logical sub-modules (papers, keywords, embedding, chat, quality) with clear interfaces

**Embedding Workflow Complexity**
- Issue: Embedding deferred to manual "Embed Papers" button - state management is complex across filtered views
- Files: `R/mod_search_notebook.R` (lines 392-1600), `R/_ragnar.R`
- Impact: Users may not realize papers aren't embedded; search/RAG may fail silently with poor results; ragnar integration adds fallback complexity
- Fix approach: Auto-embed during import or show clear blocking UI. Consolidate ragnar and legacy embedding into single coherent path

**Configuration Validation Gaps**
- Issue: API keys and embeddings can be accessed before validation; no type checking in config loading
- Files: `R/config.R`, `R/rag.R` (lines 62-76)
- Impact: Missing API keys produce cryptic error messages deep in RAG/chat flows instead of upfront
- Fix approach: Validate config on app startup; block features with missing required settings

**Database Migration Pattern**
- Issue: Ad-hoc ALTER TABLE statements in `init_schema()` with try-catch - no version tracking
- Files: `R/db.R` (lines 102-219)
- Impact: Difficult to track what migrations have run; potential for column duplication if schema logic changes; no rollback capability
- Fix approach: Implement migration versioning table (source, version, applied_at) with single-run guards

## Known Bugs

**Abstract Embedding Not Working (Issue #55)**
- Symptoms: Abstracts imported from OpenAlex don't embed when "Embed Papers" clicked; search finds no results for papers
- Files: `R/mod_search_notebook.R` (lines 1475-1600), `R/rag.R`
- Trigger: Import OpenAlex papers, click "Embed Papers" button - abstracts remain without embeddings
- Root cause: Embedding logic filters by `source_type = 'document'` only; abstracts have `source_type = 'abstract'` but are not processed
- Workaround: None - abstract search completely broken
- Priority: High - blocks search notebook core functionality

**Citation Metrics Null Handling**
- Symptoms: UI displays "NA" for papers with missing FWCI or citation counts
- Files: `R/api_openalex.R` (lines 102-145), `R/mod_search_notebook.R` (lines 196-230)
- Trigger: Import papers from OpenAlex with incomplete metrics data
- Root cause: FWCI returned as `NA` from API; no default fallback in parsing
- Impact: Confusing UX; metrics don't display cleanly
- Fix approach: Use 0 or default value for missing metrics; format display with conditional logic

**Quality Cache Download Race Condition**
- Symptoms: Multiple users/tabs can trigger simultaneous cache refresh; table conflicts
- Files: `R/quality_filter.R`, `R/db.R` (lines 848-957)
- Trigger: Click "Download quality data" in multiple windows simultaneously
- Root cause: No locking mechanism; `DELETE FROM predatory_publishers` followed by insert has gap
- Impact: Partial data load, corrupted quality filtering
- Fix approach: Use `ON CONFLICT DO UPDATE` pattern or transaction lock

## Security Considerations

**API Key Exposure in Config File**
- Risk: `config.yml` with OpenRouter/OpenAlex keys can be committed to git if .gitignore fails
- Files: `config.yml` (not shown but referenced in `config.example.yml`)
- Current mitigation: `.gitignore` should exclude `config.yml`; example file provided
- Recommendations:
  - Document in README that `config.yml` must never be committed
  - Add git hook to prevent commits with API key patterns
  - Consider environment variable support as alternative to file-based config

**PDF File Path Traversal Risk**
- Risk: PDF filenames stored in database without sanitization; could include `../` patterns
- Files: `R/pdf.R`, `R/mod_document_notebook.R` (line 121)
- Current mitigation: File stored in `.temp/pdfs/{notebook_id}/` sandbox
- Recommendations:
  - Validate filename contains no `..`, `./`, `/` characters before storing
  - Use UUID for internal storage instead of original filename
  - Display original filename separately from stored path

**OpenAlex Email Validation Weak**
- Risk: Email used for polite pool access; weak validation only checks format
- Files: `R/api_openalex.R` (lines 353-368)
- Current mitigation: Basic regex check for `@` symbol
- Recommendations:
  - Add DNS MX record verification on config save
  - Rate-limit API calls if invalid email detected
  - Log invalid email attempts

## Performance Bottlenecks

**Full Database Scans on Paper List Render**
- Problem: `filtered_papers()` reactive may query all abstracts from notebook without limiting
- Files: `R/mod_search_notebook.R` (lines ~300-350)
- Cause: Every paper list re-render queries database without pagination
- Impact: Slowdown with 1000+ papers; UI becomes unresponsive; memory spikes
- Improvement path: Implement pagination (show 50 at a time), lazy loading, indexed queries on (notebook_id, created_at)

**Cosine Similarity in R Loop**
- Problem: `search_chunks()` in `R/db.R` (lines 446-505) iterates through chunks in R instead of SQL
- Cause: DuckDB lacks native embedding similarity; fallback implementation loads all embeddings into memory
- Impact: >100 chunks = 10+ seconds; memory usage O(n); doesn't scale
- Improvement path:
  - Migrate to DuckDB native vector extension when available
  - Use ragnar/BM25 hybrid search (already available, see `search_chunks_hybrid()`)
  - Implement chunking by source to limit result sets

**Quality Filter Normalization Repeated**
- Problem: `normalize_name()` called on every paper check; no caching
- Files: `R/quality_filter.R` (lines 26-34), `R/mod_search_notebook.R` (lines ~500-600)
- Cause: Normalizing predatory journal names for comparison without memoization
- Impact: 1000 papers * 3 lookups = 3000 string operations per filter refresh
- Improvement path: Load normalized name sets into memory once on startup; use lookup set instead of function calls

**Full Abstract Text in Memory**
- Problem: `reconstruct_abstract()` and OpenAlex API return full inverted index; stored entirely in database
- Files: `R/api_openalex.R` (lines 25-54), `R/db.R` (line 56)
- Cause: Abstract text is large; stored without compression or chunking
- Impact: Large database file size; slow queries for papers with long abstracts
- Improvement path: Chunk abstracts at import time; store first 500 words as summary; full text in ragnar only

## Fragile Areas

**Ragnar Integration Fallback Chain**
- Files: `R/_ragnar.R`, `R/rag.R` (lines 80-112), `R/mod_search_notebook.R` (lines 1475-1600)
- Why fragile:
  - Ragnar available check happens in 3 different places
  - Falls back to legacy embedding search with incompatible column names
  - Legacy search requires pre-embedded query; ragnar doesn't - can cause failures when switching
  - Error messages don't distinguish which search method failed
- Safe modification: Create single `search_papers()` wrapper that:
  1. Tries ragnar if available and store exists
  2. Falls back to legacy embedding if ragnar fails
  3. Returns normalized result set with consistent columns
  4. Logs which method was used
- Test coverage: Add integration tests for both paths; mock ragnar availability

**JSON Serialization Round-Trip**
- Files: `R/db.R` (lines 234, 548-552, 639), `R/mod_search_notebook.R` (lines 675-678, 635-641)
- Why fragile:
  - Authors and keywords stored as JSON strings
  - Parsed with `fromJSON()` in UI with silent error handlers
  - If JSON invalid, silently returns empty list/character
  - No validation on insert; garbage data persists
- Safe modification:
  - Add `validate_json()` function before database insert
  - Store validation result in database
  - Log parse errors with context (which notebook, which field)
- Test coverage: Test with malformed JSON; verify error handling

**Page Number Context Loss**
- Files: `R/pdf.R`, `R/_ragnar.R` (lines 105-150), `R/mod_document_notebook.R`
- Why fragile:
  - Page numbers extracted from PDF correctly
  - Ragnar chunking preserves page via origin string (line 113: `#page=%d`)
  - But origin string parsed manually with `sub("^abstract:", "", ...)` (db.R line 736)
  - If parsing logic changes, citations break silently
- Safe modification:
  - Create `parse_origin()` function to extract {type, id, page} safely
  - Store page_number directly in chunks table instead of in origin string
  - Use this as single source of truth for citation formatting
- Test coverage: Test with multi-page documents; verify page numbers in citations

**Email Configuration for OpenAlex**
- Files: `R/config.R`, `R/api_openalex.R` (lines 11-23)
- Why fragile:
  - Email is optional but recommended (polite pool access)
  - If missing, API still works but rate-limited
  - No warning if missing; silent degradation
  - Email validated once at config load, then never checked again
- Safe modification:
  - Show warning banner if email not set
  - Add periodic validation (every 100 requests)
  - Collect email at first search if missing
  - Log when rate limiting detected

## Test Coverage Gaps

**Embedding Workflow**
- What's not tested: Abstract import + "Embed Papers" button + search retrieval end-to-end
- Files: `R/mod_search_notebook.R` (lines 1475-1600), `R/rag.R`, `R/_ragnar.R`
- Risk: Issue #55 not caught before production; critical feature completely broken
- Priority: High - add integration test: import papers → embed → search → verify results

**Quality Filter Updates**
- What's not tested: Cache refresh with dirty/stale data; partial failures
- Files: `R/quality_filter.R`, `R/db.R` (lines 845-957)
- Risk: Retracted papers not flagged if cache download fails mid-way; data corruption
- Priority: Medium - add test for: fetch failure → rollback, partial data → verification

**RAG Context Building with Mixed Sources**
- What's not tested: Chat with papers + documents mixed; null fields; missing source names
- Files: `R/rag.R` (lines 4-49), `R/mod_search_notebook.R` (lines ~1300-1400)
- Risk: Chat crashes with null pointer if abstract_title missing; context formatting broken
- Priority: Medium - add test for: mixed sources → formatted context → chat response

**PDF Text Extraction Fallback**
- What's not tested: Large PDFs; corrupted PDFs; PDFs with images only
- Files: `R/pdf.R` (lines 8-23), `R/mod_document_notebook.R` (document upload)
- Risk: Upload fails silently; user thinks upload succeeded but no content stored
- Priority: Low - add test for: edge case PDFs → error message → retry option

**Configuration Validation**
- What's not tested: Invalid config.yml syntax; missing required fields; type mismatches
- Files: `R/config.R`
- Risk: App starts but features silently fail when accessing unconfigured keys
- Priority: Medium - add test for: invalid config → app startup behavior → error messages

---

*Concerns audit: 2026-02-10*
