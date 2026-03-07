# Phase 50 Context: API Pagination Foundation

**Created:** 2026-03-07
**Phase goal:** OpenAlex API client supports cursor-based pagination for both Refresh and Load More workflows

## Decisions

### 1. Function Strategy

**Decision:** Modify existing `search_papers()` directly — do not create a separate function.

- Add `cursor` parameter (default `NULL`) and `sort` parameter (default `"relevance_score"`)
- Change return format from `list(parsed_works...)` to `list(papers, next_cursor, count)`
- Update all existing callers in this phase (not deferred to Phase 51)
- Callers access papers via `result$papers` — no helper function needed

**Rationale:** One function, not two. Even without requesting more than 25, the structured return is useful for downstream. httr2 infrastructure makes cursor support straightforward.

### 2. Sort Order for Pagination

**Decision:** Default to relevance score, but accept a `sort` parameter.

- Add `sort` parameter to `search_papers()` with default `"relevance_score"`
- No UI for sort selection — just the function signature ready for future use
- OpenAlex cursor pagination requires sort; relevance is natural for academic search

### 3. Error Handling & Resilience

**Decision:** Retry with backoff, then throw. Applied globally to all OpenAlex calls.

- Add `httr2::req_retry()` to `build_openalex_request()` so all API functions benefit
- Config: `max_tries = 3`, respect `Retry-After` header from 429s, exponential backoff for 5xx
- On permanent failure: propagate via existing `stop_api_error()` pattern

### 4. Empty Results

**Decision:** Return `list(papers = list(), next_cursor = NULL, count = 0)` when results are empty.

- Signals clean terminal state for pagination
- Caller knows there's nothing more without checking cursor separately

### 5. Malformed Response

**Decision:** Throw a descriptive error if API response is missing `meta` or `results` fields.

- Explicit validation: check for `body$meta` and `body$results` presence
- Error message: descriptive (e.g., "Unexpected OpenAlex response format") for debugging
- Do not silently return safe defaults — malformed responses indicate a real problem

## Code Context

### Files to modify

- `R/api_openalex.R` — Primary target
  - `build_openalex_request()` — Add `req_retry()` here (all functions benefit)
  - `search_papers()` (L294-376) — Add cursor/sort params, change return format, add response validation
- `R/mod_search_notebook.R` — Update all `search_papers()` call sites to use `result$papers`

### Existing patterns to follow

- `build_openalex_request()` is the shared request builder — retry goes here
- `stop_api_error()` is the existing error wrapper — keep using it
- `parse_openalex_work()` handles individual work parsing — unchanged
- Other functions (`get_citing_papers`, `get_cited_papers`, etc.) use same builder — they get retry for free

### OpenAlex API cursor behavior

- `cursor=*` starts pagination; response includes `meta.next_cursor`
- Cursors are stateless (base64-encoded position markers) — no expiration concern
- `meta.next_cursor` is `null` when no more results
- `meta.count` gives total result count

## Deferred Ideas

None identified during discussion.

---
*Context gathered: 2026-03-07*
