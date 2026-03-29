# Phase 66: Error Handling - Research

**Researched:** 2026-03-27
**Domain:** R/Shiny error UX — modal-then-notify pattern, shared error utility extraction, preset handler consistency
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Error Display Strategy (ERRH-02)**
- D-01: All preset error handlers must use `show_error_toast()` with `classify_api_error()` — the pattern already established in mod_search_notebook.R. The document notebook currently returns errors as chat content via `sprintf("Error: %s", e$message)` — this must be replaced with the toast pattern for consistency.
- D-02: Error toasts separate error UX from chat content. Users should see errors as system notifications, not as "assistant" messages in the conversation thread.

**Shared Helper Location (ERRH-02)**
- D-03: `show_error_toast()` and `classify_api_error()` must be accessible to both mod_document_notebook.R and mod_search_notebook.R. Move to a shared location (e.g., a utility file in R/) rather than duplicating. The exact file is Claude's discretion.

**Modal Dismissal on Error (ERRH-01)**
- D-04: When a preset error occurs while a synthesis modal is open, dismiss the modal FIRST with `removeModal()`, THEN show the error toast. This is the "modal-then-notify" pattern documented in FEATURES.md Pattern D. It directly resolves the z-index issue — if no modal is open, the toast is never obscured.
- D-05: Do NOT use CSS z-index overrides. The modal-then-notify pattern is the structural fix. CSS hacks (`z-index: 9999 !important`) risk destabilizing the Catppuccin theme's existing z-index layering.

**Button Re-enable on Error**
- D-06: All error handlers must re-enable the generate/submit button after an error. This is already done in search notebook handlers but must be verified for document notebook.

### Claude's Discretion
- Exact file location for shared error utilities (e.g., new `R/error_utils.R` or added to existing `R/config.R` or `R/rag.R`)
- Whether `classify_api_error()` needs any modification when applied to document notebook context (it was written for OpenAlex/OpenRouter — verify it handles all error shapes)
- Whether to add a brief error message as chat content in addition to the toast (e.g., a placeholder like "An error occurred — see notification") or rely solely on the toast

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ERRH-01 | Error toast notifications appear above synthesis modal (not behind it) | Resolved structurally by modal-then-notify: `removeModal()` before `show_error_toast()` eliminates the z-index conflict entirely — no toast fires while a modal backdrop is visible |
| ERRH-02 | Error handling patterns are consistent between document and search notebook presets | Achieved by extracting `show_error_toast()` + `classify_api_error()` to a shared file and replacing all document notebook `sprintf("Error: %s", e$message)` returns with the toast pattern |
</phase_requirements>

---

## Summary

Phase 66 has a narrow, well-defined scope: two bugs in error UX consistency and visibility. The codebase already has a complete, working error handling pattern in `mod_search_notebook.R` — the work is to extract it into a shared location and apply it to the document notebook, which still uses an inferior pattern that silently embeds errors as chat content.

The z-index problem (ERRH-01) is solved as a side effect of ERRH-02: if `removeModal()` always runs before `show_error_toast()`, there is never a modal backdrop obscuring the toast. No CSS changes are needed. The fix is purely about sequencing `removeModal()` before `showNotification()` inside every error handler.

The code inventory is complete and concrete. `mod_document_notebook.R` has exactly 6 error handlers that use the wrong pattern (`sprintf("Error: %s", e$message)` returned as assistant message content). `mod_search_notebook.R` has 4 preset error handlers that correctly use `show_error_toast()` + `classify_api_error()` but do NOT call `removeModal()` before the toast — so they also need the `removeModal()` addition. Both `show_error_toast()` (defined at mod_search_notebook.R:60) and `classify_api_error()` (defined at api_openalex.R:22) need to move to a shared utility file.

**Primary recommendation:** Create `R/utils_notifications.R`, move `show_error_toast()` there, ensure `classify_api_error()` stays in `api_openalex.R` (it is already globally sourced), then update all preset error handlers in both modules to follow the modal-then-notify pattern.

---

## Standard Stack

