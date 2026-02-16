# Pitfalls Research: Ragnar RAG Overhaul

**Domain:** Migrating from legacy embedding system to ragnar-only in R/Shiny + DuckDB
**Researched:** 2026-02-16
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: DuckDB Connection Locking with Multiple Ragnar Stores

**What goes wrong:**
Multiple per-notebook ragnar stores open simultaneously cause DuckDB file locking errors. Each ragnar store internally opens a DuckDB connection. When the main application also has a DuckDB connection open (for `notebooks.duckdb`), and multiple ragnar stores are accessed (e.g., switching between notebooks), you hit DuckDB's single-writer limitation. Error manifests as "Database file is locked" or connection timeouts.

**Why it happens:**
DuckDB's concurrency model enforces single-writer access. One process can read/write OR multiple processes can read (with `access_mode = 'READ_ONLY'`), but no simultaneous read/write from multiple connections. Ragnar stores each have their own DuckDB file, but if you:
1. Open main DB (`notebooks.duckdb`) for read/write
2. Open ragnar store 1 (`notebook_A.ragnar.duckdb`) for read/write
3. Open ragnar store 2 (`notebook_B.ragnar.duckdb`) for read/write
4. Try to query both stores simultaneously (e.g., during notebook switching)

The OS-level file locks conflict, especially on Windows where file locking is more aggressive.

**How to avoid:**
- **Connection pooling strategy:** Create ragnar store connections lazily and close them immediately after use. Do NOT store ragnar store objects in reactive values that persist across requests.
- **Single active store pattern:** Only keep ONE ragnar store open at a time. Close previous store before opening new one when switching notebooks.
- **Read-only retrieval:** For search operations, connect to ragnar stores with read-only access if ragnar API supports it (check `ragnar::ragnar_store_connect()` parameters).
- **Avoid concurrent writes:** Never insert chunks into multiple ragnar stores within the same Shiny observer. Batch all writes to one store, close connection, then write to next.

**Warning signs:**
- "Database is locked" errors in Shiny console when switching between notebooks
- Timeouts during ragnar retrieval operations
- App freezes when multiple users access different notebooks simultaneously
- File handle leaks (check with `lsof` on Linux or Process Explorer on Windows)

**Phase to address:**
Phase 1 (Per-notebook store architecture design) - Establish connection lifecycle pattern BEFORE implementing multiple stores. Add explicit `close_ragnar_store()` calls after each operation.

---

### Pitfall 2: Data Loss from Premature Legacy Embedding Deletion

**What goes wrong:**
Deleting legacy embeddings (`chunks.embedding` column) before confirming ragnar migration completeness causes permanent data loss. User queries fail because neither system has embeddings. Scenario:
1. Migration script deletes `chunks.embedding` column
2. Ragnar store exists but is incomplete (some documents failed to chunk/embed)
3. User queries old documents → no fallback → empty results
4. No way to regenerate embeddings without re-uploading original PDFs

**Why it happens:**
Developers assume migration is atomic (all-or-nothing), but PDF processing can fail silently (corrupted files, API rate limits, encoding issues). The code currently has:
```r
ragnar_indexed <- FALSE
# Try ragnar...
if (!ragnar_indexed && !is.null(api_key)) {
  # Legacy fallback
}
```
If migration removes this fallback, failures propagate to users.

**How to avoid:**
- **Dual-write period:** Keep BOTH systems active for migration period. Continue populating legacy embeddings even after ragnar is working.
- **Validation before deletion:** Before dropping `chunks.embedding` column, verify:
  - Count of chunks with embeddings (legacy) matches count in ragnar store
  - Sample retrieval queries return equivalent results from both systems
  - All notebooks have corresponding ragnar stores
- **Migration status tracking:** Add `migration_status` table:
  ```sql
  CREATE TABLE migration_status (
    notebook_id VARCHAR PRIMARY KEY,
    ragnar_store_path VARCHAR,
    chunks_migrated INTEGER,
    chunks_total INTEGER,
    migration_completed BOOLEAN DEFAULT FALSE,
    migrated_at TIMESTAMP
  )
  ```
- **Graceful degradation path:** Even after "ragnar-only" deployment, keep legacy retrieval code path for N weeks with logging to catch edge cases.

