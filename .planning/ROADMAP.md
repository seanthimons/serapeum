# Roadmap: Serapeum

## Milestones

- ✅ **v1.0 Fix + Discovery** - Phases 0-4 (shipped 2026-02-11)
- ✅ **v1.1 Quality of Life** - Phases 5-8 (shipped 2026-02-11)
- ✅ **v1.2 Stabilization** - Phases 9-10 (shipped 2026-02-12)
- ✅ **v2.0 Discovery Workflow & Output** - Phases 11-15 (shipped 2026-02-13)
- ✅ **v2.1 Polish & Analysis** - Phases 16-19 (shipped 2026-02-13)
- 🚧 **v3.0 Ragnar RAG Overhaul** - Phases 20-24 (in progress)

## Phases

<details>
<summary>✅ v1.0 Fix + Discovery (Phases 0-4) - SHIPPED 2026-02-11</summary>

- [x] Phase 0: Foundation (1/1 plans) - completed 2026-02-10
- [x] Phase 1: Seed Paper Discovery (2/2 plans) - completed 2026-02-10
- [x] Phase 2: Query Builder + Sorting (2/2 plans) - completed 2026-02-10
- [x] Phase 3: Topic Explorer (2/2 plans) - completed 2026-02-11
- [x] Phase 4: Startup Wizard + Polish (2/2 plans) - completed 2026-02-11

</details>

<details>
<summary>✅ v1.1 Quality of Life (Phases 5-8) - SHIPPED 2026-02-11</summary>

- [x] Phase 5: Cost Visibility (2/2 plans) - completed 2026-02-11
- [x] Phase 6: Model Selection (1/1 plan) - completed 2026-02-11
- [x] Phase 7: Interactive Keywords (1/1 plan) - completed 2026-02-11
- [x] Phase 8: Journal Quality Controls (2/2 plans) - completed 2026-02-11

</details>

<details>
<summary>✅ v1.2 Stabilization (Phases 9-10) - SHIPPED 2026-02-12</summary>

- [x] Phase 9: Bug Fixes (1/1 plan) - completed 2026-02-12
- [x] Phase 10: UI Polish (1/1 plan) - completed 2026-02-12

</details>

<details>
<summary>✅ v2.0 Discovery Workflow & Output (Phases 11-15) - SHIPPED 2026-02-13</summary>

- [x] Phase 11: DOI Storage & Migration Infrastructure (2/2 plans) - completed 2026-02-12
- [x] Phase 12: Citation Network Visualization (2/2 plans) - completed 2026-02-12
- [x] Phase 13: Export-to-Seed Workflow (1/1 plan) - completed 2026-02-12
- [x] Phase 14: Citation Export (2/2 plans) - completed 2026-02-12
- [x] Phase 15: Synthesis Export (1/1 plan) - completed 2026-02-12

</details>

<details>
<summary>✅ v2.1 Polish & Analysis (Phases 16-19) - SHIPPED 2026-02-13</summary>

- [x] Phase 16: UI Polish (1/1 plan) - completed 2026-02-13
- [x] Phase 17: Year Range Slider-Filter (2/2 plans) - completed 2026-02-13
- [x] Phase 18: Progress Modal with Cancellation (2/2 plans) - completed 2026-02-13
- [x] Phase 19: Conclusion Synthesis (2/2 plans) - completed 2026-02-13

</details>

### 🚧 v3.0 Ragnar RAG Overhaul (In Progress)

**Milestone Goal:** Replace the legacy embedding/retrieval system with ragnar as the sole RAG backend, using per-notebook vector stores for clean isolation and optimal retrieval.

- [x] **Phase 20: Foundation & Connection Safety** - Per-notebook path helpers, metadata encoding, version checks, connection lifecycle (completed 2026-02-16)
- [ ] **Phase 21: Store Lifecycle** - Automatic creation on first content, deletion cascade, rebuild capability, corruption recovery
- [ ] **Phase 22: Module Migration** - Switch document and search notebook modules to per-notebook ragnar stores
- [ ] **Phase 23: Legacy Code Removal** - Remove ragnar_available conditionals, cosine similarity fallback, digest dependency
- [ ] **Phase 24: Integration Testing & Cleanup** - End-to-end tests, shared store deletion

## Phase Details

### Phase 20: Foundation & Connection Safety
**Goal**: Establish deterministic path construction, metadata encoding, and connection lifecycle patterns for per-notebook ragnar stores
**Depends on**: Nothing (first phase of v3.0)
**Requirements**: FNDTN-01, FNDTN-02, FNDTN-03, TEST-02
**Success Criteria** (what must be TRUE):
  1. Every notebook ID produces a deterministic path `data/ragnar/{notebook_id}.duckdb` without database lookups
  2. Section_hint metadata survives round-trip through ragnar's origin field encoding/decoding
  3. App detects incompatible ragnar versions on startup and warns user before attempting store operations
  4. Ragnar store connections automatically close on error, session end, and context exit via explicit cleanup hooks
