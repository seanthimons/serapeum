# Phase 50: API Pagination Foundation - Research

**Researched:** 2026-03-07
**Domain:** OpenAlex API cursor-based pagination + httr2 retry infrastructure
**Confidence:** HIGH

## Summary

OpenAlex API cursor-based pagination replaces offset-based paging to access beyond 10,000 results. The implementation modifies `search_papers()` to accept a `cursor` parameter, return structured pagination state (`list(papers, next_cursor, count)`), and add retry logic globally via `build_openalex_request()`.

**Primary recommendation:** Use httr2's `req_retry()` in the shared request builder for automatic retry across all OpenAlex functions. Treat cursors as opaque strings—never parse, decode, or validate their contents. Default to `relevance_score` sorting for academic search workflows while keeping the parameter flexible for future use cases.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
1. **Function Strategy:** Modify existing `search_papers()` directly—do not create a separate function. Add `cursor` parameter (default `NULL`) and `sort` parameter (default `"relevance_score"`). Change return format from `list(parsed_works...)` to `list(papers, next_cursor, count)`. Update all existing callers in this phase.

2. **Sort Order for Pagination:** Default to relevance score, but accept a `sort` parameter. Add `sort` parameter to `search_papers()` with default `"relevance_score"`. No UI for sort selection—just the function signature ready for future use.

3. **Error Handling & Resilience:** Retry with backoff, then throw. Applied globally to all OpenAlex calls. Add `httr2::req_retry()` to `build_openalex_request()` so all API functions benefit. Config: `max_tries = 3`, respect `Retry-After` header from 429s, exponential backoff for 5xx. On permanent failure: propagate via existing `stop_api_error()` pattern.

4. **Empty Results:** Return `list(papers = list(), next_cursor = NULL, count = 0)` when results are empty.

5. **Malformed Response:** Throw a descriptive error if API response is missing `meta` or `results` fields. Explicit validation: check for `body$meta` and `body$results` presence. Error message: descriptive (e.g., "Unexpected OpenAlex response format") for debugging. Do not silently return safe defaults.

### Claude's Discretion
None specified—all technical decisions are locked.

### Deferred Ideas (OUT OF SCOPE)
None identified during discussion.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PAGE-06 | OpenAlex cursor-based pagination in API client (replaces offset-based) | OpenAlex cursor pagination docs, httr2 retry patterns, R error handling conventions |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| httr2 | Current (already in use) | HTTP client with retry support | Already used project-wide; `req_retry()` provides native exponential backoff + header-aware retries |
| jsonlite | Current (already in use) | JSON parsing for API responses | Standard R JSON library, used throughout api_openalex.R |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| testthat | Current (already in use) | Unit testing | Test pagination logic, cursor handling, error cases |

### Alternatives Considered
None—all required libraries are already in use.

**Installation:**
No new dependencies required. All libraries already present in project.

## Architecture Patterns

### Recommended Function Signature
```r
search_papers <- function(query, email, api_key = NULL,
                          from_year = NULL, to_year = NULL, per_page = 25,
                          search_field = "default", is_oa = FALSE,
                          min_citations = NULL, exclude_retracted = TRUE,
                          work_types = NULL,
                          cursor = NULL,
                          sort = "relevance_score") {
  # ...
}
```

### Pattern 1: Cursor Pagination State
**What:** Return structured pagination metadata alongside results
**When to use:** Any API function that supports pagination
**Example:**
```r
# Source: User decision (CONTEXT.md), OpenAlex API pattern
result <- search_papers("machine learning", email, cursor = NULL)
# Returns: list(papers = <list>, next_cursor = <string or NULL>, count = <integer>)

# Caller accesses:
papers <- result$papers
next_cursor <- result$next_cursor  # Use for next page
total_count <- result$count
```

### Pattern 2: Opaque Cursor Treatment
**What:** Never parse, decode, or validate cursor strings—treat as opaque tokens
**When to use:** Always when handling cursors from external APIs
**Example:**
```r
# Source: OpenAlex pagination docs (developers.openalex.org)
# CORRECT: Pass cursor directly to API
req <- req |> req_url_query(cursor = cursor)

# WRONG: Don't do this
# decoded <- base64_decode(cursor)  # NO
# if (nchar(cursor) > 100) stop()   # NO
```

