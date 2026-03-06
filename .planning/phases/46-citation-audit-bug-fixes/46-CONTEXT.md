# Phase 46: Citation Audit Bug Fixes - Context

**Gathered:** 2026-03-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix critical citation audit bugs preventing multi-paper imports and abstract notebook sync. This phase diagnoses the root cause of per-paper error modals, fixes multi-paper import, and ensures papers appear in the abstract notebook after import. No new features — bug fixes and reliability improvements only.

</domain>

<decisions>
## Implementation Decisions

### Multi-paper import behavior
- **Sequential import with progress**: import papers one at a time, showing "Adding paper 3/7..." progress
- **Best-effort on failure**: if one paper fails, skip it and continue importing the rest, report failures at the end
- **Duplicate handling**: skip duplicates silently but include count in summary ("Added 5 papers, 2 already existed (skipped)")
- **Selection UI**: add checkbox selection per paper in citation audit results, PLUS keep the existing "add all" button
- **Root cause investigation required**: diagnose WHY error modals fire for every additional paper added to notebook — this is the core bug

### Abstract notebook sync
- **Immediate reactive refresh** as default behavior — papers appear in abstract notebook as they're added
- **Manual refresh fallback** — if reactive gets stuck in a bad state, user can force a refresh to pull new papers
- **RESEARCH NEEDED**: investigate how reactive refresh interacts with abstract-searched notebook behavior. Could break existing search state.
- **New paper ordering**: new papers go to top of list, but do NOT override/displace seeded papers from their position
- **Toast notification**: "3 papers added to notebook" confirmation toast after import completes

### Error recovery UX
- **Toast-based errors**: "Failed to add 2 papers: [reason]" — non-blocking toast, no modal dialogs
- **No retry button**: just report failures. User can re-attempt manually via citation audit if needed.
- **Diagnose root cause first**: research the specific bug causing per-paper error modals before replacing error handling
- **Progress indicator**: updating progress toast ("Adding papers... 3/7") — lightweight, non-blocking

### Concurrency handling
- **Single-user, single-tab assumed** for now. #NOTE: may need to pivot to multi-user at some point — design decisions should not preclude this.
- **RESEARCH NEEDED (CRITICAL)**: DuckDB only allows a single write operation. Must research:
  - How to avoid locking up the write cycle during sequential multi-paper import
  - Per-paper transactions vs single outer transaction vs write queue
  - Whether DuckDB's single-writer model is fundamentally suitable or if infrastructure change is needed
- **Button disable vs stacking**: RESEARCH-GATED decision. Disable during import is the safe fallback if we can't solve the single-writer issue. Stacking (allowing queued imports) is the modern UX choice if writes can be safely serialized.
- **Openness to infrastructure change**: if DuckDB's single-writer is a fundamental bottleneck for this use case, user is open to ripping the bandaid off and changing storage infrastructure now rather than later.

### Claude's Discretion
- Specific DuckDB transaction pattern (after research resolves the write concurrency question)
- Toast notification library/implementation approach
- Exact reactive invalidation mechanism for abstract notebook sync
- Whether to use Shiny's built-in notification system or a custom toast

</decisions>

<specifics>
## Specific Ideas

- The per-paper error modal bug is the highest priority — everything else builds on understanding why it happens
- DuckDB single-writer constraint is the biggest technical risk. Research must evaluate: can we work within DuckDB's model, or do we need to change databases?
- User prefers modern UX (stacking imports) but will accept safe fallback (disable buttons) if research shows it's necessary

</specifics>

<deferred>
## Deferred Ideas

- Multi-user support — noted as future consideration, but single-user is fine for now. Design shouldn't preclude multi-user pivot.

</deferred>

---

*Phase: 46-citation-audit-bug-fixes*
*Context gathered: 2026-03-04*
