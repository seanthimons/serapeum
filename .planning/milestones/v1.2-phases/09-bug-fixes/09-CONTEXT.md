# Phase 9: Bug Fixes - Context

**Gathered:** 2026-02-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix three API interaction bugs: OpenAlex 401 errors on topic searches, raw HTTP error codes shown to users, and duplicate OpenAlex requests triggered by tab navigation. No new features — only fixing broken behavior.

</domain>

<decisions>
## Implementation Decisions

### Error message style
- Toast notifications (non-blocking, temporary popup in corner)
- Plain language message up front with expandable "Show details" toggle for HTTP status/error code
- No action buttons (no Retry) — informational only, user retries by repeating their action
- Severity-based styling: red/danger for hard failures, yellow/warning for degraded/partial results

### Tab navigation behavior
- Cached results shown as-is when returning to search notebook — no new API call triggered
- Results persist until user explicitly runs a new search (never auto-stale)
- Results only are cached — UI state (scroll position, expanded abstracts) resets to top on return
- No visual indicator that results are cached — results look the same whether cached or fresh

### Claude's Discretion
- Root cause investigation and fix approach for OpenAlex 401 errors (BUGF-01)
- Retry/recovery strategy for API failures (user chose no retry button, but internal retry logic is Claude's call)
- Technical approach for preventing duplicate requests on tab switch
- Toast auto-dismiss timing and positioning
- How to classify errors into failure vs warning severity

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 09-bug-fixes*
*Context gathered: 2026-02-11*