### Core (Already Present — No New Dependencies)
| Library | Purpose | Notes |
|---------|---------|-------|
| Shiny `showNotification()` | Displays user-facing error toasts | Already used throughout; `type = "error"` or `"warning"` |
| Shiny `removeModal()` | Dismisses the synthesis modal before showing toast | Already called in success paths; must move to error paths too |
| `htmltools::htmlEscape()` | Sanitizes error message strings in HTML toast content | Already used in `show_error_toast()` |

No new packages needed. This phase is pure code reorganization and pattern application.

---

## Architecture Patterns

### Existing File Sourcing Model
`app.R` sources all files under `R/` with `for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f)`. A new `R/utils_notifications.R` file is automatically available to all modules — no manual wiring needed.

### Pattern D: Modal-Then-Notify (Canonical, from FEATURES.md)
```r
# Correct: close modal first, then show toast
tryCatch({
  generate_preset(...)
}, error = function(e) {
  removeModal()   # FIRST: eliminates z-index conflict
  if (inherits(e, "api_error")) {
    show_error_toast(e$message, e$details, e$severity)
  } else {
    err <- classify_api_error(e, "OpenRouter")
    show_error_toast(err$message, err$details, err$severity)
  }
  is_processing(FALSE)
})
```

### Current Document Notebook Pattern (Wrong — Replace)
```r
# Current: error becomes assistant chat content (mod_document_notebook.R:1486-1488)
response <- tryCatch({
  generate_preset(con(), cfg, nb_id, preset_type, session_id = session$token)
}, error = function(e) {
  sprintf("Error: %s", e$message)   # BAD: silently adds error string to chat
})
# Then: messages() and is_processing(FALSE) run unconditionally
# Then: removeModal() runs at end of handler (too late if error)
```

### Current Search Notebook Pattern (Mostly Right — Add removeModal)
```r
# Current: correct toast but modal not dismissed on error
# (mod_search_notebook.R:3509-3516, and matching blocks at 3563, 3615)
response <- tryCatch({
  generate_overview_preset(...)
}, error = function(e) {
  if (inherits(e, "api_error")) {
    show_error_toast(e$message, e$details, e$severity)
  } else {
    err <- classify_api_error(e, "OpenRouter")
    show_error_toast(err$message, err$details, err$severity)
  }
  "Sorry, I encountered an error generating the overview."  # placeholder keeps chat clean
})
# removeModal() and is_processing(FALSE) run outside error handler — OK for success path
# Missing: removeModal() INSIDE error handler before the toast
```

### Recommended Shared Utility Location
Create `R/utils_notifications.R`. This follows the existing `utils_*.R` naming convention in the project:
- `R/utils_filters.R`
- `R/utils_citation.R`
- `R/utils_export.R`
- `R/utils_scoring.R`
- `R/utils_doi.R`

Move `show_error_toast()` from `mod_search_notebook.R:60-80` to this file verbatim. `classify_api_error()` stays in `api_openalex.R` where it already lives — it is general API error classification, not notification-specific.

---

## Exact Scope: All Error Handlers to Fix

### Document Notebook — 6 handlers in mod_document_notebook.R

| Location | Handler | Current Pattern | Fix Required |
|----------|---------|-----------------|--------------|
| Line 1483-1488 | `handle_preset()` shared function | `sprintf("Error: %s", e$message)` → chat content | Replace with modal-then-notify toast; set `is_processing(FALSE)` inside error handler |
| Line 1546-1548 | `btn_overview_generate` | `sprintf("Error: %s", e$message)` → chat content | Same fix; this handler is inline (not via `handle_preset`) |
| Line 1593-1595 | `btn_conclusions` | `sprintf("Error: %s", e$message)` → chat content | Same fix |
| Line 1650-1652 | `btn_lit_review` | `sprintf("Error: %s", e$message)` → chat content | Same fix |
| Line 1712-1714 | `btn_methods` | `sprintf("Error: %s", e$message)` → chat content | Same fix |
| Line 1781-1783 | `btn_gaps` | `sprintf("Error: %s", e$message)` → chat content | Same fix |

