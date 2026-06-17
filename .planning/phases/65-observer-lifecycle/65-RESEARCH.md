# Phase 65: Observer Lifecycle - Research

**Researched:** 2026-03-27
**Domain:** R/Shiny observer management, reactive lifecycle, destroy-before-recreate pattern
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**LIFE-01 — Slide chip handler lifecycle (D-01, D-02):**
- The current implementation pre-allocates 10 `observeEvent` handlers once via `lapply(seq_len(10), ...)` at module server init (lines 1218-1225), outside any reactive scope. Verify this is accumulation-free — if handlers are registered only once in the module body, LIFE-01 may require no code changes.
- If verification reveals chip observers ARE inside a reactive scope, apply the destroy-before-recreate pattern from mod_research_refiner.R (lines 308-324): store observer references in a reactiveValues list, destroy all before re-creating.

**LIFE-02 — Figure action observer lifecycle (D-03, D-04, D-05):**
- The destroy loop at mod_document_notebook.R lines 931-938 already exists. Verify it runs BEFORE the renderUI at line 990+ re-creates observers for new figure IDs.
- Check the `is.null(fig_action_observers[[fig$id]])` guard at line 1023 — if figure IDs are reused across extractions, old observers may not be destroyed. The destroy loop at 931-938 should handle this.
- Follow mod_research_refiner.R lines 308-324 as the canonical reference implementation.

**LIFE-03 — Document list renderUI efficiency (D-06, D-07):**
- Extract `list_documents()` into a separate `reactive()` expression that the renderUI depends on — Shiny's lazy evaluation ensures it runs once per invalidation cycle.
- Also check `output$index_action_ui` renderUI (line 281) which has its own `list_documents()` call. If both depend on the same reactive, the DB query runs once and both renderUI blocks benefit.

**LIFE-04 — Module cleanup on close (D-08, D-09, D-10):**
- For mod_slides.R: add cleanup that destroys stored observers when the modal is dismissed or module scope ends. Prefer scoped cleanup tied to modal close over `session$onSessionEnded()`.
- For mod_document_notebook.R: destroy `extract_observers` and `fig_action_observers` entries when the notebook is switched or closed. Follow mod_citation_network.R line 1598 pattern.
- Console errors from orphaned observers should be eliminated — absence of these errors is the SC-4 verification criterion.

### Claude's Discretion
- Whether SC-1 already passes and LIFE-01 requires no code changes (just verification)
- Exact reactive() expression granularity for the list_documents caching
- Whether to add defensive `tryCatch` around observer `$destroy()` calls
- Whether to log observer lifecycle events during development (remove before merge)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LIFE-01 | Slide chip handler observers are destroyed before re-creation on each modal open | Confirmed: chip handlers at lines 1218-1225 are in module body (not a reactive scope) — likely no-change; verify via code audit |
| LIFE-02 | Figure action observers are destroyed and re-registered on re-extraction | Destroy loop exists at lines 931-938; guard at 1023 prevents re-creation; verify ordering relative to fig_refresh() increment |
| LIFE-03 | renderUI in document notebook does not repeatedly query list_documents() during processing | Both output$document_list (line 639) and output$index_action_ui (line 281) call list_documents() directly; cache in reactive() |
| LIFE-04 | Observer lifecycle and resource paths are cleaned up in slides and notebook modules | session$onSessionEnded pattern exists in mod_citation_network.R line 1598; apply same to slides and notebook modules |
</phase_requirements>

---

## Summary

Phase 65 is a targeted lifecycle hardening pass across two modules: `mod_slides.R` and `mod_document_notebook.R`. The work falls into four discrete tasks: (1) confirming or fixing chip observer registration in the slides modal, (2) verifying the existing figure action observer destroy loop fires in the correct order, (3) caching the `list_documents()` DB query in a `reactive()` to prevent redundant calls during async processing, and (4) adding module-close cleanup hooks for any observers and resource references that outlive a modal or notebook switch.

