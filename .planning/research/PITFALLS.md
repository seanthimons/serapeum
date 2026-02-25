# Pitfalls Research

**Domain:** Citation Audit, Bulk Import, .bib Parsing, and Prompt Healing for R/Shiny Research Assistant
**Researched:** 2026-02-25
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: OpenAlex Rate Limit Cascade Failure

**What goes wrong:**
Bulk DOI imports trigger rapid-fire API requests that hit the 100 req/sec limit (or $1/day budget limit with free API key), causing 429 errors that block all subsequent operations. Users paste 50 DOIs, app makes 50 sequential requests in 2 seconds, OpenAlex returns 429 for requests 11-50, and the entire batch fails without partial results.

**Why it happens:**
Developers treat bulk operations as "loop over single-item function" without considering that OpenAlex enforces per-second rate limits globally, not per-session. The existing `get_paper()` function has no rate limiting—it's designed for single lookups. As of February 13, 2026, OpenAlex requires an API key and free tier gets $1/day budget—single entity lookups are free, but list queries cost $0.0001 and search queries cost $0.001. Exceeding budget or making >100 req/sec returns 429 errors.

**How to avoid:**
1. **Batch API requests using OR syntax**: OpenAlex supports `filter=doi:10.xxx/yyy|10.aaa/bbb` with up to 50 DOIs per request—this turns 50 requests into 1 request
2. **Add global rate limiter**: Track requests per second across all threads using semaphore or rate limiter (not per-thread counters)
3. **Add delays between batches**: If processing >50 DOIs, add 0.1-0.2 second sleep between each 50-DOI batch
4. **Implement exponential backoff**: On 429 error, wait 2^n seconds before retry (n = attempt number)
5. **Show partial results**: Store successfully fetched papers before rate limit hit, allow user to retry remaining

**Warning signs:**
- 429 errors in logs during bulk operations
- User reports "some papers loaded, then nothing"
- OpenAlex API calls fail after first 10-20 DOIs
- Budget exhaustion messages in API responses

**Phase to address:**
Phase 34 (Bulk DOI Upload) must implement batching and rate limiting before any UI work

---

### Pitfall 2: BibTeX Parsing Malformed Entry Silent Failure

**What goes wrong:**
User uploads .bib file with one malformed entry (missing closing brace, unescaped special character in author field, nested braces in abstract), parser fails on that entry and either crashes the entire import or silently skips it without notification. User expects 50 papers, gets 42, doesn't know which 8 failed or why.

**Why it happens:**
Real-world BibTeX files are messy: exported from different reference managers (Zotero, Mendeley, EndNote) with varying compliance to BibTeX spec, contain UTF-8 characters without proper escaping, have multi-line fields with unpredictable whitespace, include custom fields that don't match standard schema. R's `bib2df::bib2df()` and `bibtex::read.bib()` parsers throw errors on malformed entries rather than attempting recovery. Inside string literals and nested braces (2+ levels deep), virtually everything including whitespace becomes literal string tokens—naive line-by-line splitting breaks.

**How to avoid:**
1. **Use rbibutils or RefManageR**: These parsers (based on btparse C library) are more tolerant of malformed entries than bib2df
2. **Implement entry-level try-catch**: Parse each `@article{...}` block independently—if one fails, mark it as "unknown" type and preserve content for manual fixing
3. **Pre-validate file structure**: Before full parse, check for matching braces, detect encoding (UTF-8 BOM vs Latin-1), count entries
4. **Show parse diagnostics**: Display "Parsed 42/50 entries. 8 failed (see details)" with line numbers and error types
5. **Extract DOIs even from malformed entries**: Use regex to find `doi = {10.\d{4,}/\S+}` patterns before structural parsing—DOIs can seed OpenAlex lookups to recover metadata

**Warning signs:**
- Import completes but result count doesn't match file's `@article` count
- No error message displayed but network graph is incomplete
- DOI extraction returns empty list from non-empty .bib file
- Special characters (ä, é, ñ) in author names cause parse failures

**Phase to address:**
Phase 35 (.bib File Upload) must include robust parser with per-entry error handling and diagnostic UI

---

### Pitfall 3: Citation Audit SQL N+1 Query Explosion

**What goes wrong:**
Citation audit analyzes `referenced_works` column for 500 abstracts in database. Naive implementation loops through each abstract, queries `referenced_works`, counts occurrences across all rows—results in 500 individual SQL queries that take 30+ seconds and lock UI. At 5,000 abstracts, operation times out.

