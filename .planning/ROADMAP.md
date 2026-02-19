# Roadmap: Serapeum

## Milestones

- ✅ **v1.0 Fix + Discovery** - Phases 0-4 (shipped 2026-02-11)
- ✅ **v1.1 Quality of Life** - Phases 5-8 (shipped 2026-02-11)
- ✅ **v1.2 Stabilization** - Phases 9-10 (shipped 2026-02-12)
- ✅ **v2.0 Discovery Workflow & Output** - Phases 11-15 (shipped 2026-02-13)
- ✅ **v2.1 Polish & Analysis** - Phases 16-19 (shipped 2026-02-13)
- ✅ **v3.0 Ragnar RAG Overhaul** - Phases 20-24 (shipped 2026-02-17)
- 🚧 **v4.0 Stability + Synthesis** - Phases 25-28 (in progress)

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

<details>
<summary>✅ v3.0 Ragnar RAG Overhaul (Phases 20-24) - SHIPPED 2026-02-17</summary>

- [x] Phase 20: Foundation & Connection Safety (2/2 plans) - completed 2026-02-16
- [x] Phase 21: Store Lifecycle (2/2 plans) - completed 2026-02-17
- [x] Phase 22: Module Migration (3/3 plans) - completed 2026-02-17
- [x] Phase 23: Legacy Code Removal (1/1 plan) - completed 2026-02-17
- [x] Phase 24: Integration Testing & Cleanup (1/1 plan) - completed 2026-02-17

</details>

### 🚧 v4.0 Stability + Synthesis (In Progress)

**Milestone Goal:** Stabilize the codebase after rapid v1.0-v3.0 shipping, then deliver the highest-value AI synthesis outputs leveraging v3.0's ragnar infrastructure.

- [x] **Phase 25: Stabilize** - Fix all known bugs, resolve tech debt, land pending PRs, and polish the UI (completed 2026-02-18)
- [ ] **Phase 26: Unified Overview Preset** - Merge Summarize + Key Points into a single Overview output (#98)
- [ ] **Phase 27: Research Question Generator** - Add PICO-framed research question synthesis preset (#102)
- [ ] **Phase 28: Literature Review Table** - Add structured per-paper comparison matrix synthesis preset (#99)

## Phase Details

### Phase 25: Stabilize
**Goal**: The app is bug-free, connection-safe, and visually polished — a reliable foundation before any synthesis features are added
**Depends on**: Phase 24 (v3.0 shipped)
**Requirements**: BUGF-01, BUGF-02, BUGF-03, BUGF-04, DEBT-01, DEBT-02, DEBT-03, UIPX-01, UIPX-02, UIPX-03, UIPX-04, UIPX-05
**Success Criteria** (what must be TRUE):
  1. User sees seed paper in abstract search results without it being hidden or missing
  2. User sees only one modal when removing an abstract or blocking a journal (no repeated modals)
  3. User sees the cost tracking table update immediately after each LLM request
  4. User sees correct paper count after refreshing following one or more removals
  5. Ragnar store connections in search_chunks_hybrid are closed after use — no Windows file-lock errors block store rebuild; section_hint is encoded in newly-indexed PDF origins; dead code is removed or purposefully repurposed; duplicate toast notifications are dismissed; keywords panel is collapsible; citation network tooltip stays within graph bounds; citation network renders with correct background color; settings page two-column layout is balanced
**Plans:** 2/2 plans complete

Plans:
- [ ] 25-01-PLAN.md — Land PRs 112/115 and fix bugs (BUGF-01..04)
- [ ] 25-02-PLAN.md — Tech debt (DEBT-01..03) and UI polish (UIPX-03, UIPX-04)

### Phase 26: Unified Overview Preset
**Goal**: Users can generate a single unified Overview output that replaces the separate Summarize and Key Points presets, reducing friction for the most common synthesis workflow
**Depends on**: Phase 25
**Requirements**: SYNTH-01
**Success Criteria** (what must be TRUE):
  1. User sees an "Overview" button in both the document notebook and search notebook preset panels
  2. User clicks Overview and receives a single response combining a summary and key points in one LLM call
  3. Overview output renders correctly in the chat panel with the AI-generated content disclaimer
**Plans**: TBD

Plans:
- [ ] 26-01: Overview preset — add to generate_preset(), replace buttons in both modules, update tests

### Phase 27: Research Question Generator
**Goal**: Users can generate a structured list of research questions derived from their notebook's papers, grounded in identified gaps and framed with PICO structure
**Depends on**: Phase 26
**Requirements**: SYNTH-03
**Success Criteria** (what must be TRUE):
  1. User sees a "Research Questions" button in the search notebook preset panel
  2. User clicks Research Questions and receives 5-7 numbered questions each with a rationale tied to a paper gap
  3. Research question output renders as a numbered markdown list in the chat panel with the AI-generated content disclaimer
**Plans:** 1 plan

Plans:
- [ ] 27-01-PLAN.md — Backend function + UI wiring for Research Questions preset

### Phase 28: Literature Review Table
**Goal**: Users can generate a structured comparison matrix of their papers showing methodology, sample, findings, and limitations side-by-side — the primary structured output researchers need for literature reviews
**Depends on**: Phase 27
**Requirements**: SYNTH-02
**Success Criteria** (what must be TRUE):
  1. User sees a "Literature Review Table" button in the search notebook preset panel
  2. User clicks the button and receives a formatted table with one row per paper and five standard columns (Author/Year, Methodology, Sample, Key Findings, Limitations)
  3. Table renders with Bootstrap 5 table styling in the chat panel and is visually legible
  4. User can export the table via the existing chat export mechanism (Markdown or HTML)
  5. When the LLM produces malformed output, the user sees a clear error message rather than a crash or garbled table
**Plans**: TBD

Plans:
- [ ] 28-01: Literature Review Table — add generate_lit_review_table() to rag.R, wire button in mod_search_notebook.R, add CSS, install DT + writexl

## Progress

| Phase | Milestone | Plans | Status | Completed |
|-------|-----------|-------|--------|-----------|
| 0-4 | v1.0 | 9/9 | Complete | 2026-02-11 |
| 5-8 | v1.1 | 6/6 | Complete | 2026-02-11 |
| 9-10 | v1.2 | 2/2 | Complete | 2026-02-12 |
| 11-15 | v2.0 | 8/8 | Complete | 2026-02-13 |
| 16-19 | v2.1 | 7/7 | Complete | 2026-02-13 |
| 20-24 | v3.0 | 9/9 | Complete | 2026-02-17 |
| 25. Stabilize | v4.0 | Complete    | 2026-02-18 | - |
| 26. Unified Overview | v4.0 | 0/1 | Not started | - |
| 27. Research Question Generator | v4.0 | 0/1 | Not started | - |
| 28. Literature Review Table | v4.0 | 0/1 | Not started | - |

**Total: 41 plans complete across phases 0-24 (6 milestones shipped) + 5 plans planned for v4.0**

---
*Updated: 2026-02-19 — Phase 27 plan created*
