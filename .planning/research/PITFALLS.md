# Pitfalls Research: v20.0 Shiny Reactivity Cleanup

**Domain:** Shiny reactive lifecycle management — adding isolate() guards, destroying observers, and fixing error handling in a large existing R/Shiny application (27,000+ LOC, 15 modules)
**Researched:** 2026-03-26
**Confidence:** HIGH — grounded in actual codebase patterns, Mastering Shiny documentation, and prior incidents documented in CLAUDE.md

---

## Critical Pitfalls

### Pitfall 1: isolate() Over-Application Breaks Reactive Invalidation

**What goes wrong:**
When adding `isolate()` guards to prevent reactive loops, the guard is applied to a reactive read that *should* trigger re-execution. The observer then never re-fires when that value changes, silently breaking the feature. No error surfaces — the UI simply stops updating.

**Why it happens:**
The fix pattern for infinite loops is "wrap everything in `isolate()`." Applied correctly, this suppresses the dependency. Applied incorrectly to the *primary trigger*, the entire observer goes dead. In Serapeum's `observe()` + ExtendedTask result handlers, every reactive read inside the block is a potential over-isolation target.

**Concrete example from codebase:**
`mod_citation_network.R` line 707: the task result handler reads `progress_poller()` and `current_interrupt_flag()` without `isolate()`. Adding `isolate()` to `network_task$result()` itself (the primary trigger) would permanently break the handler.

**How to avoid:**
Identify the single reactive value that should trigger the observer. That one value must NOT be wrapped in `isolate()`. Everything else that the observer reads as a side-input should be isolated. Rule: "isolate() the reads, not the trigger."

**Warning signs:**
- Observer fires once on startup but never again after user action
- UI element stopped updating after a "fix" commit
- Adding `message()` debug lines confirms the observer never runs

**Phase to address:** Observer isolation audit phase — verify the isolated expression is never the primary trigger before merging.

---

### Pitfall 2: observe() + Read/Write Same ReactiveVal = Infinite Loop (Known)

**What goes wrong:**
An `observe()` block that both reads a `reactiveVal` and writes to it creates a self-triggering cycle: read establishes dependency → write invalidates → observer re-fires → infinite loop. Shiny does not throw an error; it simply hammers the CPU until the session hangs.

**Why it happens:**
This is the most common reactive anti-pattern in Serapeum. It has already caused incidents: `doc_refresh(doc_refresh() + 1)` inside `observe()` was the v3.0 UAT finding. The `paper_refresh(paper_refresh() + 1)` pattern in `mod_search_notebook.R` line 902 replicates this. Adding new reactive counter increments during cleanup without adding `isolate()` will re-introduce this bug.

**How to avoid:**
Wrap all reactive reads/writes inside `observe()` except the primary trigger in `isolate({...})`. The template is:
```r
observe({
  result <- task$result()          # ONLY this triggers re-run
  isolate({
    counter(counter() + 1)         # safe — isolated read+write
    showNotification(...)
  })
})
```

**Warning signs:**
- App CPU usage spikes to 100% after a reactivity change
- Notification toast appears repeatedly (the known incident symptom)
- Shiny session eventually disconnects with "Error: Maximum call stack size exceeded" or hangs

**Phase to address:** Any phase touching `observe()` blocks that increment counter reactiveVals.

---

### Pitfall 3: Dynamic Observer Accumulation Without Destroy

**What goes wrong:**
Observers are created inside a reactive context (an `observe()`, `renderUI()`, or `observeEvent()`) each time the parent fires. Without explicit `$destroy()` calls on stale observers, old observers accumulate and continue firing alongside new ones. Each paper list refresh, notebook switch, or filter change multiplies the listener count.

**Why it happens:**
Serapeum has three confirmed patterns of dynamic observer creation:

1. `mod_search_notebook.R` line 1725: `observe()` + `lapply(papers$id, function(paper_id) { observeEvent(...) })` — creates a new `observeEvent` for every paper on every filter change, never destroying the previous set.
2. `mod_search_notebook.R` line 2087: `block_journal_observers` pattern uses a `NULL`-check guard but does not destroy when the papers list shrinks. Old observers for removed papers persist in memory.
3. `mod_slides.R` line 1218: `lapply(seq_len(10), function(i) { observeEvent(input[[paste0("chip_", i)]], ...) })` — fires fresh observers on every `input$open_heal` trigger that opens the modal without cleanup from the prior modal.

