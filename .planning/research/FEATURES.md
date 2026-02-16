# Feature Research

**Domain:** Per-Notebook Ragnar Store Management (RAG Backend Overhaul)
**Researched:** 2026-02-16
**Confidence:** MEDIUM

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Automatic store creation on first content** | Users expect PDFs/abstracts to "just work" without manual setup | LOW | Create ragnar store on first PDF upload or abstract embedding; users shouldn't know/care that a store exists |
| **Automatic cleanup on notebook deletion** | Deleting a notebook should clean up all associated data, including vector stores | MEDIUM | Must cascade delete: ragnar store file + DuckDB notebook record + all chunks/documents; file deletion timing is critical (before or after DB commit?) |
| **Seamless switching between notebooks** | RAG retrieval should automatically use the correct per-notebook store | LOW | Pass notebook-specific ragnar store path to `search_chunks_hybrid()`; current shared store approach needs refactoring |
| **Transparent re-embedding on corruption** | If store is corrupted/missing, user should be able to rebuild it without losing content | MEDIUM | Detect corruption on connect failure; provide "Re-build Index" button; re-chunk and re-embed all documents/abstracts for that notebook |
| **Graceful degradation without ragnar** | App should still function (even if degraded) if ragnar is unavailable | LOW | Already handled via `ragnar_available()` checks; ensure per-notebook path logic doesn't break fallback |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Health check with self-repair** | Proactively detect and fix store corruption before user notices | HIGH | Background health check on app startup; auto-rebuild if corruption detected; show non-blocking toast notification; differentiates from "re-index button only" pattern |
| **Incremental re-embedding** | Re-embed only changed/new content instead of full rebuild | HIGH | Track embedding state per document/abstract (e.g., `embedded_at` timestamp, content hash); only re-process items with changed content or missing embeddings; significantly reduces API cost for large notebooks |
| **Store migration assistant** | One-click migration from shared store to per-notebook stores | MEDIUM | Existing users have one shared `serapeum.ragnar.duckdb`; migration wizard reads all notebooks, creates per-notebook stores, moves chunks based on notebook_id; deletes old shared store after confirmation |
| **Storage usage visibility** | Show per-notebook ragnar store size in UI | LOW | Display file size of `.ragnar.duckdb` per notebook in settings/info panel; helps users understand storage impact; useful for cleanup decisions |
| **Export/import notebook with store** | Package notebook data + ragnar store for sharing/backup | MEDIUM | ZIP export includes: DuckDB notebook data + ragnar store file + PDFs; import unpacks and reconnects store; enables notebook portability |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Manual store path configuration** | Power users want control over file locations | Creates support burden (broken paths, permission issues, relative vs absolute); DuckDB already has a configured data directory | Store all ragnar DBs in `data/ragnar/{notebook_id}.ragnar.duckdb` using notebook ID as namespace; predictable, safe, auto-cleanup-friendly |
| **Shared store with namespace filtering** | "Why not just use namespaces in one DB like Pinecone?" | DuckDB concurrency model discourages single-file writes from multiple contexts; file corruption in shared store breaks ALL notebooks; per-file isolation is more robust for local-first apps | Per-notebook stores provide file-level isolation; DuckDB's single-user design favors separate files |
| **Real-time background re-indexing** | "Automatically re-embed when I edit a PDF" | PDFs are immutable after upload (no in-app editing); background re-embedding adds API cost without clear trigger; users don't expect real-time indexing for uploaded documents | Manual "Re-build Index" button when user explicitly needs it (e.g., after ragnar upgrade, corruption detected); show last-indexed timestamp |
| **Cross-notebook search** | "Search all my notebooks at once" | Per-notebook isolation is the entire point; mixing results from different projects creates confusion; performance degrades with multiple stores | Keep notebook-scoped search; add global search as separate feature later if validated by user feedback; search notebooks list first, then search within |
| **Ragnar version pinning per notebook** | "Lock ragnar version per notebook for reproducibility" | Ragnar embedding model/chunking changes rarely; managing multiple ragnar versions is complex; local-first apps should stay current for security/performance | Use single ragnar version app-wide; provide migration path if ragnar makes breaking changes; document ragnar version in notebook metadata for auditing |

## Feature Dependencies