**Warning signs:**
- Retrieval returns 0 results for documents that previously worked
- `chunks` table has rows but ragnar store file is missing or empty
- API error logs during document upload (embeddings failed but chunks were saved)
- User complaints about "old documents not searchable anymore"

**Phase to address:**
Phase 3 (Migration execution) - Implement validation and rollback BEFORE any destructive operations. Phase 4 (Legacy cleanup) should happen AFTER Phase 3 validation passes for ALL notebooks.

---

### Pitfall 3: Breaking Changes in Ragnar API Between Versions

**What goes wrong:**
Ragnar updates introduce breaking API changes (e.g., `ragnar_store_create()` signature changes, `ragnar_retrieve()` result structure changes). App breaks on `update.packages()`. Current ragnar version is 0.2.1 (Feb 2026), but package is young and API may not be stable.

Example breaking change risk:
- `store@version` changes from 1 to 2 with incompatible chunk schema
- `markdown_chunk()` returns different column names
- `ragnar_retrieve()` changes from returning `text` to `content` column

**Why it happens:**
Ragnar is a tidyverse package in active development. Tidyverse ecosystem values iteration and "tidying" APIs based on user feedback. Version 0.x.x signals pre-1.0 instability. The app hardcodes assumptions:
```r
# Assumes 'text' column
results$content <- results$text
```
If ragnar switches to standardized `content`, this breaks.

**How to avoid:**
- **Pin ragnar version:** In `DESCRIPTION` (if packaged) or install script:
  ```r
  remotes::install_version("ragnar", version = "0.2.1", upgrade = "never")
  ```
- **Version detection guard:**
  ```r
  ragnar_version <- packageVersion("ragnar")
  if (ragnar_version < "0.2.1" || ragnar_version >= "0.3.0") {
    warning("Untested ragnar version. Expected 0.2.x")
  }
  ```
- **API abstraction layer:** Wrap all ragnar calls in `R/_ragnar.R` with internal API:
  ```r
  # Internal API stays stable
  serapeum_retrieve <- function(store, query, top_k) {
    results <- ragnar::ragnar_retrieve(store, query, top_k)
    # Normalize to internal schema
    list(content = results$text %||% results$content, ...)
  }
  ```
- **Automated tests against API contract:** Test that ragnar functions return expected structure (not just success/failure).

**Warning signs:**
- `Error: object 'text' not found` after ragnar update
- Ragnar store created with one version fails to open with another version
- Unit tests pass but integration fails after dependency update
- `store@version` mismatch errors

**Phase to address:**
Phase 1 (Dependency management) - Pin version and add compatibility checks BEFORE writing integration code. Phase 6 (Testing) must include version upgrade simulation.

---

### Pitfall 4: Section_hint Metadata Loss During Ragnar-Only Migration

**What goes wrong:**
Ragnar stores don't natively support custom metadata like `section_hint`. Migration loses this data. Conclusion synthesis feature breaks because it relies on filtering chunks by `section_hint IN ('conclusion', 'future_work', 'late_section')`.

Current workaround in `search_chunks_hybrid()`:
```r
# Ragnar results don't have section_hint, query from chunks table
section_hints <- dbGetQuery(con, "
  SELECT DISTINCT substr(content, 1, 100) as content_prefix, section_hint
  FROM chunks WHERE substr(content, 1, 100) IN (...)
")
```
If legacy `chunks` table is deleted, this fails.

**Why it happens:**
Ragnar's data model is `(origin, hash, text)` - minimalist design for general RAG. No built-in support for domain-specific metadata. The workaround (JOIN on content prefix) is fragile:
- Content may have changed (whitespace normalization)
- 100-char prefix collisions possible
- Performance degrades with large datasets (full table scan)

**How to avoid:**
- **Metadata sidecar table:** Keep `chunks` table but drop `embedding` column only:
  ```sql
  -- Keep: id, source_id, chunk_index, content, page_number, section_hint
  -- Drop: embedding (stored in ragnar now)
  ALTER TABLE chunks DROP COLUMN embedding;
  ```
  Link chunks to ragnar via `hash` or `(source_id, chunk_index)`.

- **Extend ragnar store schema:** If ragnar allows custom columns (check docs), add during creation:
  ```r
  # Hypothetical - verify ragnar supports this
  ragnar_chunks$section_hint <- detect_section_hint(...)
  ragnar::ragnar_store_insert(store, ragnar_chunks)
  ```

