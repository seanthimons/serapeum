# TODO

Future enhancements for the Research Notebook tool, organized by priority.

---

## Pending PRs

| PR | Title | Status | Branch |
|----|-------|--------|--------|
| [PR #39](https://github.com/seanthimons/serapeum/pull/39) | Add R package for PDF image extraction | draft | copilot/add-pdf-image-extraction-package |

---

## Known Tech Debt

Items carried forward from v4.0 that should be addressed early in the next milestone.

| Item | Description | Severity |
|------|-------------|----------|
| Ragnar leak | `ensure_ragnar_store()` in mod_search_notebook.R ~L2061 — store opened for indexing but never explicitly closed | Medium |
| Test fixtures | 13 pre-existing test failures from missing schema columns (section_hint, doi) in test fixtures | Low |
| Dark mode | Dark mode not properly considered across UI ([#121](https://github.com/seanthimons/serapeum/issues/121)) | Medium |

---

## New Issues

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#121](https://github.com/seanthimons/serapeum/issues/121) | Dark mode is not properly considered | Low | High |
| [#120](https://github.com/seanthimons/serapeum/issues/120) | UI for viewing/editing prompts for research outputs | Medium | Medium |
| [#113](https://github.com/seanthimons/serapeum/issues/113) | Bulk upload for network analysis/seeding | Medium | Medium |
| [#109](https://github.com/seanthimons/serapeum/issues/109) | moonshot: Flag to disable AI features, pure abstract searching app | High | High |

---

## High Priority (Quick Wins)

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#85](https://github.com/seanthimons/serapeum/issues/85) | Select all to be imported into document notebook | Low | Medium |
| — | Explore: Partial BFS graph as intentional visualization mode | Medium | Medium |

---

## AI Output Presets

Remaining presets from [epic #107](https://github.com/seanthimons/serapeum/issues/107). Overview (#98), Research Questions (#102), and Lit Review Table (#99) shipped in v4.0.

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#88](https://github.com/seanthimons/serapeum/issues/88) | Rethink conclusion synthesis as split presets for faster responses | High | High |
| [#100](https://github.com/seanthimons/serapeum/issues/100) | Methodology Extractor preset | Medium | High |
| [#101](https://github.com/seanthimons/serapeum/issues/101) | Gap Analysis Report preset | Medium | High |
| [#103](https://github.com/seanthimons/serapeum/issues/103) | Citation Audit — find missing seminal papers (no LLM) | Medium | High |
| [#104](https://github.com/seanthimons/serapeum/issues/104) | Argument Map / Claims Network preset | High | Medium |
| [#105](https://github.com/seanthimons/serapeum/issues/105) | Annotated Bibliography export (APA/MLA) | Medium | Medium |
| [#106](https://github.com/seanthimons/serapeum/issues/106) | Teaching Materials Generator | Low-Medium | Medium |

---

## Medium Priority

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#87](https://github.com/seanthimons/serapeum/issues/87) | Chat UX: busy spinners, progress messages, modal messaging | Medium | Medium |
| [#84](https://github.com/seanthimons/serapeum/issues/84) | Export from network graph to abstract search + vice versa | High | Medium |
| [#8](https://github.com/seanthimons/serapeum/issues/8) | Local model support | High | High |
| [#11](https://github.com/seanthimons/serapeum/issues/11) | Recursive abstract searching | High | High |
| [#24](https://github.com/seanthimons/serapeum/issues/24) | Bulk DOI upload for OpenAlex lookup | High | Medium |
| [#48](https://github.com/seanthimons/serapeum/issues/48) | Tighter RAG document retrieval controls | Low | Medium |
| [#52](https://github.com/seanthimons/serapeum/issues/52) | Does Quarto support citations better? | Low | Medium |
| [#60](https://github.com/seanthimons/serapeum/issues/60) | Toggle/UI to expose API queries | Medium | Medium |

---

## PDF Image Pipeline ([#44](https://github.com/seanthimons/serapeum/issues/44))

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#44](https://github.com/seanthimons/serapeum/issues/44) | epic: PDF Image Pipeline (extraction → slides) | High | High |
| [#38](https://github.com/seanthimons/serapeum/issues/38) | PDF image extraction process | High | High |
| [#28](https://github.com/seanthimons/serapeum/issues/28) | Image/table/chart extraction | High | High |
| [#29](https://github.com/seanthimons/serapeum/issues/29) | Image/chart injection into slides | High | High |
| [#37](https://github.com/seanthimons/serapeum/issues/37) | Results of image parsing | Medium | Medium |

---

## Low Priority (Backlog)

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#6](https://github.com/seanthimons/serapeum/issues/6) | Timeline heatmap | Medium | Low |
| [#9](https://github.com/seanthimons/serapeum/issues/9) | Versioning for releases | Low | Low |
| [#12](https://github.com/seanthimons/serapeum/issues/12) | Evaluate reranker need | Low | TBD |
| [#21](https://github.com/seanthimons/serapeum/issues/21) | Semantic Scholar integration | High | Low |
| [#22](https://github.com/seanthimons/serapeum/issues/22) | Audio overview (NotebookLM style) | High | Medium |
| [#30](https://github.com/seanthimons/serapeum/issues/30) | Demo mode | Medium | Low |

---

## Epics

| Issue | Title | Status |
|-------|-------|--------|
| [#107](https://github.com/seanthimons/serapeum/issues/107) | epic: AI Output Overhaul | 4/10 complete (#88 rethought, #98, #99, #102 shipped) |
| [#44](https://github.com/seanthimons/serapeum/issues/44) | epic: PDF Image Pipeline | 0/4 — future milestone |
| [#74](https://github.com/seanthimons/serapeum/issues/74) | epic: Discovery Workflow Enhancement | 4/4 complete — **CLOSED** |
| [#75](https://github.com/seanthimons/serapeum/issues/75) | epic: Document Output & Export | 4/4 complete — **CLOSED** |
| [#76](https://github.com/seanthimons/serapeum/issues/76) | epic: Synthesis & Analysis | 2/2 complete — **CLOSED** |

---

## Moonshot Goals

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#41](https://github.com/seanthimons/serapeum/issues/41) | Full OpenAlex Corpus Ingestion | Very High | Very High |
| [#42](https://github.com/seanthimons/serapeum/issues/42) | DuckDB Native Vector Search | High | High |
| [#109](https://github.com/seanthimons/serapeum/issues/109) | Disable AI features — pure abstract search mode | High | High |

---

## Completed

<details>
<summary>v1.0–v4.0 completed items (click to expand)</summary>

- [x] Basic document notebooks with PDF upload
- [x] Search notebooks via OpenAlex
- [x] RAG chat with citations
- [x] Preset generation (summary, key points, etc.)
- [x] Settings page with model configuration
- [x] Quarto slide deck generation
- [x] [#5](https://github.com/seanthimons/serapeum/issues/5): Filter papers without abstracts
- [x] [#7](https://github.com/seanthimons/serapeum/issues/7): Retraction watch / junk journal filtering
- [x] [#13](https://github.com/seanthimons/serapeum/issues/13): Paper keywords from API
- [x] [#23](https://github.com/seanthimons/serapeum/issues/23): API key status indicators
- [x] OpenAlex Phase 1: Document type filter and badges
- [x] OpenAlex Phase 2: OA status badges and citation metrics
- [x] Deferred embedding workflow (Embed Papers button)
- [x] [#34](https://github.com/seanthimons/serapeum/issues/34): Embed count reflects filtered papers
- [x] [#35](https://github.com/seanthimons/serapeum/issues/35): Citation/reference display fix
- [x] [#45](https://github.com/seanthimons/serapeum/issues/45): About page layout overflow fix
- [x] [#47](https://github.com/seanthimons/serapeum/issues/47): API key status validates config.yaml on initial load
- [x] [#55](https://github.com/seanthimons/serapeum/issues/55): Fix abstract embedding (v1.0)
- [x] [#25](https://github.com/seanthimons/serapeum/issues/25): Seed paper for searching (v1.0)
- [x] [#10](https://github.com/seanthimons/serapeum/issues/10): Meta-prompt query builder (v1.0)
- [x] [#40](https://github.com/seanthimons/serapeum/issues/40): OpenAlex Topics & Discovery (v1.0)
- [x] [#43](https://github.com/seanthimons/serapeum/issues/43): Startup wizard UI (v1.0)
- [x] [#54](https://github.com/seanthimons/serapeum/issues/54): Rich sorting for search results (v1.0)
- [x] [#51](https://github.com/seanthimons/serapeum/issues/51): Slide citation CSS fix (v1.0)
- [x] [#19](https://github.com/seanthimons/serapeum/issues/19): OpenRouter cost tracking (v1.1)
- [x] [#20](https://github.com/seanthimons/serapeum/issues/20): Expanded model selection (v1.1)
- [x] [#17](https://github.com/seanthimons/serapeum/issues/17): Enhanced keyword tag behavior (v1.1)
- [x] [#26](https://github.com/seanthimons/serapeum/issues/26): Ban/hard filter for suspect journals (v1.1)
- [x] [#57](https://github.com/seanthimons/serapeum/issues/57): Seed discovery email prompt bug fix
- [x] [#59](https://github.com/seanthimons/serapeum/issues/59): Fix 401 on OpenAlex topic searches (v1.2)
- [x] [#65](https://github.com/seanthimons/serapeum/issues/65): User-friendly API error messages (v1.2)
- [x] [#68](https://github.com/seanthimons/serapeum/issues/68): Fix tab-swap OpenAlex re-request (v1.2)
- [x] [#73](https://github.com/seanthimons/serapeum/issues/73): Collapsible Journal Quality card (v1.2)
- [x] [#72](https://github.com/seanthimons/serapeum/issues/72): Fix block badge misalignment (v1.2)
- [x] [#66](https://github.com/seanthimons/serapeum/issues/66): DOI on abstract preview (v2.0)
- [x] [#53](https://github.com/seanthimons/serapeum/issues/53): Citation network graph (v2.0)
- [x] [#67](https://github.com/seanthimons/serapeum/issues/67): Export abstract to seeded paper search (v2.0)
- [x] [#71](https://github.com/seanthimons/serapeum/issues/71): Seeded search same view as abstract preview (v2.0)
- [x] [#64](https://github.com/seanthimons/serapeum/issues/64): Citation export BibTeX/CSV (v2.0)
- [x] [#49](https://github.com/seanthimons/serapeum/issues/49): Export synthesis outputs (v2.0)
- [x] [#50](https://github.com/seanthimons/serapeum/issues/50): Rich markdown rendering in chat (v2.0)
- [x] [#63](https://github.com/seanthimons/serapeum/issues/63): Additional synthesis outputs (v2.0)
- [x] [#69](https://github.com/seanthimons/serapeum/issues/69): Community standards
- [x] Citation network node sizing, self-loop filtering, year-to-color mapping, physics auto-freeze
- [x] [#80](https://github.com/seanthimons/serapeum/issues/80): Progress modal with stop button (v2.1)
- [x] [#33](https://github.com/seanthimons/serapeum/issues/33): Favicon (v2.1)
- [x] [#61](https://github.com/seanthimons/serapeum/issues/61): Conclusion synthesis icon (v2.1)
- [x] [#62](https://github.com/seanthimons/serapeum/issues/62): Preset icons (v2.1)
- [x] [#27](https://github.com/seanthimons/serapeum/issues/27): Conclusion synthesis (v2.1)
- [x] [#81](https://github.com/seanthimons/serapeum/issues/81): UI improvements to reclaim space
- [x] [#90](https://github.com/seanthimons/serapeum/issues/90): Move to renv
- [x] [#78](https://github.com/seanthimons/serapeum/issues/78): GHA/local functions for RDS support files
- [x] [#77](https://github.com/seanthimons/serapeum/issues/77): ragnar package integration (v3.0)
- [x] [#110](https://github.com/seanthimons/serapeum/issues/110): Seed paper not showing in abstract search (v4.0)
- [x] [#111](https://github.com/seanthimons/serapeum/issues/111): Modal repeats multiple times on remove (v4.0)
- [x] [#116](https://github.com/seanthimons/serapeum/issues/116): Cost tracking table not being updated (v4.0)
- [x] [#86](https://github.com/seanthimons/serapeum/issues/86): Refresh button adding papers after removing (v4.0)
- [x] [#117](https://github.com/seanthimons/serapeum/issues/117): Connection leak in search_chunks_hybrid (v4.0)
- [x] [#118](https://github.com/seanthimons/serapeum/issues/118): section_hint not encoded in PDF ragnar origins (v4.0)
- [x] [#119](https://github.com/seanthimons/serapeum/issues/119): Dead code removal (v4.0)
- [x] [#79](https://github.com/seanthimons/serapeum/issues/79): Tooltip overflow (v4.0)
- [x] [#89](https://github.com/seanthimons/serapeum/issues/89): Citation network background color (v4.0)
- [x] [#98](https://github.com/seanthimons/serapeum/issues/98): Unified Overview preset (v4.0)
- [x] [#99](https://github.com/seanthimons/serapeum/issues/99): Literature Review Table (v4.0)
- [x] [#102](https://github.com/seanthimons/serapeum/issues/102): Research Question Generator (v4.0)

</details>

---

## Labels Guide

**Complexity** (effort required):
- `complexity:low` - Quick fix, < 1 hour
- `complexity:medium` - Half day to full day
- `complexity:high` - Multiple days or significant refactoring

**Impact** (value delivered):
- `impact:low` - Nice to have, minor improvement
- `impact:medium` - Improves workflow or fixes notable issue
- `impact:high` - Critical feature or blocking issue
