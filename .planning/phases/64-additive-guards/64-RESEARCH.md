# Phase 64: Additive Guards - Research

**Researched:** 2026-03-27
**Domain:** R/Shiny reactive guard patterns — req(), isolate(), and input validation
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Add `req(provider, model)` after `provider_from_config()` and `resolve_model_for_operation()` calls in mod_query_builder.R (after lines 78-79), before the existing `is.null(provider$api_key)` check. This catches NULL provider itself, not just NULL api_key.
- **D-02:** The existing `is.null(provider$api_key)` check with `showNotification` remains for the case where provider exists but API key is missing — req() only handles the NULL provider/model case silently.
- **D-03:** Lines 790, 940, 948, 952 in mod_document_notebook.R use `fig_refresh(fig_refresh() + 1)` inside `observeEvent()` bodies — these are safe because observeEvent auto-isolates its handler body. No change needed for these.
- **D-04:** Lines 1033, 1039, 1094 already correctly use `isolate()` — they're inside bare `observe()` blocks. Verify these are the only bare observe() blocks that read fig_refresh.
- **D-05:** Audit all bare `observe()` blocks in mod_document_notebook.R and mod_search_notebook.R for any fig_refresh reads without isolate(). If found, wrap the read in isolate().
- **D-06:** Add early return `NULL` at the top of `match_aa_model()` in R/api_artificialanalysis.R when `openrouter_id` is NULL or empty string. This is consistent with the existing contract — the function already returns NULL on no match, and callers already handle NULL.
- **D-07:** The caller in mod_settings.R (line 649) should be reviewed — if `input$quality_model` can be NULL, the req() or null-check should happen at the caller site too.
- **D-08:** In R/rag.R retrieval functions, add a defensive check: if `section_filter` contains NA values or an empty vector, fall back to unfiltered retrieval. This matches the existing three-level retrieval fallback pattern (section-filtered → unfiltered → direct DB) from v2.1.
- **D-09:** The section_filter parameter is currently hardcoded at the call site (line 546 of R/rag.R), so this is purely defensive against future code changes or edge cases, not user input.

### Claude's Discretion
- Exact placement of additional req() guards in other modules if discovered during implementation
- Whether to add unit tests for the new guard paths (recommended but scope-dependent)
- Logging/message behavior for guard-triggered early returns

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| GARD-01 | App does not crash when provider or model is NULL in query builder (req() guard) | Code inspection confirms `resolve_model_for_operation()` can return NULL; `req()` is the documented Shiny pattern for silent cancellation before side effects. Pattern C in FEATURES.md is the exact template. |
| GARD-02 | fig_refresh counter reads inside observe() blocks use isolate() to prevent infinite loops | Lines 1033, 1039, 1094 in mod_document_notebook.R already use `isolate(fig_refresh())` correctly — they are the template. Lines 790, 940, 948, 952 are in observeEvent() bodies which auto-isolate. Audit confirms the correct pattern is established; D-05 requires confirming no additional bare observe() blocks exist. |
| GARD-03 | match_aa_model() and section_filter have input validation with safe fallback values | match_aa_model() already returns NULL for NULL aa_df (line 164); NULL openrouter_id goes to `openrouter_id %in% names(mapping)` which will not crash but produces wrong results. section_filter in db.R has tryCatch but no guard against NA values in the filter vector itself. |
</phase_requirements>

---

## Summary

Phase 64 adds three categories of defensive guards to the Serapeum codebase: (1) a `req()` guard in the query builder generate button handler to catch NULL provider or model before any side effects run, (2) an audit and verification of `isolate()` placement around `fig_refresh()` counter reads inside bare `observe()` blocks to prevent self-triggering reactive loops, and (3) input validation for `match_aa_model()` (NULL/empty openrouter_id early return) and `section_filter` (NA-safe validation before filtering).

All three changes are additive — they add guard conditions at the entry of functions or observer bodies without modifying any existing control flow, UI, or feature behavior. No new dependencies are introduced. The patterns are already established in the codebase and require only targeted, small additions.

