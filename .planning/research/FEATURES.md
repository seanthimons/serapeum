# Feature Research: Shiny Reactivity Cleanup

**Domain:** R/Shiny reactive lifecycle management — observer leaks, isolate() guards, req() guards, error handling, lifecycle cleanup
**Researched:** 2026-03-26
**Confidence:** HIGH (patterns verified against official Shiny docs, Mastering Shiny, Appsilon engineering blog)

---

## Feature Landscape

This milestone is a correctness fix milestone, not a features milestone. The 10 issues map to three distinct fix categories: (1) observer lifecycle correctness, (2) reactive dependency correctness, and (3) defensive input validation. The "features" here are the fix patterns themselves — each has expected behavior, implementation complexity, and dependencies on other fixes.

---

### Table Stakes (These Fixes Are Non-Negotiable)

Fixes that prevent silent data corruption, infinite loops, or crashes. Users may not see them, but the app silently degrades or crashes without them.

| Fix | Why Expected | Complexity | Notes |
|-----|--------------|------------|-------|
| Observer accumulation in slide chip handlers (Issue 1) | `lapply(seq_len(10), function(i) { observeEvent(...) })` re-runs on every heal modal open, stacking 10 new observers each time. After N opens, N*10 observers fire on one chip click. | MEDIUM | Must store observer refs and `$destroy()` before re-registering. The chip count is fixed at 10, so a fixed-length storage list works. Shiny Observer `$destroy()` is the correct API — confirmed by Mastering Shiny ch. 15 and Appsilon module teardown guide. |
| Missing `isolate()` on `fig_refresh` counter reads (Issue 2) | `fig_refresh(fig_refresh() + 1)` inside `observe()` creates a self-triggering loop: read establishes dependency, write fires invalidation, observer re-runs. The existing reindex task handler already has this pattern documented with a NOTE comment — fig_refresh writes in `observeEvent()` blocks are safe, but any raw `observe()` that reads AND writes `fig_refresh()` needs `isolate()`. | LOW | Only two call sites in raw `observe()` contexts need auditing. `observeEvent()` wraps its body in `isolate()` automatically, so most fig_refresh writes are already safe. The pattern is `fig_refresh(isolate(fig_refresh()) + 1)`. |
| Missing `req()` guard for NULL provider/model in query builder (Issue 3) | `resolve_model_for_operation(cfg, "query_build")` may return NULL if config has no model set. Passing NULL to `provider_chat_completion()` causes a cryptic error rather than a clean user message. | LOW | `req(model, provider$api_key)` before entering the LLM call is the correct guard. Already applied in some presets — query builder is the gap. `req()` silences the observer cleanly without session termination (confirmed: req() emits a special cancellation condition, not a real error). |
| Error toast z-index behind synthesis modal (Issue 4) | `showNotification()` renders at Bootstrap's toast z-index (~1050). `modalDialog()` renders at ~1055. When `showNotification()` fires inside a synthesize preset handler while the modal is open, the toast renders *under* the modal backdrop. User sees nothing. This is a known Bootstrap/Shiny z-index layering issue. | LOW-MEDIUM | Fix options: (a) use `showModal()` for errors during synthesis instead of `showNotification()` — consistent with "errors during modal operation should use modal UI", or (b) inject CSS `#shiny-notification-panel { z-index: 1100 !important; }`. Option (a) is cleaner; option (b) is a one-liner. Option (b) risks unintended stacking in other contexts. |
| SQL migration on fresh installs (Issue 10) | `apply_migration()` calls `get_applied_migrations()` which creates `schema_migrations` if missing. BUT if a fresh install has no DB at all, the call order matters. If any migration SQL references a table that hasn't been created yet, and a prior migration is somehow skipped, the app crashes on startup. DuckDB `CREATE TABLE IF NOT EXISTS` in every migration is the correct defensive pattern. | MEDIUM | Need to audit all 9 migrations for idempotency. Each migration SQL should be runnable on a blank DB without assuming prior state except what earlier migrations establish. The existing `apply_migration()` infrastructure handles this correctly IF migration SQL itself is defensive. |

---

### Differentiators (Good Hygiene, High Quality Signal)

Fixes that reduce technical debt and improve maintainability. Not crash-level bugs, but systematic quality improvements.

