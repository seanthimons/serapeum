# Project Research Summary

**Project:** Serapeum - Fix + Discovery Milestone
**Domain:** Academic Research Discovery Tool (Local-first R/Shiny)
**Researched:** 2026-02-10
**Confidence:** HIGH

## Executive Summary

Serapeum is a local-first research assistant that needs discovery features comparable to Connected Papers, ResearchRabbit, and Elicit while maintaining privacy guarantees and DuckDB storage. The research reveals that academic discovery tools converge on three core modes: seed paper citation traversal, natural language query building, and topic browsing. OpenAlex provides all necessary APIs (citation networks via `cites`/`cited_by` filters, topic hierarchy, autocomplete), requiring no new dependencies beyond the existing httr2/DuckDB stack.

The recommended approach prioritizes modular architecture. The existing mod_search_notebook.R is already 1,760 lines — it cannot absorb new features. Instead, create separate discovery modules (mod_seed_paper_search, mod_query_builder, mod_topic_explorer, mod_startup_wizard) that output standardized query parameters to the search notebook. This producer-consumer pattern enables independent development and testing while avoiding the "God module" anti-pattern.

Critical risks center on OpenAlex rate limits (100k credits/day burns fast with naive pagination), LLM query hallucination (must validate generated filters against OpenAlex schema), and embedding relevance traps (semantic search needs hybrid BM25 support). Mitigation strategies are well-documented: credit tracking UI, filter allowlists, cursor pagination, and hybrid search. The Phase 0 refactor foundation (database migrations + module splitting) is non-negotiable before adding features.

## Key Findings

### Recommended Stack

OpenAlex API provides all discovery primitives: citation relationships (`filter=cites:W123` for forward citations, `filter=cited_by:W456` for references), semantic similarity (`filter=related_to:W789`), and a 4-level topic hierarchy (domain → field → subfield → topic). The works endpoint supports autocomplete for seed paper search. All existing Serapeum packages (httr2, jsonlite, DuckDB, shiny, bslib) handle these patterns. **No new R package dependencies required.**

**Core technologies:**
- **OpenAlex API**: Citation network data, topic taxonomy, autocomplete — already integrated via api_openalex.R, just needs new endpoints (DOI lookup, topic queries)
- **httr2 (≥1.0.0)**: HTTP client — already in use, modern pipeable API with built-in rate limiting/retry
- **DuckDB (≥0.9.0)**: Local storage — native JSON/LIST support for citation arrays, need to add topics table and migration versioning
- **Shiny modalDialog**: Wizard UI pattern — standard Shiny feature for startup wizard, no new dependencies

**Key OpenAlex patterns:**
- **Seed discovery**: `/works/autocomplete` → select seed → `/works?filter=cites:{id}` for forward citations OR `/works?filter=related_to:{id}` for semantic similarity
- **Topic browsing**: `/topics` with hierarchical filtering by domain/field/subfield → `/works?filter=primary_topic.id:{id}`
- **Query builder**: Natural language → LLM generates OpenAlex filter syntax → validate against allowlist → execute

### Expected Features

**Must have (table stakes):**
- **Seed paper discovery** — All modern tools (Connected Papers, ResearchRabbit) start with seed papers. Users expect citation-based exploration.
- **Rich sorting** — Citation count, relevance, publication year. Google Scholar conditioning means users expect multiple sort options.
- **Multi-paper selection** — Checkboxes for batch export/actions. Basic UX expectation from Gmail, file managers.
- **BibTeX export** — Most common citation format for LaTeX and reference managers.

**Should have (competitive differentiators):**
- **LLM query builder** — Elicit's natural language queries are a key differentiator. Translates "How does sleep affect memory in teenagers?" into structured filters.
- **Topic exploration** — Browse OpenAlex's 4,500 topics hierarchically. Less computation-intensive than co-citation analysis, still valuable for domain exploration.
- **Startup wizard** — First-time users struggle with empty notebooks. Multi-step onboarding reduces abandonment.
- **Local-first citation networks** — Connected Papers charges for saved graphs. Serapeum's unlimited local storage is a privacy-first differentiator (defer complex visualization to v1.x).

**Defer (v2+):**
- **Citation network visualization** — High value but high complexity. Validate core discovery features before investing in D3.js graph rendering.
- **Research feeds** — Persistent queries for ongoing research. Add when users express "track this topic over time" need.
- **Advanced filtering** — Author, venue, funder filters. Power user features to add when specifically requested.

### Architecture Approach

Discovery features follow a producer-consumer pattern: new discovery modules (seed search, query builder, topic explorer) produce standardized query parameters (`list(search_query, filters)`), which app.R passes to the existing search notebook module. This prevents bloating mod_search_notebook.R (already 1,760 lines) and enables parallel development. The startup wizard orchestrates discovery modules via conditional routing.