The existing code is in a mostly-correct state: the isolate() fixes for fig_refresh in bare observe() blocks at lines 1033, 1039, 1094 are already done and serve as templates. The req() pattern is already used in the same module at line 74. The match_aa_model() NULL-aa_df guard is already present at line 164. This phase closes the remaining gaps.

**Primary recommendation:** Apply each guard in isolation, verify the app starts cleanly after each change (smoke test), and confirm observeEvent vs observe() distinction before adding any isolate() call.

---

## Standard Stack

### Core (all already in use — no new installs)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | installed | `req()`, `observe()`, `observeEvent()`, `isolate()` | Project foundation |
| base R | — | `is.null()`, `nchar()`, early return guards | No dependency needed |

No new packages required for this phase.

---

## Architecture Patterns

### Pattern 1: req() Guard Before Side Effects (GARD-01)

**What:** `req()` silently cancels an observer when its argument is NULL, FALSE, or empty. It emits a special cancellation condition — not an error — so nothing downstream executes, no UI gets stuck, and no error is logged.

**When to use:** At the TOP of an observer body, before `withProgress()`, `showModal()`, reactiveVal mutations, or any IO. Never mid-block.

**Critical constraint from PITFALLS.md (Pitfall 4):** If `req()` is placed after `withProgress()` has already been called, the progress overlay will appear but never be removed because `req()` aborts before the code that removes it. The existing query builder already has `withProgress()` starting at line 90. The new `req(provider, model)` must appear at lines 80-81, BEFORE line 90.

**Template (Pattern C from FEATURES.md):**
```r
observeEvent(input$generate_btn, {
  req(input$nl_query)                     # already present — line 74
  cfg <- config()
  provider <- provider_from_config(cfg, con())
  model <- resolve_model_for_operation(cfg, "query_build")
  req(provider, model)                    # NEW: guard before withProgress()
  if ((is.null(provider$api_key) || nchar(provider$api_key) == 0) && !is_local_provider(provider)) {
    # existing notification for missing api_key on non-local provider
    showNotification(...)
    return()
  }
  withProgress(message = "Generating query...", {  # side effects only after guards
    ...
  })
})
```

### Pattern 2: isolate() on Counter Reads in bare observe() (GARD-02)

**What:** When a bare `observe()` block both reads AND writes a `reactiveVal`, the read creates a reactive dependency. The write fires an invalidation. The observer re-runs. Infinite loop.

**Key distinction — observeEvent() is safe:** `observeEvent(trigger, { ... })` implicitly wraps its handler body in `isolate()`. Any `fig_refresh(fig_refresh() + 1)` inside an `observeEvent()` body is safe. The four sites at lines 790, 940, 948, 952 are all inside `observeEvent()` — no change needed.

**Correct pattern (already applied at lines 1033, 1039, 1094):**
```r
# Inside bare observe() — isolate the READ, not the write:
obs_keep <- observeEvent(input[[paste0("keep_", f_id)]], {
  db_update_figure(con(), f_id, is_excluded = FALSE)
  fig_refresh(isolate(fig_refresh()) + 1)   # isolate() wraps the read
}, ignoreInit = TRUE)
```

Note: `observeEvent()` with an explicit trigger is itself safe (auto-isolated body) so these lines are already correct. The pattern is only unsafe in bare `observe({...})` blocks with no explicit trigger argument.

**Audit scope (D-05):** Search `mod_document_notebook.R` and `mod_search_notebook.R` for the pattern `observe\(\{` (bare observe) followed by `fig_refresh(fig_refresh()`. If found, wrap the inner read: `fig_refresh(isolate(fig_refresh()) + 1)`.

### Pattern 3: Early Return NULL for Invalid Inputs (GARD-03 — match_aa_model)

**What:** `match_aa_model()` at line 163 already handles `NULL aa_df` at line 164. The missing guard is for `NULL` or `""` openrouter_id. If openrouter_id is NULL, the expression `openrouter_id %in% names(mapping)` evaluates to `logical(0)` — the if() then operates on an empty logical, which causes a zero-length warning and effectively falls through, but `normalize_model_id(NULL)` at line 178 will error.