**How to avoid:**
Store observer references in a list or `reactiveVal`. Before recreating, call `$destroy()` on every stored reference, then clear the list. The correct pattern (already in `mod_research_refiner.R` line 309):
```r
observe({
  seeds <- seed_papers()
  for (nm in names(seed_observers)) {
    seed_observers[[nm]]$destroy()
    seed_observers[[nm]] <- NULL
  }
  lapply(seq_along(seeds), function(i) {
    obs <- observeEvent(...)
    seed_observers[[paste0("obs_", i)]] <- obs
  })
})
```
Use `once = TRUE` on single-fire observers (already done in `mod_research_refiner.R`) but not as a substitute for proper lifecycle management.

**Warning signs:**
- Action button fires its handler multiple times per click
- Memory usage grows with each notebook switch or filter interaction
- `reactlog` shows unexpected observer churn — many short-lived contexts re-created on the same input

**Phase to address:** Phase targeting slide chip handlers and paper view/block journal observer cleanup.

---

### Pitfall 4: req() After Side Effects (Silent Abort with Incomplete Execution)

**What goes wrong:**
`req()` raises a silent abort that immediately stops observer execution. Any side effects that occurred before the `req()` call execute and persist; anything after is skipped. If `req()` is placed mid-block after a DB write, progress update, or reactiveVal mutation, the block leaves state partially modified with no error logged.

**Why it happens:**
Developers add `req()` guards as a safety net anywhere in a long observer body rather than at the top. In Serapeum's long `observeEvent` blocks (some exceeding 80 lines), inserting `req(provider$api_key)` or `req(model)` mid-function is tempting as a "guard at the point of use."

**Concrete risk:**
`mod_query_builder.R` currently uses `if` + `showNotification` + `return()` for missing API key (line 81). If this is converted to `req()` without moving it before the `withProgress()` call, the progress overlay can be shown but never removed on NULL input.

**How to avoid:**
All `req()` calls must appear at the TOP of the observer body, before any side effects. Canonical pattern:
```r
observeEvent(input$generate_btn, {
  req(input$nl_query)           # guard first
  cfg <- config()
  provider <- provider_from_config(cfg, con())
  req(provider, provider$api_key)  # guard before LLM call
  withProgress(...)             # side effects only after guards pass
})
```
Never use `req()` to guard inside a `withProgress()` wrapper — `removeProgress` will not run on silent abort.

**Warning signs:**
- Modal or progress overlay gets stuck open after a failed input
- ReactiveVal left in an intermediate state (e.g., `processing(TRUE)` but never reset to `FALSE`)
- Silent abort visible in `reactlog` as an observer that terminates without completing its output updates

**Phase to address:** Phase targeting NULL provider/model guards in query builder and preset observers.

---

### Pitfall 5: Poller Not Destroyed on All Exit Paths

**What goes wrong:**
Progress polling observers are created at task start and must be destroyed at task end. If an async task result handler uses `req(result)` to short-circuit on NULL (before the task completes), and then the cancel path or error path fails to call `poller$destroy()`, the poller continues firing `invalidateLater(1000)` indefinitely after the task is gone.

**Why it happens:**
The poller is destroyed in the "happy path" (task completes successfully) and the "cancel path" but missed on error paths or when the task is invoked a second time before the first completes. Serapeum's `mod_citation_network.R` line 707 correctly uses `req(result)` as the primary trigger, but reads `progress_poller()` without `isolate()` — meaning if `progress_poller` changes, the handler re-fires.

**How to avoid:**
Extract poller cleanup into a helper or ensure destroy appears in every branch. Template:
```r
observe({
  result <- task$result()
  req(result)                          # wait for completion
  poller <- isolate(progress_poller()) # isolated read
  if (!is.null(poller)) {
    poller$destroy()
    isolate(progress_poller(NULL))
  }
  # ... handle result
})
```
Also: when re-invoking a task, destroy any existing poller first.

**Warning signs:**
- Progress bar keeps updating after task was cancelled
- `invalidateLater` debug messages continue after workflow completes
- Memory profiling shows `observe` contexts accumulating in the reactive graph