### Pattern 3: Global Retry via Shared Request Builder
**What:** Add retry logic to `build_openalex_request()` so all API functions inherit it
**When to use:** When multiple functions share a common HTTP client builder
**Example:**
```r
# Source: httr2 best practices (httr2.r-lib.org)
build_openalex_request <- function(endpoint, email = NULL, api_key = NULL) {
  req <- request(paste0(OPENALEX_BASE_URL, "/", endpoint))

  # Email and API key setup
  if (!is.null(email)) {
    req <- req |> req_url_query(mailto = email)
  }
  if (!is.null(api_key) && nchar(api_key) > 0 && !grepl("^your-", api_key)) {
    req <- req |> req_url_query(api_key = api_key)
  }

  # Global retry policy
  req <- req |>
    req_timeout(30) |>
    req_retry(
      max_tries = 3,
      is_transient = \(resp) httr2::resp_status(resp) %in% c(429, 503),
      backoff = \(i) 2^(i - 1)  # 1s, 2s, 4s
    )

  req
}
```

### Pattern 4: Response Validation Before Parsing
**What:** Explicitly check for required fields in API response before accessing them
**When to use:** When parsing external API responses that may change structure
**Example:**
```r
# Source: Defensive programming pattern + user decision
body <- resp_body_json(resp)

# Validate response structure
if (is.null(body$meta) || is.null(body$results)) {
  stop("Unexpected OpenAlex response format: missing 'meta' or 'results' field")
}

# Now safe to access
next_cursor <- body$meta$next_cursor
count <- body$meta$count
papers <- lapply(body$results, parse_openalex_work)
```

### Anti-Patterns to Avoid
- **Cursor validation:** Don't check cursor format, length, or decode contents—cursors are opaque
- **Silent failure on malformed responses:** Don't return empty lists when structure is wrong—throw descriptive errors
- **Per-function retry:** Don't add `req_retry()` to individual API functions—put it in the shared builder
- **Offset pagination for large result sets:** Don't use page numbers for >10,000 results—OpenAlex limits offset paging

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP retry logic | Custom retry loops with sleep | `httr2::req_retry()` | Handles exponential backoff, `Retry-After` headers, jitter, and transient error detection automatically |
| Cursor state management | Custom cursor storage/validation | Opaque string pass-through | OpenAlex cursors are stateless; no client-side management needed |
| Response parsing with validation | Manual field access | Explicit `is.null()` checks before access | Prevents silent failures when API changes response structure |

**Key insight:** httr2 provides production-grade retry infrastructure that handles edge cases (429 rate limits, 5xx server errors, backoff jitter) better than custom implementations. Cursors are intentionally opaque—parsing or validating them couples code to OpenAlex's internal implementation.

## Common Pitfalls

### Pitfall 1: Assuming cursor=NULL means first page without sort
**What goes wrong:** Cursor pagination works without explicit sort, but results may be unstable across pagination if no sort is specified
**Why it happens:** OpenAlex docs don't explicitly require sort, but database ordering without explicit sort can change between requests
**How to avoid:** Always provide a default sort parameter (e.g., `"relevance_score"`) to ensure stable pagination
**Warning signs:** Different results when paginating through the same query multiple times

### Pitfall 2: Parsing or decoding cursor strings
**What goes wrong:** Code breaks when OpenAlex changes cursor encoding format
**Why it happens:** Developers assume cursors are base64-encoded positions and try to inspect/validate them
**How to avoid:** Treat cursors as completely opaque—never call `base64_decode()`, check length, validate format, or parse contents
**Warning signs:** Code that references cursor internals, validation logic for cursor format

### Pitfall 3: Returning empty list() on malformed responses
**What goes wrong:** API changes or bugs are masked, making debugging difficult
**Why it happens:** Developer assumes empty results are safer than errors
**How to avoid:** Validate response structure explicitly and throw descriptive errors when `meta` or `results` are missing
**Warning signs:** Silent failures, mysterious "no results" when API actually errored

