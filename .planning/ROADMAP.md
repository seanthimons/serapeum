# Roadmap: Serapeum

## Milestones

- ✅ **v1.0 Fix + Discovery** - Phases 0-4 (shipped 2026-02-11)
- 🚧 **v1.1 Quality of Life** - Phases 5-9 (in progress)

## Phases

<details>
<summary>✅ v1.0 Fix + Discovery (Phases 0-4) - SHIPPED 2026-02-11</summary>

- [x] Phase 0: Foundation (1/1 plans) - completed 2026-02-10
- [x] Phase 1: Seed Paper Discovery (2/2 plans) - completed 2026-02-10
- [x] Phase 2: Query Builder + Sorting (2/2 plans) - completed 2026-02-10
- [x] Phase 3: Topic Explorer (2/2 plans) - completed 2026-02-11
- [x] Phase 4: Startup Wizard + Polish (2/2 plans) - completed 2026-02-11

</details>

### 🚧 v1.1 Quality of Life (In Progress)

**Milestone Goal:** Polish existing workflows with cost visibility, better model selection, interactive keyword filtering, journal quality controls, and (stretch) bulk DOI/.bib import.

#### Phase 5: Cost Visibility
**Goal**: Users can monitor and understand LLM usage costs
**Depends on**: Phase 4
**Requirements**: COST-01, COST-02, COST-03
**Success Criteria** (what must be TRUE):
  1. User sees per-request cost displayed after each chat message
  2. User sees per-request cost displayed after embedding operations
  3. User sees running session total cost in the UI
  4. User can view cost history over time with trend visualization
  5. User can identify which operations consume the most credits
**Plans:** 2 plans

Plans:
- [x] 05-01-PLAN.md — Cost tracking backend (API usage metadata, cost_log table, helper functions)
- [x] 05-02-PLAN.md — Cost tracker UI and caller integration (update all callers, cost module, sidebar display)

#### Phase 6: Model Selection
**Goal**: Users can choose from expanded model options with visibility into pricing and capabilities
**Depends on**: Phase 5
**Requirements**: MODL-01, MODL-02
**Success Criteria** (what must be TRUE):
  1. User can select from 10+ OpenRouter models in settings
  2. User sees model context window and pricing before selection
  3. User sees current model details (provider, pricing) in settings page
  4. User can switch models without breaking existing functionality
**Plans:** 1 plan

Plans:
- [x] 06-01-PLAN.md — Dynamic chat model selector with pricing/context info and model details panel

#### Phase 7: Interactive Keywords
**Goal**: Users can interactively filter search results by clicking keyword tags
**Depends on**: Phase 6
**Requirements**: KWRD-01, KWRD-02, KWRD-03, KWRD-04
**Success Criteria** (what must be TRUE):
  1. User can click a keyword tag to include it as a search filter
  2. User can click a keyword tag to exclude it from results
  3. User sees visual distinction (color/icon) for included, excluded, and neutral tags
  4. User can filter currently displayed results in real-time without re-running search
  5. User can clear keyword filters to return to original results
**Plans:** 1 plan

Plans:
- [x] 07-01-PLAN.md — Keyword filter module with tri-state tags and search notebook integration

#### Phase 8: Journal Quality Controls
**Goal**: Users can identify and filter out predatory journals from search results
**Depends on**: Phase 7
**Requirements**: JRNL-01, JRNL-02, JRNL-03, JRNL-04
**Success Criteria** (what must be TRUE):
  1. Search results display predatory journal/publisher warnings with visual badges
  2. User can toggle predatory journal filter on/off (default: off, showing all results with warnings)
  3. User can add journals to a personal blocklist
  4. User can view and remove journals from their blocklist
  5. User's blocklist persists across sessions in local database
**Plans:** 2 plans

Plans:
- [x] 08-01-PLAN.md — Blocked journals DB migration + journal quality filter module (mod_journal_filter.R)
- [x] 08-02-PLAN.md — Search notebook integration, block action, blocklist management modal

#### Phase 9: Bulk Import (Stretch)
**Goal**: Users can import multiple papers via DOI list or .bib files for notebooks and discovery seeding
**Depends on**: Phase 8
**Requirements**: BULK-01, BULK-02, BULK-03, BULK-04, BULK-05
**Success Criteria** (what must be TRUE):
  1. User can paste multiple DOIs (line-separated) to look up papers in batch
  2. User can upload a .bib file and see imported papers parsed correctly
  3. User can add imported papers to an existing or new search notebook
  4. User can add imported papers to an existing or new document notebook
  5. User can use imported papers as seeds for discovery (related papers lookup)
**Plans**: TBD

Plans:
- [ ] 09-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 5 → 6 → 7 → 8 → 9

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 0. Foundation | v1.0 | 1/1 | Complete | 2026-02-10 |
| 1. Seed Paper Discovery | v1.0 | 2/2 | Complete | 2026-02-10 |
| 2. Query Builder + Sorting | v1.0 | 2/2 | Complete | 2026-02-10 |
| 3. Topic Explorer | v1.0 | 2/2 | Complete | 2026-02-11 |
| 4. Startup Wizard + Polish | v1.0 | 2/2 | Complete | 2026-02-11 |
| 5. Cost Visibility | v1.1 | 2/2 | Complete | 2026-02-11 |
| 6. Model Selection | v1.1 | 1/1 | Complete | 2026-02-11 |
| 7. Interactive Keywords | v1.1 | 1/1 | Complete | 2026-02-11 |
| 8. Journal Quality Controls | v1.1 | 2/2 | Complete | 2026-02-11 |
| 9. Bulk Import (Stretch) | v1.1 | 0/0 | Not started | - |

---
*Updated: 2026-02-11 after Phase 8 execution complete*
