# Phase 42: Year Filters + Network Trimming - Context

**Gathered:** 2026-03-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix the year filter lower-bound to reflect actual network data (currently hardcoded at 1950) and add a toggle to trim the network to only seeds, influential papers, and connectivity-preserving bridge papers.

</domain>

<decisions>
## Implementation Decisions

### Trim control UX
- Toggle control (on/off), not a slider — the audit process already identifies influential papers, so the distinction is binary
- Located in the side panel filters section (alongside year filters)
- Auto-enable for networks with 500+ nodes; off by default for smaller networks
- Seeds are always visible — never removed by trim
- Toggle label shows count of papers that will be removed (e.g., "Trim to influential (removes 47 papers)")

### Trim threshold
- Claude's discretion to investigate how the audit currently flags influential papers (existing field/flag in codebase)
- Bridge papers (non-influential, non-seed papers that connect influential clusters) are kept to preserve network connectivity
- Mark bridge-paper retention logic with `#NOTE` tag in code as a design choice that can be tweaked in the future

### Filter feedback
- Instant removal when trim activates — no fade animation
- No persistent indicator showing how many papers are hidden
- No extra tooltip/badge on surviving papers — seeds and influential papers already have distinct shapes, which is sufficient
- Bridge papers get no visual distinction from other papers

### Year filter behavior
- Auto-update min/max bounds when network data changes (new search, papers added)
- Keep existing slider control — just fix the lower bound to use `min(year)` from network data instead of hardcoded 1950
- Network updates on slider release, not live during drag
- Year filter and trim toggle are independent filters (AND logic) — both apply, order doesn't matter

### Claude's Discretion
- How to determine "influential" from existing audit data (investigate codebase for existing flags/fields)
- Bridge paper detection algorithm
- Exact placement and styling of toggle within side panel
- Performance optimization for filtering large networks

</decisions>

<specifics>
## Specific Ideas

- Seeds + influential papers get their own shapes already — if something survives trim that isn't one of those, it's a bridge paper (interesting by nature of its connectivity role)
- The audit process already identifies influential papers, so no new threshold logic needed — just leverage existing data

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 42-year-filters-network-trimming*
*Context gathered: 2026-03-03*