The destroy-before-recreate pattern is already established in `mod_research_refiner.R` lines 308-324 and partially implemented in `mod_document_notebook.R`. This phase is primarily verification and gap-filling rather than introducing new patterns. The canonical pattern uses a `reactiveValues()` store, iterates `names()`, calls `$destroy()` on each entry, then assigns `NULL`, then re-creates.

The highest-risk item is LIFE-03: the current `renderUI` blocks call `list_documents(con(), nb_id)` directly, meaning every `doc_refresh()` invalidation triggers a DB round-trip in each block independently. The fix is a single `reactive()` that both `renderUI` blocks depend on, reducing two queries to one per cycle.

**Primary recommendation:** Audit LIFE-01 first (may be a no-op), then address LIFE-02 ordering verification, LIFE-03 reactive caching, and LIFE-04 cleanup hooks — in that order.

---

## Standard Stack

### Core (project-fixed — no alternatives to consider)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | project-installed | Module server, observer lifecycle, reactiveValues | App framework — locked |
| bslib | project-installed | UI bootstrap theming | App framework — locked |

### Shiny Observer Lifecycle API

| Function | Purpose | Notes |
|----------|---------|-------|
| `observeEvent(...) -> observer` | Returns an observer handle | Return value must be captured to enable `$destroy()` |
| `observer$destroy()` | Terminates the observer permanently | Safe to call even if observer already fired (with `once = TRUE`) |
| `reactiveValues()` | Named mutable store for observer handles | Allows iteration via `names()` |
| `reactive({...})` | Lazy computed value with caching | Runs once per invalidation cycle regardless of how many outputs depend on it |
| `session$onSessionEnded(fn)` | Callback when Shiny session ends | Last-resort cleanup; prefer modal-close scoped cleanup |

### No external packages needed

All lifecycle management uses base Shiny APIs. No additional packages are required or appropriate for this phase.

---

## Architecture Patterns

### Pattern 1: Destroy-Before-Recreate (canonical — mod_research_refiner.R lines 308-324)

**What:** Store observer handles in `reactiveValues()`. On each reactive trigger, iterate all stored handles calling `$destroy()` and assign `NULL`, then re-create fresh observers.

**When to use:** Any observer set that must be re-created when the underlying data changes (e.g., per-item button handlers that depend on which items exist).

```r
# Source: R/mod_research_refiner.R lines 308-326
seed_observers <- reactiveValues()
observe({
  seeds <- seed_papers()
  # Destroy previous observers
  for (nm in names(seed_observers)) {
    seed_observers[[nm]]$destroy()
    seed_observers[[nm]] <- NULL
  }
  # Create fresh observers for current item count
  lapply(seq_along(seeds), function(i) {
    obs <- observeEvent(input[[paste0("remove_seed_", i)]], {
      current <- seed_papers()
      if (i <= length(current)) {
        seed_papers(current[-i])
      }
    }, ignoreInit = TRUE, once = TRUE)
    seed_observers[[paste0("obs_", i)]] <- obs
  })
})
```

**Key detail:** The `observe()` block here does NOT write back to `seed_papers()` — only reads it. Writing happens inside the nested `observeEvent`, so there is no infinite loop risk. The outer `observe()` has a single reactive dependency on `seed_papers()`.

### Pattern 2: Pre-allocated Fixed-Count Observers (mod_slides.R lines 1217-1225)

**What:** Register a fixed number (10) of `observeEvent` handlers once at module server init, outside any reactive scope. A `reactiveVal` (`current_chips`) gates which indices are actually active.

**When to use:** When the maximum number of items is bounded and small, and handlers don't need to be destroyed/re-created — they simply read `current_chips()` to determine if the index is in range.

```r
# Source: R/mod_slides.R lines 1218-1225
lapply(seq_len(10), function(i) {
  observeEvent(input[[paste0("chip_", i)]], {
    chips <- current_chips()
    if (i <= length(chips)) {
      updateTextAreaInput(session, "heal_instructions", value = chips[i])
    }
  }, ignoreInit = TRUE)
})
```

