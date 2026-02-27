# Phase 34: OpenAlex Batch API Support - Context

**Gathered:** 2026-02-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Enable efficient batch fetching of papers from OpenAlex with proper rate limiting and error handling. Accepts lists of DOIs (from Phase 33's parse_doi_list()), queries OpenAlex in batches of up to 50 using pipe-separated filter syntax, and returns structured results with categorized errors. This is the API transport layer for bulk import (Phase 35-37) and citation audit (Phase 37).

</domain>

<decisions>
## Implementation Decisions

### Return format
- Return normalized paper objects by default (via existing parse_openalex_work())
- Add `parse = TRUE` parameter so callers can opt into raw OpenAlex work objects when needed
- Extend parse_openalex_work() to extract three new fields: `is_retracted`, `cited_by_percentile`, and `topics` (concepts/topics array)
- Deduplicate results by OpenAlex work ID (paper_id) — if two DOI variants resolve to the same paper, return it once

### DOI matching
- Match OpenAlex results back to input DOIs by comparing normalized DOIs after lookup
- Unmatched input DOIs go to a separate `not_found` list with the original DOI string
- No retry for individual missing DOIs — if OpenAlex doesn't have it, it's "not found"

### Error handling & partial failure
- Three error categories: `not_found` (DOI not in OpenAlex), `api_error` (request failed after retries), `rate_limited` (gave up after backoff)
- Each error entry includes the original DOI and a reason string
- If a batch request fails entirely: retry the whole batch up to 3 times, then mark all DOIs in that batch as `api_error`
- Return partial results — all found papers plus structured error report for failed DOIs
- Never fail the entire operation because of one bad batch

### Rate limiting
- 0.1s inter-batch delay, configurable via `delay` parameter (default 0.1)
- Exponential backoff on 429 errors: 1s, 2s, 4s (3 retries max)
- Respect OpenAlex Retry-After header when present, fall back to exponential backoff otherwise
- Connection failures (timeout, DNS): retry once after 2s, then fail the batch

### Progress & feedback
- Accept optional `progress_callback` parameter — function receives: batch_current, batch_total, found_so_far, not_found_so_far
- Shiny UI can wire this to a progress bar (e.g., "Fetching batch 3/4... 127 papers found")
- Dual logging: message() for console AND persistent log file in app log directory (logs/openalex_batch.log)
- Log entries include: batch URLs, response codes, timing, retry attempts

### Claude's Discretion
- Exact log file format and rotation strategy
- Internal chunking implementation (how to split DOI vector into batches of 50)
- HTTP client configuration (timeout values, connection pooling)
- Test fixture design for rate limit and error scenarios

</decisions>

<specifics>
## Specific Ideas

- The debate analysis recommended normalized-by-default with raw escape hatch — this avoids the 10x maintenance burden of raw-everywhere while preserving flexibility for future analytics/export features
- Log to both message() and file because message() may be missed in local deployments and log files may be inaccessible on server deployments — belt and suspenders
- Progress callback pattern allows Shiny modules to provide real-time feedback without the batch function knowing about Shiny

</specifics>

<deferred>
## Deferred Ideas

- Storing full raw OpenAlex JSON blobs for future analytics — revisit if export/analysis features are added
- Institutional affiliation extraction — future phase if co-authorship analysis is needed
- OpenAlex email-based authentication for higher rate limits — separate configuration phase

</deferred>

---

*Phase: 34-openalex-batch-api-support*
*Context gathered: 2026-02-25*
