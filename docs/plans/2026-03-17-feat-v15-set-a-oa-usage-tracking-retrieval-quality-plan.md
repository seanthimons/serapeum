---
title: "v15 Set A: OA Usage Tracking + Retrieval Quality"
type: feat
date: 2026-03-17
issues: ["#157", "#12", "#48", "#142", "#159"]
---

# v15 Set A: OA Usage Tracking + Retrieval Quality

## Overview

Two parallel workstreams forming the foundation of v15 AI Infrastructure:

1. **OpenAlex Usage Tracking (#157)** — Migrate from legacy `mailto` polite pool to the new OA API key model, parse usage headers, log to DB, display in Cost Tracker, and add sidebar budget warnings.
2. **Retrieval Quality (#12/#48)** — Implement RAG-Fusion query reformulation, split VSS/BM25 with RRF fusion, and contextual chunk headers to sharpen retrieval quality without adding new API keys.

Both workstreams are independent and can be developed in parallel.

## Problem Statement

### OpenAlex Usage Tracking

OpenAlex migrated to a freemium API key model (Feb 2026). Free keys get $1/day credit. Serapeum still uses the legacy `mailto` parameter and has no visibility into OA usage or costs. Users risk silently hitting rate limits with no feedback.

### Retrieval Quality

Current retrieval pipeline (`query -> ragnar hybrid -> filter -> top-k -> LLM`) isn't sharp enough for high-quality synthesis, especially in small-notebook scenarios (3 PDFs, no citation network). Single-query retrieval misses chunks due to vocabulary mismatch. Abstract chunks are labeled `[Abstract]` instead of paper titles (#159), degrading citation quality.

## Technical Approach

### Architecture

#### Workstream 1: OA Usage Tracking

```
OA Request Flow (current):
  build_openalex_request() → req_perform() → resp_body_json() → discard resp

OA Request Flow (new):
  build_openalex_request() → perform_oa_request() → {
    resp = req_perform()
    parse_oa_usage_headers(resp) → log to oa_usage_log table
    update reactive usage state
    return resp_body_json(resp)
  }
```

**Central wrapper approach:** Introduce `perform_oa_request(req, con)` that wraps all ~10 `req_perform()` call sites. Single point of change for header extraction, usage logging, and error tracking.

#### Workstream 2: Retrieval Quality

```
Current pipeline:
  query → ragnar_retrieve(hybrid) → filter → top-k → LLM

New pipeline:
  query
    → chat_completion(fast model): generate 3-5 query variants
    → For each variant:
        → ragnar_retrieve_vss(top_k=20)   → ranked list
        → ragnar_retrieve_bm25(top_k=20)  → ranked list
    → RRF merge all lists: score = Σ 1/(k + rank_i), k=60
    → Deduplicate by chunk hash
    → filter by notebook/section
    → Take top-k
    → LLM
```

### Implementation Phases

---

#### Phase 1: OA API Key Migration + Usage Infrastructure

**Goal:** Add API key support to settings, create the centralized request wrapper, and build the usage logging table.

**Tasks and deliverables:**

- [x] Add `openalex_api_key` text input to Settings UI (`R/mod_settings.R:37`)
- [x] Add `openalex_api_key` to effective config (`R/mod_settings.R:669-671`)
- [x] Add env var support for `OPENALEX_API_KEY` (`R/config.R`)
- [x] Create migration `migrations/011_create_oa_usage_log.sql`:
  ```sql
  CREATE TABLE IF NOT EXISTS oa_usage_log (
    id VARCHAR PRIMARY KEY DEFAULT (gen_random_uuid()::VARCHAR),
    operation VARCHAR NOT NULL,
    endpoint VARCHAR,
    daily_limit DOUBLE,
    remaining DOUBLE,
    credits_used DOUBLE,
    cost_usd DOUBLE,
    reset_seconds INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
  ```
- [x] Create `perform_oa_request(req, con)` wrapper in `R/api_openalex.R` that:
  - Calls `req_perform(req)`
  - Extracts `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Credits-Used`, `X-RateLimit-Reset` headers
  - Extracts `cost_usd` from response meta if present
  - Logs to `oa_usage_log` table
  - Returns `resp_body_json(resp)` (preserving current API contract)
  - Gracefully handles missing headers (polite-pool users)
- [x] Replace all `req_perform()` calls in `api_openalex.R` with `perform_oa_request()`
  - `search_papers()` (line 401)
  - `get_paper()` (line 545)
  - `get_citing_papers()` (line 608)
  - `get_cited_papers()` (line 647)
  - `get_related_papers()` (line 686)
  - `fetch_topics_page()` (line 717)
  - `fetch_all_topics()` (line 810)
  - `fetch_single_batch()` (line 923)
- [x] Add migration nudge: inline banner in Settings when `openalex_email` is set but `openalex_api_key` is empty
  - Dismissible — store `oa_migration_nudge_dismissed` in DB settings
  - Link to `openalex.org/settings/api`
- [x] Add API key validation via test request to `/works?per_page=1` with the key

**Success criteria:**
- All OA requests go through centralized wrapper
- Usage data logged to `oa_usage_log` for every API-keyed request
- Polite-pool requests work without errors (headers gracefully absent)
- Migration nudge shown only when email exists without key

---

#### Phase 2: OA Cost Tracker UI + Sidebar Badge

**Goal:** Display OA usage in the Cost Tracker tab and add a sidebar budget badge.

**Tasks and deliverables:**

- [x] Add `get_oa_daily_usage(con)` function to query today's usage from `oa_usage_log`
- [x] Add `get_oa_usage_history(con, days=30)` function for historical view
- [x] Add OA section to Cost Tracker tab (`R/mod_cost_tracker.R:292`):
  - Daily budget value box (remaining / limit)
  - Today's request count and credit usage
  - Daily usage bar chart (last 30 days, one bar per day showing credit consumption)
  - Recent OA requests table (operation, credits used, timestamp)
- [x] Add `openalex_search`, `openalex_fetch`, `openalex_topics` to `COST_OPERATION_META` (`R/cost_tracking.R:29`)
- [x] Add sidebar OA budget badge (`app.R:234-256`):
  - Show percentage of daily budget consumed: `floor((1 - remaining/limit) * 100)`
  - Color: green (0-60%), yellow (60-85%), red (85-100%)
  - Only visible when `openalex_api_key` is configured (hide for polite-pool users)
  - Updates on each OA response (reactive, not polled)
- [x] Implement one-time toast at >= 90% daily usage:
  - Track via `oa_toast_last_fired_date` DB setting
  - Fire once per calendar day (UTC)
  - Reset tracking when `X-RateLimit-Reset` indicates a new day
  - Toast message: "OpenAlex daily budget is {pct}% consumed. Resets at midnight UTC."
- [x] Handle stale badge data:
  - Show "as of HH:MM" timestamp under the badge
  - On app load, if last logged usage is from a previous UTC day, show badge as 0% (fresh day)

**Success criteria:**
- Cost Tracker shows OA section with daily budget, history chart, and request log
- Sidebar badge reflects current daily budget consumption
- Badge hidden for polite-pool users
- Toast fires once per day at >= 90%

---

#### Phase 3: Split VSS/BM25 Retrieval with RRF Fusion

**Goal:** Replace the single `ragnar_retrieve()` call with split VSS+BM25 retrieval and RRF merging. This phase does NOT add query reformulation yet — it validates the RRF merge approach with a single query first.

**Tasks and deliverables:**

- [x] Verify `ragnar::ragnar_retrieve_vss()` and `ragnar::ragnar_retrieve_bm25()` exist:
  ```r
  # Run at implementation start
  intersect(c("ragnar_retrieve_vss", "ragnar_retrieve_bm25"), ls("package:ragnar"))
  ```
  If `ragnar_retrieve_vss` doesn't exist, fall back to using `ragnar_retrieve()` with `cosine_distance` column for VSS ranking.
- [x] Create `rrf_merge(ranked_lists, k = 60)` function in `R/rag.R`:
  - Input: list of data frames, each with `text`, `origin`, `hash`, and a score/rank column
  - Assign rank within each list (1-indexed)
  - Compute RRF score per chunk: `score = sum(1 / (k + rank_i))` across all lists where the chunk appears
  - Deduplicate by `hash` (exact match on chunk hash, not fuzzy text matching)
  - Return sorted by RRF score descending
- [x] Create `retrieve_split_rrf(store, query, top_k = 20, k = 60)` in `R/_ragnar.R`:
  - Call `ragnar_retrieve_vss(store, query, top_k)`
  - Call `ragnar_retrieve_bm25(store, query, top_k)`
  - Pass both lists to `rrf_merge()`
  - Return merged results
- [x] Replace `retrieve_with_ragnar()` call in `search_chunks_hybrid()` (`R/db.R:830`) with `retrieve_split_rrf()`
- [x] Preserve existing notebook/section filtering (applied after RRF merge)
- [x] Fix abstract title bug at `_ragnar.R:1051` — replace `[Abstract]` with actual paper title from DB lookup

**Success criteria:**
- Single-query retrieval uses split VSS+BM25 with RRF merge
- Results are at least as relevant as current hybrid retrieval (manual testing with known queries)
- Abstract chunks display paper titles instead of `[Abstract]` (#159 resolved)
- No regression in retrieval speed (< 2x current latency acceptable for this phase)

---

#### Phase 4: Query Reformulation (RAG-Fusion)

**Goal:** Add LLM-powered query variant generation before retrieval to improve recall, especially for vocabulary-mismatched queries.

**Tasks and deliverables:**

- [x] Create `generate_query_variants(query, config, con, n_variants = 3)` in `R/rag.R`:
  - System prompt: "Generate {n_variants} alternative search queries for the following research question. Each variant should use different vocabulary, synonyms, or approach the topic from a different angle. Return only the queries, one per line."
  - Use a fast/cheap model — look up user's chat model, but prefer a flash/mini variant if available. Fall back to user's selected model.
  - Parse response into character vector of query variants
  - Always include the original query as the first variant
  - Log cost as operation `query_reformulation` via `log_cost()`
- [x] Add `query_reformulation` to `COST_OPERATION_META` with icon and accent class
- [x] Update `retrieve_split_rrf()` to accept multiple queries:
  - For each query variant, run VSS + BM25 retrieval
  - Collect all ranked lists (2 per variant = 6-10 total lists)
  - RRF merge all lists together
  - Deduplicate and return top-k
- [x] Wire into `search_chunks_hybrid()`:
  - Call `generate_query_variants()` before retrieval
  - Pass all variants to `retrieve_split_rrf()`
- [x] Add "Reformulating query..." progress indicator in chat UI
- [x] Add user toggle in Settings: "Query Reformulation" (enabled by default)
  - Store as `rag_query_reformulation` DB setting
  - When disabled, skip the LLM call and use single-query retrieval (still with split VSS/BM25 + RRF)

**Success criteria:**
- Chat queries generate 3-5 variants before retrieval
- Vocabulary-mismatched queries show improved recall (test with "emerging contaminants" example from #159)
- Reformulation cost logged and visible in Cost Tracker
- Users can disable reformulation in Settings
- Total retrieval latency < 5 seconds for typical queries

---

#### Phase 5: Contextual Chunk Headers + Re-indexing

**Goal:** Prepend paper title (and section hint when available) to chunk text at index time, improving both retrieval embeddings and LLM citation context. Trigger re-indexing for existing notebooks.

**Tasks and deliverables:**

- [x] Modify `chunk_with_ragnar()` (`R/_ragnar.R:240`) to prepend contextual header:
  ```r
  # Format: "[Paper Title]\n" or "[Paper Title | Section: Methods]\n"
  header <- paste0("[", paper_title, "]\n")
  if (!is.null(section_hint) && nchar(section_hint) > 0) {
    header <- paste0("[", paper_title, " | Section: ", section_hint, "]\n")
  }
  chunk$content <- paste0(header, chunk$content)
  ```
- [x] Modify abstract chunk indexing (`R/_ragnar.R:828-830`) to prepend paper title:
  ```r
  # Instead of "[Abstract]", use actual title
  abstract_text <- paste0("[", paper_title, "]\n", abstract_content)
  ```
- [x] Add `index_schema_version` DB setting (initial value: 2; current implicit version: 1)
- [x] Extend stale index detection in existing missing-index check path:
  - On notebook open / store connect, compare stored `index_schema_version` with current version
  - If stale, surface the same "please re-index" prompt used for missing indexes
  - Track per-notebook: store `index_version` in notebook metadata
- [x] Handle edge cases during re-indexing:
  - Paper metadata deleted but chunks remain → skip contextual header, use filename as fallback
  - Abstract imported without title → use DOI or "Untitled" as fallback
  - Partially re-indexed notebooks → track re-index completion status
- [x] Update `retrieve_with_ragnar()` to strip contextual headers from chunk text before sending to LLM (or keep them — test which produces better LLM output)
- [x] Add re-index progress indicator (re-index can be slow for large notebooks)

**Success criteria:**
- New documents indexed with contextual headers automatically
- Existing notebooks prompted to re-index (non-blocking, can defer)
- Re-indexed chunks have paper titles prepended
- Retrieval quality improves for multi-paper notebooks (disambiguated chunks)
- No data loss during re-indexing (old chunks removed only after new chunks inserted)

---

## Alternative Approaches Considered

| Approach | Why Rejected |
|----------|-------------|
| **Cross-encoder reranker** (Cohere/Jina/Voyage) | Adds a third API key, conflicts with local-first philosophy. RRF + reformulation gets ~70-80% of reranker quality. Deferred as optional power-user feature. |
| **FILCO-style span filtering** | On the fence. Revisit after RRF + reformulation are in and quality can be measured. |
| **Single `cost_log` table for OA data** | OA usage is credit-based with daily resets — fundamentally different from LLM token tracking. Mixing the two would complicate queries and potentially mislead users. |
| **Modal/toast migration nudge on app load** | Annoying for users who intentionally use the polite pool. Inline Settings banner with dismiss is less intrusive. |
| **Polling-based sidebar badge** | Wasteful when badge can update reactively on each OA response. Only the "stale data after midnight" edge case needs time-based logic. |
| **Confirmation modals for expensive OA operations** | Warning only for now — gating adds friction with little benefit at $1/day free tier. |

## Test Plan

Tests follow existing project conventions: explicit `source()` from `project_root`, in-memory DuckDB via `get_db_connection(":memory:")`, mock objects for API responses, no live API calls.

### `tests/testthat/test-oa-usage-tracking.R`

**Phase 1 — Header Parsing & Usage Logging:**

```r
test_that("parse_oa_usage_headers extracts all rate-limit fields from response", {
  # Mock httr2 response with OA rate-limit headers
  # Verify: daily_limit, remaining, credits_used, reset_seconds all extracted
  # Verify: returns named list with correct types (numeric)
})

test_that("parse_oa_usage_headers returns NAs for missing headers (polite pool)", {
  # Mock response with NO rate-limit headers (email-only user)
  # Verify: returns list with all NA values, no errors
})

test_that("parse_oa_usage_headers extracts cost_usd from response meta", {
  # Mock response body containing meta.cost_usd field
  # Verify: cost_usd extracted alongside header values
})

test_that("log_oa_usage writes to oa_usage_log table", {
  # In-memory DuckDB, init_schema()
  # Call log_oa_usage() with known values
  # Query oa_usage_log, verify row inserted with correct columns
  # Verify: id generated, created_at populated, all fields match
})

test_that("log_oa_usage handles NA values gracefully (polite pool)", {
  # In-memory DuckDB, init_schema()
  # Call log_oa_usage() with all NA usage values
  # Verify: row inserted without error, NULL columns stored
})

test_that("perform_oa_request preserves existing return contract", {
  # Mock req_perform to return a fake response
  # Verify: perform_oa_request() returns same structure as resp_body_json()
  # Verify: callers don't need to change their response handling
})
```

**Phase 2 — Usage Queries & Badge Logic:**

```r
test_that("get_oa_daily_usage returns today's aggregated usage", {
  # In-memory DuckDB with multiple oa_usage_log rows for today
  # Verify: returns total credits_used, latest remaining, latest daily_limit
  # Verify: excludes yesterday's rows
})

test_that("get_oa_daily_usage returns zeros when no data exists", {
  # In-memory DuckDB with empty oa_usage_log
  # Verify: returns zero/NA structure, no errors
})

test_that("get_oa_usage_history returns daily aggregates for N days", {
  # In-memory DuckDB with rows spanning 5 days
  # Verify: returns one row per day, sorted by date
  # Verify: total_credits_used summed per day
})

test_that("oa_budget_percentage calculates correctly", {
  # remaining=0.3, limit=1.0 → 70%
  # remaining=0.0, limit=1.0 → 100%
  # remaining=NA, limit=NA → NA (polite pool)
})

test_that("oa_budget_color returns correct color tier", {
  # 50% → green, 70% → yellow, 90% → red
  # NA → hidden/NULL
})

test_that("oa_toast_should_fire checks per-day dedup", {
  # In-memory DuckDB, set oa_toast_last_fired_date to today → FALSE
  # Set to yesterday → TRUE (if budget >= 90%)
  # No setting exists → TRUE (if budget >= 90%)
  # Budget at 85% → FALSE regardless of date
})
```

### `tests/testthat/test-rrf-merge.R`

**Phase 3 — RRF Merge Algorithm:**

```r
test_that("rrf_merge produces correct scores for two ranked lists", {
  # List A: chunks [c1, c2, c3] ranked 1, 2, 3
  # List B: chunks [c2, c3, c1] ranked 1, 2, 3
  # k=60: c1 score = 1/61 + 1/63, c2 score = 1/62 + 1/61, c3 score = 1/63 + 1/62
  # Verify: c2 ranked first (appears high in both lists)
})

test_that("rrf_merge handles chunks appearing in only one list", {
  # List A: [c1, c2], List B: [c3, c4]
  # Verify: all 4 chunks present in output
  # Verify: scores are 1/(k+rank) for single-list chunks
})

test_that("rrf_merge deduplicates by chunk hash", {
  # Same chunk appearing with same hash in multiple lists
  # Verify: output has unique hashes only
  # Verify: scores are accumulated across lists
})

test_that("rrf_merge returns results sorted by score descending", {
  # Multiple lists with known rankings
  # Verify: output is sorted by rrf_score descending
})

test_that("rrf_merge handles empty lists gracefully", {
  # One empty list + one populated list
  # Verify: returns results from populated list only
  # All empty lists → returns empty data frame with correct columns
})

test_that("rrf_merge with k=60 matches expected ranking for known data", {
  # Reproduce example from RRF paper with known inputs/outputs
  # Verify: ranking matches expected order
})
```

**Phase 3 — Split Retrieval:**

```r
test_that("retrieve_split_rrf calls both vss and bm25 and merges", {
  # Mock ragnar_retrieve_vss and ragnar_retrieve_bm25
  # Verify: both called with same query and top_k
  # Verify: rrf_merge called with both result lists
  # Verify: output structure matches retrieve_with_ragnar contract
})

test_that("retrieve_split_rrf falls back when ragnar_retrieve_vss unavailable", {
  # Mock ragnar namespace without ragnar_retrieve_vss
  # Verify: falls back to ragnar_retrieve() with score column extraction
  # Verify: no error thrown
})
```

### `tests/testthat/test-query-reformulation.R`

**Phase 4 — Query Variant Generation:**

```r
test_that("parse_query_variants extracts one query per line", {
  # Input: "variant 1\nvariant 2\nvariant 3"
  # Verify: returns c("variant 1", "variant 2", "variant 3")
})

test_that("parse_query_variants handles numbered list format", {
  # Input: "1. variant 1\n2. variant 2\n3. variant 3"
  # Verify: strips numbering, returns clean queries
})

test_that("parse_query_variants strips empty lines and whitespace", {
  # Input with blank lines, leading/trailing whitespace
  # Verify: cleaned output with no empty strings
})

test_that("generate_query_variants always includes original query", {
  # Mock chat_completion to return 3 variants
  # Verify: result[1] == original query
  # Verify: length(result) == 4 (original + 3 variants)
})

test_that("generate_query_variants respects n_variants parameter", {
  # Mock chat_completion
  # n_variants=5 → system prompt asks for 5 variants
  # Verify: prompt contains "5"
})

test_that("generate_query_variants logs cost as query_reformulation", {
  # In-memory DuckDB
  # Mock chat_completion with usage data
  # Verify: log_cost called with operation = "query_reformulation"
})

test_that("query reformulation skipped when setting disabled", {
  # Config with rag_query_reformulation = FALSE
  # Verify: no LLM call made, returns only original query
})
```

### `tests/testthat/test-contextual-headers.R`

**Phase 5 — Chunk Headers:**

```r
test_that("prepend_contextual_header adds title to chunk content", {
  # Input: content = "Some chunk text", title = "My Paper"
  # Verify: output = "[My Paper]\nSome chunk text"
})

test_that("prepend_contextual_header adds title + section when available", {
  # Input: content = "Methods text", title = "My Paper", section = "Methods"
  # Verify: output = "[My Paper | Section: Methods]\nMethods text"
})

test_that("prepend_contextual_header handles NULL/empty section", {
  # section = NULL → title only
  # section = "" → title only
  # section = NA → title only
})

test_that("prepend_contextual_header uses filename fallback for missing title", {
  # title = NULL, filename = "paper.pdf"
  # Verify: output = "[paper.pdf]\nSome chunk text"
})

test_that("abstract chunks use paper title instead of [Abstract]", {
  # Mock paper with title "Water Quality Assessment"
  # Verify: abstract chunk content starts with "[Water Quality Assessment]\n"
  # Verify: NOT "[Abstract]"
})

test_that("abstract chunks use DOI fallback when title missing", {
  # Paper with no title but doi = "10.1234/test"
  # Verify: abstract chunk starts with "[10.1234/test]\n"
})

test_that("stale_index_detected compares schema versions", {
  # In-memory DuckDB, set index_schema_version = 1
  # Current version = 2
  # Verify: stale_index_detected() returns TRUE
  # Set index_schema_version = 2 → returns FALSE
})
```

### `tests/testthat/test-oa-migration.R`

**Phase 1 — Migration & Settings:**

```r
test_that("migration 011 creates oa_usage_log table", {
  # In-memory DuckDB, run migrations up to 011
  # Verify: oa_usage_log table exists with correct columns
  # Verify: id, operation, endpoint, daily_limit, remaining,
  #         credits_used, cost_usd, reset_seconds, created_at
})

test_that("effective config includes openalex api_key when set", {
  # In-memory DuckDB, save_db_setting("openalex_api_key", "test-key")
  # Build effective config
  # Verify: config$openalex$api_key == "test-key"
})

test_that("effective config loads openalex api_key from env var", {
  # withr::with_envvar(c(OPENALEX_API_KEY = "env-key"), { ... })
  # Verify: config$openalex$api_key == "env-key"
})

test_that("migration nudge shown when email set but no api_key", {
  # email = "user@example.com", api_key = NULL
  # Verify: should_show_oa_migration_nudge() == TRUE
})

test_that("migration nudge hidden when api_key present", {
  # email = "user@example.com", api_key = "oakey_12345"
  # Verify: should_show_oa_migration_nudge() == FALSE
})

test_that("migration nudge hidden when dismissed", {
  # In-memory DuckDB, save_db_setting("oa_migration_nudge_dismissed", TRUE)
  # Verify: should_show_oa_migration_nudge() == FALSE
})
```

### Test File Summary

| Test File | Phase | Tests | What's Covered |
|-----------|-------|-------|----------------|
| `test-oa-usage-tracking.R` | 1, 2 | ~12 | Header parsing, usage logging, daily queries, badge logic, toast dedup |
| `test-oa-migration.R` | 1 | ~6 | Migration 011, settings, env vars, nudge logic |
| `test-rrf-merge.R` | 3 | ~8 | RRF algorithm, dedup, empty lists, split retrieval fallback |
| `test-query-reformulation.R` | 4 | ~7 | Variant parsing, original query inclusion, cost logging, toggle |
| `test-contextual-headers.R` | 5 | ~7 | Header prepending, fallbacks, abstract fix, stale detection |
| **Total** | | **~40** | |

Each test file should be written alongside its corresponding phase implementation. Tests run without API keys or network access.

## Acceptance Criteria

### Functional Requirements

- [x] OA API key can be configured in Settings, persisted to DB, loaded from env var
- [x] Migration nudge appears for email-only users, dismissible
- [x] Every OA request logs usage headers to `oa_usage_log`
- [x] Cost Tracker shows OA section with daily budget, history chart, request log
- [x] Sidebar badge shows OA daily budget percentage (green/yellow/red)
- [x] Toast fires once per day at >= 90% budget consumption
- [x] Badge/toast hidden for polite-pool users (no API key)
- [x] Chat retrieval uses split VSS/BM25 with RRF fusion
- [x] Query reformulation generates 3-5 variants before retrieval
- [x] Reformulation can be toggled off in Settings
- [x] Reformulation LLM cost logged and visible in Cost Tracker
- [x] New documents indexed with contextual headers (paper title + section)
- [x] Existing notebooks prompted to re-index for contextual headers
- [x] Abstract chunks show paper titles instead of `[Abstract]` (#159)

### Non-Functional Requirements

- [x] OA usage logging adds < 50ms per request (header parsing + DB write)
- [x] Split VSS/BM25 + RRF retrieval latency < 2x current for single query
- [x] Full pipeline (reformulation + split retrieval + RRF) < 5 seconds typical
- [x] Polite-pool users experience no degradation or errors
- [x] Re-indexing handles edge cases (missing metadata, partial completion)

### Quality Gates

- [x] Unit tests for `perform_oa_request()` header parsing (mock responses)
- [x] Unit tests for `rrf_merge()` with known ranked lists
- [x] Unit tests for `generate_query_variants()` output parsing
- [x] Unit tests for contextual header prepending
- [x] Integration test: OA request → log → query → verify data integrity
- [x] Manual test: chat quality comparison with/without reformulation
- [x] Smoke test: app starts without errors after each phase

## Success Metrics

- **OA Usage Tracking:** Users can see their daily OA budget consumption at a glance. No surprise rate-limit errors.
- **Retrieval Quality:** Measurable improvement in chat answer relevance for small-notebook queries. The "emerging contaminants" query (#159) returns relevant chunks from the correct papers.
- **Cost Transparency:** Both OA and OpenRouter costs are fully tracked and visible in a unified Cost Tracker tab.

## Dependencies & Prerequisites

| Dependency | Status | Impact |
|-----------|--------|--------|
| ragnar `ragnar_retrieve_vss()` function | **Verify at Phase 3 start** | If missing, use `ragnar_retrieve()` with score column extraction |
| OpenAlex API key model | Available (Feb 2026) | Required for usage headers |
| DuckDB migration system | Exists (at v010) | Add migration 011 |
| Cost tracking infrastructure | Exists (`R/cost_tracking.R`) | Extend with OA operations |
| Missing-index detection path | Exists (`R/_ragnar.R`) | Extend for stale index detection |

## Risk Analysis & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Polite-pool responses lack rate-limit headers | Medium | High | Graceful fallback: hide badge/tracker for keyless users; test with curl before implementation |
| `ragnar_retrieve_vss()` doesn't exist as exported function | Low | High | Check at Phase 3 start; fallback to `ragnar_retrieve()` with score column |
| Query reformulation adds too much latency | Medium | Medium | Use fast model; add progress indicator; make toggleable |
| Re-indexing large notebooks is slow | High | Low | Background re-index with progress indicator; don't block app use |
| RRF constant k=60 produces poor results | Low | Medium | Standard value in literature; tunable parameter for later optimization |
| Concurrent OA requests produce flickering badge | Low | Low | Use `X-RateLimit-Remaining` from most recent response only; don't interpolate |
| Failed OA requests may/may not consume credits | Medium | Low | Log all responses (success and error); note uncertainty in Cost Tracker |

## Future Considerations

- **Cross-encoder reranker** — Optional power-user feature. Cohere Rerank 4 Pro is top pick (ELO 1629, $0.05/1M). Would add after Phase 4 as Phase 6 if quality delta warrants a third API key.
- **FILCO-style span filtering** — Revisit after measuring RRF + reformulation quality.
- **Citation proximity / audit signals** — #142 Phases 2-5, only relevant when citation networks exist.
- **OA budget gating** — Confirmation modals for expensive operations (PDF downloads at $10/1K). Only if user feedback indicates warnings are insufficient.
- **Adaptive reformulation** — Skip reformulation for simple/direct queries; only apply for complex research questions.

## Documentation Plan

- [x] Update README.md with OA API key setup instructions
- [x] Update TODO.md to mark #157, #12, #48 as in-progress/resolved
- [x] Update #142 issue to reflect revised phase ordering (query reformulation + RRF as new Phase 1)

## References & Research

### Internal References

- Brainstorm: `docs/brainstorms/2026-03-15-v15-set-a-brainstorm.md`
- OA request builder: `R/api_openalex.R:98` (`build_openalex_request()`)
- Cost tracking: `R/cost_tracking.R:29` (`COST_OPERATION_META`)
- Cost tracker UI: `R/mod_cost_tracker.R:292` (`mod_cost_tracker_ui`)
- Sidebar footer: `app.R:234-256`
- Ragnar retrieval: `R/_ragnar.R:1021` (`retrieve_with_ragnar()`)
- Chunk indexing: `R/_ragnar.R:240` (`chunk_with_ragnar()`)
- Abstract bug: `R/_ragnar.R:1051` (`[Abstract]` placeholder)
- Search pipeline: `R/db.R:830` (`search_chunks_hybrid()`)
- RAG pipeline: `R/rag.R:81`
- Settings: `R/mod_settings.R:37` (settings UI), `R/mod_settings.R:669` (effective config)

### Related Issues

- #157 — OpenAlex Usage Tracking
- #12 — Retrieval quality (reranker — resolved via RRF + reformulation)
- #48 — Retrieval quality (document selection — resolved via reformulation)
- #142 — Citation-aware retrieval (Phase 1 updated)
- #159 — Chat doesn't reference papers correctly (abstract `[Abstract]` bug)

### OA API Reference

- Rate limit headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Credits-Used`, `X-RateLimit-Reset`
- Account status endpoint: `/rate-limit`
- Usage dashboard: `openalex.org/settings/usage`
- API key signup: `openalex.org/settings/api`
