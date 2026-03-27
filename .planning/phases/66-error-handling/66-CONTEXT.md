# Phase 66: Error Handling - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Standardize error handling across all preset handlers in both document and search notebooks, and fix the toast z-index issue where error notifications render behind open synthesis modals. Two requirements: ERRH-01 (toast z-index behind modal) and ERRH-02 (consistent error handling between notebook types). No new features, no UI additions — purely error UX consistency and visibility.

</domain>

<decisions>
## Implementation Decisions

### Error Display Strategy (ERRH-02)
- **D-01:** All preset error handlers must use `show_error_toast()` with `classify_api_error()` — the pattern already established in mod_search_notebook.R. The document notebook currently returns errors as chat content via `sprintf("Error: %s", e$message)` — this must be replaced with the toast pattern for consistency.
- **D-02:** Error toasts separate error UX from chat content. Users should see errors as system notifications, not as "assistant" messages in the conversation thread.

### Shared Helper Location (ERRH-02)
- **D-03:** `show_error_toast()` and `classify_api_error()` must be accessible to both mod_document_notebook.R and mod_search_notebook.R. Move to a shared location (e.g., a utility file in R/) rather than duplicating. The exact file is Claude's discretion.

### Modal Dismissal on Error (ERRH-01)
- **D-04:** When a preset error occurs while a synthesis modal is open, dismiss the modal FIRST with `removeModal()`, THEN show the error toast. This is the "modal-then-notify" pattern documented in FEATURES.md Pattern D. It directly resolves the z-index issue — if no modal is open, the toast is never obscured.
- **D-05:** Do NOT use CSS z-index overrides. The modal-then-notify pattern is the structural fix. CSS hacks (`z-index: 9999 !important`) risk destabilizing the Catppuccin theme's existing z-index layering.

### Button Re-enable on Error
- **D-06:** All error handlers must re-enable the generate/submit button after an error. This is already done in search notebook handlers but must be verified for document notebook.

### Claude's Discretion
- Exact file location for shared error utilities (e.g., new `R/error_utils.R` or added to existing `R/config.R` or `R/rag.R`)
- Whether `classify_api_error()` needs any modification when applied to document notebook context (it was written for OpenAlex/OpenRouter — verify it handles all error shapes)
- Whether to add a brief error message as chat content in addition to the toast (e.g., a placeholder like "An error occurred — see notification") or rely solely on the toast

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Error handling patterns
- `.planning/research/FEATURES.md` — Pattern D: Modal-Then-Notify error handling pattern (lines 190-204). Also Issue 4 (toast z-index) and Issue 8 (standardize error handling) analysis
- `.planning/research/PITFALLS.md` — Global z-index override anti-pattern explanation

### Target files
- `R/mod_search_notebook.R` — Lines 60-80: existing `show_error_toast()` implementation to extract/share
- `R/mod_search_notebook.R` — Lines 2813-2821, 3446-3454, 3509-3514, 3564-3567, 3616+: search notebook preset error handlers (the reference pattern)
- `R/mod_document_notebook.R` — Lines 1480-1494: document notebook preset handler with inconsistent error handling (the fix target)
- `R/rag.R` — Lines 401-418: `generate_preset()` function that returns error strings — callers must handle these

### Requirements
- `.planning/REQUIREMENTS.md` — ERRH-01 (toast above modal), ERRH-02 (consistent error handling)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `show_error_toast()` (mod_search_notebook.R:60): Rich error toast with expandable details section — ready to extract to shared location
- `classify_api_error()`: Classifies raw errors into structured `{message, details, severity}` objects — used by all search notebook handlers
- Pattern D from FEATURES.md: `removeModal()` → `showNotification()` sequence

### Established Patterns
- Search notebook preset handlers all follow: `tryCatch({ ... }, error = function(e) { if (inherits(e, "api_error")) show_error_toast(e$message, e$details, e$severity) else { err <- classify_api_error(e, service); show_error_toast(err$message, err$details, err$severity) } })`
- Document notebook uses a different pattern: `tryCatch({ generate_preset(...) }, error = function(e) sprintf("Error: %s", e$message))` — error becomes chat content

### Integration Points
- Document notebook's single preset handler at line 1484 is the primary fix target
- `removeModal()` calls already exist throughout both modules — the modal-then-notify pattern adds one before error toast display
- `is_processing()` reactiveVal must be set to FALSE on error in all handlers

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. The research (FEATURES.md) already documents the recommended pattern clearly.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 66-error-handling*
*Context gathered: 2026-03-27*