**LIFE-01 verification:** This `lapply` is in the module server body at the top level — not inside an `observe()`, `renderUI()`, or `observeEvent()`. It runs exactly once when the module initializes. SC-1 (opening modal N times registers exactly one handler) is already satisfied by this structure.

### Pattern 3: Cached reactive() for DB Queries

**What:** Move repeated DB calls out of `renderUI` blocks into a `reactive()` expression. Shiny caches the `reactive()` result for the current invalidation cycle — all dependents get the same result without re-executing the query.

**When to use:** When multiple `renderUI` or `render*` blocks call the same query with the same inputs.

```r
# Before (current — two independent queries per doc_refresh() cycle):
output$document_list <- renderUI({
  doc_refresh()
  nb_id <- notebook_id()
  req(nb_id)
  docs <- list_documents(con(), nb_id)   # Query 1
  ...
})

output$index_action_ui <- renderUI({
  nb_id <- notebook_id()
  req(nb_id)
  docs <- list_documents(con(), nb_id)   # Query 2 (independent)
  ...
})

# After (one query per cycle):
docs_reactive <- reactive({
  doc_refresh()                          # Take dependency on refresh counter
  nb_id <- notebook_id()
  req(nb_id)
  list_documents(con(), nb_id)           # Single query, result cached
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

**Key detail:** `doc_refresh()` dependency moves into the `reactive()`. The `renderUI` blocks no longer need to call `doc_refresh()` directly — they inherit invalidation through the reactive chain.

### Pattern 4: Session Cleanup Hook (mod_citation_network.R line 1598)

**What:** Register cleanup logic with `session$onSessionEnded()` to destroy observers and close resources when the Shiny session ends.

**When to use:** As a safety net for resources that may not have been cleaned up through scoped cleanup. Preferred scoped cleanup (tied to modal close) should still be attempted first.

```r
# Source: R/mod_citation_network.R line 1598
session$onSessionEnded(function() {
  cleanup_session_flags(session$token)
})
```

**For LIFE-04:** Apply analogous patterns in mod_slides.R and mod_document_notebook.R to destroy `fig_action_observers` and `extract_observers` entries.

### Anti-Patterns to Avoid

- **Observer registration inside renderUI:** Each renderUI re-execution would re-register observers without destroying previous ones. All observer registration in this codebase happens inside `observe()` or at module init level.
- **Reading reactive and writing same reactive in observe() without isolate():** Causes infinite loops. The CLAUDE.md documents this: any `observe()` that both reads and writes the same `reactiveVal` must wrap secondary reads/writes in `isolate({...})`.
- **Calling `$destroy()` without assigning `NULL`:** The handle still exists in the `reactiveValues` store; subsequent iteration will attempt to destroy an already-destroyed observer. Always assign `NULL` after `$destroy()`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Observer lifecycle tracking | Custom list, environment, or vector of handles | `reactiveValues()` | reactiveValues is reactive-aware and iterable by `names()` |
| Cache DB query results | Memoization cache, global variable | `reactive({...})` | Shiny's lazy evaluation handles cache invalidation automatically |
| Module teardown callback | Custom event system | `session$onSessionEnded()` | Built-in Shiny lifecycle hook, always fires |

**Key insight:** Shiny provides all the primitives needed. `reactiveValues` as an observer store + `reactive()` for query caching + `session$onSessionEnded()` for cleanup covers every lifecycle scenario in this phase.

---

## Common Pitfalls

### Pitfall 1: Destroying observers inside a reactive triggered by the same inputs

**What goes wrong:** If the `observe()` that destroys-and-recreates observers reads from a reactive that is also invalidated by those observers' actions, destroy-recreate loops can occur.

**Why it happens:** The outer `observe()` in mod_research_refiner.R reads `seed_papers()`. The inner `observeEvent` also writes to `seed_papers()`. This does NOT cause a loop because the write happens inside the nested `observeEvent` handler — not inside the outer `observe()` body. The outer observe only reads once per `seed_papers()` change, then re-creates handlers.

**How to avoid:** Ensure the destroy-recreate `observe()` block only reads the state reactiveVal at the top, and any writes to it happen inside nested `observeEvent` handlers.

### Pitfall 2: is.null() guard blocks re-creation after destroy

**What goes wrong:** The `if (is.null(fig_action_observers[[fig$id]]))` guard at line 1023 prevents registering a duplicate observer for a figure already in the store. If figures are re-extracted and get the same IDs, the destroy loop at 931-938 must clear the store first — otherwise the guard blocks re-registration of observers for existing IDs.

**Why it happens:** The destroy loop runs in the extraction success handler; the guard runs inside the gallery renderUI. If the renderUI fires before the destroy loop completes, old handles are still in the store.

**How to avoid:** The `fig_refresh()` increment at line 940 (after the destroy loop at 931-938) is what triggers the gallery renderUI to re-render. Since Shiny processes reactive invalidations sequentially within a session, the destroy loop at 931-938 completes before `fig_refresh()` invalidates the renderUI. Verify this ordering is preserved.

**Warning signs:** Button clicks on re-extracted figures trigger the old handler's action instead of the new one.

### Pitfall 3: Calling doc_refresh() in both reactive() and renderUI()

**What goes wrong:** If `doc_refresh()` is called inside the new `reactive()` expression AND still called inside a `renderUI`, the `renderUI` creates a redundant dependency on `doc_refresh()` that doesn't go through the cache.

**How to avoid:** Remove any direct `doc_refresh()` reads from `renderUI` blocks after extracting the `reactive()`. The `renderUI` should only call `docs_reactive()`.

### Pitfall 4: Orphaned resource path references after modal close

**What goes wrong:** mod_slides.R or mod_document_notebook.R may hold resource path strings (e.g., file paths used in `addResourcePath()`) that become stale after a modal is dismissed. Subsequent operations that check these paths can trigger console errors.

**How to avoid:** Track resource path registrations alongside observer registrations. Clean both in the same teardown hook.

---

## Code Examples

Verified from codebase source:

### Existing destroy loop (mod_document_notebook.R lines 931-938)

```r
# Destroy and clear old figure action observers (figure IDs changed)
for (old_id in names(fig_action_observers)) {
  obs_list <- fig_action_observers[[old_id]]
  if (is.list(obs_list)) {
    for (obs in obs_list) if (!is.null(obs)) obs$destroy()
  }
  fig_action_observers[[old_id]] <- NULL
}
```

This is already correct. The only question for LIFE-02 is whether this fires before the gallery renderUI re-registers — confirmed by the `fig_refresh()` increment at line 940 which triggers the renderUI invalidation.

### Observer handle capture (mod_document_notebook.R lines 1031-1096)

```r
# The handles are stored as a list of three observers per figure
fig_action_observers[[f_id]] <- list(obs_keep, obs_ban, obs_retry)
```

### Adding defensive tryCatch to $destroy() calls (Claude's discretion)

```r
# If there is any risk of double-destroy:
tryCatch(
  obs$destroy(),
  error = function(e) NULL   # Silently ignore already-destroyed observers
)
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| No observer tracking (pre-v20.0) | reactiveValues() store with explicit $destroy() | Eliminates accumulation bugs |
| Direct list_documents() in renderUI | reactive() caching layer | Reduces DB round-trips during async processing |
| No teardown hooks | session$onSessionEnded() cleanup | Eliminates orphaned observer console errors |

