# Project Research Summary

**Project:** Ragnar RAG Overhaul (Per-Notebook Vector Stores)
**Domain:** RAG (Retrieval-Augmented Generation) backend migration in R/Shiny
**Researched:** 2026-02-16
**Confidence:** HIGH

## Executive Summary

Serapeum currently uses a single shared ragnar store for all notebooks, leading to orphaned data, no isolation between notebooks, and brittle metadata handling. The research validates migrating to per-notebook ragnar stores as the correct approach: one DuckDB file per notebook in `data/ragnar/{notebook_id}.duckdb`. This aligns with DuckDB's single-writer design philosophy and enables clean notebook deletion without cross-contamination.

The recommended approach uses ragnar 0.3.0 with version 2 store format, encoding `section_hint` metadata directly in ragnar's `origin` field to avoid post-retrieval database lookups. The migration path is clear: create per-notebook stores for new content, migrate existing shared store data via one-time script, then remove legacy embedding code paths entirely. This eliminates 220+ lines of fallback code while improving retrieval performance.

Key risk is DuckDB connection management: multiple open ragnar stores can cause file locking errors. Mitigation requires explicit connection lifecycle management with `on.exit()` cleanup in all reactive contexts and a single-active-store pattern during notebook switching. Secondary risk is data loss if legacy embeddings are deleted before validating migration completeness. Mitigation: dual-write period with validation before any destructive operations.

## Key Findings

### Recommended Stack

Ragnar 0.3.0 is Posit's purpose-built RAG package for R, using DuckDB 1.3.2 with automatic VSS extension loading. Version 2 stores support document-level storage with overlapping chunks and de-overlapping at retrieval. The package handles embedding and indexing transparently, with hybrid VSS + BM25 search out of the box.

**Core technologies:**
- **ragnar 0.3.0**: Vector store management with hybrid retrieval — Posit's official RAG solution, DuckDB-native, automatic VSS extension handling
- **DuckDB 1.3.2**: Embedded database for vector storage — lightweight, no-server, native VSS support, single-writer concurrency model
- **uuid**: Per-notebook store identifiers — filesystem-safe IDs for deterministic path construction (`data/ragnar/{notebook_id}.duckdb`)

**Version strategy:**
- Use version 2 stores for all new notebooks (MarkdownDocumentChunks input, ragnar handles hashing)
- Keep version 1 for existing shared store during migration (manual digest::digest() hashing)
- Remove digest dependency once migration completes

### Expected Features

The research identifies clear table stakes vs differentiators. Users expect transparent store creation (no manual setup), automatic cleanup on notebook deletion, and seamless switching between notebooks. These are non-negotiable.

**Must have (table stakes):**
- **Automatic store creation on first content** — create ragnar store on first PDF upload or abstract embed, users shouldn't manage stores manually
- **Automatic cleanup on notebook deletion** — cascade delete ragnar store file when notebook deleted, no orphaned data
- **Seamless notebook switching** — RAG retrieval automatically uses correct per-notebook store without filtering
- **Transparent re-embedding on corruption** — if store corrupted, show "Re-build Index" button with progress feedback

**Should have (competitive):**
- **Storage usage visibility** — show per-notebook ragnar store file size in UI, helps users understand storage impact
- **Store migration assistant** — one-click migration from shared store to per-notebook stores for existing users
- **Health check with self-repair** — background check on app startup, auto-rebuild if corruption detected (non-blocking toast)

**Defer (v2+):**
- **Incremental re-embedding** — only re-embed changed content (requires content hash tracking, adds complexity)
- **Export/import notebook with store** — package notebook data + ragnar DB for sharing/backup
- **Cross-notebook search** — search all notebooks at once (contradicts isolation goal, separate feature)

**Anti-features (avoid):**
- Manual store path configuration (support burden, broken paths)
- Shared store with namespace filtering (defeats isolation, corruption breaks all notebooks)
- Real-time background re-indexing (PDFs are immutable, no clear trigger)

### Architecture Approach

The architecture shifts from centralized filtering to distributed isolation. Current state has all chunks in one shared ragnar store with post-retrieval filtering by notebook_id. Target state has one ragnar store per notebook, eliminating filtering entirely. Metadata (section_hint) moves from separate chunks table to encoded in ragnar's origin field.

