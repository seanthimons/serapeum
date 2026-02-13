# Roadmap: Serapeum

## Milestones

- ✅ **v1.0 Fix + Discovery** - Phases 0-4 (shipped 2026-02-11)
- ✅ **v1.1 Quality of Life** - Phases 5-8 (shipped 2026-02-11)
- ✅ **v1.2 Stabilization** - Phases 9-10 (shipped 2026-02-12)
- 🚧 **v2.0 Discovery Workflow & Output** - Phases 11-15 (in progress)

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

### 🚧 v2.0 Discovery Workflow & Output (In Progress)

**Milestone Goal:** Make discovery modes fluid and interconnected, add DOI visibility, and enable research output export (citations, synthesis).

#### Phase 11: DOI Storage & Migration Infrastructure

**Goal**: Every paper in the database has DOI metadata, enabling downstream export and seeded search workflows

**Depends on**: Nothing (foundation for all v2.0 features)

**Issues Addressed**: #66 (DOI on abstract preview)

**Success Criteria** (what must be TRUE):
  1. User can see DOI displayed in abstract preview for newly fetched papers
  2. User with existing database (1000+ papers) sees DOI backfilled automatically without manual intervention
  3. User sees graceful degradation (citation key from title+year) when DOI is unavailable for legacy papers
  4. Database migration runs successfully on startup, preserving all existing data

**Plans:** 2 plans

Plans:
- [ ] 11-01: Migration versioning infrastructure, DOI column addition, and backfill strategy
- [ ] 11-02: DOI display in abstract preview UI with graceful degradation for NULL values

#### Phase 12: Citation Network Visualization

**Goal**: Users can visually explore citation relationships to discover related papers through interactive network graphs

**Depends on**: Phase 11 (requires DOI for OpenAlex citation API calls)

**Issues Addressed**: #53 (Citation network graph for paper discovery)

**Success Criteria** (what must be TRUE):
  1. User can generate a citation network graph from any abstract detail view with one click
  2. User can click a node in the citation network to view that paper's abstract details
  3. User sees network graphs limited to 100 nodes maximum to prevent performance issues
  4. User sees citation graphs load within 5 seconds for papers with 500+ citations (via depth/breadth limits)
  5. User can pan, zoom, and interact with the network graph smoothly without browser lag

**Plans:** 2 plans

Plans:
- [x] 12-01: visNetwork integration, citation fetching utility with depth/breadth limits, and cycle detection
- [x] 12-02: Citation network module UI with interactive controls and graph caching

#### Phase 13: Export-to-Seed Workflow

**Goal**: Users can seamlessly transition from viewing an abstract to launching a new seeded search, creating fluid discovery workflows

**Depends on**: Phase 11 (requires DOI for seeded search)

**Issues Addressed**: #67 (Export abstract to seeded paper search), #71 (Seeded search same view as abstract preview)

**Success Criteria** (what must be TRUE):
  1. User can click "Use as Seed" button from abstract detail view to pre-fill a new seeded search
  2. User navigates to discovery view with DOI pre-filled and ready to execute
  3. User's current search results persist when navigating to seed search and back
  4. User sees consistent search notebook UI for seeded searches (same filters, sorting as keyword search)

**Plans:** 1 plan

Plans:
- [x] 13-01: Cross-module communication for seed requests and navigation to discovery view with state preservation

#### Phase 14: Citation Export

**Goal**: Users can export search results as BibTeX or CSV for use in reference managers and spreadsheet analysis

**Depends on**: Phase 11 (requires DOI for citation metadata)

**Issues Addressed**: #64 (Citation export)

**Success Criteria** (what must be TRUE):
  1. User can download search results as BibTeX file that imports cleanly into Zotero/Mendeley
  2. User can download search results as CSV file for spreadsheet analysis
  3. User sees unique citation keys generated (author_year with suffix for duplicates) without collisions
  4. User with papers containing special characters (accents, symbols) sees correct encoding in exported files
  5. User can export papers without DOI and sees graceful fallback citation keys (title+year based)

**Plans:** 2 plans

Plans:
- [x] 14-01: BibTeX formatter with LaTeX escaping, UTF-8 encoding, and unique citation key generation
- [x] 14-02: CSV export formatter and download UI with format selection dropdown

#### Phase 15: Synthesis Export

**Goal**: Users can export chat summaries and synthesis outputs as Markdown or HTML for external use

**Depends on**: Nothing (independent text export feature)

**Issues Addressed**: #49 (Export synthesis outputs)

**Success Criteria** (what must be TRUE):
  1. User can download chat conversation as Markdown file from document or search notebook
  2. User can download chat conversation as HTML file with basic styling
  3. User sees full conversation (user + assistant messages) with timestamps in exported file
  4. User can open exported HTML file in any browser and see readable formatted output

**Plans:** 1 plan

Plans:
- [ ] 15-01: Synthesis export formatter (Markdown/HTML) and download button in chat interface

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
| 10. UI Polish | v1.2 | 1/1 | Complete | 2026-02-12 |
| 11. DOI Storage & Migration | v2.0 | 2/2 | Complete | 2026-02-12 |
| 12. Citation Network Visualization | v2.0 | 2/2 | Complete | 2026-02-12 |
| 13. Export-to-Seed Workflow | v2.0 | 1/1 | Complete | 2026-02-12 |
| 14. Citation Export | v2.0 | 2/2 | Complete | 2026-02-12 |
| 15. Synthesis Export | v2.0 | 0/1 | Not started | - |

---
*Updated: 2026-02-12 — v2.0 Discovery Workflow & Output milestone started*