**Major components:**
1. **mod_startup_wizard** — First-time onboarding, routes to seed/search/topics based on user choice
2. **mod_seed_paper_search** — DOI/URL lookup, fetch related works (cites/cited_by/related_to), output query params
3. **mod_query_builder** — Visual filters (year, field, type, venue), LLM-assisted natural language, validate + generate OpenAlex syntax
4. **mod_topic_explorer** — Browse topic hierarchy (domain → field → subfield → topic), filter works by topic ID
5. **mod_search_notebook** — Existing module receives query params, displays results (DO NOT EXPAND — already complex)

**Build order:** Phase 1 (infrastructure: API extensions + DB migrations) → Phase 2 (discovery modules in parallel) → Phase 3 (wizard orchestration) → Phase 4 (app integration). Seed paper search comes first for end-to-end validation, then query builder (simplest, no API deps), then topic explorer (API-heavy).

### Critical Pitfalls

1. **OpenAlex rate limit blindness** — Free API key = 100k credits/day. Paginated list queries cost 10 credits each. Naive implementations burn through quota in hours. Users hit 429 errors and can't search. **Mitigation:** Track credits client-side, display remaining quota, batch entity lookups with OR syntax (`id=W1|W2|W3`), cache aggressively in DuckDB.

2. **LLM query builder hallucinated filters** — LLM generates OpenAlex filters with non-existent fields (`venue.impact_factor`, `author.h_index_recent`) or malformed boolean logic. Queries return zero results. Users lose trust. **Mitigation:** Provide exact OpenAlex filter schema in system prompt, validate LLM output against allowlist before API call, display generated query for user approval.

3. **God module refactor paralysis** — mod_search_notebook.R is 1,760 lines. Adding discovery features here = touching 10+ reactive chains. Bug fixes break unrelated features. Onboarding takes days. **Mitigation:** Split by responsibility into sub-modules (<500 lines each), extract non-reactive logic to pure functions, enforce line limits in PRs.

4. **Database migration ad-hocery** — Add column in dev, push to production. Existing user databases lack column → SQL errors crash app. No rollback mechanism. **Mitigation:** Use `PRAGMA user_version` for schema versioning, numbered migration scripts, apply missing migrations in transaction on app init, test v0→v1 and v0→vN paths.

5. **Deep pagination performance cliff** — Fetching page 100+ takes 20+ seconds or times out. OpenAlex cursor pagination degrades beyond 10k results. **Mitigation:** Use cursor pagination (`cursor=*` then `meta.next_cursor`) for all searches, cap results at 10k with refinement suggestions, implement virtual scrolling in UI.

## Implications for Roadmap

