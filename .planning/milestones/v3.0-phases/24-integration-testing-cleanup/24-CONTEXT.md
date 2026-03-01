# Phase 24: Integration Testing & Cleanup - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

End-to-end integration tests validate the per-notebook ragnar workflow (upload → chunk → embed → query), and the legacy shared store is deleted on app startup. This phase closes out v3.0.

</domain>

<decisions>
## Implementation Decisions

### Shared store deletion
- Auto-delete on app startup — no user confirmation required
- Delete unconditionally — don't check whether per-notebook stores exist first (shared store is obsolete regardless)
- Show a brief toast notification: "Legacy search index removed" (non-blocking)
- Clean up ALL legacy RAG files in data/, not just `data/serapeum.ragnar.duckdb` — includes .wal files and any other legacy embedding artifacts

### Claude's Discretion
- Integration test scope and depth (happy path vs edge cases)
- Test infrastructure choices (where tests live, mocking strategy)
- Exact list of legacy files to clean up (investigate what exists in data/)
- Order of operations (test first or cleanup first)

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for the test implementation. The shared store deletion should feel invisible to the user aside from the toast.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 24-integration-testing-cleanup*
*Context gathered: 2026-02-17*