**Major components:**
1. **Per-notebook store path construction** — deterministic `data/ragnar/{notebook_id}.duckdb` from notebook ID, no DB state needed
2. **Store lifecycle binding** — create ragnar store during notebook creation, delete during notebook deletion via `delete_ragnar_store()`
3. **Metadata encoding in origin field** — encode `section_hint` as `"{filename}#page={N}|section={hint}"` to survive ragnar persistence
4. **Ragnar-only retrieval path** — remove legacy cosine similarity fallback, require ragnar, fail fast if unavailable

**Data flow changes:**
- Remove: chunks table CRUD, search_chunks_hybrid filtering (db.R:848-875), dual embedding paths (pdf.R:263-299, rag.R:94-121)
- Add: get_notebook_ragnar_path(), delete_ragnar_store(), section_hint encoding/decoding

**Build order:**
1. Foundation: Add path helpers and metadata encoding (no breaking changes)
2. Module updates: Switch to notebook-scoped paths (parallel-safe)
3. Simplification: Remove legacy code paths (breaking changes)
4. Cleanup: Drop chunks table, delete shared store (after migration validated)

### Critical Pitfalls

1. **DuckDB connection locking** — Multiple ragnar stores open simultaneously cause "database locked" errors due to DuckDB's single-writer model. Mitigation: single-active-store pattern, explicit `on.exit()` cleanup, read-only connections for retrieval where possible.

2. **Data loss from premature legacy deletion** — Deleting chunks.embedding column before validating ragnar migration completeness causes permanent data loss. Mitigation: dual-write period, migration_status table tracking per-notebook completion, validation before any destructive operations.

3. **Ragnar API breaking changes** — Ragnar 0.x.x signals pre-1.0 instability, API may change between versions. Mitigation: pin ragnar version in install script, add version detection guard, wrap all ragnar calls in abstraction layer (R/_ragnar.R).

4. **Section_hint metadata loss** — Ragnar doesn't natively support custom metadata like section_hint, conclusion synthesis breaks if lost. Mitigation: encode section_hint in origin field as `|section={hint}`, parse on retrieval.

5. **Shiny reactive context leaks** — Ragnar store connections opened in reactive contexts don't clean up, memory leaks accumulate. Mitigation: explicit `on.exit()` cleanup, session-level resource tracking with `session$onSessionEnded()`, test with automated notebook switching.

## Implications for Roadmap

Based on research, suggested 6-phase structure addressing dependencies and pitfalls:

### Phase 1: Foundation (Path Helpers & Metadata Encoding)

**Rationale:** Non-breaking foundation enables all subsequent work. Path construction and metadata encoding can be tested independently without touching existing store logic.

**Delivers:**
- `get_notebook_ragnar_path(notebook_id)` function for deterministic paths
- `delete_ragnar_store(notebook_id)` function for cleanup
- Section_hint encoding in `insert_chunks_to_ragnar()` via origin field
- Section_hint decoding in `retrieve_with_ragnar()` via regex parsing