Note: `handle_preset()` is a shared function called by `btn_studyguide` and `btn_outline` via `observeEvent(input$btn_studyguide, handle_preset("studyguide", "Study Guide"))`. Fixing `handle_preset()` fixes those two handlers in one change.

### Search Notebook — 4 handlers in mod_search_notebook.R

| Location | Handler | Current Pattern | Fix Required |
|----------|---------|-----------------|--------------|
| Line 3509-3516 | `btn_overview_generate` | Toast but no `removeModal()` in error branch | Add `removeModal()` before toast; add `is_processing(FALSE)` in error branch |
| Line 3560-3569 | `btn_conclusions` | Toast but no `removeModal()` in error branch | Same fix |
| Line 3612-3621 | `btn_research_questions` | Toast but no `removeModal()` in error branch | Same fix |
| Line 3444-3454 | RAG chat handler | Toast but no modal open in this path | Verify: RAG chat does not open a synthesis modal, so no `removeModal()` needed |

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Error message formatting | Custom string formatting | `classify_api_error()` already in `api_openalex.R` | Handles HTTP status codes, timeouts, network errors with appropriate severity levels |
| Toast display with expandable details | Custom `showNotification()` HTML | `show_error_toast()` (extract to `utils_notifications.R`) | Already handles HTML escaping, expandable details, severity-to-type mapping |
| Z-index layering | CSS overrides | `removeModal()` before `showNotification()` | Structural fix; CSS override risks breaking Catppuccin theme layering |

---

## Common Pitfalls

### Pitfall 1: Fixing `handle_preset()` but Missing Inline Handlers
**What goes wrong:** `handle_preset()` covers `btn_studyguide` and `btn_outline`. But `btn_overview_generate`, `btn_conclusions`, `btn_lit_review`, `btn_methods`, and `btn_gaps` each have their own inline handlers with duplicate error patterns. Fixing only `handle_preset()` leaves 5 of 6 handlers broken.
**How to avoid:** Fix all 6 locations in `mod_document_notebook.R`.

### Pitfall 2: Placing `is_processing(FALSE)` Only in the Success Path
**What goes wrong:** If the error handler uses the toast pattern and returns an empty string / exits early, but `is_processing(FALSE)` only runs in the unconditional code after the `tryCatch`, the button stays disabled if the error path `return()`s early.
**Current status:** Document notebook's `handle_preset()` does call `is_processing(FALSE)` unconditionally after the `tryCatch` — so this is currently not broken. But when restructuring the error handler to exit early (no return value propagated as chat content), ensure `is_processing(FALSE)` is called within the error branch.
**How to avoid:** In the error branch: `removeModal()` → `show_error_toast(...)` → `is_processing(FALSE)` → `return()` (explicit early exit).

### Pitfall 3: `removeModal()` in Search Notebook's Success Path Is Already Correct
**What goes wrong:** Search notebook calls `removeModal()` and `is_processing(FALSE)` unconditionally AFTER the `tryCatch`. This is correct for the success path. Adding `removeModal()` + `is_processing(FALSE)` INSIDE the error handler means they run twice on error (once in error branch, once in unconditional code after `tryCatch`).
**How to avoid:** Either: (a) restructure error branch to `return()` early after toast so unconditional code is skipped, or (b) accept the double call (harmless: `removeModal()` is idempotent, `is_processing(FALSE)` is a reactiveVal write). Option (a) is cleaner.

### Pitfall 4: `classify_api_error()` Service Parameter
**What goes wrong:** `classify_api_error(e, service)` includes the service name in the error message (e.g., "OpenRouter authentication failed"). Document notebook calls are all OpenRouter-backed (LLM synthesis). Using `"OpenAlex"` as the service name would produce misleading messages.
**How to avoid:** Use `classify_api_error(e, "OpenRouter")` for all document notebook preset handlers.