**Phase to address:** Poller lifecycle review phase — verify all exit paths (success, cancel, error, re-invoke) call destroy.

---

### Pitfall 6: Destroying Observers While They Are Executing

**What goes wrong:**
Calling `$destroy()` on an observer from within its own execution context (or from a sibling observer that fires in the same reactive flush) can cause the observer to fire one additional time after destroy, or can corrupt the reactive graph's invalidation queue for that flush cycle.

**Why it happens:**
In `mod_search_notebook.R` line 2087, the `block_journal_observers` pattern calls `block_journal_observers[[paper_id_str]] <- NULL` (effectively destroying the reference) from *inside* the observer's own body. The actual observer object may still be alive until the flush completes.

**How to avoid:**
Destroy observers from outside their own execution context — from the parent observer or from a dedicated cleanup observer. The `once = TRUE` flag on `observeEvent()` is the safe equivalent for single-fire cases: Shiny handles the self-destruction cleanly. For multi-fire dynamic observers, destroy from the parent context before recreating.

**Warning signs:**
- An observer fires once after destroy is called
- Reactive flush causes an error about "modified reactive values during evaluation"
- Event handler runs partially on first fire and fully on second

**Phase to address:** Dynamic observer cleanup phases in slides and search notebook.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `observe()` + `lapply()` for dynamic button handlers without destroy | Simple to write, works initially | Observer count grows with each filter refresh; memory leak | Never for lists that change size |
| `if (is.null(result)) return()` instead of `req(result)` in ExtendedTask handler | Explicit, readable | `req()` silently aborts; `return()` keeps processing; subtle semantic difference for downstream reactive dependencies | Either is acceptable; prefer `req()` for clarity in ExtendedTask handlers since it is the documented pattern |
| Adding `isolate()` to entire observer body | Stops infinite loop immediately | Breaks reactivity — observer may never re-fire | Never; always isolate selectively |
| Using `once = TRUE` to avoid destroy boilerplate | Eliminates lifecycle management code | Accumulates N observers on N-th open of same modal | Acceptable only when the input truly fires exactly once per observer lifetime |
| `tryCatch` around entire observer body | Catches all errors | Swallows reactive aborts from `req()` — the abort becomes a normal return, downstream observers do not see the cancellation signal | Never wrap entire `observe()` in `tryCatch`; wrap only specific IO calls |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| ExtendedTask + observe() | Using `observeEvent(task$result(), ...)` or `bindEvent(task$result())` — Shiny documentation explicitly states this does NOT work; invalidation is ignored | Use bare `observe({ result <- task$result(); req(result); isolate({ ... }) })` |
| mirai + reactive state | Reading reactive values inside the mirai worker (passed via closure) — mirai runs in a separate process with no Shiny session | Pass all needed values as plain R objects to `task$invoke()`; worker returns a plain list |
| visNetwork + reactive data | Rebuilding entire network on every reactive change | Use `visNetworkProxy` + `visUpdateNodes`/`visUpdateEdges` for targeted mutations; full re-render resets physics state |
| DuckDB + async workers | Sharing a DuckDB connection across mirai worker and main session | Each worker must open its own connection via `db_path` parameter; DuckDB is single-writer |
| ragnar DuckDB stores + async | Calling ragnar functions inside mirai without re-opening the store | Pass `store_path` and re-open inside worker; S7 objects are not serializable across process boundaries |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `observe()` + `lapply(papers$id, observeEvent(...))` without destroy | UI lag on filter changes; memory grows session-length | Destroy old observers before creating new ones; use `reactiveValues` to track references | Breaks noticeably with 50+ papers in the list |
| `renderUI()` that queries the database on every render | Slow tab switches; DB connection contention | Cache DB results in `reactive()` upstream of `renderUI()`; `renderUI()` should only format, not query | Breaks at any database size when render triggers are frequent |
| `invalidateLater(1000)` poller left running | Battery drain; session memory growth; background R process stays busy | Strict destroy() on all exit paths | Breaks immediately if poller leaks; impacts session longevity |
| Multiple `observe()` blocks with overlapping reactive dependencies | Redundant reactive evaluations when one input changes | Audit reactive graph with `reactlog`; consolidate observers that depend on the same trigger | Compounds with each cleanup pass that adds new observers |