```
[Automatic store creation]
    └──requires──> [Per-notebook store path resolution]
                       └──requires──> [Notebook ID available at embedding time]

[Automatic cleanup on deletion]
    └──requires──> [Per-notebook store path resolution]
    └──requires──> [Cascade delete in delete_notebook()]

[Transparent re-embedding]
    └──requires──> [Chunk source tracking in DuckDB]
                       └──requires──> [Re-chunk all documents/abstracts API]
    └──requires──> [Corruption detection on connect]

[Health check with self-repair]
    └──requires──> [Transparent re-embedding]
    └──requires──> [Background job on app startup]

[Incremental re-embedding]
    └──requires──> [Content hash tracking per document/abstract]
    └──enhances──> [Transparent re-embedding]
    └──conflicts──> [Simple full rebuild button] (adds complexity)

[Store migration assistant]
    └──requires──> [Per-notebook store creation]
    └──requires──> [Chunk origin parsing] (to map chunks to notebooks)
```

### Dependency Notes

- **Per-notebook store creation requires notebook ID:** Ragnar store path must be deterministic from notebook ID (e.g., `data/ragnar/{notebook_id}.ragnar.duckdb`)
- **Re-embedding requires chunk source tracking:** Need to query DuckDB for all documents/abstracts in notebook, re-chunk, re-insert to ragnar
- **Incremental re-embedding enhances but conflicts:** Makes re-embedding faster/cheaper but adds complexity; defer to v2 unless API costs become prohibitive
- **Migration assistant is one-time:** Only needed for existing users; new users start with per-notebook stores; can be a separate script vs in-app feature

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the concept.

- [x] **Per-notebook store path resolution** — `data/ragnar/{notebook_id}.ragnar.duckdb` pattern
- [x] **Automatic store creation on first PDF/abstract** — Create store in `process_pdf()` and abstract embedding flow
- [x] **Automatic cleanup on notebook deletion** — Delete ragnar file in `delete_notebook()` after DB cleanup
- [x] **Manual re-build index button** — UI button in notebook settings to trigger full re-embedding
- [x] **Corruption detection** — Check if ragnar store is readable on connect; show re-build button if corrupted
- [x] **Remove legacy embedding code paths** — Delete old cosine similarity search, embedding storage in chunks table

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] **Storage usage visibility** — Show ragnar store file size per notebook (simple `file.size()` call)
- [ ] **Store migration assistant** — Script or UI wizard to migrate existing shared store to per-notebook stores (one-time for existing users)
- [ ] **Health check on startup** — Background check for store corruption; show non-blocking notification if rebuild needed
- [ ] **Last-indexed timestamp** — Display when notebook was last indexed; helps users understand freshness

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] **Incremental re-embedding** — Only re-embed changed content (requires content hash tracking)
- [ ] **Export/import notebook with store** — Package notebook + ragnar DB for sharing/backup
- [ ] **Parallel re-embedding** — Process multiple documents concurrently during re-build (API rate limits may constrain)
- [ ] **Automatic re-embedding on ragnar upgrade** — Detect ragnar version change, offer one-click re-embed (only if ragnar makes breaking changes)

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Per-notebook store creation | HIGH | LOW | P1 |
| Automatic cleanup on deletion | HIGH | MEDIUM | P1 |
| Manual re-build index button | HIGH | MEDIUM | P1 |
| Corruption detection | HIGH | LOW | P1 |
| Remove legacy embedding | MEDIUM | LOW | P1 |
| Storage usage visibility | MEDIUM | LOW | P2 |
| Store migration assistant | MEDIUM | MEDIUM | P2 |
| Health check on startup | MEDIUM | MEDIUM | P2 |
| Last-indexed timestamp | LOW | LOW | P2 |
| Incremental re-embedding | HIGH | HIGH | P3 |
| Export/import notebook | MEDIUM | MEDIUM | P3 |
| Parallel re-embedding | MEDIUM | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch (core functionality)
- P2: Should have, add when possible (polish/DX improvements)
- P3: Nice to have, future consideration (optimization/advanced features)

## User Flows

### Flow 1: First PDF Upload to New Notebook (Happy Path)

1. User creates new document notebook
2. User uploads first PDF
3. App detects no ragnar store exists for this notebook
4. App creates `data/ragnar/{notebook_id}.ragnar.duckdb` with OpenRouter embed function
5. App chunks PDF with `chunk_with_ragnar()` (page-aware semantic chunking)
6. App inserts chunks to ragnar store with `insert_chunks_to_ragnar()`
7. App builds ragnar index with `build_ragnar_index()`
8. User can immediately query via RAG chat (no additional setup)

**Key UX:** Transparent. User doesn't know a "store" was created. It just works.

### Flow 2: Embedding Abstracts in Search Notebook (Happy Path)

1. User creates search notebook, runs OpenAlex query
2. User clicks "Embed Abstracts" (or auto-embed on import)
3. App detects no ragnar store exists for this notebook
4. App creates `data/ragnar/{notebook_id}.ragnar.duckdb`
5. App chunks each abstract (title + abstract text) with `chunk_with_ragnar()`
6. App inserts chunks with origin `abstract:{abstract_id}`
7. App builds index
8. User can query abstracts via RAG