**Plans**: 2 plans

Plans:
- [ ] 20-01-PLAN.md — Path helper + metadata encode/decode (TDD)
- [ ] 20-02-PLAN.md — Version check, connection lifecycle, directory creation

### Phase 21: Store Lifecycle
**Goal**: Per-notebook ragnar stores are created automatically on first content, deleted when notebook is deleted, and can be rebuilt on corruption
**Depends on**: Phase 20
**Requirements**: LIFE-01, LIFE-02, LIFE-03, LIFE-04
**Success Criteria** (what must be TRUE):
  1. User uploads PDF to new notebook and ragnar store is created automatically in background without manual setup
  2. User embeds abstract in search notebook and ragnar store is created automatically on first embed
  3. User deletes notebook and its ragnar store file is removed from disk within same transaction
  4. User sees "Re-build Index" button when ragnar store is missing or corrupted, can rebuild with progress feedback
**Plans**: 2 plans

Plans:
- [ ] 21-01-PLAN.md — Core lifecycle functions, deletion cascade, orphan cleanup
- [ ] 21-02-PLAN.md — Corruption detection, integrity check on open, rebuild with progress

### Phase 22: Module Migration
**Goal**: Document and search notebook modules use per-notebook ragnar stores for all RAG operations, eliminating cross-notebook pollution
**Depends on**: Phase 21
**Requirements**: (Implicit - enables per-notebook isolation)
**Success Criteria** (what must be TRUE):
  1. User uploads PDF to notebook A and chats with it, sees only chunks from notebook A in retrieval results
  2. User switches to notebook B and retrieval automatically uses notebook B's store without filtering
  3. User embeds abstracts in search notebook and section-targeted synthesis retrieves correct chunks using encoded section_hint
  4. User can work with multiple notebooks simultaneously without cross-contamination of retrieval results
**Plans**: TBD

Plans:
- [ ] 22-01: TBD

### Phase 23: Legacy Code Removal
**Goal**: Remove all legacy embedding and retrieval code paths, making ragnar the sole RAG backend
**Depends on**: Phase 22
**Requirements**: LEGC-01, LEGC-02, LEGC-04
**Success Criteria** (what must be TRUE):
  1. No ragnar_available() conditional branches remain in codebase - all RAG paths use ragnar directly
  2. No manual get_embeddings() calls or cosine similarity functions exist in pdf.R or rag.R
  3. Digest package is removed from dependencies and no code references digest::digest()
  4. Codebase search for "ragnar_available", "cosine", "get_embeddings" returns zero results in R files
**Plans**: TBD

Plans:
- [ ] 23-01: TBD

### Phase 24: Integration Testing & Cleanup
**Goal**: End-to-end integration tests validate per-notebook workflow, shared store is deleted after migration
**Depends on**: Phase 23
**Requirements**: TEST-01, LEGC-03
**Success Criteria** (what must be TRUE):
  1. Integration test creates notebook, uploads PDF, embeds chunks, queries ragnar store, and verifies correct retrieval - all passing
  2. Integration test validates section_hint encoding survives round-trip from upload through retrieval
  3. Shared ragnar store file `data/serapeum.ragnar.duckdb` no longer exists on disk after app startup detects per-notebook stores
  4. App startup checks for legacy shared store, logs deletion, and proceeds normally without errors
**Plans**: TBD

Plans:
- [ ] 24-01: TBD

## Progress

| Phase | Milestone | Plans | Status | Completed |
|-------|-----------|-------|--------|-----------|
| 0-4 | v1.0 | 9/9 | Complete | 2026-02-11 |
| 5-8 | v1.1 | 6/6 | Complete | 2026-02-11 |
| 9-10 | v1.2 | 2/2 | Complete | 2026-02-12 |
| 11-15 | v2.0 | 8/8 | Complete | 2026-02-13 |
| 16-19 | v2.1 | 7/7 | Complete | 2026-02-13 |
| 20. Foundation & Connection Safety | v3.0 | Complete    | 2026-02-16 | - |
| 21. Store Lifecycle | v3.0 | 0/2 | Not started | - |
| 22. Module Migration | v3.0 | 0/? | Not started | - |
| 23. Legacy Code Removal | v3.0 | 0/? | Not started | - |
| 24. Integration Testing & Cleanup | v3.0 | 0/? | Not started | - |

**Total: 34 plans across 21 phases (5 milestones shipped), 5 phases planned for v3.0**

---
*Updated: 2026-02-16 — Phase 21 planned (2 plans)*