### Pitfall 5: `tryCatch` Swallowing `req()` Cancellations
**What goes wrong:** From PITFALLS.md: wrapping `req()` inside `tryCatch` catches Shiny's silent abort condition, turning it into a normal return. The upstream `req(!is_processing())` calls are outside the `tryCatch` in all handlers, so this is not a risk here. But do NOT move the `tryCatch` to wrap the entire handler body.
**How to avoid:** Keep `req()` guards above and outside `tryCatch`. Only the LLM call itself is wrapped.

---

## Code Examples

### Correct Error Handler for Document Notebook (After Fix)
```r
# Source: Pattern D from FEATURES.md + D-04/D-06 from CONTEXT.md
response <- tryCatch({
  generate_preset(con(), cfg, nb_id, preset_type, session_id = session$token)
}, error = function(e) {
  removeModal()
  if (inherits(e, "api_error")) {
    show_error_toast(e$message, e$details, e$severity)
  } else {
    err <- classify_api_error(e, "OpenRouter")
    show_error_toast(err$message, err$details, err$severity)
  }
  is_processing(FALSE)
  return(NULL)  # early exit — no chat content added for errors
})

# Only update messages and UI if response is non-NULL (success path)
if (!is.null(response)) {
  update_synthesis_status("Processing response...")
  msgs <- c(msgs, list(list(role = "assistant", content = response, timestamp = Sys.time())))
  messages(msgs)
  is_processing(FALSE)
  removeModal()
}
```

### Alternative: Return Sentinel and Guard Downstream
```r
# Simpler: error returns NULL, guard the message append
response <- tryCatch({
  generate_preset(...)
}, error = function(e) {
  removeModal()
  err <- if (inherits(e, "api_error")) e else classify_api_error(e, "OpenRouter")
  show_error_toast(err$message, err$details, err$severity)
  is_processing(FALSE)
  NULL
})
if (!is.null(response)) {
  msgs <- c(msgs, list(list(role = "assistant", content = response, timestamp = Sys.time())))
  messages(msgs)
  is_processing(FALSE)
  removeModal()
}
```

### show_error_toast (Extract Verbatim to R/utils_notifications.R)
```r
# Source: mod_search_notebook.R lines 55-80 — extract verbatim
show_error_toast <- function(message, details = NULL, severity = "error", duration = NULL) {
  if (is.null(duration)) {
    duration <- if (severity == "warning") 5 else 8
  }
  content <- if (!is.null(details) && nchar(details) > 0) {
    HTML(paste0(
      '<div>', htmltools::htmlEscape(message), '</div>',
      '<details class="mt-1"><summary class="small text-muted" style="cursor:pointer;">Show details</summary>',
      '<div class="small text-muted mt-1 font-monospace" style="word-break:break-all;">',
      htmltools::htmlEscape(details),
      '</div></details>'
    ))
  } else {
    message
  }
  type <- if (severity == "warning") "warning" else "error"
  showNotification(content, type = type, duration = duration)
}
```

### Search Notebook Fix (Add removeModal + is_processing in error branch)
```r
# Source: Pattern D from FEATURES.md — add removeModal() inside error handler
response <- tryCatch({
  generate_overview_preset(con(), cfg, nb_id, notebook_type = "search",
                           depth = depth, mode = mode, session_id = session$token)
}, error = function(e) {
  removeModal()                          # ADD: dismiss modal before toast
  if (inherits(e, "api_error")) {
    show_error_toast(e$message, e$details, e$severity)
  } else {
    err <- classify_api_error(e, "OpenRouter")
    show_error_toast(err$message, err$details, err$severity)
  }
  is_processing(FALSE)                   # ADD: re-enable button in error path
  NULL                                   # return NULL to skip chat append
})
if (!is.null(response)) {
  update_synthesis_status("Processing response...")
  # ... rest of success path
  is_processing(FALSE)
  removeModal()
}
```

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat (R) |
| Config file | No dedicated config — run via `testthat::test_dir("tests/testthat")` |
| Quick run command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-api-openalex.R')"` |
| Full suite command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Notes |
|--------|----------|-----------|-------|
| ERRH-01 | Error during synthesis closes modal before toast | Manual-only | Shiny reactive interactions cannot be tested with testthat unit tests — requires Shiny session. Verify visually: trigger a preset failure while modal is open, confirm toast appears without backdrop. |
| ERRH-02 | `show_error_toast()` and `classify_api_error()` work from shared location | Unit | Test that `classify_api_error()` still works after `show_error_toast()` moves to `utils_notifications.R`; can add test to `test-api-openalex.R` since `classify_api_error` stays there |
| ERRH-02 | `classify_api_error()` handles all error shapes document notebook will encounter | Unit | Add test cases: plain R error, httr2 HTTP error (401, 429, 500), timeout error |

