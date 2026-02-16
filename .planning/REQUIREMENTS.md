# Requirements: Serapeum

**Defined:** 2026-02-16
**Core Value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings

## v3.0 Requirements

Requirements for ragnar RAG overhaul. Each maps to roadmap phases.

### Store Foundation

- [ ] **FNDTN-01**: Per-notebook ragnar store paths use deterministic `data/ragnar/{notebook_id}.duckdb` convention
- [ ] **FNDTN-02**: Section_hint metadata is encoded in ragnar's origin field and decoded on retrieval
- [ ] **FNDTN-03**: App checks ragnar version on startup and warns if incompatible

### Store Lifecycle

- [ ] **LIFE-01**: Ragnar store is created automatically on first PDF upload or abstract embed for a notebook
- [ ] **LIFE-02**: Ragnar store file is deleted when its notebook is deleted
- [ ] **LIFE-03**: User can re-build a notebook's search index via a "Re-build Index" button
- [ ] **LIFE-04**: Corrupted or missing ragnar store is detected on connect and user is prompted to re-build

### Legacy Removal

- [ ] **LEGC-01**: All `ragnar_available()` conditional branches are removed — ragnar is the sole RAG path
- [ ] **LEGC-02**: Legacy cosine similarity search and manual `get_embeddings()` calls are removed
- [ ] **LEGC-03**: Shared `data/serapeum.ragnar.duckdb` store is deleted on app startup if per-notebook stores exist
- [ ] **LEGC-04**: digest package dependency is removed

### Testing & Reliability

- [ ] **TEST-01**: Integration tests cover upload PDF → chunk → embed → query with per-notebook stores
- [ ] **TEST-02**: Ragnar store connections use explicit `on.exit()` cleanup and `session$onSessionEnded()` lifecycle management

## Future Requirements

Deferred to future release. Tracked but not in current roadmap.

### Store Management

- **MGMT-01**: Per-notebook ragnar store file size visible in UI
- **MGMT-02**: Health check on app startup detects corrupted stores with non-blocking toast
- **MGMT-03**: Last-indexed timestamp displayed per notebook

### Advanced RAG

- **ARAG-01**: Incremental re-embedding — only re-embed changed/new content
- **ARAG-02**: Export/import notebook with ragnar store for portability
- **ARAG-03**: Parallel re-embedding during re-build for faster processing

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Cross-notebook search | Contradicts per-notebook isolation goal |
| Manual store path configuration | Support burden, broken paths |
| Shared store with namespace filtering | Defeats isolation, corruption breaks all notebooks |
| Real-time background re-indexing | PDFs are immutable after upload, no clear trigger |
| Migration script for shared store | User decided to delete and re-embed fresh |
| Ragnar version pinning per notebook | Over-engineering, single version app-wide is sufficient |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FNDTN-01 | Phase 20 | Pending |
| FNDTN-02 | Phase 20 | Pending |
| FNDTN-03 | Phase 20 | Pending |
| TEST-02 | Phase 20 | Pending |
| LIFE-01 | Phase 21 | Pending |
| LIFE-02 | Phase 21 | Pending |
| LIFE-03 | Phase 21 | Pending |
| LIFE-04 | Phase 21 | Pending |
| (Module Migration) | Phase 22 | Pending |
| LEGC-01 | Phase 23 | Pending |
| LEGC-02 | Phase 23 | Pending |
| LEGC-04 | Phase 23 | Pending |
| TEST-01 | Phase 24 | Pending |
| LEGC-03 | Phase 24 | Pending |

**Coverage:**
- v3.0 requirements: 13 total
- Mapped to phases: 13/13 ✓
- Unmapped: 0

**Notes:**
- Phase 22 has no explicit requirements but enables per-notebook isolation (critical for all subsequent phases)
- TEST-02 woven into Phase 20 (connection lifecycle patterns established early)
- LEGC-03 (destructive shared store deletion) deferred to final phase for safety

---
*Requirements defined: 2026-02-16*
*Last updated: 2026-02-16 after roadmap creation*
