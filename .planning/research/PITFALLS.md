# Pitfalls Research: Research Discovery Tools

**Domain:** Academic Research Discovery (Seed Papers, Query Building, Topic Exploration)
**Researched:** 2026-02-10
**Confidence:** MEDIUM

## Critical Pitfalls

Mistakes that cause rewrites or major issues.

### Pitfall 1: OpenAlex API Rate Limit Blindness

**What goes wrong:**
Application makes hundreds of individual API calls during normal usage, hitting 429 rate limit errors. Users can't search or refresh paper lists. With free API key (100,000 credits/day), list queries (10 credits each) allow only ~10,000 queries/day, but naive implementations can burn through this in hours.

**Why it happens:**
Developers don't track credit consumption per endpoint type. Each paginated list query costs 10 credits, not 1. Looping through individual paper lookups (1 credit each) instead of batching with OR syntax. Vector/semantic search endpoints cost 1,000 credits per query — a single embeddings feature can consume entire daily quota.

**How to avoid:**
- Track cumulative credit usage client-side with counter
- Batch entity lookups using OR syntax (`id=W1|W2|W3...`) — 50 lookups in 1 request
- Cache paper metadata aggressively (DuckDB persistence)
- Display remaining credits to user before expensive operations
- Never trigger semantic search on page load — user-initiated only
- Implement exponential backoff for 429 responses

**Warning signs:**
- Users report "search stopped working" intermittently
- 429 HTTP errors in logs
- Features work in morning but fail by afternoon (daily quota reset)
- Testing with few papers works, production with 100+ fails

**Phase to address:**
Phase 1 (Startup/Seed Paper) — quota tracking infrastructure must exist before any API usage

