# Phase 34: OpenAlex Batch API Support - Research

**Researched:** 2026-02-25
**Domain:** OpenAlex API batch querying, R HTTP client patterns
**Confidence:** HIGH

## Summary

Phase 34 adds a batch DOI lookup function to the existing OpenAlex API client (`R/api_openalex.R`). The OpenAlex API natively supports pipe-separated filter syntax for querying up to 50 DOIs per request (officially documented as up to 100 values per filter, but CONTEXT.md locks batch size at 50). The existing codebase already uses `httr2` for all API calls, and `httr2` provides built-in `req_retry()` with exponential backoff and `req_throttle()` for rate limiting — both directly applicable.

The implementation is straightforward: chunk DOIs from `parse_doi_list()` (Phase 33) into batches of 50, query OpenAlex with `filter=doi:doi1|doi2|...|doi50`, match results back to input DOIs, and categorize failures. The main complexity is proper error categorization (not_found vs api_error vs rate_limited) and the progress callback pattern for Shiny integration.

**Primary recommendation:** Build `batch_fetch_papers()` in `R/api_openalex.R` using httr2's `req_retry()` for backoff and manual `Sys.sleep()` for inter-batch delays, reusing `parse_openalex_work()` for result normalization.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Return normalized paper objects by default (via existing parse_openalex_work())
- Add `parse = TRUE` parameter so callers can opt into raw OpenAlex work objects when needed
- Extend parse_openalex_work() to extract three new fields: `is_retracted`, `cited_by_percentile`, and `topics`
- Deduplicate results by OpenAlex work ID (paper_id)
- Match OpenAlex results back to input DOIs by comparing normalized DOIs after lookup
- Unmatched input DOIs go to a separate `not_found` list with the original DOI string
- No retry for individual missing DOIs
- Three error categories: `not_found`, `api_error`, `rate_limited`
- Each error entry includes the original DOI and a reason string
- If a batch request fails entirely: retry the whole batch up to 3 times, then mark all DOIs in that batch as `api_error`
- Return partial results — never fail the entire operation because of one bad batch
- 0.1s inter-batch delay, configurable via `delay` parameter (default 0.1)
- Exponential backoff on 429 errors: 1s, 2s, 4s (3 retries max)
- Respect OpenAlex Retry-After header when present, fall back to exponential backoff otherwise
- Connection failures (timeout, DNS): retry once after 2s, then fail the batch
- Accept optional `progress_callback` parameter
- Dual logging: message() for console AND persistent log file

### Claude's Discretion
- Exact log file format and rotation strategy
- Internal chunking implementation (how to split DOI vector into batches of 50)
- HTTP client configuration (timeout values, connection pooling)
- Test fixture design for rate limit and error scenarios

### Deferred Ideas (OUT OF SCOPE)
- Storing full raw OpenAlex JSON blobs for future analytics
- Institutional affiliation extraction
- OpenAlex email-based authentication for higher rate limits
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| Foundation for BULK-04 | System batch-queries OpenAlex (50 DOIs per request) with rate limiting | OpenAlex pipe-separated filter supports up to 100 values; httr2 req_retry() handles backoff |
| Foundation for BULK-05 | Import runs async with progress bar showing N/total papers fetched | progress_callback pattern enables Shiny integration without coupling |
| Foundation for AUDIT-02 | System analyzes backward references using referenced_works | batch_fetch_papers() can look up referenced_works DOIs in bulk |
| Foundation for AUDIT-03 | System analyzes forward citations via OpenAlex cited_by | batch_fetch_papers() provides the transport layer for citation lookups |
| Foundation for AUDIT-06 | User can import individual missing papers with one click | Single-DOI case is just batch_size=1, same function |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| httr2 | 1.0+ | HTTP requests, retry, throttling | Already used throughout project; provides req_retry(), req_throttle() |
| jsonlite | 1.8+ | JSON parsing | Already used; resp_body_json() wraps it |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| base R | - | Chunking (split()), logging (message()), file writing (cat()) | All batch orchestration logic |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual Sys.sleep() | httr2::req_throttle() | req_throttle() is per-request, not per-batch; manual sleep gives more control for batch delays |
| Custom retry logic | httr2::req_retry() | req_retry() handles 429 + backoff natively; use it for per-request retries |