| Fix | Value Proposition | Complexity | Notes |
|-----|-------------------|------------|-------|
| `renderUI` re-query reduction during processing (Issue 5) | `output$index_action_ui` calls `list_documents(con(), nb_id)` directly in `renderUI`. When `doc_refresh` invalidates frequently during async operations (every 1s poller tick), this fires repeatedly. Correct pattern: cache result in a `reactive({ list_documents(...) })` so multiple `renderUI` blocks share one DB query per invalidation cycle. | MEDIUM | Extract `docs_reactive <- reactive({ req(nb_id()); list_documents(con(), notebook_id()) })` and reference it in both `output$document_list` and `output$index_action_ui`. This is the standard "factor expensive operations into shared reactive expressions" pattern from Engineering Production-Grade Shiny Apps. |
| Figure action observer destruction on re-extraction (Issue 6) | `fig_action_observers` tracks per-figure observers (keep/ban/retry). When figures are re-extracted for a document, the old observers accumulate if not explicitly destroyed. The `reactiveValues()` store is cleared with `fig_action_observers[[old_id]] <- NULL` but does NOT call `$destroy()` first. Setting to NULL drops the R reference but does NOT destroy the Shiny observer — it keeps running until session end. | MEDIUM | Before `fig_action_observers[[f_id]] <- list(obs_keep, obs_ban, obs_retry)`, iterate existing observers and call `$destroy()` on each. The pattern: `if (!is.null(fig_action_observers[[f_id]])) { lapply(fig_action_observers[[f_id]], function(o) o$destroy()) }`. |
| Observer lifecycle cleanup in slides/notebook (Issue 7) | Heal modal opens create chip observers via `lapply(seq_len(10), ...)`. The slides module has no teardown on modal close. Notebook module's `reindex_poller` observer is correctly stored and destroyed, setting the correct pattern to follow. The gap is chip handlers in the heal modal path. | MEDIUM | Pattern: store chip observer list, call `$destroy()` on each before re-registering. Consider using `onStop()` session hook for module-level cleanup as a belt-and-suspenders approach. |
| Standardized error handling across presets (Issue 8) | `generate_preset()` in `rag.R` wraps `provider_chat_completion()` in `tryCatch`. Some preset handlers in `mod_document_notebook.R` and `mod_search_notebook.R` catch the error and show a notification; others let it propagate silently. Inconsistency means some preset failures are invisible to users. | MEDIUM | Define a single `handle_preset_error(e, session)` helper that: (1) logs the error with `message()`, (2) shows a user-visible notification with the error message (outside any open modal — close modal first or use an in-modal error panel), (3) re-enables the generate button. Apply uniformly across all 7 preset handlers. |
| Input validation for `match_aa_model()` and `section_filter` (Issue 9) | `match_aa_model(openrouter_id, aa_df)` receives `openrouter_id` from `input$quality_model`. If the input is NULL before the selectInput populates (race condition on startup), `match_aa_model()` passes a NULL ID into string operations, causing a warning or wrong result. `section_filter` in `search_chunks_hybrid()` accepts arbitrary character vectors — no validation that values are in the known set of section hints. | LOW | For `match_aa_model()`: add `req(openrouter_id)` or NULL guard at top. For `section_filter`: add a `stopifnot(all(section_filter %in% VALID_SECTION_HINTS))` or silently filter to valid values. The NULL guard is the critical fix; the section_filter validation is belt-and-suspenders. |

---

### Anti-Features (Do Not Implement These)

Patterns that seem like fixes but introduce new problems.

| Anti-Feature | Why Requested | Why Problematic | Alternative |
|--------------|---------------|-----------------|-------------|
| Blanket `isolate()` around all observer bodies | Prevents all reactive loops universally | Breaks legitimate reactive dependencies — if an observer should respond to a value change, wrapping its read in `isolate()` silently breaks that reactivity. Debugging becomes very hard. | Apply `isolate()` only to reads of values the observer also *writes to*, or reads that should not trigger re-execution. Use `observeEvent()` instead of `observe()` when the trigger is clear. |
| `onStop(session, ...)` for all observer cleanup | Belt-and-suspenders approach | Session-level cleanup happens anyway — Shiny destroys all session observers on disconnect. Using `onStop` for observers that should be destroyed *mid-session* (e.g., on modal close) does not solve the mid-session accumulation problem. | Use explicit `$destroy()` at the specific lifecycle event (modal close, re-extraction trigger). |
| Converting all `observe()` to `observeEvent()` globally | Eliminates `observe()` footgun | Breaks existing correct `observe()` calls that legitimately depend on multiple reactive values. The conversion is non-trivial for multi-dependency observers. | Audit specifically for `observe()` blocks that both read AND write the same reactive. Only convert or add `isolate()` to those. |
| Global z-index override for all notifications | Fixes toast-behind-modal quickly | `z-index: 9999` on the notification panel creates a new problem: notifications then appear over popovers, tooltips, and other intentionally top-layer UI. Serapeum's Catppuccin CSS already has z-index layering; an !important override can destabilize it. | Fix the specific modal/notification conflict: close the synthesis modal before showing the error notification (modal-then-notify pattern), or use an in-modal error UI element. |
| Caching `list_documents()` globally in app.R | Prevents duplicate DB calls in renderUI | A global reactive would be shared across modules, coupling their invalidation cycles. Module isolation is a core Serapeum architectural principle (per-notebook isolation). | Cache per-module: each module gets its own `reactive({ list_documents(con(), notebook_id()) })` expression. |

