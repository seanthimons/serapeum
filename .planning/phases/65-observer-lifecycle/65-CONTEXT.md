# Phase 65: Observer Lifecycle - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Eliminate observer accumulation — each modal open, re-extraction, and task cycle registers exactly one set of observers. Four requirements: LIFE-01 (slide chip handler lifecycle), LIFE-02 (figure action observer lifecycle), LIFE-03 (renderUI list_documents efficiency), LIFE-04 (module cleanup on close). No new features, no UI changes.

</domain>

<decisions>
## Implementation Decisions

### Slide Chip Handler Lifecycle (LIFE-01)
- **D-01:** The current implementation (mod_slides.R lines 1218-1225) pre-allocates 10 `observeEvent` handlers once via `lapply(seq_len(10), ...)` during module server init. The `current_chips()` reactiveVal gates which indices are active. This means handlers are NOT re-created on each modal open — they are registered once and remain. Verify this is actually accumulation-free by confirming `observeEvent` is called only once (in the module server body, not inside another reactive). If SC-1 already passes, document it and move on.
- **D-02:** If verification reveals the chip observers ARE inside a reactive scope (e.g., inside an `observe()` or `renderUI`), apply the destroy-before-recreate pattern from mod_research_refiner.R: store observer references in a reactiveValues list, destroy all before re-creating.

### Figure Action Observer Lifecycle (LIFE-02)
- **D-03:** The destroy loop at mod_document_notebook.R lines 931-938 already destroys old `fig_action_observers` on re-extraction. Verify this runs BEFORE the renderUI at line 990+ re-creates observers for new figure IDs. If the destroy happens in the extraction success handler but new observers are created in the gallery renderUI, ensure the renderUI triggers after the destroy (it should, via `fig_refresh()` increment at line 940).
- **D-04:** Check the `is.null(fig_action_observers[[fig$id]])` guard at line 1023 — if figure IDs are reused across extractions, old observers won't be destroyed because the guard prevents re-creation. The destroy loop at 931-938 should handle this, but verify with a re-extraction scenario.
- **D-05:** Follow the existing destroy-before-recreate pattern from mod_research_refiner.R (lines 308-324) as the canonical reference implementation.

### Document List RenderUI Efficiency (LIFE-03)
- **D-06:** The `output$document_list` renderUI (line 639) calls `list_documents(con(), nb_id)` on every re-execution. During async processing (embedding, extraction), `doc_refresh()` can fire multiple times, causing redundant DB queries. Extract `list_documents()` into a separate `reactive()` expression that the renderUI depends on — Shiny's lazy evaluation ensures it runs once per invalidation cycle.
- **D-07:** Also check `output$index_action_ui` renderUI (line 281) which has its own `list_documents()` call. If both depend on the same reactive, the DB query runs once and both renderUI blocks benefit.

### Module Cleanup on Close (LIFE-04)
- **D-08:** For slides module (mod_slides.R): add cleanup in module server that destroys any stored observers when the modal is dismissed or the module scope ends. Use `session$onSessionEnded()` as the last resort, but prefer scoped cleanup tied to modal close.
- **D-09:** For document notebook (mod_document_notebook.R): destroy `extract_observers` and `fig_action_observers` entries when the notebook is switched or closed. Follow the pattern from mod_citation_network.R line 1598 (`session$onSessionEnded`).
- **D-10:** Console errors from orphaned observers (accessing destroyed inputs/outputs) should be eliminated — absence of these errors is the SC-4 verification criterion.

### Claude's Discretion
- Whether SC-1 already passes and LIFE-01 requires no code changes (just verification)
- Exact reactive() expression granularity for the list_documents caching
- Whether to add defensive `tryCatch` around observer `$destroy()` calls (handles already-destroyed observers)
- Whether to log observer lifecycle events during development (message() calls) — remove before merge

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Reactive safety
- `CLAUDE.md` §Shiny Reactive Safety — Documents the observe() + read/write same reactiveVal = infinite loop pattern and the isolate() fix
- `.planning/research/FEATURES.md` — Pattern analysis for all 10 v20.0 issues, lifecycle patterns
- `.planning/research/PITFALLS.md` — Over-isolation trap, observer accumulation risks

### Target files
- `R/mod_slides.R` — LIFE-01: lines 548-549 (current_chips reactiveVal), 1211-1225 (chip click handlers)
- `R/mod_document_notebook.R` — LIFE-02: lines 205-206 (observer tracking reactiveValues), 931-938 (destroy loop), 1022-1098 (figure action observer registration)
- `R/mod_document_notebook.R` — LIFE-03: lines 281-285 (index_action_ui renderUI + list_documents), 639-644 (document_list renderUI + list_documents)
- `R/mod_document_notebook.R` — LIFE-04: extract_observers and fig_action_observers cleanup
- `R/mod_slides.R` — LIFE-04: chip observer and modal cleanup
- `R/mod_citation_network.R` — line 1598: existing `session$onSessionEnded` cleanup pattern to follow

### Reference implementation
- `R/mod_research_refiner.R` — lines 308-324: canonical destroy-before-recreate pattern using reactiveValues observer storage

### Requirements
- `.planning/REQUIREMENTS.md` — LIFE-01 through LIFE-04 definitions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `fig_action_observers` (reactiveValues) — already tracks per-figure action observers in mod_document_notebook.R
- `extract_observers` (reactiveValues) — already tracks extraction button observers
- `seed_observers` pattern in mod_research_refiner.R — proven destroy-before-recreate cycle
- `session$onSessionEnded` in mod_citation_network.R — existing module cleanup hook

### Established Patterns
- Observer tracking via reactiveValues with `$destroy()` + NULL assignment (mod_research_refiner.R)
- `is.null(observers[[id]])` guard to prevent duplicate registration (mod_document_notebook.R line 741, 1023)
- `fig_refresh()` counter for triggering gallery re-renders after figure changes
- `doc_refresh()` counter for triggering document list re-renders

### Integration Points
- Slide heal modal lifecycle: `showModal()` at line 1214, chip handlers at 1218-1225
- Figure gallery renderUI at line 990 — where figure action observers are registered
- Document list renderUI at line 639 — where list_documents() is called
- Module server return — where cleanup hooks should be registered

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. The mod_research_refiner.R destroy-before-recreate pattern is the established convention to follow.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 65-observer-lifecycle*
*Context gathered: 2026-03-27*