**Key UX:** Same transparent pattern. Search notebooks and document notebooks behave identically.

### Flow 3: Deleting a Notebook (Cleanup)

1. User selects "Delete Notebook" from UI
2. App shows confirmation modal: "This will permanently delete [notebook name] and all associated data."
3. User confirms
4. App calls `delete_notebook(con, notebook_id)`
   - Deletes chunks from DuckDB (`chunks` table entries)
   - Deletes documents/abstracts from DuckDB
   - Deletes notebook record from DuckDB
   - Deletes ragnar store file: `data/ragnar/{notebook_id}.ragnar.duckdb`
5. UI updates to remove notebook from list

**Key UX:** Clean. No orphaned files. Storage reclaimed immediately.

**Complexity Note:** File deletion should happen AFTER DB commit succeeds (avoid orphaned DB records if file deletion fails).

### Flow 4: Re-embedding After Corruption (Recovery)

1. User opens notebook, tries to use RAG chat
2. App attempts to connect to ragnar store: `connect_ragnar_store(path)`
3. Connection fails (file corrupted, version mismatch, etc.)
4. App detects failure, sets flag: `store_corrupted = TRUE`
5. UI shows warning banner: "Search index is unavailable. [Re-build Index]"
6. User clicks "Re-build Index"
7. App shows modal: "Re-building index will re-process all documents and abstracts. This may take several minutes and consume API credits. Continue?"
8. User confirms
9. App shows progress modal: "Re-building index... (1/5 documents processed)"
10. For each document in notebook:
    - Re-chunk PDF with `chunk_with_ragnar()`
    - Insert to NEW ragnar store (overwrite old corrupted file)
11. For each abstract in notebook:
    - Re-chunk abstract text
    - Insert to ragnar store
12. Build index
13. Modal closes, banner disappears
14. RAG chat works normally

**Key UX:** Transparent recovery. User understands what went wrong ("index unavailable") and how to fix it ("re-build"). Progress feedback during rebuild.

**Complexity Note:** Deleting old corrupted ragnar file and creating fresh one is simpler than trying to repair in-place.

### Flow 5: Migrating Existing Shared Store (One-Time)

**Context:** Existing Serapeum users have one shared `data/serapeum.ragnar.duckdb` with all notebooks' chunks mixed together.

1. App detects shared store exists but no per-notebook stores
2. UI shows migration banner: "Your search index needs a one-time upgrade. [Migrate Now]"
3. User clicks "Migrate Now"
4. Modal explains: "This will create separate search indexes for each notebook. Your existing data will be preserved. Continue?"
5. User confirms
6. App shows progress: "Migrating notebooks... (1/3 complete)"
7. For each notebook:
   - Create `data/ragnar/{notebook_id}.ragnar.duckdb`
   - Query DuckDB for all documents/abstracts in that notebook
   - Re-chunk and insert to new per-notebook store
8. After all notebooks migrated:
   - Delete old shared `data/serapeum.ragnar.duckdb`
   - Mark migration as complete in settings
9. Modal closes, banner disappears

**Key UX:** One-time, guided migration. User understands why it's happening ("upgrade") and what to expect ("preserve data").

**Complexity Note:** This can be a background script (`scripts/migrate_ragnar_stores.R`) run via startup check rather than in-app UI (reduces app complexity).

## Complexity Analysis

