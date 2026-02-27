# Roadmap: Serapeum

## Milestones

- ✅ **v1.0 Fix + Discovery** - Phases 0-4 (shipped 2026-02-11)
- ✅ **v1.1 Quality of Life** - Phases 5-8 (shipped 2026-02-11)
- ✅ **v1.2 Stabilization** - Phases 9-10 (shipped 2026-02-12)
- ✅ **v2.0 Discovery Workflow & Output** - Phases 11-15 (shipped 2026-02-13)
- ✅ **v2.1 Polish & Analysis** - Phases 16-19 (shipped 2026-02-13)
- ✅ **v3.0 Ragnar RAG Overhaul** - Phases 20-24 (shipped 2026-02-17)
- ✅ **v4.0 Stability + Synthesis** - Phases 25-28 (shipped 2026-02-22)
- ✅ **v5.0 Fix Document Embeddings** - Phase 29 (shipped 2026-02-22)
- ✅ **v6.0 Dark Mode + UI Polish** - Phases 30-32 (shipped 2026-02-25)
- 🚧 **v7.0 Citation Audit + Quick Wins** - Phases 33-39 (in progress)

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

<details>
<summary>✅ v4.0 Stability + Synthesis (Phases 25-28) - SHIPPED 2026-02-22</summary>

- [x] Phase 25: Stabilize (2/2 plans) - completed 2026-02-18
- [x] Phase 26: Unified Overview Preset (2/2 plans) - completed 2026-02-19
- [x] Phase 27: Research Question Generator (1/1 plan) - completed 2026-02-19
- [x] Phase 28: Literature Review Table (1/1 plan) - completed 2026-02-19

See [v4.0-ROADMAP.md](milestones/v4.0-ROADMAP.md) for full details.

</details>

<details>
<summary>✅ v5.0 Fix Document Embeddings (Phase 29) - SHIPPED 2026-02-22</summary>

- [x] Phase 29: Fix Ragnar Embed Closure Bug (1/1 plan) - completed 2026-02-22

See [v5.0-ROADMAP.md](milestones/v5.0-ROADMAP.md) for full details.

</details>

<details>
<summary>✅ v6.0 Dark Mode + UI Polish (Phases 30-32) - SHIPPED 2026-02-25</summary>

- [x] Phase 30: Core Dark Mode Palette (2/2 plans) - completed 2026-02-22
- [x] Phase 31: Component Styling & Visual Consistency (5/5 plans) - completed 2026-02-22
- [x] Phase 32: Testing & Polish (1/1 plan) - completed 2026-02-22

See [v6.0-ROADMAP.md](milestones/v6.0-ROADMAP.md) for full details.

</details>

### 🚧 v7.0 Citation Audit + Quick Wins (In Progress)

**Milestone Goal:** Add citation audit, bulk import workflows, and slide prompt healing.

**Overview:** v7.0 adds citation audit and bulk import capabilities to Serapeum's research workflow. Starting from foundational DOI parsing utilities (Phase 33), we build up to OpenAlex batch API support (Phase 34), then deliver three major user-facing features: bulk DOI/CSV/BibTeX import (Phases 35-36), citation gap detection (Phase 37), and select-all batch workflows (Phase 38). The milestone completes with slide generation prompt healing (Phase 39) for improved synthesis quality. This architecture-first approach ensures rate limiting and batch operations work reliably before exposing them to users, mitigating the highest risks (OpenAlex 429 errors, BibTeX parsing failures) at the infrastructure layer.

- [x] **Phase 33: DOI Parsing Utilities** - Foundation for bulk import and citation workflows (completed 2026-02-25)
- [x] **Phase 34: OpenAlex Batch API** - Efficient batch fetching with rate limiting (completed 2026-02-26)
- [x] **Phase 35: Bulk DOI Import UI** - Paste/upload DOI lists for batch import (completed 2026-02-26)
- [x] **Phase 36: BibTeX Import** - Upload .bib files for library migration (completed 2026-02-26)
- [x] **Phase 37: Citation Audit** - Find missing seminal papers by reference frequency (completed 2026-02-26)
- [x] **Phase 38: Select-All Import** - Batch select and import filtered abstracts (completed 2026-02-26)
- [x] **Phase 39: Slide Healing** - Prompt improvements and regeneration workflow (completed 2026-02-27)

