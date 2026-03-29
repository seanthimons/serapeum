# Phase 64: Additive Guards - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Add defensive req(), isolate(), and input validation guards to prevent crashes and infinite reactive loops. Pure additive changes — no control flow modifications, no feature additions. Three requirements: GARD-01 (query builder NULL guard), GARD-02 (fig_refresh isolate), GARD-03 (match_aa_model and section_filter validation).

</domain>

<decisions>
## Implementation Decisions

### req() Guard Placement (GARD-01)
- **D-01:** Add `req(provider, model)` after `provider_from_config()` and `resolve_model_for_operation()` calls in mod_query_builder.R (after lines 78-79), before the existing `is.null(provider$api_key)` check. This catches NULL provider itself, not just NULL api_key.
- **D-02:** The existing `is.null(provider$api_key)` check with `showNotification` remains for the case where provider exists but API key is missing — req() only handles the NULL provider/model case silently.

### fig_refresh isolate() Scope (GARD-02)
- **D-03:** Lines 790, 940, 948, 952 in mod_document_notebook.R use `fig_refresh(fig_refresh() + 1)` inside `observeEvent()` bodies — these are safe because observeEvent auto-isolates its handler body. No change needed for these.
- **D-04:** Lines 1033, 1039, 1094 already correctly use `isolate()` — they're inside bare `observe()` blocks. Verify these are the only bare observe() blocks that read fig_refresh.
- **D-05:** Audit all bare `observe()` blocks in mod_document_notebook.R and mod_search_notebook.R for any fig_refresh reads without isolate(). If found, wrap the read in isolate().

### match_aa_model Input Validation (GARD-03)
- **D-06:** Add early return `NULL` at the top of `match_aa_model()` in R/api_artificialanalysis.R when `openrouter_id` is NULL or empty string. This is consistent with the existing contract — the function already returns NULL on no match, and callers already handle NULL.
- **D-07:** The caller in mod_settings.R (line 649) should be reviewed — if `input$quality_model` can be NULL, the req() or null-check should happen at the caller site too.

### section_filter Validation (GARD-03)
- **D-08:** In R/rag.R retrieval functions, add a defensive check: if `section_filter` contains NA values or an empty vector, fall back to unfiltered retrieval. This matches the existing three-level retrieval fallback pattern (section-filtered → unfiltered → direct DB) from v2.1.
- **D-09:** The section_filter parameter is currently hardcoded at the call site (line 546 of R/rag.R), so this is purely defensive against future code changes or edge cases, not user input.

### Claude's Discretion
- Exact placement of additional req() guards in other modules if discovered during implementation
- Whether to add unit tests for the new guard paths (recommended but scope-dependent)
- Logging/message behavior for guard-triggered early returns

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Reactive safety
- `CLAUDE.md` §Shiny Reactive Safety — Documents the observe() + read/write same reactiveVal = infinite loop pattern and the isolate() fix
- `.planning/research/FEATURES.md` — Pattern analysis for all 10 v20.0 issues, including req() placement rules and isolate() scope
- `.planning/research/PITFALLS.md` — Over-isolation trap (isolating the primary trigger kills the observer) and req() mid-body stuck UI risk

### Target files
- `R/mod_query_builder.R` — GARD-01: lines 72-104 (generate button handler)
- `R/mod_document_notebook.R` — GARD-02: lines 790, 940, 948, 952, 1033, 1039, 1094 (fig_refresh usage)
- `R/api_artificialanalysis.R` — GARD-03: lines 163-189 (match_aa_model function)
- `R/rag.R` — GARD-03: line 546 (section_filter usage in retrieval)
- `R/mod_settings.R` — GARD-03: line 649 (match_aa_model caller)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `req()` is already used in mod_query_builder.R (line 74: `req(input$nl_query)`) — established pattern in this module
- `isolate()` is already used correctly in mod_document_notebook.R lines 1033, 1039, 1094 — the correct pattern exists as a template
- `match_aa_model()` already returns NULL on no match — callers already handle this case

### Established Patterns
- **req() at top of observeEvent:** Standard Shiny practice. Silently cancels if condition not met. Used throughout the codebase.
- **isolate() wrapping counter reads:** Documented in CLAUDE.md. Only needed inside bare `observe()` blocks, not `observeEvent()` handlers.
- **Three-level retrieval fallback:** section-filtered → unfiltered → direct DB. Established in v2.1 for robustness.
- **Early return NULL for invalid inputs:** Standard pattern in api_artificialanalysis.R (line 164 already does `if (is.null(aa_df)) return(NULL)`)

### Integration Points
- mod_query_builder.R `generate_btn` handler is the only entry point for GARD-01
- fig_refresh is a local reactiveVal scoped to mod_document_notebook_server — changes are module-contained
- match_aa_model is called from mod_settings.R and api_artificialanalysis.R itself — two call sites
- section_filter is hardcoded in R/rag.R — one location

</code_context>

<specifics>
## Specific Ideas

No specific requirements — all decisions follow existing codebase patterns. The key principle from CLAUDE.md: "Any observe() block that reads a reactiveVal AND writes to it will self-trigger infinitely. Fix: wrap everything except the primary trigger in isolate()."

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 64-additive-guards*
*Context gathered: 2026-03-27*
