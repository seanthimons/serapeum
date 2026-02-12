# Roadmap: Serapeum

## Milestones

- ✅ **v1.0 Fix + Discovery** - Phases 0-4 (shipped 2026-02-11)
- ✅ **v1.1 Quality of Life** - Phases 5-8 (shipped 2026-02-11)
- 🚧 **v1.2 Stabilization** - Phases 9-10 (in progress)

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

### 🚧 v1.2 Stabilization (In Progress)

**Milestone Goal:** Fix critical bugs and polish UI elements for stable production use.

#### Phase 9: Bug Fixes

**Goal**: OpenAlex and OpenRouter API interactions work reliably without errors

**Depends on**: Nothing (independent fixes)

**Requirements**: BUGF-01, BUGF-02, BUGF-03

**Success Criteria** (what must be TRUE):
  1. User can browse OpenAlex topics without encountering 401 authentication errors
  2. User sees clear, actionable error messages (not raw HTTP codes) when API calls fail
  3. User can switch between search notebook and other tabs without triggering duplicate OpenAlex requests

**Plans:** 1 plan

Plans:
- [x] 09-01-PLAN.md — Fix OpenAlex 401 auth, friendly error toasts, prevent duplicate requests on tab navigation - completed 2026-02-12

#### Phase 10: UI Polish

**Goal**: Search notebook interface elements display correctly and provide better UX

**Depends on**: Nothing (independent of Phase 9)

**Requirements**: UIPX-01, UIPX-02

**Success Criteria** (what must be TRUE):
  1. User can collapse/expand the Journal Quality filter card to reclaim vertical space when not needed
  2. User sees all badges (year, type, access, journal, block journal) aligned consistently on the same baseline in abstract detail view

**Plans:** 1 plan

Plans:
- [ ] 10-01-PLAN.md — Collapsible Journal Quality card and badge alignment in abstract detail view

## Progress

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
| 9. Bug Fixes | v1.2 | 1/1 | Complete | 2026-02-12 |
| 10. UI Polish | v1.2 | 0/1 | Not started | - |

---
*Updated: 2026-02-12 after Phase 10 planning complete*