**Sources:**
- [OpenAlex Rate Limits Documentation](https://docs.openalex.org/how-to-use-the-api/rate-limits-and-authentication)
- [OpenAlex API Guide for LLMs](https://docs.openalex.org/api-guide-for-llms)

---

### Pitfall 2: Deep Pagination Performance Cliff

**What goes wrong:**
Fetching page 100+ of search results takes 20+ seconds or times out. Users wait indefinitely for "Load More" button. OpenAlex cursor pagination becomes prohibitively slow beyond 10,000 results. App appears frozen.

**Why it happens:**
Using offset-based pagination (`page=100`) instead of cursor pagination for deep result sets. Each deep page requires database to scan all previous records. Cursor pagination (`cursor=*` then `meta.next_cursor`) maintains state but still degrades at 100k+ scale. Developers attempt to download entire OpenAlex corpus via API instead of using snapshot.

**How to avoid:**
- Use cursor pagination for all searches (mandatory for >10k results)
- Limit result sets with strong filters before pagination (publication year, type, venue)
- Display "Showing first 10,000 results" cap with refinement suggestions
- Never attempt bulk download via API — use [OpenAlex snapshot](https://docs.openalex.org/download-all-data/openalex-snapshot) for corpus-wide analysis
- Implement virtual scrolling/windowing for large lists in UI

**Warning signs:**
- Search performance degrades as user scrolls deeper
- Timeout errors on page 50+
- Users complain "old interface was faster" (simple pagination vs. cursor complexity)
- Database query time grows linearly with offset

**Phase to address:**
Phase 2 (Query Builder) — pagination must scale before users build complex queries returning 50k+ results

**Sources:**
- [OpenAlex Paging Documentation](https://docs.openalex.org/how-to-use-the-api/get-lists-of-entities/paging)
- [Comprehensive Guide to Elasticsearch Pagination 2026](https://www.luigisbox.com/blog/elasticsearch-pagination/)
- [OpenSearch Pagination Best Practices](https://opensearch.org/blog/navigating-pagination-in-hybrid-queries-with-the-pagination_depth-parameter/)

---

### Pitfall 3: LLM Query Builder Hallucinated Filters

**What goes wrong:**
LLM-assisted query builder generates OpenAlex filters with non-existent fields (`venue.impact_factor`, `author.h_index_recent`), malformed boolean logic (`AND` instead of comma-separated), or semantically incorrect date ranges ("recent papers" → `from_publication_date=2020` in 2026). Queries return zero results or wrong papers. Users lose trust in assistant.

**Why it happens:**
LLM trained on generic API patterns, not OpenAlex-specific filter syntax. Field hallucination when user asks for unavailable metadata (impact factor, author reputation). Ambiguous queries ("don't serve meat" → restaurants serving meat) because negation is poorly handled. Schema drift — LLM trained on old OpenAlex docs.

**How to avoid:**
- Provide **exact** OpenAlex filter schema in system prompt with examples
- Use few-shot examples: "Show me recent ML papers" → `filter=publication_year:2024-2026,concepts.id:C154945302`
- Validate LLM output against allowed filter fields before API call
- Display generated query to user for approval before execution
- Maintain allowlist of valid filter keys/operators from [OpenAlex docs](https://docs.openalex.org/how-to-use-the-api/get-lists-of-entities/filter-entity-lists)
- For unsupported filters (impact factor), explain limitation + suggest alternatives

**Warning signs:**
- Zero results from seemingly valid queries
- LLM generates filters not in OpenAlex docs
- Date filters off by years
- Boolean logic errors (AND/OR confusion)
- Users manually fix queries repeatedly

**Phase to address:**
Phase 2 (Query Builder) — validation layer is non-negotiable before LLM touches API

**Sources:**
- [Text-to-SQL: Comparison of LLM Accuracy 2026](https://research.aimultiple.com/text-to-sql/)
- [LLM-based Query Expansion Fails for Unfamiliar Queries](https://dl.acm.org/doi/10.1145/3726302.3730222)
- [Bridging Natural Language and Databases: LLM-Generated SQL](https://medium.com/@vi.ha.engr/bridging-natural-language-and-databases-best-practices-for-llm-generated-sql-fcba0449d4e5)

---

### Pitfall 4: Embedding Relevance Trap

**What goes wrong:**
Semantic search returns topically related papers that are lexically mismatched. Query "transformer models for NLP" returns papers about electrical transformers or visual transformers. Embedding search finds "similar" papers that users reject as irrelevant. Keyword filter + embedding conflict — papers pass embedding threshold but lack query keywords.

**Why it happens:**
Embeddings compress semantics into fixed-dimension vectors — insufficient resolution to distinguish "transformer (electrical)" from "transformer (attention mechanism)". Model trained on broad corpus, not domain-specific. Using semantic search alone without hybrid (BM25 + vector). Embedding model drift — text-embedding-3-small has high relevance but low accuracy (finds general area, not specific answer).

**How to avoid:**
- **Hybrid search:** Combine embedding similarity with keyword matching (BM25)
- Weight keyword match higher for technical/ambiguous terms
- Use domain-specific embedding models (e.g., [Cohere embed-english-v3.0](https://www.graft.com/blog/text-embeddings-for-search-semantic) trained on scientific text)
- Rerank top 100 embedding results with cross-encoder for precision
- Show keyword match highlighting alongside similarity score
- Allow users to toggle "strict keyword matching" to override embeddings

**Warning signs:**
- Users report "irrelevant" results in semantic search
- High similarity scores (0.85+) but wrong domain
- Keyword search outperforms embedding search
- Users manually add keywords to compensate for semantic drift

**Phase to address:**
Phase 3 (Topic Explorer) — hybrid search must exist before introducing embedding-based navigation

**Sources:**
- [Search Relevance Tuning: Balancing Keyword and Semantic Search](https://www.elastic.co/search-labs/blog/search-relevance-tuning-in-semantic-search)
- [Understanding Hybrid Search RAG for Better AI Answers](https://www.meilisearch.com/blog/hybrid-search-rag)
- [Taxonomy of the Retrieval System Framework: Pitfalls and Paradigms](https://arxiv.org/html/2601.20131)

---

### Pitfall 5: Database Migration Ad-Hocery

**What goes wrong:**
Add new column to DuckDB table in dev, push to production. Existing user databases lack column → SQL errors crash app. Try ALTER TABLE on app start → race conditions with concurrent sessions. Schema mismatch between fresh installs and upgraded databases. No rollback mechanism when migration fails.

**Why it happens:**
No schema versioning system (`PRAGMA user_version` unused). Migrations run in Shiny server function without transaction safety. Developers manually ALTER TABLE in console, forget to document. DuckDB doesn't enforce strict schema migrations like Rails/Django. Small userbase makes testing easy → scales poorly.

**How to avoid:**
- Use `PRAGMA user_version` to track schema version (integer, starts at 0)
- Numbered migration scripts: `migration_001.sql`, `migration_002.sql`
- On app init: read version, apply missing migrations in transaction
- Wrap all migrations in `dbWithTransaction()` for atomicity
- Test migration path: v0 → v1 → v2 AND v0 → v2 (skip-safe)
- Log applied migrations to table (`schema_migrations` with version + timestamp)
- Fail loudly on version downgrade (new app → old database)

**Warning signs:**
- "Column does not exist" errors in production logs
- Different behavior for new users vs. existing users
- Developer says "just delete your database and restart"
- Hotfixes involve manual SQL in user support

**Phase to address:**
Phase 1 (Startup/Seed Paper) — versioning infrastructure before ANY schema changes

**Sources:**
- [Advanced SQLite Patterns for R and Shiny](https://unconj.ca/blog/advanced-sqlite-patterns-for-r-and-shiny.html)
- [Using Databases with Shiny](https://emilyriederer.netlify.app/post/shiny-db/)

---

### Pitfall 6: 1760-Line Module Refactor Paralysis

**What goes wrong:**
`mod_search_notebook.R` is 1,760 lines. Adding new features (seed paper, sorting, topic filter) requires touching 10+ reactive chains. Bug fixes break unrelated features. Onboarding new developers takes days. Code review is impossible. Refactoring "too risky" so features are bolted on, making problem worse.

**Why it happens:**
Single module handles: paper list rendering, keyword panel, abstract detail, chat interface, embedding workflow, import/export. Reactivity graph has 30+ reactive expressions with hidden dependencies. No clear separation between data layer (DB queries), logic (filtering/sorting), and presentation (UI rendering). "Just one more feature" mentality.

**How to avoid:**
- **Split by responsibility:** `mod_paper_list`, `mod_keyword_filter`, `mod_abstract_detail`, `mod_chat_panel`
- Extract non-reactive logic to pure functions (testable in isolation)
- Use reactive modules for sub-components (e.g., `keyword_filter_server()` returns filtered IDs)
- Document reactive dependencies with comments or `reactlog`
- Enforce line limit: modules >500 lines require split justification in PR
- Add integration tests before refactoring (ensure behavior preserved)

**Warning signs:**
- "I don't remember what this reactive does"
- Fixing bug A breaks feature B
- Pull requests touch 20+ functions
- Developers avoid module because "too complex"
- Reactivity cascade takes >5 seconds to stabilize

**Phase to address:**
Phase 0 (Refactor Foundation) — split module BEFORE adding discovery features (phases 1-3 depend on this)

**Sources:**
- [Engineering Production-Grade Shiny Apps: Common Caveats](https://engineering-shiny.org/common-app-caveats.html)
- [Optimizing Shiny Performance for Big Data](https://www.numberanalytics.com/blog/optimizing-shiny-performance-big-data)

---

## Moderate Pitfalls

### Pitfall 7: Topic Model False Positives

**What goes wrong:**
OpenAlex topic classification tags papers with spurious concepts. "Machine learning" paper tagged with "healthcare" because dataset mentions patient records. Topic filter excludes relevant papers or includes junk. Users distrust automated classification.

**Why it happens:**
Topic models detect word co-occurrence, not semantic relationships. Demographically correlated words (survey responses from medical researchers → medical terms co-occur with ML terms). Ambiguous terminology (e.g., "cell" in biology vs. spreadsheets).

**How to avoid:**
- Display topic scores/confidence (don't show low-confidence tags)
- Allow users to override topic filters with keyword search
- Hybrid filtering: topic AND keyword for precision
- Seed topic models with domain-specific prompts (2026 technique)
- Show why topic was assigned (word overlap visualization)

**Warning signs:**
- Users manually remove topic filters
- High false positive rate in filtered results
- Topic tags unrelated to paper content

**Phase to address:**
Phase 3 (Topic Explorer) — implement confidence thresholds and override mechanisms

**Sources:**
- [Making Sense of Topic Models](https://www.pewresearch.org/decoded/2018/08/13/making-sense-of-topic-models/)
- [Topic Modeling Techniques for 2026](https://towardsdatascience.com/topic-modeling-techniques-for-2026-seeded-modeling-llm-integration-and-data-summaries/)

---

### Pitfall 8: Abstract Inverted Index Reconstruction Errors

**What goes wrong:**
Reconstruct abstract from OpenAlex inverted index with word ordering bugs. "transformer models attention mechanism" becomes "attention mechanism transformer models". Punctuation lost. Line breaks in wrong places. Users read garbled abstracts.

**Why it happens:**
Inverted index stores `{word: [positions]}` — must reconstruct sequentially. Off-by-one errors in position mapping (0-indexed vs. 1-indexed). Missing handling for empty positions or duplicate positions. Punctuation stored separately or lost entirely.

**How to avoid:**
- Test reconstruction with known abstracts (ground truth comparison)
- Handle edge cases: empty index, single word, max position = 0
- Preserve whitespace from original (spaces, newlines)
- Validate reconstructed length matches expected (char count ± 5%)
- Fallback: if reconstruction fails, fetch from DOI/source

**Warning signs:**
- Abstracts with wrong word order
- Missing punctuation or spacing
- Users report "abstract doesn't match paper"

**Phase to address:**
Phase 1 (Startup/Seed Paper) — seed paper selection relies on abstract quality

**Sources:**
- [Getting Abstracts from Microsoft Academic's Inverted Index](https://christinaslisrant.scientopia.org/2018/05/14/getting-abstracts-back-from-microsoft-academics-inverted-index/)
- Current codebase: `R/api_openalex.R` line 28-54 (`reconstruct_abstract`)

---

### Pitfall 9: Shiny Reactivity Over-Triggering

**What goes wrong:**
User types in search box → triggers 20 reactive updates → UI freezes for 3 seconds. Every keystroke reruns expensive embedding search. Reactive loop: filter A updates filter B updates filter A (infinite loop crash).

**Why it happens:**
No debouncing on text inputs. Reactive expressions depend on expensive operations (database queries, API calls) without caching. Circular dependencies between reactives. Large datasets (10k+ papers) reprocessed on every input change.

**How to avoid:**
- Debounce text inputs (`debounce(input$search, 500)` for 500ms delay)
- Cache expensive reactives with `bindCache()` (requires Shiny 1.6+)
- Use `observeEvent()` with `ignoreInit = TRUE` to prevent startup cascade
- Async operations for long-running tasks (prevent UI blocking)
- Profile with `reactlog::reactlog_enable()` to visualize dependency graph

**Warning signs:**
- UI sluggish during typing
- Rapid console output during single action
- "Reactive inferno" messages in logs
- Memory usage grows over session time

**Phase to address:**
Phase 2 (Query Builder) — complex filters require tight reactivity control

**Sources:**
- [Shiny Reactive Programming: Advanced Patterns](https://www.datanovia.com/learn/tools/shiny-apps/fundamentals/reactive-programming.html)
- [From 30 to 3 Seconds: Making Shiny App 10x Faster](https://www.appsilon.com/post/shiny-app-performance-fix)

---

### Pitfall 10: DuckDB Vector Search Index Corruption

**What goes wrong:**
HNSW vector index becomes stale after deletions. Query performance degrades from <1s to 20s. App crashes on shutdown → database reopens with corrupted index. Embeddings return wrong papers or no results.

**Why it happens:**
DuckDB VSS extension (experimental) doesn't handle WAL recovery for custom indexes. Deletes marked but not pruned → index bloat. Full index rewrite on every checkpoint (performance cliff). No incremental updates.

**How to avoid:**
- Call `PRAGMA hnsw_compact_index('index_name')` after bulk deletes (manually trigger compaction)
- Rebuild index periodically (weekly cron job or startup check)
- Monitor index staleness: track delete count since last compaction
- Graceful shutdown: close DuckDB connection properly (avoid WAL corruption)
- Test recovery: simulate crash, verify index integrity on restart

**Warning signs:**
- Embedding search slows over time
- Wrong papers returned after deletions
- Database file size grows unexpectedly
- Errors on app restart after crash

**Phase to address:**
Phase 3 (Topic Explorer) — vector search at scale requires index maintenance

**Sources:**
- [DuckDB Vector Similarity Search Extension](https://duckdb.org/docs/stable/core_extensions/vss)
- [Using DuckDB for Embeddings and Vector Search](https://blog.brunk.io/posts/similarity-search-with-duckdb/)
- [Vector Search Performance: Speed & Scalability Benchmarks](https://www.newtuple.com/post/speed-and-scalability-in-vector-search)

---

## Minor Pitfalls

### Pitfall 11: Wizard Onboarding Premature Interruption

**What goes wrong:**
Startup wizard forces user through 5-step configuration before accessing app. Users skip steps to "get to the real app." Wizard doesn't persist progress → exit means restart. Users abandon before completing.

**Why it happens:**
Push-based onboarding (forced tutorial) violates "paradox of active user" — users want to start immediately, not learn. Wizard interrupts goal-oriented workflow. No skip option or progressive disclosure.

**How to avoid:**
- Pull-based onboarding: contextual help when user needs it (tooltips, inline hints)
- Skip option with sensible defaults (minimal config to start)
- Persist wizard progress (resume on next session)
- Role-aware onboarding (first-time vs. returning user)
- Show value before asking for config (demo search results with placeholder data)

**Warning signs:**
- High wizard abandonment rate
- Users complain "too many steps"
- Support requests: "how do I skip wizard?"

**Phase to address:**
Phase 1 (Startup/Seed Paper) — wizard must enhance, not block, first use

**Sources:**
- [Progressive Disclosure Examples for SaaS](https://userpilot.com/blog/progressive-disclosure-examples/)
- [Onboarding Tutorials vs. Contextual Help](https://www.nngroup.com/articles/onboarding-tutorials/)

---

### Pitfall 12: Filter UI Checkbox Overload

**What goes wrong:**
Topic explorer shows 150 checkboxes for topic categories. Users scroll for 30 seconds to find relevant topics. Analysis paralysis → users don't filter at all. Mobile UI unusable.

**Why it happens:**
No progressive disclosure (all filters visible at once). No prioritization (all topics equal weight). No search within filters.

**How to avoid:**
- Group filters hierarchically (collapsible sections)
- Show top 10 most-used filters by default, "Show more" for rest
- Search box to filter filter list (meta-filter)
- Prioritize by frequency in current result set
- Use count badges to show impact (e.g., "NLP (423 papers)")

**Warning signs:**
- Users don't use filters despite many options
- Complaints about "too many checkboxes"
- Mobile users avoid filter panel

**Phase to address:**
Phase 3 (Topic Explorer) — hierarchy and search required for 100+ topics

**Sources:**
- [Checkbox UX: Best Practices and Mistakes](https://www.eleken.co/blog-posts/checkbox-ux)
- [Filtering UX/UI Design Patterns and Best Practices](https://blog.logrocket.com/ux-design/filtering-ux-ui-design-patterns-best-practices/)

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skip API key validation | Faster startup | Users hit rate limits without warning | Never (2-line check) |
| Embed all papers on search load | "Automatic" semantic search | Burns OpenRouter credits, slow for 100+ papers | Never (user-triggered only) |
| Store embeddings as JSON string | Simple schema | Can't index/query efficiently, slow retrieval | Prototype only (migrate in Phase 3) |
| Single reactive module | Faster initial dev | Impossible to maintain/test | MVP only (refactor <500 lines) |
| No migration versioning | Skip boilerplate | Schema drift breaks user databases | Never (upfront cost <1 hour) |
| Cursor pagination without UI feedback | Simpler code | Users think app is frozen during load | Never (add spinner/progress) |
| LLM query builder without validation | "Intelligent" UX | Hallucinated filters break searches | Never (validation <30 lines) |
| Cache embeddings forever | Fast search | Stale after paper updates/deletions | Short sessions only (invalidate daily) |

---

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| OpenAlex API | Individual paper lookups in loop | Batch with OR syntax (`id=W1\|W2\|W3...`) |
| OpenRouter Embeddings | Embed on every search | Cache embeddings in DuckDB, embed on-demand |
| OpenAlex Filters | Trust LLM-generated filter syntax | Validate against field allowlist before API call |
| DuckDB Vector Search | Assume ACID guarantees | Manually compact index after deletes, test crash recovery |
| OpenAlex Pagination | Use offset for deep pages | Use cursor (`cursor=*`) for >10k results |
| OpenRouter Chat | Send full chat history every call | Truncate to last 10 messages or use summarization |

---

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Embedding all papers on load | 5-paper search works, 100-paper search times out | User-triggered embedding with progress bar | 50+ papers (OpenRouter rate limit) |
| Reactive re-render of 1000-row table | UI freezes on filter change | Virtual scrolling (DT or reactable) | 200+ rows rendered |
| Full history in chat context | First 10 messages fine, then slow | Sliding window (last 10) or summarize old messages | 30+ messages (token limit) |
| No index on paper lookup | Works with 100 papers | Index on paper ID, search notebook ID | 1000+ papers in DB |
| Synchronous API calls in Shiny | Single user OK, multi-user blocked | Async with `promises` or background jobs | 2+ concurrent users |
| DuckDB connection per reactive | Dev mode fast, production crashes | Singleton connection with lock | 10+ concurrent sessions |

---

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Expose OpenRouter API key client-side | Key theft → unlimited usage billed to you | Server-side only, never in JS or HTML |
| Store API keys in plain text config | Source control leak → credential theft | Use keyring package or env vars, gitignore config.yaml |
| No rate limiting on LLM calls | User spams "Generate" → $100 bill | Throttle: 1 request per 5 seconds per user |
| Allow arbitrary OpenAlex filters from LLM | Injection via crafted prompts | Allowlist validation (only known filter keys) |
| No input sanitization for search | XSS if displaying user queries | Escape HTML in search terms before rendering |

---

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No indication of API quota usage | Surprise "out of credits" error mid-search | Display remaining credits, warn at 20% |
| Embedding without progress feedback | App appears frozen for 60s | Progress bar: "Embedding paper 5 of 50..." |
| Generated query hidden from user | Trust issues when results seem wrong | Show query in expandable panel, allow editing |
| Zero results without explanation | User doesn't know if query bad or data unavailable | Suggest query relaxation (remove filters one-by-one) |
| Topic filter removes all results | Confusion, user abandons | Disable filters that yield 0 results, show count before applying |
| Seed paper selection without preview | Blind choice leads to bad search | Show title + abstract + citation count before confirming |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Seed paper search:** Looks functional, but missing abstract quality check (empty/truncated abstracts break similarity)
- [ ] **LLM query builder:** Generates queries, but no validation → hallucinated filters cause silent failures
- [ ] **Topic explorer:** Shows topics, but no disambiguation → "cell" biology vs. spreadsheets both tagged
- [ ] **Embedding search:** Returns results, but no hybrid BM25 → irrelevant papers with high cosine similarity
- [ ] **Pagination UI:** "Load More" works, but no cursor state → reloading page loses position
- [ ] **Database migrations:** ALTER TABLE runs, but no versioning → existing users get schema errors
- [ ] **API error handling:** Catches 429, but no retry logic → permanent failure on transient error
- [ ] **Progress indicators:** Shows spinner, but no ETA → users can't tell if 10s or 10min wait

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Hit rate limit mid-search | LOW | Show error with quota reset time, cache current results |
| Corrupted HNSW index | MEDIUM | Rebuild index from existing embeddings (5-10min for 10k papers) |
| LLM hallucinated filter | LOW | Catch API error, explain invalid filter, suggest valid alternatives |
| 1760-line module | HIGH | Incremental refactor: extract 1 sub-module per sprint, integration tests |
| Schema migration failed | MEDIUM | Rollback transaction, log error, prevent app start with clear message |
| Embedding search returns junk | LOW | Toggle to keyword-only mode, offer reranking with stricter threshold |
| Infinite reactive loop | MEDIUM | Emergency: `isolate()` problematic reactive, fix dependency cycle |
| Zero results from valid query | LOW | Relax filters one-by-one, show diagnostic (which filter excluded most) |

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| OpenAlex rate limit blindness | Phase 1 (Startup/Seed Paper) | Load test: 50 searches within 1 hour, monitor credits |
| Deep pagination cliff | Phase 2 (Query Builder) | Search with >10k results, verify cursor pagination, measure p95 latency |
| LLM query hallucination | Phase 2 (Query Builder) | Unit test: invalid filter schema rejected, integration test: zero hallucinations on 20 test queries |
| Embedding relevance trap | Phase 3 (Topic Explorer) | Manual review: 100 random embedding results, <5% false positives |
| Database migration chaos | Phase 0 (Refactor Foundation) | Test: fresh install, v0→v1 migration, v0→v3 migration, all pass |
| Module refactor paralysis | Phase 0 (Refactor Foundation) | Line count: no module >500 lines, test coverage >80% |
| Topic model false positives | Phase 3 (Topic Explorer) | User testing: 10 users filter by topic, <2 report irrelevant results |
| Abstract reconstruction errors | Phase 1 (Startup/Seed Paper) | Ground truth test: 100 known abstracts, 100% correct reconstruction |
| Reactivity over-triggering | Phase 2 (Query Builder) | Reactlog analysis: <10 reactive invalidations per user action |
| DuckDB index corruption | Phase 3 (Topic Explorer) | Crash test: kill app mid-write, restart, verify index integrity |
| Wizard abandonment | Phase 1 (Startup/Seed Paper) | Telemetry: <20% wizard skip rate, >70% completion rate |
| Filter checkbox overload | Phase 3 (Topic Explorer) | Usability test: users find target topic in <10 seconds |

---

## Sources

### Official Documentation (HIGH Confidence)
- [OpenAlex Rate Limits and Authentication](https://docs.openalex.org/how-to-use-the-api/rate-limits-and-authentication)
- [OpenAlex Paging Documentation](https://docs.openalex.org/how-to-use-the-api/get-lists-of-entities/paging)
- [OpenAlex API Guide for LLMs](https://docs.openalex.org/api-guide-for-llms)
- [DuckDB Vector Similarity Search Extension](https://duckdb.org/docs/stable/core_extensions/vss)
- [DuckDB Vector Similarity Search Blog](https://duckdb.org/2024/05/03/vector-similarity-search-vss)

### Academic Research (MEDIUM Confidence)
- [LLM-based Query Expansion Fails for Unfamiliar Queries](https://dl.acm.org/doi/10.1145/3726302.3730222)
- [Taxonomy of the Retrieval System Framework: Pitfalls and Paradigms](https://arxiv.org/html/2601.20131)
- [Making Sense of Topic Models - Pew Research](https://www.pewresearch.org/decoded/2018/08/13/making-sense-of-topic-models/)

### Technical Blogs & Guides (MEDIUM Confidence)
- [Advanced SQLite Patterns for R and Shiny](https://unconj.ca/blog/advanced-sqlite-patterns-for-r-and-shiny.html)
- [Using Databases with Shiny - Emily Riederer](https://emilyriederer.netlify.app/post/shiny-db/)
- [Search Relevance Tuning: Balancing Keyword and Semantic Search](https://www.elastic.co/search-labs/blog/search-relevance-tuning-in-semantic-search)
- [Understanding Hybrid Search RAG](https://www.meilisearch.com/blog/hybrid-search-rag)
- [Using DuckDB for Embeddings and Vector Search](https://blog.brunk.io/posts/similarity-search-with-duckdb/)
- [Vector Search Performance Benchmarks](https://www.newtuple.com/post/speed-and-scalability-in-vector-search)

### Best Practices & Patterns (MEDIUM Confidence)
- [Engineering Production-Grade Shiny Apps: Common Caveats](https://engineering-shiny.org/common-app-caveats.html)
- [Optimizing Shiny Performance for Big Data](https://www.numberanalytics.com/blog/optimizing-shiny-performance-big-data)
- [From 30 to 3 Seconds: Making Shiny App 10x Faster](https://www.appsilon.com/post/shiny-app-performance-fix)
- [Text-to-SQL: Comparison of LLM Accuracy 2026](https://research.aimultiple.com/text-to-sql/)
- [Comprehensive Guide to Elasticsearch Pagination 2026](https://www.luigisbox.com/blog/elasticsearch-pagination/)

### UX Research (MEDIUM Confidence)
- [Progressive Disclosure Examples for SaaS](https://userpilot.com/blog/progressive-disclosure-examples/)
- [Onboarding Tutorials vs. Contextual Help - Nielsen Norman Group](https://www.nngroup.com/articles/onboarding-tutorials/)
- [Checkbox UX: Best Practices and Mistakes](https://www.eleken.co/blog-posts/checkbox-ux)
- [Filtering UX/UI Design Patterns](https://blog.logrocket.com/ux-design/filtering-ux-ui-design-patterns-best-practices/)

### Domain-Specific (LOW Confidence)
- [Topic Modeling Techniques for 2026](https://towardsdatascience.com/topic-modeling-techniques-for-2026-seeded-modeling-llm-integration-and-data-summaries/) (WebSearch only)
- [Getting Abstracts from Microsoft Academic's Inverted Index](https://christinaslisrant.scientopia.org/2018/05/14/getting-abstracts-back-from-microsoft-academics-inverted-index/) (Blog, 2018)

---

*Pitfalls research for: Serapeum Research Discovery Features*
*Researched: 2026-02-10*
*Confidence: MEDIUM (mix of official docs, academic research, and community best practices)*
