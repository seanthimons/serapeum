# Phase 22: Module Migration - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Switch document notebook and search notebook modules from legacy/shared RAG to per-notebook ragnar stores for all embedding and retrieval operations. The shared store can be purged — no dual-write period needed. Legacy code removal is Phase 23.

</domain>

<decisions>
## Implementation Decisions

### Migration trigger
- When user opens a notebook with no per-notebook ragnar store, show a prompt/modal asking them to re-index
- New/empty notebooks that have never had content: silently create per-notebook store on first content upload via ensure_ragnar_store() (Phase 21) — no prompt needed
- If user declines re-indexing: disable RAG features (chat, synthesis) for that notebook with greyed-out buttons/tooltip until they re-index
- The existing shared store (`data/serapeum.ragnar.duckdb`) can be safely deleted — no need to preserve legacy data during migration

### Store wiring strategy
- Lazy connection: don't open ragnar store connection until first RAG operation (chat, embed, synthesis) — not on notebook open
- Shared per-notebook accessor: one reactive value per notebook that all modules (document notebook, search notebook) share — no per-module connections
- On store connection failure: trigger Phase 21 corruption recovery flow (rebuild modal)
- Close store connection when user switches to a different notebook — conservative on resources, consistent with on.exit() pattern from Phase 20

### User feedback during migration
- Blocking modal with progress bar during re-indexing — user cannot use notebook until complete
- Per-document detail in progress: "Embedding paper 3 of 12: Smith et al. 2023"
- Allow cancellation mid-way — if cancelled, delete the partial store; user is prompted again next time
- On successful completion: toast notification showing document count (user approved simplification over modal success state transition)

### Search notebook handling
- Search notebooks use the same per-notebook ragnar store as document notebooks — unified approach with section_hint metadata to distinguish content types
- Section-targeted retrieval (intro, methods, results, discussion) filters by section_hint in the ragnar query using origin field — not post-retrieval filtering in R
- Embedding is user-initiated, not automatic on adding papers to search results
- Incremental embedding: each embed cycle appends new chunks to existing store (does not rebuild)
- When a paper is removed from search results, its chunks are immediately deleted from the ragnar store
- Re-index is available as a full rebuild/consistency reset mechanism

### Claude's Discretion
- Exact embed trigger UI (smart "Embed All Unembedded" button vs keeping current UI with backend swap)
- Reactive value implementation pattern for shared per-notebook store accessor
- Exact modal/prompt styling for re-index prompt on notebook open
- How to identify which chunks belong to a removed paper (origin field matching pattern)

</decisions>

<specifics>
## Specific Ideas

- User's concern about multi-step search/embed workflow: the store should handle search → curate → embed → search more → embed more gracefully via incremental appending
- Shared store can be purged immediately — user confirmed no need for dual-write or migration period

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 22-module-migration*
*Context gathered: 2026-02-17*