### Pitfall 4: Adding retry to individual functions
**What goes wrong:** Inconsistent retry behavior across API functions, code duplication
**Why it happens:** Developer adds `req_retry()` to `search_papers()` without realizing other functions need it too
**How to avoid:** Put `req_retry()` in `build_openalex_request()` so all functions (`get_citing_papers()`, `get_cited_papers()`, `get_related_papers()`, etc.) inherit retry automatically
**Warning signs:** Some API functions retry on 429, others don't

### Pitfall 5: Not handling next_cursor=null correctly
**What goes wrong:** Pagination loop tries to fetch with cursor=null and gets duplicate results
**Why it happens:** Developer doesn't check if `next_cursor` is null before making next request
**How to avoid:** Check `if (is.null(next_cursor))` before attempting next page; treat null cursor as "no more results"
**Warning signs:** Infinite pagination loops, duplicate results appended

### Pitfall 6: Forgetting to update existing callers
**What goes wrong:** Callers expect `list(paper1, paper2, ...)` but get `list(papers=..., next_cursor=..., count=...)`
**Why it happens:** Return format changed but call sites weren't updated to use `result$papers`
**How to avoid:** Search codebase for all `search_papers()` calls and update to access `result$papers` explicitly
**Warning signs:** Type errors, "object of type 'list' is not subsettable" errors

## Code Examples

Verified patterns from official sources and existing codebase:

### Initiating Cursor Pagination
```r
# Source: OpenAlex API docs (developers.openalex.org/how-to-use-the-api/get-lists-of-entities/paging)
# First request: cursor = "*" or NULL (API treats missing cursor like cursor=*)
req <- build_openalex_request("works", email, api_key) |>
  req_url_query(
    search = query,
    filter = filter_str,
    per_page = per_page,
    sort = sort,
    cursor = if (is.null(cursor)) "*" else cursor
  )
```

### Extracting Pagination Metadata
```r
# Source: OpenAlex API response structure + user decision
body <- resp_body_json(resp)

# Validate structure first
if (is.null(body$meta) || is.null(body$results)) {
  stop("Unexpected OpenAlex response format: missing 'meta' or 'results' field")
}

# Extract pagination state
next_cursor <- body$meta$next_cursor  # NULL when no more pages
count <- body$meta$count %||% 0       # Total result count

# Parse papers
papers <- if (length(body$results) > 0) {
  lapply(body$results, parse_openalex_work)
} else {
  list()
}

# Return structured result
list(
  papers = papers,
  next_cursor = next_cursor,
  count = count
)
```

### httr2 Retry Configuration
```r
# Source: httr2 documentation (httr2.r-lib.org/reference/req_retry.html)
req_retry(
  max_tries = 3,
  is_transient = \(resp) httr2::resp_status(resp) %in% c(429, 503),
  backoff = \(i) 2^(i - 1)  # Exponential: 1s, 2s, 4s
)

# httr2 automatically respects Retry-After header from 429 responses
# No need to implement manual header parsing
```