**Addresses:** Anti-pattern of storing paths in DB (FEATURES.md), metadata loss pitfall (PITFALLS.md #4)

**Avoids:** Premature breaking changes, enables testing path construction before switching modules

### Phase 2: Per-Notebook Store Creation

**Rationale:** Core feature enabling isolation. Must work before migration or module updates. Documents table already has notebook_id foreign key, so store path construction is straightforward.

**Delivers:**
- Notebook creation triggers ragnar store creation
- Version 2 stores for new notebooks (MarkdownDocumentChunks input)
- Automatic store directory creation (`data/ragnar/`)
- Error handling for missing API keys (graceful degradation)

**Uses:** ragnar 0.3.0 version 2 stores (STACK.md), get_notebook_ragnar_path() from Phase 1

**Implements:** Store lifecycle binding pattern (ARCHITECTURE.md Pattern 2)

**Addresses:** Automatic store creation table stake (FEATURES.md)

**Avoids:** DuckDB connection locking by creating stores lazily, only when first content added

### Phase 3: Per-Notebook Store Deletion

**Rationale:** Complete lifecycle management before modules start using per-notebook stores. Prevents orphan accumulation. Must cascade properly with DuckDB transaction.

**Delivers:**
- Notebook deletion triggers ragnar store file deletion
- Cleanup timing: after DB commit succeeds (avoid orphaned DB records)
- File existence check before deletion (idempotent)
- Logging for debugging orphaned stores

**Addresses:** Automatic cleanup table stake (FEATURES.md)

**Avoids:** Orphan accumulation problem from current shared store

**Research flag:** Test file deletion timing with transaction rollback scenarios

### Phase 4: Module Updates (Document & Search Notebooks)

**Rationale:** Switch modules to use notebook-scoped paths. Parallel-safe since document and search notebooks are independent modules. Can test each module separately.

**Delivers:**
- `mod_document_notebook.R` uses `get_notebook_ragnar_path(notebook_id)` for PDF indexing
- `mod_search_notebook.R` uses `get_notebook_ragnar_path(notebook_id)` for abstract indexing
- Both modules pass notebook_id to ragnar functions
- Progress feedback for indexing operations

**Addresses:** Seamless notebook switching table stake (FEATURES.md)

**Avoids:** Post-retrieval filtering complexity (current db.R:860-874 logic)

**Research flag:** Test concurrent PDF upload in notebook A and abstract embed in notebook B (connection locking risk)

### Phase 5: Migration Script (Shared Store → Per-Notebook)

**Rationale:** One-time data migration for existing users. Separate script vs in-app feature reduces app complexity. Must run before Phase 6 legacy cleanup.

**Delivers:**
- `scripts/migrate_ragnar_stores.R` script
- Reads all notebooks, creates per-notebook stores
- Copies chunks from shared store based on notebook_id
- Validation: chunk count matches between legacy and ragnar
- Migration status tracking table with per-notebook completion flags

**Addresses:** Store migration assistant differentiator (FEATURES.md)

**Avoids:** Data loss pitfall (PITFALLS.md #2) via validation before destructive operations

**Research flag:** HIGH priority — test migration with large shared store (10k+ chunks), measure API cost and time

### Phase 6: Legacy Cleanup (Remove Fallback Code)

**Rationale:** Final simplification after migration validated. Removes 220+ lines of fallback code. Must wait until all notebooks migrated successfully.

**Delivers:**
- Remove legacy embedding path from `R/pdf.R` (lines 263-299)
- Remove legacy retrieval fallback from `R/rag.R` (lines 94-121)
- Remove `search_chunks_hybrid()` filtering logic from `R/db.R` (lines 848-875)
- Drop `chunks.embedding` column (keep section_hint metadata in chunks table as backup)
- Delete shared `data/serapeum.ragnar.duckdb`
- Remove digest dependency (version 2 stores use rlang::hash internally)

**Addresses:** Simplification goal (ARCHITECTURE.md: "Removes dual maintenance burden")

**Avoids:** Keeping anti-pattern of dual persistence indefinitely (PITFALLS.md Tech Debt)

**Research flag:** Retain chunks table (without embedding) as metadata sidecar in case origin field encoding proves insufficient

### Phase Ordering Rationale

- **Phase 1 before all others:** Path helpers and metadata encoding are non-breaking, required by all subsequent phases, can be tested independently
- **Phase 2-3 before 4:** Lifecycle management must be complete before modules start creating per-notebook stores
- **Phase 4 before 5:** Modules must support per-notebook paths before migration creates those stores
- **Phase 5 before 6:** Legacy data must migrate before legacy code can be removed
- **Phase 3 and 4 are partially parallel:** Module updates can start while deletion logic is being implemented, but both must complete before Phase 5

**Dependency chain:**
```
Phase 1 (foundation)
    └──> Phase 2 (creation) + Phase 3 (deletion)
              └──> Phase 4 (module updates)
                      └──> Phase 5 (migration)
                              └──> Phase 6 (cleanup)
```

**How this avoids pitfalls:**
- Connection locking (P1): Single-active-store pattern enforced in Phase 4
- Data loss (P2): Validation gates in Phase 5 before Phase 6 cleanup
- API breaking changes (P3): Version pinning in Phase 1
- Metadata loss (P4): Encoding implemented in Phase 1, tested in Phase 2
- Reactive leaks (P5): Cleanup pattern established in Phase 4

### Research Flags

**Phases likely needing deeper research during planning:**

- **Phase 3 (Deletion):** Transaction coordination between DuckDB commit and file deletion timing — needs testing with rollback scenarios to prevent orphaned records
- **Phase 5 (Migration):** Large-scale migration performance and API cost — estimate time and OpenRouter API cost for migrating 10k+ chunks, may need batching/rate limiting

**Phases with standard patterns (skip research-phase):**

- **Phase 1 (Foundation):** Path construction is straightforward string formatting, metadata encoding is regex-based parsing (well-documented R patterns)
- **Phase 2 (Creation):** Ragnar store creation API well-documented in package vignette
- **Phase 4 (Module Updates):** Shiny module patterns are standard, just parameter passing
- **Phase 6 (Cleanup):** Code deletion and schema changes (low risk, can rollback)

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | ragnar 0.3.0 package documentation verified via help(), DuckDB 1.3.2 in renv.lock, live testing of VSS extension loading |
| Features | MEDIUM | Table stakes validated via RAG best practices and multi-tenant isolation patterns, but Serapeum-specific UX needs user validation |
| Architecture | HIGH | Current codebase analyzed (R/_ragnar.R, R/db.R, mod_*.R), per-notebook store pattern verified via DuckDB multi-database docs, metadata encoding tested |
| Pitfalls | HIGH | DuckDB concurrency model confirmed via official docs, connection locking verified in community discussions, Shiny reactive leaks documented in Posit forum |

**Overall confidence:** HIGH

### Gaps to Address

**Gap 1: Migration API cost estimation**
- **Issue:** Don't know total cost to re-embed all existing chunks via OpenRouter API
- **Resolution:** In Phase 5 planning, query chunks table for total token count, multiply by OpenRouter pricing, present estimate to user before migration starts
- **Impact:** May need to add "migrate per notebook" option if bulk migration too expensive

**Gap 2: Section_hint encoding robustness**
- **Issue:** Encoding in origin field is non-standard, may have edge cases (special chars in section names, parsing failures)
- **Resolution:** In Phase 1 implementation, add comprehensive tests for section_hint round-trip with special characters, validate regex parsing
- **Impact:** If encoding proves fragile, fallback to chunks table sidecar (keep chunks table after Phase 6, just drop embedding column)

**Gap 3: Concurrent store access patterns**
- **Issue:** Don't know if simultaneous PDF upload in notebook A + abstract embed in notebook B will cause issues
- **Resolution:** In Phase 4 testing, simulate concurrent operations, measure whether separate ragnar stores truly avoid DuckDB locking
- **Impact:** May need connection pooling library if simultaneous writes to different stores still conflict

**Gap 4: Ragnar version stability**
- **Issue:** Ragnar 0.3.0 is recent (Feb 2026), unclear if API will remain stable through 0.4.x
- **Resolution:** Pin version in Phase 1, monitor ragnar GitHub for breaking changes, add version compatibility tests
- **Impact:** If breaking changes occur, may need API adapter layer in R/_ragnar.R (already recommended in STACK.md)

## Sources

### Primary (HIGH confidence)
- ragnar 0.3.0 package documentation (`help(ragnar_store_create)`, package vignette) — verified all function signatures and store version differences
- DuckDB 1.3.2 renv.lock entry — confirmed installed version
- Serapeum codebase: R/_ragnar.R, R/db.R, R/rag.R, R/pdf.R, mod_document_notebook.R, mod_search_notebook.R — analyzed current implementation and integration points
- Live testing: ragnar store creation, VSS extension auto-loading, metadata attribute behavior

### Secondary (MEDIUM confidence)
- [DuckDB Concurrency Documentation](https://duckdb.org/docs/stable/connect/concurrency) — single-writer model confirmed
- [DuckDB VSS Extension Docs](https://duckdb.org/docs/stable/core_extensions/vss) — HNSW index, experimental status
- [Neon: One Database per User, Zero Complexity](https://neon.com/use-cases/database-per-tenant) — per-tenant isolation patterns
- [Shiny Database Connection Best Practices (Posit forum)](https://forum.posit.co/t/best-practice-for-sql-connection-in-reactive-shiny-app/8110) — connection lifecycle in reactive contexts
- [Why pool? - Connection Management in Shiny (CRAN)](https://cran.r-project.org/web/packages/pool/vignettes/why-pool.html) — pooling patterns for database connections

### Tertiary (LOW confidence)
- [ZenML: 10 Best Vector Databases for RAG Pipelines](https://www.zenml.io/blog/vector-databases-for-rag) — general RAG architecture patterns, not DuckDB-specific
- [Data Quality for Vector Databases](https://www.telm.ai/blog/data-quality-for-vector-databases/) — best practices for vector store management
- [Data Migration Best Practices 2026 (Medium)](https://medium.com/@kanerika/data-migration-best-practices-your-ultimate-guide-for-2026-7cbd5594d92e) — general migration patterns, adapted to ragnar context

---
*Research completed: 2026-02-16*
*Ready for roadmap: yes*