---

## Open Questions

1. **LIFE-01: Does verification confirm no accumulation, or is code change needed?**
   - What we know: The `lapply(seq_len(10), ...)` is at module server top level (not inside a reactive). This means handlers are registered exactly once.
   - What's unclear: Whether opening the modal triggers any code path that re-executes the lapply block.
   - Recommendation: Read the full module server body (not just lines 1218-1225) to confirm no wrapper reactive scope exists. If the lapply is unconditionally at the top level, LIFE-01 is a documentation-only task.

2. **LIFE-03: Should doc_refresh() be the sole invalidation trigger in the reactive()?**
   - What we know: Both renderUI blocks currently read `doc_refresh()` and `notebook_id()`.
   - What's unclear: Whether `notebook_id()` changes should also invalidate the docs reactive independently of `doc_refresh()`.
   - Recommendation: Include both `doc_refresh()` and `notebook_id()` as dependencies in the new `reactive()` — this mirrors the existing invalidation logic.

3. **LIFE-04: Are there resource path registrations (addResourcePath) that need cleanup?**
   - What we know: The success criteria mentions "absence of console errors on subsequent operations."
   - What's unclear: Whether console errors are from orphaned observers or from stale `addResourcePath` registrations.
   - Recommendation: Search for `addResourcePath` calls in mod_slides.R and mod_document_notebook.R and determine if they are scoped or persistent.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat (version from project) |
