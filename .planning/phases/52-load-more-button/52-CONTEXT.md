# Phase 52: Load More Button - Context

**Gathered:** 2026-03-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a Load More button to the search notebook toolbar that fetches the next page of results from OpenAlex and appends them to the existing paper list. The pagination state layer (Phase 51) already tracks cursor, has_more, and total_fetched — this phase adds the UI trigger and append logic.

</domain>

<decisions>
## Implementation Decisions

### Button placement & style
- Position: after Refresh button, before result count span
- Label: icon + "Load More" text (matches Refresh pattern)
- Icon: angles-down (double chevron down — conveys "fetch more below")
- Color: `btn-outline-info` (sapphire — matches Seed Citation Network button)
- Size: `btn-sm` (matches all toolbar buttons)
- Tooltip: descriptive text explaining the button's function (e.g., "Fetch next page of search results")

### Visibility & disabled state
- Always visible in toolbar (not conditionally rendered)
- Disabled when `pagination_state$has_more` is FALSE (including before first search)
- Disabled while a fetch is in progress (prevents double-clicks)
- Button remains in place — no layout shift from show/hide

### Loading feedback
- While fetching: button disabled, icon swaps to spinner
- After batch completes: result count ("X of Y results") updates once
- Success toast: "Loaded X more papers (Y total)" — brief confirmation
- On last page (has_more becomes FALSE): standard toast, button disabling is the signal — no special "all loaded" message
- Error: error toast ("Failed to load more — try again"), re-enable button for retry

### Append behavior
- New papers inserted into DB, then deduped by OpenAlex ID (same as existing Refresh logic — skip duplicates silently)
- After append, full paper list re-sorted by active sort criterion (client-side sort from Phase 51 applies to all papers)
- Scroll position: preserve current position (best effort — Claude's discretion on implementation given Shiny rendering)
- Papers persist until Refresh is clicked or filters change (existing behavior from Phase 51 cursor reset logic)

### Claude's Discretion
- Exact shinyjs/Shiny mechanism for spinner swap (updateActionButton vs JS toggle)
- Scroll position preservation approach (may depend on how the paper list renders)
- Whether to reuse `do_search_refresh()` with a mode parameter or create a separate `do_load_more()` function
- Toast message exact wording

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `pagination_state` reactiveValues (line 378): already tracks `cursor`, `has_more`, `total_fetched`, `api_total`
- `do_search_refresh()` (line 2225): existing search execution function — calls `search_papers()`, inserts into DB, updates pagination_state
- `search_papers()` in `R/api_openalex.R`: accepts cursor parameter, returns `list(papers, next_cursor, count)`
- `format_result_count()`: helper for "X of Y results" display
- `icon_rotate()`, existing icon helpers in `R/theme_catppuccin.R`

### Established Patterns
- Toolbar buttons: `actionButton(ns("id"), "Label", class = "btn-sm btn-outline-{color}", icon = icon_fn())`
- Sapphire/info color: `btn-outline-info` maps to Catppuccin sapphire via CSS custom properties
- Toast notifications: `showNotification()` used throughout for success/error feedback
- Processing state: `is_processing` reactiveVal (line 357) used for disabling UI during operations

### Integration Points
- Toolbar div at line 82: `d-flex gap-2` container — new button inserts after Refresh (line 108-110)
- `do_search_refresh()` at line 2225: Load More needs similar logic but with cursor != NULL and append mode
- `paper_refresh` reactiveVal at line 356: triggers paper list re-read from DB after insert
- `papers_data()` reactive at line 931: applies sort + filters to full paper list from DB

</code_context>

<specifics>
## Specific Ideas

- Tooltip should be informative about the button's function, not just the label
- Refresh is a recovery tool; Load More is the primary way to bring in more data (from Phase 51 discussion)
- "X of Y results" gives researchers context about how much more is available

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 52-load-more-button*
*Context gathered: 2026-03-09*