Based on research, the milestone should be split into 4-5 phases with clear dependencies. The current GitHub issues (#25, #10, #40, #43, #54, #51, #55) map to these phases but need reordering.

### Phase 0: Foundation (Refactor + DB Migrations)
**Rationale:** Cannot add discovery features to 1,760-line mod_search_notebook.R. Must split before extending. Database migrations (topics table, wizard state) need versioning infrastructure before ANY schema changes.

**Delivers:**
- Schema versioning (`PRAGMA user_version`, migration scripts)
- Topics table in DuckDB (topic_id, display_name, hierarchy fields)
- Wizard state tracking (has_seen_wizard setting)
- (Optional) Split mod_search_notebook.R into sub-modules if >1,760 lines causes issues

**Addresses:**
- Pitfall #6 (module refactor paralysis)
- Pitfall #5 (database migration chaos)

**Avoids:** Bolting features onto unmaintainable module, schema drift breaking user databases

**Research needs:** Standard patterns, no research-phase needed (documented in ARCHITECTURE.md and PITFALLS.md)

### Phase 1: Seed Paper Discovery + API Extensions
**Rationale:** Highest-value feature for validation. Tests end-to-end flow (user input → API call → query params → search notebook). Validates architecture before parallelizing other discovery modes.

**Delivers:**
- api_openalex.R: `get_work_by_doi()`, `get_related_works()` (cites/cited_by/related_to)
- mod_seed_paper_search module: DOI/URL input, autocomplete, related paper preview
- Integration: seed module outputs query params → app.R creates search notebook
- Abstract embedding fix (#55) if needed for seed paper selection quality

**Addresses:**
- Feature: Seed paper discovery (table stakes)
- Issue #25 (seed paper search)
- Issue #55 (abstract embedding fix — dependency for quality seed results)

**Avoids:**
- Pitfall #1 (rate limit blindness via credit tracking)
- Pitfall #8 (abstract reconstruction errors)

**Research needs:** Minimal — patterns documented in STACK.md. May need research-phase for embedding quality validation if #55 fix is complex.

### Phase 2: Query Builder + Sorting
**Rationale:** Simplest discovery module (no API deps beyond existing search). Enables LLM-assisted query construction. Rich sorting is table stakes and low-effort.

**Delivers:**
- mod_query_builder module: Year range, field selector, document type filters
- LLM-assisted natural language query → OpenAlex filter syntax
- Filter validation against allowlist (prevent hallucination)
- Rich sorting UI in search notebook (#54: relevance/citations/date toggles)

**Addresses:**
- Feature: LLM query builder (competitive differentiator)
- Feature: Rich sorting (table stakes)
- Issue #10 (LLM query builder)
- Issue #54 (rich sorting)

**Avoids:**
- Pitfall #3 (LLM hallucinated filters via validation)
- Pitfall #9 (reactivity over-triggering via debouncing)

**Research needs:** Medium — LLM prompt engineering for filter generation needs validation loop. Recommend research-phase for OpenRouter prompt testing.

### Phase 3: Topic Explorer
**Rationale:** Requires api_openalex.R extensions for topics endpoint. More API-intensive than query builder. Deferred until seed + query builder validate architecture.

**Delivers:**
- api_openalex.R: `get_topics_tree()`, `filter_works_by_topic()`
- mod_topic_explorer module: Hierarchical topic navigation (domain → field → subfield → topic)
- Topics table population (fetch OpenAlex taxonomy, store locally for offline browsing)
- Filter works by `primary_topic.id` or `topics.id`

**Addresses:**
- Feature: Topic exploration (competitive differentiator)
- Issue #40 (OpenAlex topics)

**Avoids:**
- Pitfall #7 (topic false positives via confidence thresholds)
- Pitfall #12 (filter checkbox overload via hierarchy + search)

**Research needs:** Low — OpenAlex Topics API is well-documented. Standard patterns apply.

### Phase 4: Startup Wizard + Integration
**Rationale:** Wizard depends on all discovery modules existing. Orchestrates user onboarding by routing to seed/search/topics. App integration wires everything together.

**Delivers:**
- mod_startup_wizard module: Multi-step onboarding (choose mode → discovery UI → create notebook)
- app.R integration: Show wizard on first startup (check has_seen_wizard flag)
- Wire all discovery modules to notebook creation workflow
- Dismissal + skip logic (don't block users, sensible defaults)

**Addresses:**
- Feature: Startup wizard (competitive differentiator)
- Issue #43 (startup wizard)

**Avoids:**
- Pitfall #11 (wizard abandonment via skip option + progressive disclosure)

**Research needs:** Low — Shiny modal patterns well-documented, wizard UX patterns in PITFALLS.md.

### Phase 5: Slide Citation Fix (Optional)
**Rationale:** Independent of discovery features. Can be parallel or post-discovery depending on priority.

**Delivers:**
- Fix #51 (slide citation formatting issue)

**Addresses:**
- Issue #51 (slide citation fix)

**Research needs:** None — bug fix, not feature.

### Phase Ordering Rationale

- **Phase 0 first**: Infrastructure before features. Cannot safely add discovery without schema versioning and module boundaries.
- **Seed paper (Phase 1) validates architecture**: Highest-value feature tests entire flow. If producer-consumer pattern fails, catch early.
- **Query builder (Phase 2) after seed**: Simplest discovery module (no API deps). Adds LLM validation patterns needed for other features.
- **Topic explorer (Phase 3) after query builder**: API-heavy. Deferred until architecture validated. Reuses patterns from Phase 1 (api_openalex extensions) and Phase 2 (filter UI).
- **Wizard (Phase 4) after all discovery modules**: Orchestrator cannot exist before orchestratees.
- **Dependencies respected**: DB migrations → API extensions → discovery modules → wizard integration.

### Research Flags

**Phases likely needing research-phase during planning:**
- **Phase 2 (Query Builder):** LLM prompt engineering for OpenAlex filter generation needs validation loop. Test with 20-30 sample queries to tune system prompt and validate allowlist coverage.

**Phases with standard patterns (skip research-phase):**
- **Phase 0 (Foundation):** Database migrations and module splitting are documented in PITFALLS.md and ARCHITECTURE.md. Follow existing patterns.
- **Phase 1 (Seed Paper):** OpenAlex citation endpoints well-documented in STACK.md. Straightforward API integration.
- **Phase 3 (Topic Explorer):** OpenAlex Topics API documented. Hierarchical UI patterns in ARCHITECTURE.md.
- **Phase 4 (Wizard):** Shiny modal patterns standard. Wizard UX patterns in PITFALLS.md.
- **Phase 5 (Slide Citation):** Bug fix, not research-intensive.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All recommendations verified from OpenAlex official docs and existing Serapeum codebase. No new dependencies needed. |
| Features | HIGH | Competitor analysis across 5 major tools (Connected Papers, Semantic Scholar, Elicit, ResearchRabbit, Litmaps). Table stakes vs. differentiators well-established. |
| Architecture | HIGH | Shiny module patterns documented in official Posit guides and Mastering Shiny. Producer-consumer pattern proven. Build order validated by dependency analysis. |
| Pitfalls | MEDIUM | Mix of official docs (OpenAlex rate limits, DuckDB VSS), academic research (LLM query hallucination), and community best practices (Shiny reactivity). Some pitfalls inferred from similar domains. |

**Overall confidence:** HIGH

Research is comprehensive across all four dimensions. Stack and architecture recommendations are directly verifiable. Feature landscape informed by extensive competitor analysis. Pitfalls research combines high-confidence official sources with medium-confidence community patterns — flagged appropriately.

### Gaps to Address

- **LLM query builder prompt tuning:** System prompt examples in STACK.md are starting points. Needs empirical validation with 20-30 test queries during Phase 2 planning. Use research-phase to iterate on prompt structure and validate filter allowlist coverage.

- **Embedding model choice:** STACK.md recommends text-embedding-3-small (already in use) but notes Cohere embed-english-v3.0 is domain-specific for scientific text. If embedding relevance issues emerge during Phase 1 (seed paper selection quality), evaluate Cohere or hybrid BM25+vector approach. Not blocking for initial implementation.

- **Startup wizard UX validation:** PITFALLS.md documents abandonment risks. Phase 4 planning should include telemetry for skip rate and completion rate. Consider A/B testing wizard vs. contextual help if abandonment >30%.

- **OpenAlex API quota exhaustion edge cases:** Credit tracking UI designed in Phase 1, but quota exhaustion recovery patterns (exponential backoff, user notification) need testing under realistic usage. Validate during Phase 1 with load testing (50+ searches within 1 hour).

## Sources

### Primary (HIGH confidence)
- [OpenAlex Works API](https://docs.openalex.org/api-entities/works) — Endpoints, filters, search (STACK.md)
- [OpenAlex Filter Works](https://docs.openalex.org/api-entities/works/filter-works) — Complete filter reference (STACK.md)
- [OpenAlex Work Object](https://docs.openalex.org/api-entities/works/work-object) — Field structure (STACK.md)
- [OpenAlex Topics](https://docs.openalex.org/api-entities/topics) — Topic hierarchy (STACK.md)
- [OpenAlex Rate Limits](https://docs.openalex.org/how-to-use-the-api/rate-limits-and-authentication) — Credit system (PITFALLS.md)
- [OpenAlex Paging](https://docs.openalex.org/how-to-use-the-api/get-lists-of-entities/paging) — Cursor pagination (PITFALLS.md)
- [Shiny Modules](https://shiny.posit.co/r/articles/improve/modules/) — Official Posit documentation (ARCHITECTURE.md)
- [Mastering Shiny: Modules](https://mastering-shiny.org/scaling-modules.html) — Module patterns (ARCHITECTURE.md)
- [DuckDB Vector Similarity Search](https://duckdb.org/docs/stable/core_extensions/vss) — Vector index maintenance (PITFALLS.md)

### Secondary (MEDIUM confidence)
- [Connected Papers, Semantic Scholar, Elicit, ResearchRabbit, Litmaps](https://libguides.lmu.edu/AIresearchtools/CP) — Competitor feature analysis (FEATURES.md)
- [Engineering Production-Grade Shiny Apps](https://engineering-shiny.org/structuring-project.html) — Module best practices (ARCHITECTURE.md)
- [Advanced SQLite Patterns for R and Shiny](https://unconj.ca/blog/advanced-sqlite-patterns-for-r-and-shiny.html) — Database migration patterns (PITFALLS.md)
- [LLM-based Query Expansion](https://dl.acm.org/doi/10.1145/3726302.3730222) — Query hallucination research (PITFALLS.md)
- [Search Relevance Tuning](https://www.elastic.co/search-labs/blog/search-relevance-tuning-in-semantic-search) — Hybrid search patterns (PITFALLS.md)
- [Text-to-SQL LLM Accuracy](https://research.aimultiple.com/text-to-sql/) — Query generation benchmarks (PITFALLS.md)

### Tertiary (LOW confidence)
- Community blog posts and LibGuides for competitor workflows (FEATURES.md)
- 2026 projection articles for topic modeling techniques (PITFALLS.md)
- Inference from related domain patterns (e.g., Elasticsearch pagination applied to OpenAlex)

---
*Research completed: 2026-02-10*
*Ready for roadmap: yes*
