# Roadmap: Serapeum

## Milestones

- ✅ **v1.0 Fix + Discovery** - Phases 0-4 (shipped 2026-02-11)
- ✅ **v1.1 Quality of Life** - Phases 5-8 (shipped 2026-02-11)
- ✅ **v1.2 Stabilization** - Phases 9-10 (shipped 2026-02-12)
- ✅ **v2.0 Discovery Workflow & Output** - Phases 11-15 (shipped 2026-02-13)
- 🚧 **v2.1 Polish & Analysis** - Phases 16-19 (in progress)

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

### 🚧 v2.1 Polish & Analysis (In Progress)

**Milestone Goal:** Clean up UI rough edges, add interactive year filtering across discovery modes, and introduce conclusion synthesis with future research directions.

#### Phase 16: UI Polish
**Goal**: App has consistent icons, favicon, and optimized sidebar layout
**Depends on**: Nothing (isolated UI changes)
**Requirements**: UIPX-01, UIPX-02, UIPX-03
**Success Criteria** (what must be TRUE):
  1. Synthesis preset buttons display distinct, meaningful icons
  2. Browser tab shows Serapeum favicon
  3. Sidebar uses space efficiently with cost link relocated and redundant elements removed
**Plans**: 1 plan

Plans:
- [x] 16-01-PLAN.md — Add preset icons, favicon, and optimize sidebar layout (completed 2026-02-13)

#### Phase 17: Interactive Year Range Slider-Filter
**Goal**: Users can filter papers by year range with histogram preview across search and citation modes
**Depends on**: Phase 16 (UI foundation)
**Requirements**: YEAR-01, YEAR-02, YEAR-03, YEAR-04
**Success Criteria** (what must be TRUE):
  1. User can adjust year range slider in search notebooks and see filtered results
  2. User sees histogram showing paper distribution by year on the slider
  3. User can filter citation network nodes using the same year slider pattern
  4. Papers with unknown publication years display an indicator and can be included/excluded via checkbox
  5. Year filter updates are debounced to prevent UI freezes during drag
**Plans**: TBD

Plans:
- [ ] 17-01: TBD

#### Phase 18: Progress Modal with Cancellation
**Goal**: Long-running citation network operations show progress and allow cancellation with partial results
**Depends on**: Phase 17 (establishes cross-module patterns)
**Requirements**: PROG-01, PROG-02, PROG-03
**Success Criteria** (what must be TRUE):
  1. User sees progress modal with live status during citation network build
  2. User can click stop button to cancel citation network build mid-operation
  3. Cancelled builds display accumulated nodes collected before cancellation
  4. Progress modal shows granular status updates
**Plans**: TBD

Plans:
- [ ] 18-01: TBD

#### Phase 19: Conclusion Synthesis
**Goal**: Users can synthesize research conclusions and future directions across papers with RAG-targeted retrieval
**Depends on**: Phase 18 (interrupt infrastructure for long synthesis operations)
**Requirements**: SYNTH-01, SYNTH-02, SYNTH-03, SYNTH-04, SYNTH-05
**Success Criteria** (what must be TRUE):
  1. User can trigger conclusion synthesis from search notebook chat via preset button
  2. User can trigger conclusion synthesis from document notebook chat via preset button
  3. Synthesis output aggregates research positions across papers
  4. Synthesis proposes future research directions based on identified gaps
  5. All synthesis outputs display prominent disclaimers about AI-generated content
**Plans**: TBD

Plans:
- [ ] 19-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 16 → 17 → 18 → 19

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
| 10. UI Polish | v1.2 | 1/1 | Complete | 2026-02-12 |
| 11. DOI Storage & Migration | v2.0 | 2/2 | Complete | 2026-02-12 |
| 12. Citation Network Visualization | v2.0 | 2/2 | Complete | 2026-02-12 |
| 13. Export-to-Seed Workflow | v2.0 | 1/1 | Complete | 2026-02-12 |
| 14. Citation Export | v2.0 | 2/2 | Complete | 2026-02-12 |
| 15. Synthesis Export | v2.0 | 1/1 | Complete | 2026-02-12 |
| 16. UI Polish | v2.1 | 1/1 | Complete | 2026-02-13 |
| 17. Year Range Filter | v2.1 | 0/? | Not started | - |
| 18. Progress Modal | v2.1 | 0/? | Not started | - |
| 19. Conclusion Synthesis | v2.1 | 0/? | Not started | - |

---
*Updated: 2026-02-13 — Phase 16 complete (1/1 plans)*