- **Metadata in origin field:** Encode metadata in ragnar's `origin`:
  ```r
  # Instead of: origin = "doc.pdf#page=5"
  # Use: origin = "doc.pdf#page=5#section=conclusion"
  ```
  Parse on retrieval. Fragile but works without schema changes.

- **Parallel metadata store:** Separate DuckDB table `chunk_metadata`:
  ```sql
  CREATE TABLE chunk_metadata (
    chunk_hash VARCHAR PRIMARY KEY,
    section_hint VARCHAR,
    custom_field VARCHAR
  )
  ```
  Query after ragnar retrieval to enrich results.

**Warning signs:**
- Conclusion synthesis returns empty results after migration
- Section filter parameter is ignored in search results
- `section_hint` column missing from ragnar retrieval results
- JOIN queries timing out on large datasets

**Phase to address:**
Phase 2 (Schema design) - Decide metadata strategy BEFORE building per-notebook stores. Test metadata round-trip (insert → retrieve → verify section_hint preserved).

---

### Pitfall 5: Shiny Reactive Context Issues with Ragnar Store Connections

**What goes wrong:**
Ragnar store connections opened inside reactive contexts (`observe()`, `reactive()`) don't clean up properly. Memory leaks accumulate. Error manifests as:
1. First notebook switch: works fine
2. 10th notebook switch: app slows down
3. 50th notebook switch: R process crashes (out of memory)

Root cause: DuckDB connections opened in reactive contexts are not explicitly closed. When reactive invalidates, R's garbage collector doesn't immediately finalize connections (DuckDB holds OS-level file handles).

**Why it happens:**
Shiny's reactive programming model creates closures that capture variables. If you do:
```r
observeEvent(input$notebook_selected, {
  store <- get_ragnar_store(ragnar_path)  # Opens connection
  results <- ragnar_retrieve(store, query)
  # store object still in closure, not garbage collected until observer re-runs
})
```
Each notebook switch creates new connection without closing previous one.

**How to avoid:**
- **Explicit cleanup with on.exit:**
  ```r
  observeEvent(input$notebook_selected, {
    store <- get_ragnar_store(ragnar_path)
    on.exit({
      # Ragnar may not have explicit close method, check docs
      # If store has @con, do: DBI::dbDisconnect(store@con)
    }, add = TRUE)
    # ... use store ...
  })
  ```

- **Session-level resource tracking:**
  ```r
  # In server function
  active_stores <- reactiveVal(list())

  observeEvent(input$notebook_selected, {
    # Close previous stores
    for (store in active_stores()) {
      close_ragnar_store(store)
    }

    new_store <- get_ragnar_store(ragnar_path)
    active_stores(list(new_store))
  })

  session$onSessionEnded(function() {
    for (store in active_stores()) {
      close_ragnar_store(store)
    }
  })
  ```

- **Connection pooling (if ragnar supports):** Similar to database `pool` package pattern - reuse connections instead of creating new ones.

- **Read-only connections where possible:** Retrieval doesn't need write access. If ragnar allows read-only connections, they may have less strict locking and better cleanup behavior.

**Warning signs:**
- R process memory usage grows linearly with notebook switches
- File handle count increases over time (check with `lsof -p <pid>` on Linux)
- "Too many open files" errors
- DuckDB WAL files accumulate in data directory without cleanup
- App becomes unresponsive after extended use

