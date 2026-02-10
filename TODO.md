# TODO

Future enhancements for the Research Notebook tool, organized by priority.

---

## High Priority (Quick Wins & Critical)

Bug fixes and high-impact features with low-to-medium effort.

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#10](https://github.com/seanthimons/serapeum/issues/10) | feat: Meta-prompt for query building | Medium | High |
| [#25](https://github.com/seanthimons/serapeum/issues/25) | feat: Seed paper for searching | Medium | High |
| [#40](https://github.com/seanthimons/serapeum/issues/40) | feat: OpenAlex Phase 3 - Topics & Discovery | Medium | High |
| [#43](https://github.com/seanthimons/serapeum/issues/43) | feat: Startup UI for seed papers or search term generation | Medium | High |
| [#51](https://github.com/seanthimons/serapeum/issues/51) | bugfix: Slide generation citations too large | Low | Medium |

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
| [#17](https://github.com/seanthimons/serapeum/issues/17) | feat: Enhanced keyword tag behavior | Medium | Medium |
| [#19](https://github.com/seanthimons/serapeum/issues/19) | feat: OpenRouter cost tracking | Medium | Medium |
| [#20](https://github.com/seanthimons/serapeum/issues/20) | feat: Expanded model selection | Medium | Medium |
| [#26](https://github.com/seanthimons/serapeum/issues/26) | feat: Ban/hard filter for suspect journals | Low | Medium |
| [#24](https://github.com/seanthimons/serapeum/issues/24) | feat: Bulk DOI upload | High | Medium |
| [#37](https://github.com/seanthimons/serapeum/issues/37) | feat: Results of image parsing | Medium | Medium |
| [#44](https://github.com/seanthimons/serapeum/issues/44) | epic: PDF Image Pipeline (extraction → slides) | High | High |
| [#48](https://github.com/seanthimons/serapeum/issues/48) | dev: Tighter RAG document retrieval controls | Low | Medium |
| [#49](https://github.com/seanthimons/serapeum/issues/49) | feat: Export synthesis outputs (document notebooks) | Medium | Medium |
| [#50](https://github.com/seanthimons/serapeum/issues/50) | feat: Rich output preview (document notebook synthesis) | Medium | Medium |
| [#52](https://github.com/seanthimons/serapeum/issues/52) | dev: Does Quarto support citations better? | Low | Medium |
| [#53](https://github.com/seanthimons/serapeum/issues/53) | feat: Citation network graph for paper discovery | Medium | High |

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
| [#45](https://github.com/seanthimons/serapeum/issues/45) | ui: Overflow on about page | Low | Low |

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