## Architecture Patterns

### Recommended Structure
```
R/
├── api_openalex.R     # Add batch_fetch_papers() here (alongside existing functions)
├── utils_doi.R        # parse_doi_list() from Phase 33 feeds DOIs in

tests/testthat/
├── test-api-openalex.R      # Existing tests
├── test-batch-openalex.R    # New: batch function tests with mocked HTTP
```

### Pattern 1: Batch Chunking with Progress
**What:** Split DOI vector into chunks of N, iterate with progress callback
**When to use:** Any batch operation over a list of identifiers
**Example:**
```r
chunk_dois <- function(dois, batch_size = 50) {
  split(dois, ceiling(seq_along(dois) / batch_size))
}

# In batch_fetch_papers():
chunks <- chunk_dois(clean_dois, batch_size)
for (i in seq_along(chunks)) {
  result <- fetch_single_batch(chunks[[i]], email, api_key)
  if (!is.null(progress_callback)) {
    progress_callback(batch_current = i, batch_total = length(chunks),
                      found_so_far = length(all_found),
                      not_found_so_far = length(all_not_found))
  }
  if (i < length(chunks)) Sys.sleep(delay)
}
```

### Pattern 2: OpenAlex Pipe-Separated DOI Filter
**What:** Query multiple DOIs in one request using pipe separator in filter parameter
**When to use:** Looking up known DOIs in OpenAlex
**Example:**
```r
# Use SHORT form DOIs to avoid URL length limits (4096 char max)
# OpenAlex accepts both short and long form in doi filter
doi_filter <- paste(bare_dois, collapse = "|")
filter_str <- paste0("doi:", doi_filter)

req <- build_openalex_request("works", email, api_key) |>
  req_url_query(filter = filter_str, per_page = 50)
```
**Source:** https://docs.openalex.org/how-to-use-the-api/get-lists-of-entities/filter-entity-lists

### Pattern 3: httr2 Retry with Custom Backoff for 429
**What:** Use req_retry() with is_transient for 429 detection and custom backoff
**Example:**
```r
req <- build_openalex_request("works", email, api_key) |>
  req_url_query(filter = filter_str, per_page = batch_size) |>
  req_retry(
    max_tries = 3,
    is_transient = function(resp) resp_status(resp) == 429,
    backoff = function(tries) 2^(tries - 1),  # 1s, 2s, 4s
    after = function(resp) {
      retry_after <- resp_header(resp, "Retry-After")
      if (!is.null(retry_after)) as.numeric(retry_after) else NULL
    }
  )
```
**Source:** Context7 /r-lib/httr2 — req_retry() documentation

### Pattern 4: DOI Matching After Batch Fetch
**What:** Match returned works back to input DOIs by normalizing both sides
**When to use:** After batch fetch, to identify which DOIs were found vs not
**Example:**
```r
# Input DOIs are bare format from parse_doi_list()
# OpenAlex returns doi as "https://doi.org/10.xxxx/yyyy"
# Match by stripping prefix from OpenAlex result and lowercasing
match_results_to_dois <- function(works, input_dois) {
  found_dois <- vapply(works, function(w) {
    tolower(gsub("^https://doi.org/", "", w$doi %||% ""))
  }, character(1))

  input_lower <- tolower(input_dois)
  matched <- input_lower %in% found_dois

  list(
    found = works,
    not_found = input_dois[!matched]
  )
}
```