## Phase Details

### Phase 33: DOI Parsing Utilities
**Goal**: Provide robust DOI parsing and validation utilities for bulk import workflows
**Depends on**: Nothing (foundation phase)
**Requirements**: Foundation for BULK-01, BULK-02, BULK-03, AUDIT-06
**Success Criteria** (what must be TRUE):
  1. System can parse DOI lists in multiple formats (URLs, bare DOIs, comma/newline/space-separated)
  2. System normalizes all DOI formats to bare format (10.xxxx/yyyy)
  3. System validates DOI structure and rejects malformed entries with clear error messages
  4. Utility functions are tested with edge cases (mixed formats, whitespace, invalid prefixes)
**Plans**: 1 plan

Plans:
- [ ] 33-01-PLAN.md — TDD: Batch DOI parsing with categorized errors

### Phase 34: OpenAlex Batch API Support
**Goal**: Enable efficient batch fetching of papers from OpenAlex with proper rate limiting
**Depends on**: Phase 33
**Requirements**: Foundation for BULK-04, BULK-05, AUDIT-02, AUDIT-03, AUDIT-06
**Success Criteria** (what must be TRUE):
  1. System can batch-query OpenAlex with up to 50 DOIs per request using pipe-separated filter syntax
  2. System implements rate limiting with 0.1s delays between batch requests
  3. System implements exponential backoff on 429 errors with graceful failure messaging
  4. System handles missing DOIs gracefully (some DOIs in batch may not exist in OpenAlex)
  5. Batch API operations are tested with realistic volumes (100+ DOIs, missing entries, rate limit scenarios)
**Plans**: 2 plans

Plans:
- [ ] 34-01-PLAN.md — TDD: Extend parse_openalex_work with is_retracted, cited_by_percentile, topics
- [ ] 34-02-PLAN.md — TDD: Implement batch_fetch_papers with batching, retries, error categorization

### Phase 35: Bulk DOI Import UI
**Goal**: Users can paste or upload DOI lists for batch import into search notebooks
**Depends on**: Phase 34
**Requirements**: BULK-01, BULK-02, BULK-04, BULK-05, BULK-06
**Success Criteria** (what must be TRUE):
  1. User can paste a list of DOIs (mixed formats: URLs, bare, comma/newline-separated) into a textarea
  2. User can upload a CSV or text file containing DOIs
  3. Import runs asynchronously with progress bar showing N/total papers fetched
  4. User sees import summary with counts (N imported, N failed, N duplicates skipped)
  5. Failed imports show specific error messages (malformed DOI, not found in OpenAlex, API error)
**Plans**: 2 plans

Plans:
- [ ] 35-01-PLAN.md — DB schema for import runs + business logic (BibTeX extraction, duplicate detection, import orchestration)
- [ ] 35-02-PLAN.md — Shiny UI module + search notebook integration (modals, progress, results, history)

### Phase 36: BibTeX Import
**Goal**: Users can upload BibTeX files for library migration and citation network seeding
**Depends on**: Phase 35
**Requirements**: BULK-03, BULK-07, BULK-08
**Success Criteria** (what must be TRUE):
  1. User can upload a .bib file and system extracts DOIs from entries
  2. System preserves BibTeX metadata when OpenAlex enrichment fails (merge-not-replace pattern)
  3. Import shows diagnostics (N entries parsed, N with DOIs, N enriched from OpenAlex, N from .bib only)
  4. User can feed uploaded .bib file into citation network for seeding
  5. Malformed BibTeX entries are handled gracefully with per-entry error reporting
**Plans**: 2 plans

Plans:
- [ ] 36-01-PLAN.md — TDD: BibTeX parsing with bib2df + metadata merge logic
- [ ] 36-02-PLAN.md — UI: Extend bulk import module for BibTeX + citation seeding button

