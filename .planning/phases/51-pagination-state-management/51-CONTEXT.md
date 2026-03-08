# Phase 51: Pagination State Management - Context

**Gathered:** 2026-03-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Server-side state layer that tracks the pagination cursor and enables distinct Refresh vs Load More behaviors. Refresh accumulates new papers (current behavior preserved), Load More appends next page. Cursor resets when API-affecting parameters change. No UI changes in this phase — state management only (Load More button is Phase 52).

</domain>

<decisions>
## Implementation Decisions

### Refresh behavior
- Refresh keeps current accumulate behavior: fetches page 1 with `cursor = NULL`, adds new papers, skips duplicates — never deletes existing papers
- Refresh is a recovery/fix tool for weird states, not the primary data loading mechanism
- Refresh always resets cursor to NULL so next Load More starts from page 2 of current results
- Refresh button always visible (shows warning toast if no query exists)

### Cursor reset scope
- Cursor resets when ANY Edit Search parameter changes (query, year, type, OA, min citations, retracted, search field) — simple rule: if the API query changes, cursor is invalid
- `save_search` observer already triggers `do_search_refresh()` which will reset cursor
- Year slider on main view does NOT reset cursor — it's display-side filtering only, doesn't change API query
- Sort order does NOT reset cursor — sort becomes client-side only (see Sort decision below)
- Deleting papers locally does NOT reset cursor — API pagination position is unaffected by local removals

### Sort order change
- Sort becomes client-side display reordering only
- `search_papers()` always fetches with `sort = "relevance_score"` regardless of dropdown selection
- Sort dropdown reorders the displayed paper list locally
- This simplifies cursor management — cursor is never affected by sort changes

### Total fetched tracking
- `pagination_state` reactiveValues tracks: `cursor` (string or NULL), `has_more` (logical), `total_fetched` (integer), `api_total` (integer from meta.count)
- `total_fetched` = total paper count in notebook (all papers, not session-scoped)
- `api_total` = total matching results from OpenAlex `meta.count` field
- Display format: "X of Y results" shown in toolbar area
- No hard cap on fetching — users can Load More as long as `has_more` is TRUE
- Display only — informational, no behavioral limits

### Claude's Discretion
- Exact placement within toolbar area for the result count
- Whether to store cursor in DB (for session persistence) or keep in-memory only
- Reactive loop prevention strategy (isolate vs observeEvent patterns)
- Error handling when cursor becomes invalid mid-session

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `search_papers()` in `R/api_openalex.R` already returns `list(papers, next_cursor, count)` (Phase 50)
- `do_search_refresh()` in `R/mod_search_notebook.R:2189` — existing refresh logic, already passes `cursor = NULL`
- `search_refresh_trigger` reactiveVal at line 2108 — programmatic refresh trigger
- `paper_refresh` reactiveVal at line 356 — triggers paper list re-read from DB
- `save_search` observer at line 2127 — collects all Edit Search params and triggers refresh

### Established Patterns
- `reactiveValues()` used for complex state (e.g., `delete_observers`, `block_journal_observers` at lines 361-364)
- `reactiveVal()` used for simple state (e.g., `paper_refresh`, `is_processing` at lines 356-357)
- Filter chain: `papers_data()` → `keyword_filtered_papers` → display (line 794)
- 400ms debounce on year slider (line 974) — display-side only, no API call

### Integration Points
- `do_search_refresh()` is the single point where search API is called — cursor state must be read/written here
- `save_search` observer resets filters and triggers refresh — cursor reset hooks here
- `papers_data()` reactive at line 931 reads from DB — `total_fetched` can derive from this
- Phase 52 (Load More button) will call `search_papers(cursor = pagination_state$cursor)` — this phase prepares the state

</code_context>

<specifics>
## Specific Ideas

- User described Refresh as "if the notebook gets into a weird state" — it's a recovery tool, not the primary workflow
- Load More is the primary way to bring in more data
- "X of Y results" in toolbar gives researchers context about how much more is available

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 51-pagination-state-management*
*Context gathered: 2026-03-07*