**Why it happens:**
`referenced_works` is stored as TEXT array in DuckDB abstracts table (line 252 in `api_openalex.R`: `referenced_works = if (!is.null(work$referenced_works)) as.character(work$referenced_works) else character()`). Developers treat this as "need to read each row" without recognizing that DuckDB supports array operations and aggregations. The "find missing seminal papers" requirement naturally suggests "scan all rows, count references"—but doing this in R rather than SQL moves data inefficiently.

**How to avoid:**
1. **Use DuckDB array functions**: `UNNEST(referenced_works)` flattens arrays into rows for aggregation in single query
2. **Single aggregation query**: `SELECT UNNEST(referenced_works) AS ref_id, COUNT(*) AS freq FROM abstracts WHERE notebook_id = ? GROUP BY ref_id ORDER BY freq DESC`
3. **Materialize top-N only**: Don't fetch all reference counts—limit to top 20-50 most frequently cited, batch lookup metadata from OpenAlex
4. **Index on referenced_works if needed**: DuckDB 1.0+ supports GIN indexes on arrays for faster UNNEST operations
5. **Cache audit results**: Store audit results in temporary table or R session variable—don't re-run on every view

**Warning signs:**
- Citation audit button hangs for >10 seconds with 100+ abstracts
- Database CPU spikes to 100% during audit
- Shiny session becomes unresponsive during audit
- `dbGetQuery()` calls in loop pattern in code

**Phase to address:**
Phase 33 (Citation Audit) must implement single-query aggregation pattern with DuckDB array operations

---

### Pitfall 4: LLM Prompt Healing Infinite Loop on YAML Validation

**What goes wrong:**
Slide generation produces malformed YAML (missing colon after `format`, incorrect indentation, `theme` at wrong nesting level). Healing logic detects error, sends YAML back to LLM with "fix this YAML" prompt, LLM returns different malformed YAML, healing retries, repeat until max retries (3-5 attempts). User sees "Generating slides..." spinner for 2+ minutes, costs rack up ($0.30+ on Claude Sonnet), final result is still broken.

**Why it happens:**
LLMs generate YAML with ~90% structural correctness—errors are often subtle (2 spaces vs 4 spaces, colon vs space-colon). Prompt engineering improves accuracy but can't guarantee 100% compliance. Generic "fix this YAML" prompts don't provide enough context—LLM doesn't know *which* part is wrong. Temperature=0 (deterministic mode) increases likelihood of inescapable loops—same input produces same wrong output. The existing `inject_theme_to_qmd()` and `inject_citation_css()` functions use regex substitution on LLM-generated content, which assumes correct structure—if structure is wrong, injection fails silently (lines 101-196 in `slides.R`).

**How to avoid:**
1. **Validate YAML structure programmatically first**: Use `yaml::yaml.load()` to parse frontmatter—catch specific errors (missing keys, wrong types) before LLM retry
2. **Provide specific error feedback**: Instead of "fix this YAML", send "YAML parser error: 'format' key missing colon at line 3. Valid format: `format:\n  revealjs:`"
3. **Limit retries to 2 maximum**: After 2 failed attempts, fall back to template YAML with only title customized—don't burn tokens on endless retries
4. **Use schema validation, not freeform generation**: Provide JSON schema or Pydantic model for structured output—OpenAI/Anthropic support structured output modes (100% schema compliance)
5. **Post-process with template merging**: If YAML parse fails after 2 retries, extract title from LLM output, merge into known-good template YAML, append body content

**Warning signs:**
- Slide generation takes >30 seconds on medium-length content
- Multiple "Generating..." progress updates for single generation
- Cost logs show 3-5 API calls for single slide generation
- Same YAML error appears in consecutive generations
- Users report "slides take forever to generate"

**Phase to address:**
Phase 37 (Slide Prompt Healing) must implement YAML validation + specific error feedback + 2-retry limit + template fallback

---

### Pitfall 5: Select-All Import Memory Explosion with Large Result Sets

**What goes wrong:**
User searches OpenAlex, gets 500 results, clicks "Select All and Import to Document Notebook". App attempts to load all 500 abstracts into memory, serialize for transfer between notebooks, crashes with "cannot allocate vector of size X GB" or Shiny session disconnects. Even if memory doesn't crash, UI freezes for 30+ seconds during transfer.