---

## Feature Dependencies

```
Issue 1 (chip observer accumulation)
    └──same pattern as──> Issue 6 (figure action observer accumulation)
    └──same pattern as──> Issue 7 (slides/notebook lifecycle cleanup)

Issue 2 (isolate fig_refresh)
    └──precondition for──> Issue 5 (renderUI re-query reduction)
        [Both involve the same reactive invalidation cycle from doc_refresh/fig_refresh]

Issue 3 (req() for provider/model)
    └──same pattern as──> Issue 9 (match_aa_model input validation)

Issue 4 (toast z-index)
    └──depends on design choice from──> Issue 8 (error handling standardization)
        [If Issue 8 adopts modal-then-notify pattern, Issue 4 may be resolved as a side effect]

Issue 10 (SQL migration fresh install)
    └──independent──> All other issues
```

### Dependency Notes

- **Issues 1, 6, 7 share one root cause:** `observeEvent()` inside `lapply()` re-registers observers on every call without destroying old ones. Fix the pattern once, apply to all three sites.
- **Issue 8 informs Issue 4:** If error handling is standardized to "close modal, then show notification", the toast z-index problem never occurs. If notifications are shown while modals are open, CSS z-index fix is required.
- **Issue 10 is fully independent:** SQL migration hygiene does not interact with reactive patterns.

---

## MVP Definition (This Milestone)

This is a cleanup milestone — all 10 issues should be resolved. Priority ordering is by crash/data-corruption risk, then by user-visible impact.

### Launch With (P1 — Fixes That Prevent Crashes or Silent Failures)

- [x] Issue 1: Observer accumulation in slide chip handlers — silent performance degradation, grows unbounded
- [x] Issue 2: Missing `isolate()` on fig_refresh counter reads — potential infinite reactive loop
- [x] Issue 3: Missing `req()` for NULL provider/model — cryptic crash on misconfigured app
- [x] Issue 4: Error toast behind synthesis modal — errors silently invisible to user
- [x] Issue 10: SQL migration on fresh installs — app crashes on first install if migration SQL is not idempotent

### Add After P1 Validated (P2 — Quality and Consistency Improvements)

- [x] Issue 5: renderUI re-query reduction — performance, not correctness
- [x] Issue 6: Figure action observer destruction on re-extraction — accumulates slowly, not immediate crash
- [x] Issue 7: Observer lifecycle cleanup in slides/notebook — same as Issue 6 risk level
- [x] Issue 8: Standardize error handling across presets — consistency, not new functionality
- [x] Issue 9: Input validation for `match_aa_model()` and `section_filter` — defensive hardening

---

## Feature Prioritization Matrix

| Fix | User Value | Implementation Cost | Priority |
|-----|------------|---------------------|----------|
| Issue 1: Chip observer accumulation | HIGH (app degrades with use) | MEDIUM | P1 |
| Issue 2: fig_refresh isolate() | HIGH (infinite loop risk) | LOW | P1 |
| Issue 3: req() for NULL provider/model | HIGH (cryptic crash) | LOW | P1 |
| Issue 4: Toast z-index | HIGH (errors invisible) | LOW-MEDIUM | P1 |
| Issue 10: SQL migration | HIGH (fresh install crash) | MEDIUM | P1 |
| Issue 5: renderUI re-query | MEDIUM (performance) | MEDIUM | P2 |
| Issue 6: Figure observer destruction | MEDIUM (accumulates slowly) | MEDIUM | P2 |
| Issue 7: Slides/notebook lifecycle | MEDIUM (same as Issue 6) | MEDIUM | P2 |
| Issue 8: Standardize error handling | MEDIUM (consistency) | MEDIUM | P2 |
| Issue 9: match_aa_model validation | LOW-MEDIUM (race condition) | LOW | P2 |