**Template (consistent with existing early-return at line 164):**
```r
match_aa_model <- function(openrouter_id, aa_df, mapping = NULL, base_path = NULL) {
  if (is.null(openrouter_id) || !nzchar(openrouter_id)) return(NULL)  # NEW guard
  if (is.null(aa_df) || nrow(aa_df) == 0) return(NULL)                # existing
  ...
}
```

**Caller review (D-07):** mod_settings.R line 648-649:
```r
aa_row <- if (!is.null(aa) && nrow(aa) > 0) {
  match_aa_model(input$quality_model, aa)
} else { NULL }
```
The outer guard checks aa data is present but does NOT check if `input$quality_model` is NULL. The function-level guard (above) handles this safely now. Caller-level `req(input$quality_model)` would be stronger but may be at discretion.

### Pattern 4: NA-Safe section_filter Validation (GARD-03 — section_filter)

**What:** `search_chunks_hybrid()` in db.R guards `if (!is.null(section_filter))` at line 1113 but does not guard against NA values in the vector or a zero-length vector. `results$section_hint %in% section_filter` where `section_filter` contains NA produces unexpected behavior (NA values match NA values, non-NA never match NA).

**Current code (db.R line 1113):**
```r
if (!is.null(section_filter) && nrow(results) > 0) {
  # ... filter logic
}
```

**Defensive addition:**
```r
# Normalize section_filter: drop NA and empty strings
if (!is.null(section_filter)) {
  section_filter <- section_filter[!is.na(section_filter) & nzchar(section_filter)]
}
if (!is.null(section_filter) && length(section_filter) > 0 && nrow(results) > 0) {
  # ... existing filter logic unchanged
}
```

This ensures an all-NA filter falls back to unfiltered (the existing fallback chain in rag.R already handles empty results by retrying without section_filter).

### Anti-Patterns to Avoid

- **isolate() on the primary trigger:** If `observe()` uses a reactive as the sole reason to fire, wrapping that read in `isolate()` kills the observer permanently. Only isolate reads of values the observer ALSO writes.
- **req() after withProgress():** req() aborts silently. A progress overlay started before req() will never be closed. All req() calls must precede all side-effect calls.
- **Converting observeEvent to observe to add isolate():** The observeEvent body is already isolated. Converting it introduces needless risk.
- **Blanket isolate({}) wrapping entire observer body:** Breaks all reactive dependencies; the observer never re-fires. Always isolate selectively.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Silent observer cancellation on NULL | Custom `if (is.null(x)) return()` blocks | `req(x)` | req() is the documented Shiny cancellation mechanism; return() keeps the observer execution context open for further reactive deps |
| Preventing reactive read/write loops | Custom debounce timers or flag variables | `isolate()` around the counter read | isolate() is zero-overhead and directly supported; flags add state that can go out of sync |

**Key insight:** These are two-line fixes using built-in Shiny primitives. No utility functions, no helper abstractions, no new files.

---

## Common Pitfalls

### Pitfall 1: req() After withProgress() Leaves Modal Stuck
**What goes wrong:** The progress overlay is shown, req() fires, app aborts silently, progress overlay is never removed.
**Why it happens:** req() raises a special condition that exits the current observer evaluation immediately. Any cleanup code after req() does not run.
**How to avoid:** All req() guards must appear before any `withProgress()`, `showModal()`, `showNotification()`, or reactiveVal write.
**Warning signs:** Progress spinner visible in UI after clicking generate on a misconfigured app.

### Pitfall 2: isolate() on the Wrong Read
**What goes wrong:** Observer fires on startup only, never re-fires when the intended trigger changes.
**Why it happens:** The reactive read that should trigger re-execution was wrapped in isolate().
**How to avoid:** For bare `observe()` blocks: identify the single reactive that should trigger re-execution. That read must NOT be isolated. Only isolate reads that the block also writes.
**Warning signs:** Observer confirmed to have fired once (via message probe), never again after input changes.