**Why it happens:**
Shiny's default file upload limit is 5MB—abstracts are small, but 500 abstracts × 2KB average = 1MB of text data, plus metadata (authors, keywords, venue) = 3-5MB total. If abstracts include `referenced_works` arrays (up to 100 references × 30 bytes = 3KB per abstract), 500 abstracts = 1.5MB of referenced_works alone. Transferring this between modules requires serialization into reactive value or temp file—R's object overhead (pointers, attributes) multiplies actual size by 3-5x. The existing code doesn't paginate—it assumes reasonably small batches (<50 papers).

**How to avoid:**
1. **Implement batch size warning**: If selection >100 abstracts, show modal: "Large batch detected. Importing 500 abstracts may take 30-60 seconds. Continue?"
2. **Paginated transfer via database**: Instead of serializing 500 abstracts through reactive, write to temp table in DuckDB, pass table ID to destination notebook, read in batches of 50
3. **Progress indicator for large batches**: Use `withProgress()` or ExtendedTask for imports >100 abstracts—show "Importing batch X of Y"
4. **Exclude referenced_works from transfer**: When transferring abstracts between notebooks, drop `referenced_works` column to reduce size—can be re-fetched if user opens citation network
5. **Test with realistic data volumes**: Add integration test with 500-paper import to catch memory issues before production

**Warning signs:**
- "Select All" button exists but no batch size limit documented
- No progress indicator for import operation
- Memory usage spikes >1GB during abstract transfer
- Shiny session disconnects with "lost connection to server"
- RStudio session crashes during large import

**Phase to address:**
Phase 36 (Select-All Import) must implement batch size warning + paginated transfer or progress indicator before enabling select-all

---

### Pitfall 6: .bib Import Referenced_Works Data Loss During OpenAlex Enrichment

**What goes wrong:**
User uploads .bib file with 50 papers. App extracts DOIs, queries OpenAlex API for full metadata to enrich venue/citation counts. During enrichment, some papers lack OpenAlex matches (not indexed, DOI mismatch, preprints). Code overwrites .bib metadata with NULL values from failed API lookups, losing author/title information that was in original .bib file.

**Why it happens:**
BibTeX files often contain preprints, working papers, or gray literature not indexed in OpenAlex. The naive pattern is: parse .bib → extract DOI → `get_paper(doi)` → if NULL, skip or store NULL. This loses the .bib's author/title/year. Developers assume OpenAlex is canonical source without considering that .bib file *already contains* metadata—API is for *enrichment*, not *replacement*.

**How to avoid:**
1. **Merge, don't replace**: Store .bib metadata first, then enrich with OpenAlex data—use coalesce pattern: `title = openalex$title %||% bib$title`
2. **Mark enrichment status**: Add `openalex_enriched` boolean column—TRUE if API match found, FALSE if only .bib data available
3. **Show enrichment stats**: After import, display "Imported 50 papers. 42 enriched with OpenAlex metadata. 8 from .bib only."
4. **Preserve DOI even on API failure**: If OpenAlex lookup fails, keep DOI from .bib—user may want to manually look up later
5. **Handle DOI format mismatches**: .bib files contain DOIs in various formats (full URL, doi: prefix, bare 10.xxxx)—normalize before OpenAlex lookup using `normalize_doi()` function

**Warning signs:**
- Papers imported from .bib show "Unknown" author when .bib had author field
- Citation counts are NULL for papers that should have them
- Venue/year disappear after .bib import
- Import log shows "50 papers parsed, 35 imported" with no explanation of missing 15

