# Roadmap: Serapeum Fix + Discovery Milestone

## Overview

This milestone transforms Serapeum from a single-path search tool into a multi-entry discovery platform. It starts by fixing a critical embedding bug and laying database infrastructure, then builds three discovery modes (seed paper, query builder, topic explorer), and finishes by wiring them together through a startup wizard. Each phase delivers a complete, testable capability.

## Phases

- [x] **Phase 0: Foundation** - Database migration versioning and topics table schema
- [x] **Phase 1: Seed Paper Discovery** - Find related papers starting from a known paper, fix abstract embedding
- [x] **Phase 2: Query Builder + Sorting** - LLM-assisted search query construction with rich result sorting
- [x] **Phase 3: Topic Explorer** - Browse OpenAlex topic hierarchy to discover papers by research area
- [x] **Phase 4: Startup Wizard + Polish** - Guided onboarding hub routing to discovery modes, slide citation fix

## Phase Details

### Phase 0: Foundation
**Goal**: Database can safely evolve and new discovery features have schema support
**Depends on**: Nothing (first phase)
**Requirements**: INFRA-01, INFRA-02
**Complexity**: S
**Success Criteria** (what must be TRUE):
  1. App startup applies pending migrations automatically without user action
  2. Existing databases from before this milestone upgrade without data loss
  3. Topics table exists in DuckDB with hierarchy columns (domain, field, subfield, topic)
  4. Schema version is queryable via schema_migrations table (DuckDB does not support PRAGMA user_version)
**Risk flags**: Low risk. Standard patterns documented in CONCERNS.md and research.
**Plans:** 1 plan

Plans:
- [x] 00-01-PLAN.md -- Migration versioning system and topics table

### Phase 1: Seed Paper Discovery
**Goal**: Users can start from a known paper and discover related work through citation relationships
**Depends on**: Phase 0 (migration system for any schema additions)
**Requirements**: DISC-01, DISC-02
**Complexity**: L
**Success Criteria** (what must be TRUE):
  1. User can enter a DOI or paper title and see the paper's metadata (title, authors, year, abstract)
  2. User can fetch papers that cite, are cited by, or are related to the seed paper
  3. Related papers populate a search notebook where existing filtering and quality checks apply
  4. "Embed Papers" button in search notebooks successfully embeds abstracts (not just documents)
  5. RAG chat in search notebooks returns relevant results from embedded abstracts
**Risk flags**: DISC-01 (embedding fix) touches fragile ragnar fallback chain. Test both ragnar and legacy paths. Rate limit tracking needed for OpenAlex citation queries.
**Plans:** 2 plans

Plans:
- [x] 01-01-PLAN.md -- Fix abstract embedding bug (#55) with tests
- [x] 01-02-PLAN.md -- Seed paper lookup, citation API, and discovery module

### Phase 2: Query Builder + Sorting
**Goal**: Users can describe research interests in natural language and get validated OpenAlex queries, with sortable results
**Depends on**: Phase 1 (validates producer-consumer architecture between discovery modules and search notebook)
**Requirements**: DISC-03, DISC-06
**Complexity**: M
**Success Criteria** (what must be TRUE):
  1. User can type a natural language research question and receive a generated OpenAlex query
  2. Generated query is shown to user for review before execution
  3. LLM-generated filters are validated against an allowlist (invalid filters rejected with explanation)
  4. Search results can be sorted by FWCI, citation count, and outgoing citation count
  5. Papers with missing metrics display gracefully (no raw "NA" values)
**Risk flags**: LLM prompt engineering for filter generation needs empirical validation. Research-phase recommended during planning to test prompt with 20-30 sample queries.
**Plans:** 2 plans

Plans:
- [x] 02-01-PLAN.md -- Rich sorting for search results (#54)
- [x] 02-02-PLAN.md -- LLM query builder module with filter validation (#10)

### Phase 3: Topic Explorer
**Goal**: Users can browse research areas hierarchically and discover papers within topics
**Depends on**: Phase 0 (topics table), Phase 2 (reuses filter UI patterns)
**Requirements**: DISC-04
**Complexity**: M
**Success Criteria** (what must be TRUE):
  1. User can browse OpenAlex topics in a 4-level hierarchy (domain > field > subfield > topic)
  2. Selecting a topic shows papers filtered by that topic in a search notebook
  3. Topic data is cached locally in DuckDB so browsing works without repeated API calls
  4. Topic search/filter is available to narrow the hierarchy when browsing
**Risk flags**: API-intensive during initial topic taxonomy fetch. Need pagination and caching strategy. Topic confidence thresholds should filter low-quality matches.
**Plans:** 2 plans

Plans:
- [x] 03-01-PLAN.md -- OpenAlex topics API integration and local DuckDB caching
- [x] 03-02-PLAN.md -- Topic explorer module with hierarchical browsing UI

### Phase 4: Startup Wizard + Polish
**Goal**: New users get a guided entry point that routes them to the right discovery mode
**Depends on**: Phases 1, 2, 3 (all discovery modules must exist before the wizard can route to them)
**Requirements**: DISC-05, DISC-07
**Complexity**: M
**Success Criteria** (what must be TRUE):
  1. First-time users see a wizard offering three paths: seed paper, topic browsing, or search query
  2. Each wizard path routes to the corresponding discovery module and creates a notebook
  3. Wizard can be skipped, and skip preference persists across sessions
  4. Returning users go directly to their notebook list (no wizard)
  5. Quarto slide citations render at appropriate size without overflow
**Risk flags**: Low risk. Wizard is orchestration over existing modules. Slide fix (#51) is independent and small.
**Plans:** 2 plans

Plans:
- [x] 04-01-PLAN.md -- Startup wizard modal with localStorage persistence and routing (#43)
- [x] 04-02-PLAN.md -- Fix slide citation CSS injection (#51)

## Phase Ordering Rationale

- **Phase 0 first**: Cannot safely add schema changes (topics table, wizard state) without migration versioning. Foundation before features.
- **Phase 1 before other features**: Embedding fix (#55) unblocks all search notebook testing. Seed paper validates the producer-consumer architecture (discovery module outputs query params to search notebook). If this pattern fails, we catch it early.
- **Phase 2 after Phase 1**: Reuses the validated architecture. Query builder is the simplest discovery module (no new API endpoints beyond existing search). Rich sorting is low-effort and improves all search results.
- **Phase 3 after Phase 2**: Most API-intensive discovery mode. Deferred until architecture is proven. Reuses patterns from Phase 1 (OpenAlex API extensions) and Phase 2 (filter UI).
- **Phase 4 last**: Wizard orchestrates all discovery modules -- cannot exist before them. Slide fix (#51) is independent and bundled here as a quick win.

## Progress

**Execution Order:** 0 > 1 > 2 > 3 > 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 0. Foundation | 1/1 | ✓ Complete | 2026-02-10 |
| 1. Seed Paper Discovery | 2/2 | ✓ Complete | 2026-02-10 |
| 2. Query Builder + Sorting | 2/2 | ✓ Complete | 2026-02-10 |
| 3. Topic Explorer | 2/2 | ✓ Complete | 2026-02-11 |
| 4. Startup Wizard + Polish | 2/2 | ✓ Complete | 2026-02-11 |

---
*Created: 2026-02-10*