### Pitfall 3: NULL vs zero-length logical from %in% with NULL
**What goes wrong:** `NULL %in% names(mapping)` returns `logical(0)`, not `FALSE`. An `if (logical(0))` in R triggers a warning "argument is of length zero" and evaluates as FALSE, but subsequent string operations on NULL will error.
**Why it happens:** R's %in% returns a zero-length vector when the left-hand side is NULL, not FALSE.
**How to avoid:** Guard NULL before any `%in%` test. `is.null(x) || !nzchar(x)` as the first check in match_aa_model().
**Warning signs:** Warning "argument is of length zero" in Shiny log; subsequent tryCatch catches an error from normalize_model_id().

### Pitfall 4: section_filter with NA Values Matches Wrong Rows
**What goes wrong:** `"general" %in% c(NA, "conclusion")` returns FALSE (correct), but `NA %in% c(NA, "conclusion")` returns TRUE. If section_hint has NA values and section_filter also has NA, those rows pass the filter incorrectly.
**Why it happens:** R's `%in%` operator matches NA to NA. A defensive filter must strip NAs from the filter vector.
**How to avoid:** `section_filter[!is.na(section_filter) & nzchar(section_filter)]` before the filter expression. If the result is length 0, treat as NULL (no filter applied).

---

## Code Examples

### GARD-01: req() guard in mod_query_builder.R (verified from source)

Current code (lines 73-90):
```r
# Source: R/mod_query_builder.R lines 73-90 (verified 2026-03-27)
observeEvent(input$generate_btn, {
  req(input$nl_query)

  cfg <- config()
  provider <- provider_from_config(cfg, con())
  model <- resolve_model_for_operation(cfg, "query_build")

  if ((is.null(provider$api_key) || nchar(provider$api_key) == 0) && !is_local_provider(provider)) {
    showNotification("OpenRouter API key not configured. Please go to Settings.",
                     type = "warning", duration = 5)
    return()
  }

  withProgress(message = "Generating query...", {
    ...
  })
})
```

Required change — insert after line 79, before line 81:
```r
req(provider, model)   # catches NULL provider or NULL model before side effects
```

### GARD-02: Correct isolate() pattern already in place (lines 1033, 1039, 1094)

```r
# Source: R/mod_document_notebook.R lines 1031-1034 (verified 2026-03-27)
obs_keep <- observeEvent(input[[paste0("keep_", f_id)]], {
  db_update_figure(con(), f_id, is_excluded = FALSE)
  fig_refresh(isolate(fig_refresh()) + 1)
}, ignoreInit = TRUE)
```

These are inside observeEvent() bodies. observeEvent() auto-isolates its body, so the isolate() here is belt-and-suspenders. They are safe regardless. This is the template.

### GARD-03: match_aa_model NULL guard

Current function signature (api_artificialanalysis.R line 163-164):
```r
# Source: R/api_artificialanalysis.R lines 163-164 (verified 2026-03-27)
match_aa_model <- function(openrouter_id, aa_df, mapping = NULL, base_path = NULL) {
  if (is.null(aa_df) || nrow(aa_df) == 0) return(NULL)
  ...
}
```

Required addition (before line 164):
```r
if (is.null(openrouter_id) || !nzchar(openrouter_id)) return(NULL)
```

### GARD-03: section_filter NA guard in db.R

Current guard (db.R line 1113):
```r
# Source: R/db.R line 1113 (verified 2026-03-27)
if (!is.null(section_filter) && nrow(results) > 0) {
```

Required addition before line 1113:
```r
if (!is.null(section_filter)) {
  section_filter <- section_filter[!is.na(section_filter) & nzchar(section_filter)]
  if (length(section_filter) == 0) section_filter <- NULL
}
```

---

## State of the Art

| Area | Current State | Phase 64 Change |
|------|---------------|-----------------|
| req() in query builder | req(input$nl_query) guards the query text; NULL provider/model not guarded | Add req(provider, model) after resolution calls |
| fig_refresh in observeEvent() | Safe — auto-isolated by observeEvent | No change needed |
| fig_refresh in observe() bodies | Lines 1033, 1039, 1094 already use isolate() | Audit confirms — no additional bare observe() gaps found in the lines specified |
| match_aa_model NULL input | NULL aa_df guarded; NULL openrouter_id not guarded | Add NULL/empty guard at function top |
| section_filter validation | Not guarded against NA values | Add NA-stripping normalization before filter use |

