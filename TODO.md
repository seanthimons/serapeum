# TODO

Future enhancements for the Research Notebook tool, organized by priority.

---

## Pending PRs (Resolve Immediately)

| PR | Title | Status | Branch |
|----|-------|--------|--------|
| [PR #70](https://github.com/seanthimons/serapeum/pull/70) | Add GitHub community standards (LICENSE, CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, templates) | open | copilot/update-community-standards-defaults |
| [PR #56](https://github.com/seanthimons/serapeum/pull/56) | Fix abstract embedding queries missing source_type filter | draft | copilot/fix-abstract-embedding-issue |
| [PR #39](https://github.com/seanthimons/serapeum/pull/39) | Add R package for PDF image extraction | draft | copilot/add-pdf-image-extraction-package |

---

## High Priority (Quick Wins & Critical)

Bug fixes and high-impact features with low-to-medium effort.

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#53](https://github.com/seanthimons/serapeum/issues/53) | feat: Citation network graph for paper discovery | Medium | High |
| ~~[#66](https://github.com/seanthimons/serapeum/issues/66)~~ | ~~feat: DOI on abstract preview~~ | ~~Low~~ | ~~Medium~~ |
| [#67](https://github.com/seanthimons/serapeum/issues/67) | dev: Export abstract to seeded paper search | Medium | High |

---

## Medium Priority

Valuable features requiring more investment, or moderate-impact improvements.

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#8](https://github.com/seanthimons/serapeum/issues/8) | dev: Local model support | High | High |
| [#11](https://github.com/seanthimons/serapeum/issues/11) | feat: Recursive abstract searching | High | High |
| [#27](https://github.com/seanthimons/serapeum/issues/27) | feat: Conclusion synthesis → future directions | High | High |
| [#28](https://github.com/seanthimons/serapeum/issues/28) | feat: Image/table/chart extraction | High | High |
| [#29](https://github.com/seanthimons/serapeum/issues/29) | feat: Image/chart injection into slides | High | High |
| [#38](https://github.com/seanthimons/serapeum/issues/38) | dev: PDF image extraction process | High | High |
| [#44](https://github.com/seanthimons/serapeum/issues/44) | epic: PDF Image Pipeline (extraction → slides) | High | High |
| [#74](https://github.com/seanthimons/serapeum/issues/74) | epic: Discovery Workflow Enhancement (#53, #66, #67, #71) | High | High |
| [#75](https://github.com/seanthimons/serapeum/issues/75) | epic: Document Output & Export (#49, #50, #63, #64) | High | High |
| [#76](https://github.com/seanthimons/serapeum/issues/76) | epic: Synthesis & Analysis (#27, #63) | High | High |
| [#63](https://github.com/seanthimons/serapeum/issues/63) | feat: Additional synthesis outputs | High | High |
| [#64](https://github.com/seanthimons/serapeum/issues/64) | feat: Citation export | Medium | Medium |
| [#71](https://github.com/seanthimons/serapeum/issues/71) | feat: Seeded search same view as abstract preview | Medium | Medium |
| [#24](https://github.com/seanthimons/serapeum/issues/24) | feat: Bulk DOI upload | High | Medium |
| [#37](https://github.com/seanthimons/serapeum/issues/37) | feat: Results of image parsing | Medium | Medium |
| [#48](https://github.com/seanthimons/serapeum/issues/48) | dev: Tighter RAG document retrieval controls | Low | Medium |
| [#49](https://github.com/seanthimons/serapeum/issues/49) | feat: Export synthesis outputs (document notebooks) | Medium | Medium |
| [#50](https://github.com/seanthimons/serapeum/issues/50) | feat: Rich output preview (document notebook synthesis) | Medium | Medium |
| [#52](https://github.com/seanthimons/serapeum/issues/52) | dev: Does Quarto support citations better? | Low | Medium |
| [#60](https://github.com/seanthimons/serapeum/issues/60) | dev: Toggle/UI to expose API queries | Medium | Medium |

---

## UI Polish

| Area | Title | Complexity | Impact |
|------|-------|------------|--------|
| Citation Network | [#79](https://github.com/seanthimons/serapeum/issues/79): Tooltip overflows graph container and overlaps side panel | Medium | Medium |
| Citation Network | [#80](https://github.com/seanthimons/serapeum/issues/80): Expanded progress modal with stop button and detailed logging | Medium | Medium |
| Settings | Rebalance two-column layout on settings page (DOI Management card added weight to one side) | Low | Low |

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
| [#33](https://github.com/seanthimons/serapeum/issues/33) | ui: Favicon | Low | Low |
| [#61](https://github.com/seanthimons/serapeum/issues/61) | ui: Icon for conclusion/future direction synthesis | Low | Low |
| [#62](https://github.com/seanthimons/serapeum/issues/62) | ui: Icons for summarize, key points, outline, etc. | Low | Low |
| [#69](https://github.com/seanthimons/serapeum/issues/69) | dev: Add/update community standards | Low | Low |

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