### Anti-Patterns to Avoid
- **Individual DOI requests in a loop:** Each DOI as a separate API call wastes rate limit budget. Always batch.
- **Full URL DOIs in filter string:** Using `https://doi.org/10.xxxx/yyyy` format wastes URL characters. Use bare DOIs (`10.xxxx/yyyy`) — OpenAlex accepts both formats in the doi filter.
- **Ignoring partial failures:** A single batch failure should not abort the entire operation. Process remaining batches and collect errors.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP retry with backoff | Custom retry loops | httr2::req_retry() | Handles 429, Retry-After header, exponential backoff natively |
| DOI normalization | Another normalizer | normalize_doi_bare() from utils_doi.R | Already handles URL decoding, prefix stripping, lowercasing |
| DOI parsing from user input | Another parser | parse_doi_list() from Phase 33 | Already handles mixed formats, deduplication, error categorization |
| Work object parsing | Another parser | parse_openalex_work() | Already extracts 18 fields; just extend it for 3 new ones |

**Key insight:** Phase 33 and existing api_openalex.R already handle the hard parts (DOI normalization, work parsing). Phase 34 orchestrates them with batching and error tracking.

## Common Pitfalls

### Pitfall 1: URL Length Limit
**What goes wrong:** Batch request URL exceeds 4096 characters with long-form DOI URLs
**Why it happens:** Using `https://doi.org/10.xxxx/yyyy` format for each DOI in the filter
**How to avoid:** Use bare DOIs (`10.xxxx/yyyy`) in the filter string. 50 bare DOIs at ~25 chars each = ~1250 chars + separators, well within 4096 limit.
**Warning signs:** HTTP 414 errors or truncated responses

### Pitfall 2: Mismatched DOI Formats During Matching
**What goes wrong:** Input DOIs don't match returned DOIs because of case or prefix differences
**Why it happens:** Input uses bare lowercase DOIs; OpenAlex returns `https://doi.org/` prefix
**How to avoid:** Always normalize both sides before comparison. Use `tolower()` and strip `https://doi.org/` prefix from OpenAlex results.
**Warning signs:** Papers showing up as "not found" when they actually exist

### Pitfall 3: Silent Rate Limit Exhaustion
**What goes wrong:** Daily budget ($1 for free tier) exhausted without user warning
**Why it happens:** Large batch operations (500+ DOIs) can consume significant budget
**How to avoid:** Monitor `X-RateLimit-Remaining-USD` response header and warn users when budget is low. Log remaining budget after each batch.
**Warning signs:** Sudden 429 errors mid-operation after previous batches succeeded

### Pitfall 4: per_page Too Small for Batch
**What goes wrong:** Only 25 results returned even though 50 DOIs were queried
**Why it happens:** Default per_page is 25 in OpenAlex
**How to avoid:** Always set `per_page` equal to `batch_size` (e.g., per_page=50 for 50-DOI batches)
**Warning signs:** Fewer results than expected, some valid DOIs appearing as "not found"

### Pitfall 5: Retry-After Header Type
**What goes wrong:** Backoff logic fails because Retry-After value is parsed incorrectly
**Why it happens:** Retry-After can be seconds (integer) or HTTP date format
**How to avoid:** Parse as numeric first; if that fails, use default backoff. OpenAlex typically uses seconds.
**Warning signs:** Immediate retry instead of waiting, continued 429 errors

## Code Examples

