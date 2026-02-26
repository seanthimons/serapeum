# Phase 37: Citation Audit - Context

**Gathered:** 2026-02-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can identify frequently-cited papers missing from their search notebook collection. The system analyzes both backward references (cited BY collection) and forward citations (papers that CITE the collection) via OpenAlex, ranks missing papers by frequency, and lets users import them. This phase delivers the audit UI and analysis engine. Batch select-all workflows are Phase 38.

</domain>

<decisions>
## Implementation Decisions

### Results presentation
- Table layout with sortable columns (title, authors, year, collection frequency, global citation count)
- Show both collection frequency (how many times referenced by/citing user's papers) AND global OpenAlex citation count
- Show direction breakdown — distinguish backward references from forward citations (e.g., separate counts or tags)
- Default sort by collection frequency descending; columns are re-sortable by user

### Trigger & scope
- Dedicated audit tab/page (not a button inside search notebook)
- Dropdown to select which search notebook to audit
- Always audits entire notebook — no subset selection
- No minimum paper count warning — small notebooks work the same as seed-paper workflows
- Results are cached in DB with last-analysis date; user can re-run manually
- Papers imported since last audit are marked as imported in cached results
- Imported papers go into the same notebook being audited

### Import workflow
- Checkbox selection + batch import supported alongside single-paper import
- Single import: immediate action, no confirmation
- Batch import: confirmation dialog ("Import X papers?") before proceeding
- Both single and batch import navigate to the notebook after completion

### Progress & async
- Modal overlay with stepped progress bar (matching existing network building modal pattern)
- Steps shown: "Fetching backward references..." → "Fetching forward citations..." → "Ranking results..."
- Cancel button always available throughout entire analysis
- On cancel during fetch: show partial results collected so far
- On failure (rate limit, network error): show partial results with warning that results may be incomplete

### Claude's Discretion
- Exact table widget choice and styling
- Cache invalidation strategy (time-based vs manual only)
- How direction breakdown is visually presented (separate columns, badges, tooltip)
- Progress bar granularity within each step

</decisions>

<specifics>
## Specific Ideas

- Progress bar with steps should match the existing network building modal pattern — consistent UX
- Small notebook audit is effectively the same as a seed-paper discovery workflow — no special treatment needed

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 37-citation-audit*
*Context gathered: 2026-02-26*