---

## "Looks Done But Isn't" Checklist

- [ ] **Observer cleanup:** The old observers were destroyed — verify by checking that the target input handler does not fire multiple times per click after the fix. Add a `message("observer fired")` probe before merging.
- [ ] **isolate() correctness:** The isolated expression is NOT the primary trigger — confirm the observer re-fires when the intended input changes after adding `isolate()`.
- [ ] **req() placement:** All `req()` calls appear before any `showModal()`, `withProgress()`, or reactiveVal mutations — confirm by reading the observer top-to-bottom and checking nothing executes before the guards.
- [ ] **Poller destroy on all paths:** The poller is destroyed in success, cancel, AND error branches — check the full result handler for any `return()` that skips destroy.
- [ ] **ExtendedTask handler pattern:** The result observer uses `observe({ result <- task$result(); req(result); isolate({...}) })` — not `observeEvent(task$result(), ...)` which silently fails.
- [ ] **Smoke test:** The Shiny app starts without error after the change (`shiny::runApp(port=3838, launch.browser=FALSE)` reaches "Listening on" within 10 seconds).

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Observer accumulation discovered in production | MEDIUM | Add destroy() in the parent context; restart session (observers are session-scoped — existing leaked observers die on session end) |
| Infinite reactive loop deployed | HIGH | Wrap the offending reactive read in `isolate()` immediately; hotfix to main; the session will hang for any active user until they refresh |
| req() placed after side effects, leaving state corrupted | MEDIUM | Add explicit state reset at top of observer: `processing(FALSE); removeModal()` etc. before the req() guard, so failed guards reset state |
| Poller leak: invalidateLater running after task complete | LOW | Add destroy() to missing exit path; restart R session to kill existing poller |
| isolate() over-applied breaks reactivity | LOW | Remove isolate() from the primary trigger; re-test the full reactive path |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Observer accumulation — slides chip handlers | Phase addressing slides observer cleanup | Click heal button 3x; confirm handler fires once per click, not 3x |
| Observer accumulation — paper view/block journal observers | Phase addressing search notebook observer lifecycle | Filter papers, change filter, click view button — confirm fires once |
| Missing isolate() in ExtendedTask result handlers | Phase adding isolate() guards | Enable reactlog; confirm result handler does not re-fire when progress_poller changes |
| req() placement mid-block | Phase adding NULL guards to query builder and preset observers | Set API key to NULL; trigger action; confirm no modal gets stuck open |
| Poller not destroyed on error path | Poller lifecycle phase | Trigger a task that returns an error result; confirm progress bar is not visible afterward |
| isolate() over-application | Every isolate() addition | Change the primary trigger value; confirm observer re-fires |

---

## Sources

- Mastering Shiny, Chapter 15: Reactive building blocks — https://mastering-shiny.org/reactivity-objects.html
- Mastering Shiny, Chapter 10: Dynamic UI — https://mastering-shiny.org/action-dynamic.html
- Engineering Production-Grade Shiny Apps, Chapter 15: Common Application Caveats — https://engineering-shiny.org/common-app-caveats.html
- Posit: Stop reactions with isolate() — https://shiny.posit.co/r/articles/build/isolation/
- Posit: req() reference — https://shiny.posit.co/r/reference/shiny/latest/req.html
- Posit: ExtendedTask reference — https://shiny.posit.co/r/reference/shiny/latest/extendedtask.html
- Kyle Husmann: A Shiny Puzzle: Dynamic Observers (2025) — https://www.kylehusmann.com/posts/2025/shiny-dynamic-observers/
- GitHub: observeEvent stays registered after destroy() — https://github.com/rstudio/shiny/issues/1486
- CLAUDE.md project instructions: `observe()` + read/write same reactiveVal = infinite loop (documented prior incident)
- Serapeum codebase: prior incident in v3.0 UAT — `doc_refresh(doc_refresh() + 1)` without isolate; Phase 63 lapply+local() closure-over-loop pattern

---
*Pitfalls research for: Shiny Reactivity Cleanup — adding isolate() guards, destroying observers, fixing lifecycle patterns in a 27,000 LOC Shiny app*
*Researched: 2026-03-26*