| Config file | tests/testthat/ directory |
| Quick run command | `testthat::test_dir("tests/testthat", filter = "slides\|document")` |
| Full suite command | `testthat::test_dir("tests/testthat")` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LIFE-01 | Chip observers registered exactly once at module init | manual-only | N/A — requires Shiny session to verify observer count | N/A |
| LIFE-02 | Figure action observers destroyed and re-registered on re-extraction | manual-only | N/A — requires Shiny session and UI interaction | N/A |
| LIFE-03 | list_documents() called once per doc_refresh() cycle | unit (indirect) | `testthat::test_file("tests/testthat/test-document-figures.R")` | Existing |
| LIFE-04 | No console errors after closing slides/notebook | manual-only | N/A — requires browser console inspection | N/A |

**Note:** LIFE-01, LIFE-02, and LIFE-04 are observer lifecycle correctness requirements that cannot be mechanically asserted by testthat unit tests — they require running a Shiny session. The verification strategy is:

1. **Code audit** — confirm observer registration sites and destroy loops are in correct order
2. **Smoke test** — start the app (`shiny::runApp("app.R", port=3838, launch.browser=FALSE)`) and confirm no startup errors
3. **Manual verification** — open slide heal modal N times, click chips; trigger re-extraction; confirm single handler fires
4. **Console inspection** — confirm absence of Shiny observer/resource errors after modal close

### Sampling Rate

- Per task commit: `testthat::test_dir("tests/testthat", filter = "slides\|document\|figures")`
- Per wave merge: `testthat::test_dir("tests/testthat")`
- Phase gate: Full suite green + manual SC-1 through SC-4 verification before `/gsd:verify-work`

### Wave 0 Gaps

None — existing test infrastructure covers the automatable tests. The manual verification steps are inherent to the lifecycle domain and cannot be automated with testthat.

---

## Sources

### Primary (HIGH confidence)
- Codebase read: `R/mod_research_refiner.R` lines 308-326 — canonical destroy-before-recreate pattern
- Codebase read: `R/mod_document_notebook.R` lines 205-206, 640-644, 281-285, 931-942, 1022-1097 — current lifecycle state
- Codebase read: `R/mod_slides.R` lines 548-549, 1211-1225 — chip observer registration
- Codebase read: `R/mod_citation_network.R` line 1598 — session cleanup pattern
- `CLAUDE.md` §Shiny Reactive Safety — observe() + read/write reactiveVal = infinite loop rule, isolate() fix

### Secondary (MEDIUM confidence)
- `.planning/phases/65-observer-lifecycle/65-CONTEXT.md` — user decisions and verified code line references
- `.planning/REQUIREMENTS.md` — LIFE-01 through LIFE-04 definitions

---

## Metadata

**Confidence breakdown:**
- LIFE-01 (chip observers): HIGH — code structure confirms top-level registration; audit is deterministic
- LIFE-02 (figure action destroy): HIGH — destroy loop and guard both visible; ordering analysis is deterministic
- LIFE-03 (list_documents caching): HIGH — reactive() caching is standard Shiny pattern; both call sites confirmed
- LIFE-04 (module cleanup): MEDIUM — session$onSessionEnded pattern is confirmed; exact resource path cleanup scope unclear until addResourcePath audit

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (stable Shiny patterns; 30-day validity)
