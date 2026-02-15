# TODO

Future enhancements for the Research Notebook tool, organized by priority.

---

## Pending PRs (Resolve Immediately)

| PR | Title | Status | Branch |
|----|-------|--------|--------|
| [PR #39](https://github.com/seanthimons/serapeum/pull/39) | Add R package for PDF image extraction | draft | copilot/add-pdf-image-extraction-package |

---

## High Priority (Quick Wins & Critical)

Bug fixes and high-impact features with low-to-medium effort.

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#98](https://github.com/seanthimons/serapeum/issues/98) | Merge Summarize + Key Points into unified Overview output | Medium | High |
| [#85](https://github.com/seanthimons/serapeum/issues/85) | Select all to be imported into document notebook | Low | Medium |
| [#86](https://github.com/seanthimons/serapeum/issues/86) | [BUG] Does the refresh button add more papers after removing? | Low | Medium |
| [#79](https://github.com/seanthimons/serapeum/issues/79) | bug: Tooltip overflows graph container and overlaps side panel | Medium | Medium |
| — | explore: Partial BFS graph as intentional visualization mode (cancelled builds produce interesting hub-spoke clusters) | Medium | Medium |

---

## Medium Priority

Valuable features requiring more investment, or moderate-impact improvements.

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#88](https://github.com/seanthimons/serapeum/issues/88) | Rethink conclusion synthesis as split presets for faster responses | High | High |
| [#99](https://github.com/seanthimons/serapeum/issues/99) | feat: Literature Review Table (structured comparison matrix) | Medium | Very High |
| [#100](https://github.com/seanthimons/serapeum/issues/100) | feat: Methodology Extractor preset | Medium | High |
| [#101](https://github.com/seanthimons/serapeum/issues/101) | feat: Gap Analysis Report preset | Medium | High |
| [#102](https://github.com/seanthimons/serapeum/issues/102) | feat: Research Question Generator preset | Medium | High |
| [#103](https://github.com/seanthimons/serapeum/issues/103) | feat: Citation Audit — find missing seminal papers (no LLM) | Medium | High |
| [#104](https://github.com/seanthimons/serapeum/issues/104) | feat: Argument Map / Claims Network preset | High | Medium |
| [#105](https://github.com/seanthimons/serapeum/issues/105) | feat: Annotated Bibliography export (APA/MLA) | Medium | Medium |
| [#106](https://github.com/seanthimons/serapeum/issues/106) | feat: Teaching Materials Generator | Low-Medium | Medium |
| [#87](https://github.com/seanthimons/serapeum/issues/87) | Chat UX: busy spinners, progress messages, modal messaging | Medium | Medium |
| [#84](https://github.com/seanthimons/serapeum/issues/84) | Allow for export from network graph to abstract search + vice versa | High | Medium |
| [#77](https://github.com/seanthimons/serapeum/issues/77) | dev: ragnar package integration (Phase 5-6 below) | Medium | High |
| [#71](https://github.com/seanthimons/serapeum/issues/71) | feat: Seeded search same view as abstract preview | Medium | Medium |
| [#8](https://github.com/seanthimons/serapeum/issues/8) | dev: Local model support | High | High |
| [#11](https://github.com/seanthimons/serapeum/issues/11) | feat: Recursive abstract searching | High | High |
| [#28](https://github.com/seanthimons/serapeum/issues/28) | feat: Image/table/chart extraction | High | High |
| [#29](https://github.com/seanthimons/serapeum/issues/29) | feat: Image/chart injection into slides | High | High |
| [#38](https://github.com/seanthimons/serapeum/issues/38) | dev: PDF image extraction process | High | High |
| [#44](https://github.com/seanthimons/serapeum/issues/44) | epic: PDF Image Pipeline (extraction → slides) | High | High |
| [#24](https://github.com/seanthimons/serapeum/issues/24) | feat: Bulk DOI upload | High | Medium |
| [#37](https://github.com/seanthimons/serapeum/issues/37) | feat: Results of image parsing | Medium | Medium |
| [#48](https://github.com/seanthimons/serapeum/issues/48) | dev: Tighter RAG document retrieval controls | Low | Medium |
| [#52](https://github.com/seanthimons/serapeum/issues/52) | dev: Does Quarto support citations better? | Low | Medium |
| [#60](https://github.com/seanthimons/serapeum/issues/60) | dev: Toggle/UI to expose API queries | Medium | Medium |

---

## UI Polish

| Area | Title | Complexity | Impact |
|------|-------|------------|--------|
| Settings | Rebalance two-column layout on settings page (DOI Management card added weight to one side) | Low | Low |
| [#89](https://github.com/seanthimons/serapeum/issues/89) | bug: Citation network background color blending [gsd] (bundle with #79) | Medium | Medium |

---

## Ragnar Migration — Phase 5 & 6 ([#77](https://github.com/seanthimons/serapeum/issues/77))

Completing the ragnar integration (Phases 1-4 done). See `docs/RAGNAR_MIGRATION_PLAN.md`.

### Phase 5: Existing Data Migration

| Task | Description | Complexity | Impact |
|------|-------------|------------|--------|
| [#91](https://github.com/seanthimons/serapeum/issues/91) 5a. Migrate existing PDF chunks | Re-chunk existing documents via `chunk_with_ragnar()`, insert into ragnar store, re-embed. Requires API key (re-embedding costs). Iterate `chunks` table for docs not yet in ragnar store. | Medium | High |
| [#92](https://github.com/seanthimons/serapeum/issues/92) 5b. Migrate existing abstracts | Insert abstract text into ragnar store with `abstract:{id}` origin format, re-embed. | Low | High |
| [#93](https://github.com/seanthimons/serapeum/issues/93) 5c. Fix broken legacy fallback | `search_chunks_hybrid` L965-981 returns empty frame instead of calling `search_chunks()`. Users without ragnar get zero search results. **This is a live bug.** | Low | Critical |
| [#94](https://github.com/seanthimons/serapeum/issues/94) 5d. Fix lossy metadata persistence | `insert_chunks_to_ragnar` stores metadata as R `attr()` (doesn't persist). Abstract titles show "[Abstract]" placeholder. Encode richer metadata in `origin` field or add a mapping table. | Medium | Medium |

### Phase 6: Integration Testing

| Task | Description | Complexity | Impact |
|------|-------------|------------|--------|
| [#95](https://github.com/seanthimons/serapeum/issues/95) 6a. E2E test: PDF → ragnar → query | Upload small PDF, verify chunks land in ragnar store, retrieve by query, confirm source attribution. | Medium | High |
| [#96](https://github.com/seanthimons/serapeum/issues/96) 6b. E2E test: abstract → ragnar → query | Save abstract, verify ragnar indexing, test notebook-scoped filtering correctness. | Medium | High |
| [#97](https://github.com/seanthimons/serapeum/issues/97) 6c. Benchmark: ragnar vs legacy | Measure retrieval speed and answer quality with identical queries on same corpus. Document results. | Low | Medium |

---

## Low Priority (Backlog)

Nice-to-have features and research tasks.

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#6](https://github.com/seanthimons/serapeum/issues/6) | feat: Timeline heatmap | Medium | Low |
| [#9](https://github.com/seanthimons/serapeum/issues/9) | feat: Versioning for releases | Low | Low |
| [#12](https://github.com/seanthimons/serapeum/issues/12) | dev: Evaluate reranker need | Low | TBD |
| [#21](https://github.com/seanthimons/serapeum/issues/21) | feat: Semantic Scholar integration | High | Low |
| [#22](https://github.com/seanthimons/serapeum/issues/22) | feat: Audio overview (NotebookLM style) | High | Medium |
| [#30](https://github.com/seanthimons/serapeum/issues/30) | feat: Demo mode | Medium | Low |

---

## Epics (Tracking)

| Issue | Title | Sub-issues Status |
|-------|-------|-------------------|
| [#107](https://github.com/seanthimons/serapeum/issues/107) | epic: AI Output Overhaul | 1/10 complete (#88) |
| [#74](https://github.com/seanthimons/serapeum/issues/74) | epic: Discovery Workflow Enhancement | 4/4 complete — **CLOSED** |
| [#75](https://github.com/seanthimons/serapeum/issues/75) | epic: Document Output & Export | 4/4 complete — **CLOSED** |
| [#76](https://github.com/seanthimons/serapeum/issues/76) | epic: Synthesis & Analysis | 2/2 complete — **CLOSED** |

---

## Moonshot Goals

High-effort, high-payoff features for the future.

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#41](https://github.com/seanthimons/serapeum/issues/41) | moonshot: Full OpenAlex Corpus Ingestion | Very High | Very High |
| [#42](https://github.com/seanthimons/serapeum/issues/42) | moonshot: DuckDB Native Vector Search | High | High |

---

## Completed

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
- [x] [#34](https://github.com/seanthimons/serapeum/issues/34): Embed count reflects filtered papers (PR #36)
- [x] [#35](https://github.com/seanthimons/serapeum/issues/35): Citation/reference display fix (PR #36)
- [x] [#45](https://github.com/seanthimons/serapeum/issues/45): About page layout overflow fix (PR #46)
- [x] [#47](https://github.com/seanthimons/serapeum/issues/47): API key status validates config.yaml on initial load (PR #47)
- [x] [#55](https://github.com/seanthimons/serapeum/issues/55): Fix abstract embedding (v1.0)
- [x] [#25](https://github.com/seanthimons/serapeum/issues/25): Seed paper for searching (v1.0)
- [x] [#10](https://github.com/seanthimons/serapeum/issues/10): Meta-prompt query builder (v1.0)
- [x] [#40](https://github.com/seanthimons/serapeum/issues/40): OpenAlex Topics & Discovery (v1.0)
- [x] [#43](https://github.com/seanthimons/serapeum/issues/43): Startup wizard UI (v1.0)
- [x] [#54](https://github.com/seanthimons/serapeum/issues/54): Rich sorting for search results (v1.0)
- [x] [#51](https://github.com/seanthimons/serapeum/issues/51): Slide citation CSS fix (v1.0)
- [x] [#19](https://github.com/seanthimons/serapeum/issues/19): OpenRouter cost tracking (v1.1 Phase 5)
- [x] [#20](https://github.com/seanthimons/serapeum/issues/20): Expanded model selection (v1.1 Phase 6)
- [x] [#17](https://github.com/seanthimons/serapeum/issues/17): Enhanced keyword tag behavior (v1.1 Phase 7)
- [x] [#26](https://github.com/seanthimons/serapeum/issues/26): Ban/hard filter for suspect journals (v1.1 Phase 8)
- [x] [#57](https://github.com/seanthimons/serapeum/issues/57): Seed discovery email prompt bug fix
- [x] [#59](https://github.com/seanthimons/serapeum/issues/59): Fix 401 error on OpenAlex topic searches (v1.2 Phase 9)
- [x] [#65](https://github.com/seanthimons/serapeum/issues/65): User-friendly API error messages (v1.2 Phase 9)
- [x] [#68](https://github.com/seanthimons/serapeum/issues/68): Fix tab-swap OpenAlex re-request (v1.2 Phase 9)
- [x] [#73](https://github.com/seanthimons/serapeum/issues/73): Collapsible Journal Quality card (v1.2 Phase 10)
- [x] [#72](https://github.com/seanthimons/serapeum/issues/72): Fix block badge vertical misalignment (v1.2 Phase 10)
- [x] [#66](https://github.com/seanthimons/serapeum/issues/66): DOI on abstract preview (v2.0 Phase 11)
- [x] [#53](https://github.com/seanthimons/serapeum/issues/53): Citation network graph for paper discovery (v2.0 Phase 12)
- [x] [#67](https://github.com/seanthimons/serapeum/issues/67): Export abstract to seeded paper search (v2.0 Phase 13)
- [x] [#64](https://github.com/seanthimons/serapeum/issues/64): Citation export - BibTeX/CSV (v2.0 Phase 14)
- [x] [#49](https://github.com/seanthimons/serapeum/issues/49): Export synthesis outputs as Markdown/HTML (v2.0 Phase 15)
- [x] [#50](https://github.com/seanthimons/serapeum/issues/50): Rich markdown rendering in chat windows (v2.0 Phase 15)
- [x] [#63](https://github.com/seanthimons/serapeum/issues/63): Additional synthesis outputs (v2.0 Phase 15)
- [x] [#69](https://github.com/seanthimons/serapeum/issues/69): Community standards (PR #70)
- [x] Citation network node sizing — cube-root transform + wider range (fix/citation-node-sizing)
- [x] Citation network self-loop filtering (fix/citation-node-sizing)
- [x] Citation network year-to-color percentile mapping (fix/citation-node-sizing)
- [x] Citation network physics auto-freeze + spacing (fix/citation-node-sizing)
- [x] [#80](https://github.com/seanthimons/serapeum/issues/80): Progress modal with stop button for citation network (v2.1 Phase 18)
- [x] [#33](https://github.com/seanthimons/serapeum/issues/33): Favicon (v2.1 Phase 16)
- [x] [#61](https://github.com/seanthimons/serapeum/issues/61): Conclusion synthesis icon (v2.1 Phase 16)
- [x] [#62](https://github.com/seanthimons/serapeum/issues/62): Preset icons (v2.1 Phase 16)
- [x] [#27](https://github.com/seanthimons/serapeum/issues/27): Conclusion synthesis → future directions (v2.1 Phase 19)
- [x] [#81](https://github.com/seanthimons/serapeum/issues/81): UI improvements to reclaim space (sidebar rebalance)
- [x] [#90](https://github.com/seanthimons/serapeum/issues/90): Move to renv for package namespace management
- [x] [#78](https://github.com/seanthimons/serapeum/issues/78): Set up GHA/local functions for RDS support files

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

**Priority** (derived from complexity + impact):
- `priority:high` - High impact + Low/Medium complexity (quick wins, critical fixes)
- `priority:medium` - Medium impact or High impact + High complexity
- `priority:low` - Low impact items
