# Phase 25: Stabilize - Context

**Gathered:** 2026-02-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix all known bugs (BUGF-01..04), resolve tech debt (DEBT-01..03), land pending PRs (UIPX-01, UIPX-02), and polish the UI (UIPX-03..05) — making the app bug-free, connection-safe, and visually polished before any synthesis features are added.

Note: UIPX-05 (settings page layout) is already fixed — skip it.

</domain>

<decisions>
## Implementation Decisions

### Bug Fix Approach
- **BUGF-01 (seed paper visibility):** Pin seed paper as the first result in abstract search, always at top regardless of sort order
- **BUGF-02 (duplicate modals):** Check the existing open PR first — if its solution works, land it as-is rather than reimplementing
- **BUGF-03 (cost tracking):** The table refresh works fine — the real issue is that non-default models (those not on the built-in pricing list) may not show accurate costs. Fix model pricing coverage, not the refresh mechanism
- **BUGF-04 (paper count after removal):** Fix the count to update correctly after refresh following removals
- **PR landing strategy:** Land all pending PRs (UIPX-01 duplicate toasts, UIPX-02 collapsible keywords, and BUGF-02 modal PR if it exists) FIRST in a single merge pass, then fix remaining bugs on the clean base

### DEBT-01: Connection Leak Strategy
- **Approach:** Fresh approach — fix the leak however is cleanest, don't constrain to reusing with_ragnar_store()
- **Scope:** Fix search_chunks_hybrid leak as the primary target, but ALSO audit all other ragnar callers for similar leaks
- **Audit findings:** If other leaks are found during audit, log them as new issues — don't fix them in this phase (only fix the known search_chunks_hybrid leak)
- **Verification:** Code review sufficient — no special Windows file-lock testing required

### DEBT-02/03: Cleanup Scope
- **DEBT-02 (section_hint):** Add section_hint metadata to the PDF indexing pipeline for new PDFs only — existing PDFs keep current origins until re-indexed naturally
- **DEBT-03 (dead code):** Remove with_ragnar_store() and register_ragnar_cleanup() immediately — don't evaluate, just delete
- **Dead code sweep:** Light sweep — remove obviously dead code encountered along the way, but don't do a comprehensive sweep
- **Reporting:** List all removed dead code in the PR description for user review

### UI Polish
- **UIPX-03 (tooltip containment):** Smart repositioning — tooltip flips direction dynamically to stay within graph container bounds
- **UIPX-04 (network background):** Light neutral background that works with ALL themes. Critical constraint: background must not interfere with colorblind-safe node color palettes — needs good contrast with all node colors
- **UIPX-05 (settings layout):** Already fixed — skip this requirement

### Claude's Discretion
- Exact implementation pattern for connection leak fix (fresh approach)
- Technical approach for pinning seed paper to top of results
- Tooltip repositioning implementation details
- Which dead code qualifies as "obviously dead" during light sweep

</decisions>

<specifics>
## Specific Ideas

- Network background color must be colorblind-palette-safe — chosen to not interfere with any colorblind node color scheme
- BUGF-03 is a pricing coverage issue, not a refresh timing issue — investigate how non-default models are priced
- Check existing PRs before reimplementing (especially BUGF-02 modal fix)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 25-stabilize*
*Context gathered: 2026-02-18*