**Phase to address:**
Phase 35 (.bib File Upload) must implement merge-not-replace pattern with enrichment status tracking

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Sequential API calls in loop | Simple code—`lapply(dois, get_paper)` | Rate limits, poor UX, scales terribly | Only for single-paper lookups (existing use case) |
| Silently skip malformed .bib entries | Avoids error handling, "works" for clean files | Users lose data without notification, mysterious partial imports | Never—always log skipped entries |
| Load all selected abstracts into memory | Avoids pagination complexity | Crashes on >200 papers, poor UX | Only if hard-coded limit <100 papers with warning |
| Generic "fix this YAML" retry prompt | Easy to implement | Infinite loops, high cost, low success rate | Never—use schema validation or specific error feedback |
| Replace .bib metadata with NULL on API failure | Simpler merge logic | Data loss, user frustration | Never—.bib metadata is ground truth for unindexed papers |
| No progress indicator for bulk operations | Fewer UI components | Users think app froze, kill process prematurely | Only for operations guaranteed <2 seconds |
| R-based citation frequency counting | Familiar dplyr syntax | N+1 queries, doesn't scale past 1000 abstracts | Only for PoC or test—production must use SQL aggregation |

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| OpenAlex API (bulk lookups) | Loop over `get_paper()` for each DOI | Use `filter=doi:A\|B\|C` with up to 50 DOIs per request |
| OpenAlex rate limits | Assume "polite" per-thread limits work | Track req/sec *globally* across all threads, add 0.1s delays between batches |
| OpenAlex cost budgeting | Ignore $1/day free tier limit | Track daily spend, show user cost estimate before bulk operations |
| BibTeX parsing (R packages) | Use first parser found on CRAN | Test `bib2df`, `bibtex`, `rbibutils`, `RefManageR` with real-world messy .bib files |
| BibTeX DOI extraction | Assume `doi` field always exists and is formatted | Regex search across all fields—DOIs appear in `url`, `note`, custom fields |
| LLM YAML generation | Retry with same prompt on failure | Parse error, provide *specific* error in retry prompt (line number, expected format) |
| DuckDB array aggregation | Read `referenced_works` in R, count in R | Use `UNNEST()` + `GROUP BY` in SQL—10-100x faster |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Sequential DOI lookups | Works fine with 5 DOIs | Batch OR queries, rate limiting | >20 DOIs (~20 seconds) |
| In-memory abstract transfer | Fast with 10 papers | Paginated DB transfer or progress bar | >100 papers (~5MB) |
| R-based citation counting | Instant with 50 abstracts | SQL `UNNEST()` + `GROUP BY` | >500 abstracts (~30s) |
| Unbounded LLM retry loops | Fixes occasional YAML errors | Max 2 retries + template fallback | ~10% of generations, costs 5x |
| No progress indicator | Fine for <2 second ops | Add ExtendedTask for >5 second ops | Any bulk operation >10 items |
| Synchronous .bib parsing | 1-2 seconds for 50 entries | ExtendedTask for >100 entries | >200 entries (file reads block UI) |
| Full metadata in reactive transfer | Negligible with 10 papers | Drop large columns (referenced_works, abstract) | >50 papers (3MB+ reactive value) |

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Execute arbitrary YAML from LLM | Code injection if YAML contains `!expr` tags | Parse YAML with safe loader—`yaml::yaml.load(handlers = list())` disables evaluation |
| Trust DOI format from user input | SQL injection if DOI used in raw query | Use `normalize_doi()` + parameterized queries (existing code already safe via DBI placeholders) |
| Store API keys in generated QMD files | Leakage if user shares slides | Never embed API keys in LLM prompts or outputs—use session-scoped keys |
| Allow unlimited bulk API calls | User exhausts OpenAlex API key budget | Hard-limit bulk operations to 100 items per request + daily budget tracking |
| Parse .bib with `eval()` or `source()` | Arbitrary R code execution | Use dedicated BibTeX parsers only (bib2df, rbibutils)—never eval .bib content |

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No feedback during bulk import | "App is frozen—refresh and lose progress" | Progress modal with "Fetching batch 2 of 8..." and cancel button |
| Silent .bib parse failures | "Why are only 35 papers imported?" | Show diagnostic: "Parsed 35/50. 15 failed (see details)" with expandable error list |
| No batch size warning | Users try to import 1000 papers, crash app | Modal warning if >100 items: "Large batch may take 1-2 minutes. Continue?" |
| Rate limit errors shown raw | "HTTP 429: What does this mean?" | User-friendly message: "OpenAlex rate limit reached. Pausing for 10 seconds..." with auto-retry |
| No partial results on cancel | User cancels 80% complete citation network, gets nothing | Save partial results before cancellation—show "Saved 234 of ~300 papers. Resume or use partial?" |
| Citation audit takes 30s with no indicator | "App froze again" | Progress bar + estimated time remaining OR run in ExtendedTask with notification |
| Slide YAML errors shown as LLM output | "What is YAML? I just wanted slides" | Catch YAML errors, use template fallback, show user-friendly message: "Generated slides with default theme" |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Bulk DOI import:** Often missing rate limiting—verify API calls batched (50/request) and delayed (0.1s between batches)
- [ ] **Bulk DOI import:** Often missing cost estimation—verify user sees "$0.15 estimated cost for 200 papers. Continue?"
- [ ] **Bulk DOI import:** Often missing partial results—verify first 50 papers saved even if request 51 fails
- [ ] **.bib upload:** Often missing malformed entry handling—verify per-entry try-catch with diagnostic output
- [ ] **.bib upload:** Often missing DOI normalization—verify `normalize_doi()` called on extracted DOIs before OpenAlex lookup
- [ ] **.bib upload:** Often missing metadata merge—verify .bib data preserved when OpenAlex lookup fails (author/title not NULL)
- [ ] **Citation audit:** Often missing SQL optimization—verify single `UNNEST()` + `GROUP BY` query, not R loop
- [ ] **Citation audit:** Often missing progress indicator—verify ExtendedTask used if >500 abstracts expected
- [ ] **Select-all import:** Often missing batch size warning—verify modal shown if >100 papers selected
- [ ] **Select-all import:** Often missing memory test—verify 500-paper import tested without crash
- [ ] **Slide prompt healing:** Often missing retry limit—verify max 2 retries before template fallback
- [ ] **Slide prompt healing:** Often missing specific error feedback—verify YAML parser errors sent to LLM with line numbers
- [ ] **Slide prompt healing:** Often missing cost tracking—verify healing retries logged to cost_log table
- [ ] **All bulk operations:** Often missing ExtendedTask—verify operations >5 seconds use ExtendedTask + progress + cancel

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Rate limit cascade | LOW | 1. Detect 429 error 2. Save partial results 3. Show "Paused—rate limited. Resuming in 10s..." 4. Exponential backoff retry |
| .bib parse failure | MEDIUM | 1. Catch parse error 2. Use regex to extract DOIs from unparsed text 3. Query OpenAlex with DOIs only 4. Show "Imported X papers via DOI recovery" |
| Citation audit timeout | LOW | 1. Cancel long-running query 2. Switch to TOP N approach (`LIMIT 20`) 3. Show "Showing top 20 cited papers (fast mode)" |
| LLM YAML infinite loop | LOW | 1. Detect 2+ retries with same error 2. Fall back to template 3. Log incident 4. Show "Generated with default formatting" |
| Memory crash on select-all | HIGH | 1. Session lost—can't recover 2. On restart, show "Previous import failed. Try smaller batch (<100 papers)" 3. Add batch limit in code |
| OpenAlex budget exhaustion | MEDIUM | 1. Detect 429 with budget message 2. Save progress 3. Show "Daily budget reached. Resume tomorrow or add API credit" 4. Cache results to avoid re-query |
| Partial .bib metadata loss | HIGH | 1. Data already overwritten—can't recover 2. User must re-upload .bib 3. Fix: Implement merge-not-replace before launch |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Rate limit cascade | Phase 34 (Bulk DOI Upload) | Load test: Import 100 DOIs in <20 seconds without 429 errors |
| .bib parse failure | Phase 35 (.bib Upload) | Test with 5 malformed .bib files—verify diagnostic output shows skipped entries |
| SQL N+1 explosion | Phase 33 (Citation Audit) | Benchmark: 1000 abstracts audit completes in <5 seconds using single SQL query |
| YAML healing loops | Phase 37 (Slide Healing) | Test: Force YAML error—verify max 2 retries + fallback, total time <30s |
| Memory explosion | Phase 36 (Select-All Import) | Test: Import 500 papers—verify no crash, progress indicator shown |
| Metadata loss on enrichment | Phase 35 (.bib Upload) | Test: Upload .bib with 3 unindexed papers—verify author/title preserved after OpenAlex lookup fails |
| No progress on bulk ops | All bulk operation phases (33-36) | UX review: All operations >5s must have progress indicator or ExtendedTask |