### Phase 37: Citation Audit
**Goal**: Users can identify frequently-cited papers missing from their search notebook collection
**Depends on**: Phase 34
**Requirements**: AUDIT-01, AUDIT-02, AUDIT-03, AUDIT-04, AUDIT-05, AUDIT-06, AUDIT-07
**Success Criteria** (what must be TRUE):
  1. User can trigger citation gap analysis on a search notebook with one click
  2. System analyzes backward citations (papers cited BY collection via referenced_works) and forward citations (papers that CITE the collection via OpenAlex cited_by API)
  3. Missing papers are ranked by citation frequency with threshold of 2+ references
  4. User sees ranked list with title, author, year, and citation count for each missing paper
  5. User can import individual missing papers with one click
  6. Analysis runs asynchronously with progress indicator and cancellation support
  7. System handles large collections (500+ papers, thousands of referenced works) with single-query SQL aggregation
**Plans**: 2 plans

Plans:
- [ ] 37-01-PLAN.md — DB schema for audit caching + citation audit business logic (backward refs, forward citations, ranking, import)
- [ ] 37-02-PLAN.md — Shiny UI module (dedicated audit view, results table, progress modal, import workflow) + app.R integration

### Phase 38: Select-All Import
**Goal**: Users can batch select and import all filtered abstracts into document notebooks
**Depends on**: Phase 35
**Requirements**: SLCT-01, SLCT-02, SLCT-03
**Success Criteria** (what must be TRUE):
  1. User can select all filtered abstracts with a single checkbox
  2. User can import all selected abstracts into a document notebook with one click
  3. Batch import shows progress bar for large selections (50+ papers)
  4. System warns user before importing 100+ papers and uses ExtendedTask for large batches
  5. Select-all state correctly merges with individual paper selections
**Plans**: 2 plans

Plans:
- [ ] 38-01-PLAN.md — Select-all checkbox UI with tri-state behavior and state management
- [ ] 38-02-PLAN.md — Async batch import with ExtendedTask, confirmation modal, and results summary

### Phase 39: Slide Healing
**Goal**: Improve slide generation reliability with better prompts and regeneration workflow
**Depends on**: Nothing (independent improvement)
**Requirements**: SLIDE-01, SLIDE-02, SLIDE-03, SLIDE-04
**Success Criteria** (what must be TRUE):
  1. Slide generation prompt includes proper YAML template structure to reduce malformed output
  2. User can click Regenerate button to re-attempt failed slide generation
  3. User can provide specific healing instructions (e.g., "fix YAML syntax", "fix CSS")
  4. System validates YAML programmatically and provides specific error feedback
  5. System limits healing to 2 retries maximum, then falls back to template YAML with title only
  6. Slide generation prompt includes sufficient formatting reference for RevealJS/Quarto constructs (footnotes, speaker notes, etc.)
**Plans**: 3 plans

Plans:
- [x] 39-01-PLAN.md — YAML validation, improved prompts, healing logic, and fallback template functions (completed 2026-02-27)
- [x] 39-02-PLAN.md — Healing modal UI, updated results modal, retry tracking, and fallback behavior (completed 2026-02-27)
- [x] 39-03-PLAN.md — Gap closure: Add Quarto/RevealJS format reference to system prompts (completed 2026-02-27)

## Progress

**Execution Order:**
Phases execute in numeric order: 33 → 34 → 35 → 36 → 37 → 38 → 39

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 33. DOI Parsing Utilities | 1/1 | Complete    | 2026-02-25 | - |
| 34. OpenAlex Batch API | 2/2 | Complete    | 2026-02-26 | - |
| 35. Bulk DOI Import UI | 2/2 | Complete    | 2026-02-26 | - |
| 36. BibTeX Import | 2/2 | Complete   | 2026-02-26 | - |
| 37. Citation Audit | 2/2 | Complete    | 2026-02-26 | - |
| 38. Select-All Import | 2/2 | Complete    | 2026-02-26 | - |
| 39. Slide Healing | 3/3 | Complete    | 2026-02-27 | - |

---
*Updated: 2026-02-27 — Phase 39 plan 03 completed*