**Phase to address:**
Phase 1 (Architecture design) - Establish connection lifecycle pattern. Phase 5 (Shiny integration) must include explicit cleanup and leak testing (automated notebook switching test).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Single shared ragnar store instead of per-notebook | Simpler to implement, no connection management complexity | Notebook deletion requires ragnar store cleanup (orphaned chunks), cross-notebook contamination in retrieval, harder to export/import individual notebooks | MVP only - not acceptable for production |
| Keep legacy embedding fallback indefinitely | No migration risk, both systems work | Double storage cost, double API cost for embeddings, maintenance burden of two code paths, no performance benefit of ragnar-only | Transition period (3-6 months max), then must choose one system |
| Encode metadata in ragnar origin field | No schema changes required, works with vanilla ragnar | Fragile parsing, hard to query/filter, origin field pollution, no validation | Only if ragnar proves incompatible with metadata AND sidecar table performs poorly |
| Skip section_hint migration validation | Faster migration, less code | Silent data loss for conclusion synthesis, user confusion when feature stops working | Never - section_hint is user-visible feature |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| DuckDB + Ragnar | Assume ragnar and main DB can both be open read/write simultaneously | Only ONE ragnar store open at a time. Close before opening next. Main DB can stay open (different file). |
| OpenRouter embeddings via ragnar | Assume ragnar natively supports OpenRouter API | Must write custom `embed_via_openrouter()` function and pass to `ragnar_store_create()` - see `R/_ragnar.R` lines 40-46 for working example. |
| Shiny session lifecycle | Open ragnar store in global scope (outside server function) | Open lazily inside reactive context with `on.exit()` cleanup. Use `session$onSessionEnded()` for final cleanup. |
| Content matching for metadata lookup | Use full content for JOIN (exact match) | Use content prefix (first 100 chars) with `substr()` - full content has whitespace variations. Still fragile. |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Metadata lookup via content JOIN | Search latency increases from 50ms to 5s as notebooks grow | Use sidecar metadata table with indexed `chunk_hash` instead of content matching | >10,000 chunks per notebook |
| Creating new ragnar connection per query | Connection overhead dominates query time (300ms connection, 10ms query) | Connection pooling or persistent store object (with proper cleanup) | >50 queries per session |
| Building ragnar index on every chunk insert | Document upload takes 30+ seconds for 100-page PDF | Batch insert all chunks, build index ONCE at end (see `mod_document_notebook.R` line 254) | Any multi-page document |
| Not closing ragnar stores | Memory grows 50MB per notebook switch | Explicit `on.exit()` cleanup in reactive contexts | Extended session (>20 notebook switches) |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing API keys in ragnar store metadata | Ragnar store files may be exported/shared with collaborators, leaking OpenRouter API key | Never store credentials in ragnar. Pass API key only to embed function at creation time. |
| Cross-notebook data leakage via shared store | User A's private notebook chunks appear in User B's search results | Per-notebook ragnar stores (milestone goal). Validate notebook_id filtering in retrieval. |
| SQL injection via section_hint filter | Malicious section_hint values could break out of IN clause | Use parameterized queries (`dbGetQuery(con, "WHERE section_hint IN (?)", list(hints))`) not sprintf. |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Silent fallback to legacy embedding | User doesn't know ragnar failed, gets worse retrieval quality, no error feedback | Show warning toast: "Advanced search unavailable, using basic search" with details in expandable section |
| No migration progress indicator | User uploads 100-page PDF, app freezes for 60 seconds, user force-quits thinking it crashed | Multi-step progress bar: "Processing PDF (30%)... Generating embeddings (60%)... Building index (90%)" |
| Breaking existing notebooks silently | After migration, user's 6-month-old notebook returns no results, user thinks data is lost | Pre-migration validation: detect notebooks without ragnar stores, show banner "Upgrade needed for X notebooks" with one-click upgrade |
| Deleting legacy embeddings without user consent | User's workflow depends on CSV export of embeddings (external analysis), suddenly data is gone | Add Settings toggle "Enable advanced search (requires migration)" - user opts in, not forced |

## "Looks Done But Isn't" Checklist