| Feature | Implementation Complexity | Why |
|---------|--------------------------|-----|
| Per-notebook store creation | LOW | Add `notebook_id` parameter to `get_ragnar_store()`, use `sprintf("data/ragnar/%s.ragnar.duckdb", notebook_id)` for path |
| Automatic cleanup | MEDIUM | Must coordinate file deletion with DB transaction; ensure file deletion doesn't fail silently; handle case where file already deleted |
| Manual re-build button | MEDIUM | Need UI button → server handler → loop through all docs/abstracts → re-chunk → re-insert → build index; progress feedback adds complexity |
| Corruption detection | LOW | Wrap `connect_ragnar_store()` in `tryCatch()`, return NULL on failure; check NULL before retrieval |
| Migration assistant | MEDIUM-HIGH | Parse existing shared store to map chunks to notebooks (requires origin field parsing); bulk re-insert; handle errors gracefully |
| Incremental re-embedding | HIGH | Track content hash per document/abstract; compare on re-embed; only process changed items; manage partial index state |
| Health check on startup | MEDIUM | Run background check when app starts; non-blocking (don't delay app load); store check results in reactive; show toast notification |

## Expected Behavior Summary

### Store Lifecycle

- **Creation:** Automatic on first content (PDF upload or abstract embed)
- **Location:** `data/ragnar/{notebook_id}.ragnar.duckdb` (deterministic from notebook ID)
- **Deletion:** Automatic when notebook deleted (cascade cleanup)
- **Corruption:** Detected on connect failure; user prompted to re-build

### Re-Embedding Workflow

- **Trigger:** Manual button click (notebook settings or error banner)
- **Scope:** All documents + abstracts in that notebook
- **Process:** Delete old store file → create new → re-chunk all content → insert → build index
- **Feedback:** Progress modal with count (e.g., "Processing 3/10 documents...")
- **Cost Warning:** User sees API cost estimate before confirming (based on total tokens to re-embed)

### User Experience Principles

1. **Transparent creation:** Users don't manage stores; stores are implementation detail
2. **Graceful recovery:** Corruption shows clear error + actionable fix ("Re-build Index")
3. **No orphans:** Deleting notebook cleans up all associated data (DB + files)
4. **Isolated by default:** Each notebook's search is independent (no cross-contamination)
5. **Observable state:** Show when index was last built, file size, health status (after v1)

## Comparison: Shared Store vs Per-Notebook Stores

| Aspect | Shared Store (Current) | Per-Notebook Stores (Target) |
|--------|------------------------|------------------------------|
| **Isolation** | Logical (filter by notebook_id at query time) | Physical (separate files) |
| **Corruption Impact** | Breaks ALL notebooks | Breaks only affected notebook |
| **Cleanup** | Manual (orphaned chunks if not filtered correctly) | Automatic (delete file) |
| **Concurrency** | Single write bottleneck | Parallel writes possible (different notebooks) |
| **Storage** | Single file grows indefinitely | Multiple smaller files, easier to manage/backup |
| **Migration** | N/A | Required for existing users (one-time) |
| **Complexity** | Simpler (one store to manage) | Slightly more complex (per-notebook paths) |

**Recommendation:** Per-notebook stores align with DuckDB's design philosophy (separate files for isolation), provide better failure isolation, and enable cleaner lifecycle management. Migration cost is one-time and automatable.

## Sources

**Database Isolation Patterns:**
- [Neon: One Database per User, Zero Complexity](https://neon.com/use-cases/database-per-tenant)
- [Data Isolation and Sharding Architectures for Multi-Tenant Systems](https://medium.com/@justhamade/data-isolation-and-sharding-architectures-for-multi-tenant-systems-20584ae2bc31)
- [SQLite for Modern Apps: A Practical First Look (2026)](https://thelinuxcode.com/sqlite-for-modern-apps-a-practical-first-look-2026/)

**DuckDB Best Practices:**
- [DuckDB Multi-Database Support](https://duckdb.org/2024/01/26/multi-database-support-in-duckdb)
- [DuckDB Multi-Process Concurrency Discussion](https://github.com/duckdb/duckdb/discussions/5946)
- [Separating Storage and Compute in DuckDB](https://motherduck.com/blog/separating-storage-compute-duckdb/)

**RAG Vector Store Management:**
- [ZenML: 10 Best Vector Databases for RAG Pipelines](https://www.zenml.io/blog/vector-databases-for-rag)
- [Meilisearch: 10 Best RAG Tools and Platforms (2026)](https://www.meilisearch.com/blog/rag-tools)
- [OpenAI Vector Stores for RAG: A Practical Guide (2025)](https://www.eesel.ai/blog/openai-vector-stores)

**Corruption Recovery and Data Integrity:**
- [Zilliz: Safeguard Data Integrity - Backup and Recovery in VectorDBs](https://zilliz.com/learn/vector-database-backup-and-recovery-safeguard-data-integrity)
- [Data Quality for Vector Databases](https://www.telm.ai/blog/data-quality-for-vector-databases/)
- [Safeguarding Data Integrity: Best Practices for Backup and Recovery in Vector Databases](https://medium.com/@alexchen3292/safeguarding-data-integrity-best-practices-for-backup-and-recovery-in-vector-databases-cdebff41ad09)

**UX Best Practices:**
- [User Friendly Document Management Experience | Docupile](https://docupile.com/user-experience-of-a-document-management/)
- [10 UX Best Practices to Follow in 2026](https://uxpilot.ai/blogs/ux-best-practices)
- [Manual vs. Automated Indexing: Pros and Cons](https://indexplease.com/blog/manual-vs-automated-indexing-pros-cons/)

**Tenant Lifecycle Management:**
- [SAP: Tenant Lifecycle Management](https://architecture.learning.sap.com/docs/ref-arch/d31bedf420/3)
- [Particular: Multi-tenant Support - SQL Persistence](https://docs.particular.net/persistence/sql/multi-tenant)

---
*Feature research for: Per-Notebook Ragnar Store Management*
*Researched: 2026-02-16*