### Batch Fetch Core Loop
```r
batch_fetch_papers <- function(dois, email, api_key = NULL,
                                batch_size = 50, delay = 0.1,
                                parse = TRUE, progress_callback = NULL,
                                log_file = NULL) {
  # Validate inputs
  stopifnot(is.character(dois), length(dois) > 0)
  stopifnot(batch_size > 0, batch_size <= 50)

  # Initialize result collectors
  all_papers <- list()
  all_errors <- list()

  # Chunk DOIs
  chunks <- split(dois, ceiling(seq_along(dois) / batch_size))

  for (i in seq_along(chunks)) {
    batch_result <- tryCatch(
      fetch_single_batch(chunks[[i]], email, api_key, parse),
      error = function(e) {
        # Classify and record batch-level error
        list(papers = list(),
             errors = lapply(chunks[[i]], function(d)
               list(doi = d, reason = "api_error", details = conditionMessage(e))))
      }
    )

    all_papers <- c(all_papers, batch_result$papers)
    all_errors <- c(all_errors, batch_result$errors)

    # Progress callback
    if (!is.null(progress_callback)) {
      progress_callback(
        batch_current = i, batch_total = length(chunks),
        found_so_far = length(all_papers),
        not_found_so_far = sum(vapply(all_errors, function(e) e$reason == "not_found", logical(1)))
      )
    }

    # Inter-batch delay
    if (i < length(chunks)) Sys.sleep(delay)
  }

  # Deduplicate by paper_id
  seen_ids <- character()
  unique_papers <- Filter(function(p) {
    if (p$paper_id %in% seen_ids) return(FALSE)
    seen_ids <<- c(seen_ids, p$paper_id)
    TRUE
  }, all_papers)

  list(papers = unique_papers, errors = all_errors)
}
```

### Extending parse_openalex_work()
```r
# Add these extractions to the existing parse_openalex_work() function:

# is_retracted
is_retracted <- isTRUE(work$is_retracted)

# cited_by_percentile (2-year percentile from OpenAlex)
cited_by_percentile <- NA_real_
if (!is.null(work$cited_by_percentile_year) && !is.null(work$cited_by_percentile_year$min)) {
  cited_by_percentile <- work$cited_by_percentile_year$min
}

# topics (list of topic objects)
topics <- list()
if (!is.null(work$topics) && length(work$topics) > 0) {
  topics <- lapply(work$topics, function(t) {
    list(
      id = gsub("https://openalex.org/", "", t$id %||% ""),
      name = t$display_name %||% NA_character_,
      score = t$score %||% NA_real_
    )
  })
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| OpenAlex concepts | OpenAlex topics | 2024 | Topics replaced concepts for work classification |
| No rate limit budget | Cost-based daily budget | 2024-2025 | Must monitor X-RateLimit-Remaining-USD header |
| 25 results default | per_page up to 200 | Stable | Must set per_page explicitly for batch queries |

**Deprecated/outdated:**
- OpenAlex `concepts` field: replaced by `topics` in 2024. Use `topics` for subject classification.

## Open Questions

1. **X-RateLimit-Remaining-USD header availability**
   - What we know: OpenAlex documents this header for budget monitoring
   - What's unclear: Whether it's returned on every response or only authenticated ones
   - Recommendation: Check for the header and log when present, don't fail if absent

2. **Connection pooling in httr2**
   - What we know: httr2 uses curl under the hood; curl supports connection reuse
   - What's unclear: Whether httr2 reuses connections across sequential req_perform() calls
   - Recommendation: Don't worry about it — 0.1s inter-batch delay makes connection reuse negligible

## Sources

### Primary (HIGH confidence)
- Context7 /r-lib/httr2 — req_retry(), req_throttle(), backoff patterns
- https://docs.openalex.org/how-to-use-the-api/get-lists-of-entities/filter-entity-lists — pipe-separated filter syntax, up to 100 values per filter
- https://docs.openalex.org/how-to-use-the-api/rate-limits-and-authentication — 100 req/sec, $1/day budget, 429 handling

### Secondary (MEDIUM confidence)
- https://blog.openalex.org/fetch-multiple-dois-in-one-openalex-api-request/ — batch DOI tutorial (content not fully extractable, but URL format confirmed via official docs)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — httr2 already used in project, req_retry() verified via Context7
- Architecture: HIGH — OpenAlex pipe filter syntax verified via official docs
- Pitfalls: HIGH — URL length limits, per_page defaults, DOI matching all confirmed via docs and codebase analysis

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (stable API, stable R packages)
