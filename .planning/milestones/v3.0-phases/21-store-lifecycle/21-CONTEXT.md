# Phase 21: Store Lifecycle - Context

**Gathered:** 2026-02-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Per-notebook ragnar stores are created automatically on first content, deleted when notebook is deleted, and can be rebuilt on corruption. Covers creation triggers, deletion cascade, rebuild capability, and corruption recovery.

</domain>

<decisions>
## Implementation Decisions

### Store creation
- Lazy creation: store is created on first embedding operation (not on notebook creation or PDF upload)
- Show brief indicator during first-time creation (e.g., "Setting up index...")
- If store creation fails (disk full, permissions), block the embedding action with an error — do not proceed without a store

### Store deletion
- When notebook is deleted, store is cleaned up silently — delete confirmation does not mention the store/index
- Deletion timing is Claude's discretion (sync vs deferred) — optimize for not impacting UI performance
- If store deletion fails (file locked), notebook deletion still proceeds — orphaned store cleaned up later
- No automatic orphan cleanup on startup
- Manual orphan cleanup button in app settings panel

### Corruption detection and rebuild
- Proactive integrity check when notebook is opened — warn if store is corrupted
- Also detect corruption reactively when search/RAG operations fail
- "Rebuild index" action appears only in error context (not always-visible in menus)
- Notebook remains fully usable during rebuild — search/RAG disabled, everything else works normally
- Rebuild shows progress bar with document count (e.g., "Re-embedding 12/45 documents...")

### Error communication
- Transient store errors (single query fails): toast notification
- Persistent store errors (corruption, missing files): modal warning with rebuild option
- Never block content ingestion (PDF upload, abstract embedding) due to store errors — save to DB regardless, notify user that search is unavailable and show how to fix
- Orphan cleanup control lives in app settings

### Claude's Discretion
- Sync vs deferred deletion timing (optimize for performance)
- Integrity check implementation details (what constitutes "corruption")
- Toast/modal styling consistent with existing app patterns
- Progress bar implementation for rebuild

</decisions>

<specifics>
## Specific Ideas

- Store creation indicator should be subtle and brief — not a modal or blocking UI
- Orphan cleanup in settings is a simple button, not a dedicated maintenance section
- Error → rebuild flow: user sees modal with explanation + "Rebuild" button, clicks it, modal closes, progress bar appears, notebook remains usable

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 21-store-lifecycle*
*Context gathered: 2026-02-16*