### Updating Caller to Use New Return Format
```r
# Source: Existing pattern in R/mod_search_notebook.R line 2217
# BEFORE (Phase 49 and earlier):
papers <- search_papers(query, email, api_key, ...)

# AFTER (Phase 50):
result <- search_papers(query, email, api_key, ..., cursor = NULL)
papers <- result$papers
# next_cursor available but not used yet (that's Phase 51-52)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Offset-based pagination (page numbers) | Cursor-based pagination | OpenAlex API best practice (current) | Access beyond 10,000 results, stable pagination ordering |
| No retry logic | httr2 `req_retry()` with exponential backoff | httr2 2.0+ (modern R HTTP) | Automatic resilience to rate limits and transient errors |
| Manual Retry-After parsing | httr2 automatic header respect | httr2 built-in | Cleaner code, correct 429 handling |
| List return type | Structured list with metadata | Modern API client pattern | Explicit pagination state, easier to extend |

**Deprecated/outdated:**
- **Offset pagination for large datasets:** OpenAlex limits basic paging to 10,000 results; cursor pagination is required for comprehensive searches
- **Manual retry loops:** httr2's `req_retry()` supersedes custom retry implementations with better jitter and backoff strategies

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat (current version) |
| Config file | None—tests run via `testthat::test_dir("tests/testthat")` |
| Quick run command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-api-openalex.R')"` |
| Full suite command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PAGE-06 | `search_papers()` accepts cursor param | unit | `Rscript -e "testthat::test_file('tests/testthat/test-api-openalex.R')"` | ✅ (extend existing) |
| PAGE-06 | Returns `list(papers, next_cursor, count)` | unit | `Rscript -e "testthat::test_file('tests/testthat/test-api-openalex.R')"` | ✅ (extend existing) |
| PAGE-06 | Cursor treated as opaque string | unit | `Rscript -e "testthat::test_file('tests/testthat/test-api-openalex.R')"` | ✅ (extend existing) |
| PAGE-06 | `build_openalex_request()` includes retry | unit | `Rscript -e "testthat::test_file('tests/testthat/test-api-openalex.R')"` | ✅ (extend existing) |
| PAGE-06 | Malformed response throws error | unit | `Rscript -e "testthat::test_file('tests/testthat/test-api-openalex.R')"` | ✅ (extend existing) |
| PAGE-06 | Empty results return correct structure | unit | `Rscript -e "testthat::test_file('tests/testthat/test-api-openalex.R')"` | ✅ (extend existing) |
| PAGE-06 | `search_papers()` caller updated | smoke | Manual app startup (Shiny smoke test protocol from CLAUDE.md) | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `Rscript -e "testthat::test_file('tests/testthat/test-api-openalex.R')"`
- **Per wave merge:** Full test suite via `testthat::test_dir("tests/testthat")`
- **Phase gate:** Full suite green + Shiny smoke test before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] Extend `tests/testthat/test-api-openalex.R` with new test cases:
  - `test_that("search_papers returns list with papers, next_cursor, count", ...)`
  - `test_that("search_papers accepts cursor parameter", ...)`
  - `test_that("search_papers accepts sort parameter", ...)`
  - `test_that("search_papers throws on missing meta field", ...)`
  - `test_that("search_papers throws on missing results field", ...)`
  - `test_that("search_papers returns empty structure when no results", ...)`
- [ ] Shiny smoke test after caller update (per project CLAUDE.md protocol)

## Sources

### Primary (HIGH confidence)
- [OpenAlex Paging Documentation](https://developers.openalex.org/how-to-use-the-api/get-lists-of-entities/paging) - Cursor pagination mechanics
- [OpenAlex Sort Documentation](https://developers.openalex.org/how-to-use-the-api/get-lists-of-entities/sort-entity-lists) - Sort parameter format and options
- [httr2::req_retry Documentation](https://httr2.r-lib.org/reference/req_retry.html) - Retry configuration and backoff strategies
- Existing codebase: `R/api_openalex.R` (lines 93-110, 294-376), `R/mod_search_notebook.R` (line 2217)
- Phase CONTEXT.md - Locked user decisions

### Secondary (MEDIUM confidence)
- [httr2 API Wrapping Guide](https://httr2.r-lib.org/articles/wrapping-apis.html) - Best practices for retry in shared builders
- [R-hub Retry Best Practices](https://blog.r-hub.io/2020/04/07/retry-wheel/) - Why httr2 retry supersedes custom loops

### Tertiary (LOW confidence)
None—all critical findings verified with official docs or existing code.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use, no new dependencies
- Architecture: HIGH - OpenAlex API docs explicit, httr2 patterns documented, CONTEXT.md decisions lock implementation
- Pitfalls: HIGH - Common pagination anti-patterns well-documented; cursor opacity is explicit OpenAlex guidance
- Validation: HIGH - Existing test infrastructure found, test file locations verified, test commands from CLAUDE.md

**Research date:** 2026-03-07
**Valid until:** 2026-04-06 (30 days—OpenAlex API stable, httr2 mature library)