### Sampling Rate
- **Per task commit:** Run `test-api-openalex.R` to verify `classify_api_error()` still loads and works
- **Per wave merge:** Full test suite + Shiny smoke test
- **Phase gate:** Full suite green + manual visual check of error toast above modal before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/testthat/test-utils-notifications.R` — covers show_error_toast() once extracted to shared file (low priority; function is pure HTML construction, visual check sufficient)

No test framework install needed — testthat already present.

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Document notebook: `sprintf("Error: %s", e$message)` → assistant message | Toast via `show_error_toast()` + `classify_api_error()` | Errors appear as system notifications, not chat content |
| Toast fires while modal backdrop is visible | `removeModal()` before toast | No z-index layering conflict |
| `show_error_toast()` defined in mod_search_notebook.R | Extracted to `R/utils_notifications.R` | Both modules share one implementation |

---

## Open Questions

1. **Whether to add a placeholder chat message on error**
   - What we know: CONTEXT.md marks this as Claude's discretion. Search notebook currently returns a placeholder string (e.g., `"Sorry, I encountered an error..."`) as assistant content even when the toast fires.
   - What's unclear: Is the placeholder useful to the user when they have a toast? Or does it create confusion?
   - Recommendation: Do NOT add a placeholder message in the document notebook. The toast is sufficient. If the search notebook placeholder strings are already there, leave them (they provide chat thread continuity) — but document notebook should not add them as they currently come from the sprintf pattern being replaced.

2. **Whether `classify_api_error()` handles document notebook error shapes**
   - What we know: `classify_api_error()` handles HTTP status codes (httr2 pattern), timeouts, and network errors. Document notebook errors come from `generate_preset()` in `rag.R`, which calls `provider_chat_completion()` in `api_openrouter.R` — also httr2-based.
   - What's unclear: Does `rag.R` / `api_openrouter.R` use `stop_api_error()` to throw structured `api_error` conditions, or does it let raw httr2 errors propagate?
   - Recommendation: The search notebook already handles both `inherits(e, "api_error")` and plain errors via `classify_api_error()`. Use the same two-branch pattern in document notebook — it handles both cases correctly regardless.

---

## Sources

### Primary (HIGH confidence)
- `R/mod_search_notebook.R` lines 60-80 — `show_error_toast()` implementation
- `R/mod_search_notebook.R` lines 3509-3516, 3560-3569, 3612-3621 — reference error handlers
- `R/api_openalex.R` lines 18-85 — `classify_api_error()` implementation
- `R/mod_document_notebook.R` lines 1455-1495, 1543-1559, 1590-1601, 1647-1663, 1709-1725, 1778-1794 — fix targets
- `.planning/research/FEATURES.md` Pattern D — modal-then-notify canonical pattern
- `.planning/research/PITFALLS.md` — global z-index override anti-pattern
- `.planning/phases/66-error-handling/66-CONTEXT.md` — locked decisions

### Secondary (MEDIUM confidence)
- Mastering Shiny ch. 8 (Action Feedback) — notification and modal feedback patterns: https://mastering-shiny.org/action-feedback.html

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, all patterns verified in live codebase
- Architecture: HIGH — exact line numbers confirmed by reading source, patterns match CONTEXT.md decisions
- Pitfalls: HIGH — derived from reading actual code paths, not speculation

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (stable codebase, no fast-moving libraries)