- [ ] **Ragnar store connections:** Often missing explicit `close_ragnar_store()` calls in error paths - verify `on.exit()` cleanup in all reactive contexts
- [ ] **Migration validation:** Often missing per-notebook verification that chunk count matches between legacy and ragnar - verify migration_status table tracks completion
- [ ] **Section_hint round-trip:** Often missing test that section_hint survives insert → retrieve cycle - verify `detect_section_hint()` output appears in search results
- [ ] **Multi-user concurrency:** Often missing test with 2+ simultaneous users switching notebooks - verify no "database locked" errors under load
- [ ] **Error propagation:** Often missing user-facing errors when ragnar fails (silent fallback hides problems) - verify showNotification() on all ragnar failures
- [ ] **API key validation:** Often missing check that embed function works before creating ragnar store - verify OpenRouter API key valid before migration starts
- [ ] **Rollback capability:** Often missing ability to revert to legacy embeddings if ragnar fails - verify legacy code path still works after "ragnar-only" deployment

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| DuckDB connection locking | LOW | 1. Force-close app. 2. Kill R process if needed. 3. Delete `.duckdb.wal` files in data directory. 4. Restart app. 5. Add `on.exit()` cleanup to prevent recurrence. |
| Data loss from premature deletion | HIGH | 1. Restore from backup (if available). 2. If no backup: users must re-upload PDFs. 3. Implement dual-write immediately. 4. Audit all notebooks for missing embeddings. |
| Ragnar API breaking change | MEDIUM | 1. Pin ragnar version in install script. 2. Test with pinned version. 3. Create API adapter in `R/_ragnar.R` to normalize changes. 4. When ready to upgrade: update adapter, test thoroughly, deploy. |
| Section_hint metadata loss | MEDIUM | 1. If `chunks` table still exists: rejoin metadata via content matching. 2. If deleted: re-process all PDFs with `detect_section_hint()`. 3. Implement sidecar metadata table for future. |
| Shiny reactive context leak | LOW | 1. Restart app (clears memory). 2. Add session cleanup: `session$onSessionEnded(close_all_stores)`. 3. Monitor memory usage in production. 4. Add automated leak test to CI. |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| DuckDB connection locking | Phase 1: Architecture | Automated test: open store 1, open store 2, verify no "database locked" error. Manual test: switch between 5 notebooks rapidly. |
| Data loss from premature deletion | Phase 3: Migration | Before dropping `chunks.embedding`: query count matches ragnar store count for ALL notebooks. Sample 10 random documents, verify retrieval works. |
| Ragnar API breaking changes | Phase 1: Dependencies | Pin version in install script. Unit test: verify `ragnar_retrieve()` returns expected columns. |
| Section_hint metadata loss | Phase 2: Schema | Integration test: insert chunk with section_hint="conclusion", retrieve, verify section_hint present. Test with ragnar AND sidecar metadata approach. |
| Shiny reactive context leak | Phase 5: Shiny integration | Load test: automated script switches notebooks 100 times, verify memory usage stable (not linear growth). Check file handle count. |
| Silent fallback masking failures | Phase 4: Error handling | Force ragnar to fail (wrong API key), verify user sees error notification, not silent degradation. |
| Cross-notebook data leakage | Phase 2: Per-notebook stores | Create notebook A and B with distinct documents. Query in A, verify B's documents never appear. Test with shared store vs per-notebook. |
| Missing migration validation | Phase 3: Migration | Run migration on test database. Delete random chunks from ragnar store. Verify validation catches mismatch before allowing legacy deletion. |

## Sources

- [DuckDB Concurrency Documentation](https://duckdb.org/docs/stable/connect/concurrency) - DuckDB's single-writer concurrency model
- [DuckDB Multiple Connections Discussion](https://github.com/duckdb/duckdb/discussions/10397) - File locking behavior
- [DuckDB "Database Locked" Discussion](https://github.com/duckdb/duckdb/discussions/8126) - Comparison to SQLite locking
- [Shiny Database Connection Best Practices](https://forum.posit.co/t/best-practice-for-sql-connection-in-reactive-shiny-app/8110) - Posit community guidance
- [Why pool? - Connection Management in Shiny](https://cran.r-project.org/web/packages/pool/vignettes/why-pool.html) - Connection pooling patterns
- [Shiny onSessionEnded Cleanup](https://forum.posit.co/t/closing-database-connection-when-closing-shiny-app/134910) - Session lifecycle management
- [Ragnar CRAN Package](https://cran.r-project.org/package=ragnar) - Official package page (version 0.2.1 as of Feb 2026)
- [Ragnar Documentation](https://ragnar.tidyverse.org/) - Official tidyverse docs
- [Data Migration Best Practices 2026](https://medium.com/@kanerika/data-migration-best-practices-your-ultimate-guide-for-2026-7cbd5594d92e) - Migration strategy patterns
- [Legacy Data Migration Guide](https://acropolium.com/blog/legacy-data-migration/) - Avoiding data loss during transitions

---
*Pitfalls research for: Ragnar RAG Overhaul in Serapeum*
*Researched: 2026-02-16*
*Confidence: HIGH - Based on official DuckDB/Shiny documentation, existing codebase analysis, and data migration best practices*