## Sources

**OpenAlex API Documentation & Best Practices:**
- [Rate limits and authentication | OpenAlex technical documentation](https://docs.openalex.org/how-to-use-the-api/rate-limits-and-authentication) — Rate limit requirements (100 req/sec, $1/day free tier) and batching guidelines
- [API Guide for LLMs | OpenAlex technical documentation](https://docs.openalex.org/api-guide-for-llms) — Batch query syntax with 50 DOIs per request using OR filters
- [Performance and optimization • openalexR](https://docs.ropensci.org/openalexR/articles/performance-optimization.html) — R-specific optimization patterns for OpenAlex API

**BibTeX Parsing Edge Cases:**
- [bibtex-parsing edge cases · Issue #73 · citation-js/citation-js](https://github.com/citation-js/citation-js/issues/73) — Valid but unusual BibTeX entries (missing keys, arbitrary types)
- [Building an AI Review Article Writer: Bibliography Management and Validation](https://reckoning.dev/posts/ai-review-writer-07-bibliography) — Real-world BibTeX irregularities and handling strategies
- [Parsing BibTeX in Racket and generating S-Expressions, JSON, XML and BibTeX](https://matt.might.net/articles/parsing-bibtex/) — Nested braces and string literal tokenization rules
- [rOpenSci | A Roundup of R Tools for Handling BibTeX](https://ropensci.org/blog/2020/05/07/rmd-citations/) — Comparison of R BibTeX parsers (bib2df, bibtex, RefManageR, rbibutils)
- [Package 'rbibutils' January 21, 2026](https://cran.r-project.org/web/packages/rbibutils/rbibutils.pdf) — Most recent R BibTeX parser based on tolerant btparse C library

**R Shiny Memory & Performance:**
- [File upload taking a very long time using shiny 1.3.2 · Issue #2471 · rstudio/shiny](https://github.com/rstudio/shiny/issues/2471) — File upload performance issues with large files
- [Uploading large files fails - ShinyProxy](https://support.openanalytics.eu/t/uploading-large-files-fails/731) — Default 5MB limit and `shiny.maxRequestSize` configuration
- [ExtendedTask: Task or computation that proceeds in the background • shiny](https://rstudio.github.io/shiny/reference/ExtendedTask.html) — Non-blocking async operations for long-running tasks
- [Progress indicators | Shiny](https://shiny.posit.co/r/articles/build/progress/) — Progress bars for user feedback during long operations

**LLM Structured Output & Validation:**
- [LLM Infinite Loops In LLM Entity Extraction – The GDELT Project](https://blog.gdeltproject.org/llm-infinite-loops-in-llm-entity-extraction-when-temperature-basic-prompt-engineering-cant-fix-things/) — Temperature=0 creates deterministic loops, failure mode analysis
- [Prompt Learning Loops Define the Next Generation of LLM Reliability](https://www.startuphub.ai/ai-news/ai-video/2026/prompt-learning-loops-define-the-next-generation-of-llm-reliability/) — 2026 trends: continuous validation and adaptive iteration to prevent prompt degradation
- [Implementing Retry Mechanisms for LLM Calls](https://apxml.com/courses/prompt-engineering-llm-application-development/chapter-7-output-parsing-validation-reliability/implementing-retry-mechanisms) — Best practices: validate → retry 1-2 times → escalate, limit retries to prevent infinite loops
- [LLM Structured Outputs: Schema Validation for Real Pipelines | Collin Wilkins](https://collinwilkins.com/articles/structured-output) — Schema-first development with Pydantic/Zod for 100% compliance
- [PydanticAI: Validation and Reliability in LLM Applications](https://bix-tech.com/pydanticai-validation-and-reliability-in-llm-applications-without-the-headaches/) — Advanced error feedback loops with specific validation messages

**DuckDB Performance:**
- [Optimizing DuckDB Memory Limits for Aggregation](https://www.technetexperts.com/duckdb-memory-tuning-large-aggregations/) — Memory requirements for aggregation-heavy workloads (1-2 GB per thread)
- [DuckDB Performance: Querying Large Datasets on a Single Machine](https://motherduck.com/duckdb-book-summary-chapter10/) — Columnar-vectorized execution, 10-100x faster than SQLite for aggregations
- [Tuning Workloads – DuckDB](https://duckdb.org/docs/stable/guides/performance/how_to_tune_workloads) — DuckDB can't yet offload complex intermediate aggregate states to disk—may OOM on very large datasets
- [DuckDB Ecosystem Newsletter – February 2026](https://motherduck.com/blog/duckdb-ecosystem-newsletter-february-2026/) — Recent 2026 performance improvements and extensions

**Existing Serapeum Code:**
- `R/api_openalex.R` (lines 252, 498-568) — `referenced_works` array storage, existing `get_paper()` and `get_citing_papers()` functions
- `R/slides.R` (lines 101-196) — Existing YAML injection functions (`inject_theme_to_qmd`, `inject_citation_css`) that assume correct structure
- `R/citation_network.R` (lines 1-150) — Existing BFS citation network with `interrupt_flag` and `progress_callback` patterns
- `R/db.R` (lines 60-76) — Abstracts table schema with `referenced_works` column (TEXT array)

---
*Pitfalls research for: Citation Audit, Bulk Import, .bib Parsing, Prompt Healing*
*Researched: 2026-02-25*