**Priority key:**
- P1: Fix before anything else — safety and correctness
- P2: Fix in same milestone, can follow P1 in sequenced phases

---

## Fix Pattern Reference

These are the canonical patterns to apply. Each issue maps to one or more patterns.

### Pattern A: Observer Accumulation Fix
```r
# Before (leaks — re-registers on every modal open):
lapply(seq_len(10), function(i) {
  observeEvent(input[[paste0("chip_", i)]], { ... }, ignoreInit = TRUE)
})

# After (correct — destroy before re-registering):
# Store at module level:
chip_observers <- list()

# On modal open, before registering:
if (length(chip_observers) > 0) {
  lapply(chip_observers, function(o) o$destroy())
  chip_observers <- list()
}
chip_observers <- lapply(seq_len(10), function(i) {
  observeEvent(input[[paste0("chip_", i)]], { ... }, ignoreInit = TRUE)
})
```

### Pattern B: isolate() on Counter Reads
```r
# Before (infinite loop risk — reads AND writes fig_refresh in observe()):
observe({
  fig_refresh(fig_refresh() + 1)   # BAD: read creates dependency, write fires it
})

# After (correct — isolate the read):
observe({
  fig_refresh(isolate(fig_refresh()) + 1)
})

# Or better — use observeEvent() with explicit trigger:
observeEvent(trigger_val(), {
  fig_refresh(fig_refresh() + 1)   # Safe: observeEvent body is auto-isolated
})
```

### Pattern C: req() Guards
```r
# Before (cryptic NULL error):
observeEvent(input$generate_btn, {
  model <- resolve_model_for_operation(cfg, "query_build")
  provider_chat_completion(provider, model, messages)  # NULL model -> error
})

# After (clean early exit):
observeEvent(input$generate_btn, {
  req(input$nl_query)
  model <- resolve_model_for_operation(cfg, "query_build")
  req(model)  # Silently cancels observer if model is NULL
  provider_chat_completion(provider, model, messages)
})
```

### Pattern D: Modal-Then-Notify Error Handling
```r
# Before (toast hidden behind open modal):
tryCatch(
  generate_preset(...),
  error = function(e) showNotification(e$message, type = "error")
)

# After (close modal first, then notify):
tryCatch(
  generate_preset(...),
  error = function(e) {
    removeModal()  # Close synthesis modal
    showNotification(e$message, type = "error", duration = NULL)
  }
)
```

### Pattern E: Shared Reactive for DB Queries
```r
# Before (each renderUI calls list_documents() independently):
output$document_list <- renderUI({
  doc_refresh()
  docs <- list_documents(con(), notebook_id())
  ...
})
output$index_action_ui <- renderUI({
  doc_refresh()
  docs <- list_documents(con(), notebook_id())
  ...
})

# After (one reactive, shared by both):
docs_reactive <- reactive({
  doc_refresh()
  req(notebook_id())
  list_documents(con(), notebook_id())
})

output$document_list <- renderUI({
  docs <- docs_reactive()
  ...
})
output$index_action_ui <- renderUI({
  docs <- docs_reactive()
  ...
})
```

---

## Sources

- [Mastering Shiny — Reactive Building Blocks (ch. 15)](https://mastering-shiny.org/reactivity-objects.html) — Observer lifecycle, destroy(), isolate() canonical patterns
- [Shiny Official Docs — isolate()](https://shiny.posit.co/r/articles/build/isolation/) — isolate() usage patterns and pitfalls
- [Appsilon — How to Safely Remove a Dynamic Shiny Module](https://www.appsilon.com/post/how-to-safely-remove-a-dynamic-shiny-module) — $destroy() as correct API for observer cleanup; session$userData storage pattern
- [Shiny Official Reference — observeEvent](https://shiny.posit.co/r/reference/shiny/latest/observeevent.html) — observeEvent body is implicitly isolated
- [Engineering Production-Grade Shiny Apps — Common Caveats (ch. 15)](https://engineering-shiny.org/common-app-caveats.html) — Expensive renderUI anti-pattern; shared reactive expression solution
- [Mastering Shiny — Action Feedback (ch. 8)](https://mastering-shiny.org/action-feedback.html) — Notification and modal feedback patterns
- Serapeum source code — `R/mod_document_notebook.R`, `R/mod_slides.R`, `R/mod_query_builder.R`, `R/db_migrations.R`, `R/rag.R` — Existing pattern evidence and gap locations

---
*Feature research for: Shiny Reactivity Cleanup (v20.0 milestone)*
*Researched: 2026-03-26*