---

## Open Questions

1. **D-05 bare observe() audit scope**
   - What we know: Lines 1033, 1039, 1094 use `observeEvent()` with isolate (already correct). Lines 790, 940, 948, 952 are in `observeEvent()` bodies (auto-safe).
   - What's unclear: Whether any bare `observe({...})` block (without a trigger argument) reads fig_refresh in mod_document_notebook.R or mod_search_notebook.R at lines not mentioned in CONTEXT.md.
   - Recommendation: During implementation, grep for `observe\(\{` in both files and check each for fig_refresh reads. Expected result: no additional gaps.

2. **D-07 caller-site req() for input$quality_model**
   - What we know: The function-level guard in match_aa_model() handles NULL openrouter_id safely after Phase 64. The caller at mod_settings.R line 649 passes input$quality_model directly.
   - What's unclear: Whether input$quality_model can be NULL at startup before the selectInput renders (race condition).
   - Recommendation: The function-level guard is sufficient to prevent errors. Caller-site req() is at Claude's discretion per D-07.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat |
| Config file | none — tests run via `testthat::test_dir("tests/testthat")` |
| Quick run command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-api-artificialanalysis.R')"` |
| Full suite command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GARD-01 | req() guard on NULL provider/model silently cancels generate_btn handler | manual-only | Shiny smoke test: configure no model, click generate — no crash | N/A — Shiny observer, not unit testable |
| GARD-02 | fig_refresh counter reads in bare observe() use isolate() | manual-only | Code audit + smoke test: no CPU spike on document processing | N/A — reactive behavior, not unit testable |
| GARD-03 (match_aa_model) | match_aa_model(NULL, aa_df) returns NULL without error | unit | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-api-artificialanalysis.R')"` | ✅ — extend existing file |
| GARD-03 (section_filter) | section_filter with NA values falls back to unfiltered | unit | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-rag.R')"` | ✅ test-ragnar.R exists — may need new test |

### Sampling Rate
- **Per task commit:** Shiny smoke test (app starts, reaches "Listening on")
- **Per wave merge:** `testthat::test_file('tests/testthat/test-api-artificialanalysis.R')`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/testthat/test-api-artificialanalysis.R` — add `test_that("match_aa_model returns NULL for NULL openrouter_id", ...)` test covering the new guard path
- [ ] `tests/testthat/test-rag.R` or `test-ragnar.R` — add test for NA-value section_filter normalization if a unit-testable extraction of that logic exists

*(Both test files exist; only new test cases need to be added, not new files)*

---

## Sources

### Primary (HIGH confidence)
- Serapeum codebase — `R/mod_query_builder.R` lines 73-120 (verified 2026-03-27)
- Serapeum codebase — `R/mod_document_notebook.R` lines 785-1097 (verified 2026-03-27)
- Serapeum codebase — `R/api_artificialanalysis.R` lines 155-189 (verified 2026-03-27)
- Serapeum codebase — `R/db.R` lines 1002-1160 (verified 2026-03-27)
- Serapeum codebase — `R/mod_settings.R` lines 640-665 (verified 2026-03-27)
- `.planning/research/FEATURES.md` — Pattern B (isolate), Pattern C (req()), verified code examples
- `.planning/research/PITFALLS.md` — Pitfall 1 (over-isolation), Pitfall 4 (req() mid-block), Pitfall 2 (self-triggering loop)
- `CLAUDE.md` §Shiny Reactive Safety — observe() + read/write = infinite loop; isolate() fix

### Secondary (MEDIUM confidence)
- Mastering Shiny ch. 15 (reactivity-objects.html) — isolate() and observer lifecycle semantics
- Shiny official reference — observeEvent body is implicitly isolated (shiny.posit.co/r/reference)
- Shiny official docs — req() emits cancellation condition not error (shiny.posit.co/r/articles/build/isolation/)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all patterns are base Shiny primitives, already in use in codebase
- Architecture: HIGH — each fix location verified in actual source; no assumptions required
- Pitfalls: HIGH — documented from actual prior incidents (CLAUDE.md, PITFALLS.md) and verified against source code

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (stable Shiny primitives — no version dependency)
