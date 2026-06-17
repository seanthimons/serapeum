# Architecture Research

**Domain:** Shiny Reactivity Cleanup — observer leaks, isolate() guards, req() guards, error handling, lifecycle management
**Researched:** 2026-03-26
**Confidence:** HIGH (direct code inspection of all affected modules)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     app.R (Entry Point)                      │
│  page_sidebar() + bs_theme() + thematic_shiny()             │
│  Global con() reactiveVal — single DuckDB connection        │
│  Global config() reactive — YAML config re-read             │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  mod_slides  │  │ mod_document │  │ mod_search       │  │
│  │              │  │ _notebook    │  │ _notebook        │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
│         │                 │                   │             │
│  ┌──────┴──────────────────┴───────────────────┴──────────┐ │
│  │            Producer-Consumer Discovery Layer            │ │
│  │  mod_query_builder | mod_seed_discovery | mod_topic    │ │
│  └─────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              mod_citation_network                       │ │
│  │  ExtendedTask + mirai + file-based interrupt flags      │ │
│  └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                   Data Layer                                 │
│  ┌───────────────┐  ┌──────────────────────────────────┐    │
│  │  DuckDB main  │  │  ragnar per-notebook DuckDB VSS  │    │
│  │  serapeum.db  │  │  data/ragnar/{nb_id}.duckdb      │    │
│  └───────────────┘  └──────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Reactivity Surface |
|-----------|---------------|-------------------|
| `mod_slides.R` | Quarto slide deck generation, theme swatches, healing modal | `generation_state` reactiveValues, `current_chips` reactiveVal, chip click handlers via `lapply(seq_len(10), ...)` |
| `mod_document_notebook.R` | PDF upload, RAG chat, figure gallery, preset synthesis | `fig_action_observers` reactiveValues, `fig_refresh` reactiveVal, `delete_doc_observers`, `extract_observers` |
| `mod_search_notebook.R` | OpenAlex search, keyword filters, paper list, batch import | `delete_observers`, `view_observers`, `block_journal_observers`, `type_chip_observers`, `unblock_journal_observers` |
| `mod_citation_network.R` | BFS citation graph, visNetwork rendering, async build with poller | `progress_poller` reactiveVal holds the polling observe() instance; result handler uses isolate() pattern |
| `mod_query_builder.R` | NL query to OpenAlex filter generation via LLM | `provider` and `model` resolved inline at call site without upfront req() guard |
| `R/db_migrations.R` | Versioned SQL migrations via `schema_migrations` table | Pure R, not reactive — called at app startup in `app.R` before server() |
| `R/_ragnar.R` | Per-notebook ragnar store lifecycle — `ensure_ragnar_store()` | Called inside reactive contexts; secondary connection leak on creation error path |

## Recommended Project Structure

No structural changes needed. The existing layout is correct for this milestone:

```
R/
├── mod_slides.R             # Fix: isolate() on current_chips() in chip handlers
├── mod_document_notebook.R  # Fix: verify fig_action_observer destroy path; isolate() audit
├── mod_search_notebook.R    # Fix: type_chip_observers registration guard or destroy-before-replace
├── mod_citation_network.R   # Fix: poller destroy-before-create; isolate() in result handler
├── mod_query_builder.R      # Fix: add req(provider, model) after resolution
├── db_migrations.R          # Investigate: fresh-install bootstrap ordering
└── _ragnar.R                # Fix: secondary connection leak on ensure_ragnar_store() error path
```

All changes are in-place modifications to existing files. No new modules are created.

## Architectural Patterns

### Pattern 1: Guard-First observeEvent

**What:** All `observeEvent` handlers that access reactive state derived from external sources (config, notebook ID, API key, LLM provider) open with `req()` before any computation. This is already the dominant pattern throughout the codebase.

**When to use:** Any handler that can legally fire before its dependencies are ready — button clicks before a notebook is selected, query generation before config is loaded.

**Trade-offs:** Adds one line per guard. Prevents silent NULL-propagation into downstream functions that assume valid inputs.

**Correct form:**
```r
observeEvent(input$generate_btn, {
  req(input$nl_query)
  cfg <- config()
  provider <- provider_from_config(cfg, con())
  model    <- resolve_model_for_operation(cfg, "query_build")
  req(provider, model)   # currently missing — add here
  # ... rest of handler
})
```

**Current gap in mod_query_builder.R:** `provider` and `model` are resolved but not req()-guarded. The manual `if (is.null(provider$api_key)...)` check handles the API key case but does not guard against `provider` itself being NULL or `model` being NULL when no model is configured.

### Pattern 2: isolate() on Counter Reads Inside Observers That Write

**What:** Any `observe()` or `observeEvent()` body that both reads and writes the same `reactiveVal` counter must wrap the read inside `isolate({})`. Only the primary trigger is left unguarded.

**When to use:** Every `counter(counter() + 1)` call inside an observer that is also triggered by reactive reads. The canonical case is `fig_refresh(fig_refresh() + 1)`.

**Trade-offs:** Without `isolate()`, reading `fig_refresh()` inside an observer that writes `fig_refresh()` creates the self-trigger cycle documented in CLAUDE.md. With `isolate()`, the update is side-effect only — no new dependency is created.

**Correct form:**
```r
obs_keep <- observeEvent(input[[paste0("keep_", f_id)]], {
  db_update_figure(con(), f_id, is_excluded = FALSE)
  fig_refresh(isolate(fig_refresh()) + 1)
}, ignoreInit = TRUE)
```

**Current state in mod_document_notebook.R:** `isolate(fig_refresh())` is correctly used at lines 1033, 1039, 1094. The raw `fig_refresh(fig_refresh() + 1)` calls at lines 790 and 948 are inside `observeEvent` handlers that do not read `fig_refresh()` as a reactive dependency — those are safe in their current context. Line 940 executes after async work inside an upload handler and should be audited to confirm it does not re-enter an observer that holds a `fig_refresh()` dependency.

### Pattern 3: Once-Per-ID Observer Registration with reactiveValues Guard

**What:** Per-item observers (delete buttons, figure action buttons, journal block buttons) check a `reactiveValues` registry before registering. If an entry already exists for a given ID, registration is skipped.

**When to use:** Any `observe()` that iterates over a list (papers, documents, figures) and creates `observeEvent` handlers for dynamic UI elements. Without the guard, re-renders accumulate duplicate observers that all fire when the input is clicked.

**Trade-offs:** Correct for insert-only lists. For mutable lists (figures that get replaced when document selection changes), the registry must be explicitly cleared and observers destroyed when the set changes.

**Correct form:**
```r
if (is.null(fig_action_observers[[fig$id]])) {
  local({
    f_id <- fig$id
    obs <- observeEvent(input[[paste0("keep_", f_id)]], { ... })
    fig_action_observers[[f_id]] <- obs
  })
}
```

**Current state in mod_document_notebook.R:** The `fig_action_observers` registry already uses explicit `obs$destroy()` + NULL assignment at lines 932-937 when document selection changes. This destroy-and-reset pattern is correct and must be preserved. The risk is code paths that reach `renderUI` re-execution without passing through the destroy block.

**Current gap in mod_search_notebook.R:** `type_chip_observers[[i]] <<- observeEvent(...)` at line 2457 always overwrites the registry entry without checking if one already exists and without calling `$destroy()` on the previous observer. The old observer remains alive. Each re-render of the chip UI registers a duplicate. Fix: either add a guard (`if (is.null(...))`) or explicitly call `type_chip_observers[[i]]$destroy()` before re-assigning.

### Pattern 4: ExtendedTask Result Handler with isolate()

**What:** The `observe({ result <- task$result(); req(result); isolate({ ... }) })` pattern for handling async task completion. The primary trigger is the unguarded `task$result()` read. All secondary reactive reads and writes (notifications, counter increments, state updates) go inside `isolate({})`.

**When to use:** Every ExtendedTask result handler — citation network build, batch import, re-index, bulk import.

**Current state:** mod_document_notebook.R line 581 has a comment explicitly documenting this requirement (the reindex_task result handler). mod_search_notebook.R lines 874 and 3306 follow the same pattern. mod_citation_network.R line 707 is the network build result handler. All four need the `isolate()` wrap on secondary reactive writes confirmed in code review.

### Pattern 5: Slide Chip Handler Registration via lapply at Module Init

**What:** `lapply(seq_len(10), function(i) { observeEvent(input[[paste0("chip_", i)]], {...}) })` registers up to 10 chip click observers at module server startup — once, outside any reactive context.

**When to use:** Fixed-cardinality dynamic inputs where the count is bounded and known at startup.

**Current state in mod_slides.R:** No accumulation issue — lapply runs once. The `current_chips()` read inside the handler at line 1220 is safe from a dependency perspective because the handler fires on input click, not on `current_chips()` change. However, `current_chips()` inside an `observeEvent` handler does create an incidental reactive dependency on `current_chips`. If `current_chips()` updates between a click and the handler body executing, this is benign — but wrapping with `isolate()` makes the intent explicit and consistent with the rest of the codebase.

### Pattern 6: Progress Poller Lifecycle

**What:** Async tasks (citation network build, re-index, bulk import) create a polling `observe({ invalidateLater(1000); ... })` instance stored in a `reactiveVal`. On task completion or cancellation, the poller must be explicitly destroyed via `poller$destroy()`.

**When to use:** Every `invalidateLater`-based polling loop spawned for an async task.

**Current state in mod_citation_network.R:** The `progress_poller` reactiveVal stores the current poller. The result handler at line 707 destroys the poller when the task completes. The cancel handler at line 683 also destroys it. The gap to verify: when a new build is started before a previous one completes (user clicks "Build Network" twice), the old poller stored in `progress_poller()` must be destroyed before creating the new one. Pattern: `old <- progress_poller(); if (!is.null(old)) old$destroy()`.

## Data Flow

### Observer Registration Flow (the accumulation pattern being fixed)

```
Module Server Init
    |
    v
reactiveValues()   <-- observer registry (delete_observers, fig_action_observers, etc.)
    |
    v
observe({ items <- reactive_list() })   <-- outer observer, re-fires when list changes
    |
    v
lapply(items, function(item) {
    if (is.null(registry[[item$id]])) {         <-- guard prevents duplicate registration
        local({
            id <- item$id
            registry[[id]] <- observeEvent(input[[id]], { ... })
        })
    }
})
```

Without the guard on line 3: each re-fire of the outer observer creates a new observer for the same input ID. After 10 re-fires, clicking one button fires 10 handlers.

### fig_refresh Counter Flow

```
User action (keep/ban/retry figure button click)
    |
    v
observeEvent fires
    |
    v
db_update_figure()   <-- side effect write
    |
    v
fig_refresh(isolate(fig_refresh()) + 1)   <-- MUST use isolate() to avoid self-trigger
    |
    v
output$figure_gallery <- renderUI({ fig_refresh(); ... })   <-- reads counter, re-renders
    |
    v
per-figure observers checked against fig_action_observers registry (no duplicates)
```

### Migration Flow (fresh install vs upgrade path)

```
app.R startup
    |
    v
init_schema(con)           <-- creates base tables (notebooks, abstracts, etc.)
    |
    v
run_pending_migrations(con)
    |
    v
get_applied_migrations()
    -> CREATE TABLE IF NOT EXISTS schema_migrations
    -> SELECT version FROM schema_migrations
    |
    v
length(applied) == 0?
    YES -> bootstrap_existing_database()
           -> "notebooks" table exists? YES -> mark v001 applied (existing user)
                                        NO  -> no action (fresh install — proceed)
    NO  -> skip bootstrap
    |
    v
apply migrations NNN_description.sql in ascending version order
```

**Fresh install investigation target:** On a completely empty database, `bootstrap_existing_database()` correctly takes the NO branch and all migrations run. However, `init_schema()` is called before `run_pending_migrations()` and creates the base tables. If migration v001 SQL creates the same tables as `init_schema()`, running both on a fresh DB produces "table already exists" errors unless all migration SQL uses `CREATE TABLE IF NOT EXISTS`. Each migration file must be audited for idempotency on fresh databases.

### Async Task Lifecycle (citation network example)

```
User clicks "Build Network"
    |
    v
observeEvent(input$build_network)
    |
    v
old_poller <- progress_poller()
if (!is.null(old_poller)) old_poller$destroy()   <-- destroy old poller before creating new
    |
    v
create interrupt_flag file + progress_file
    |
    v
poller <- observe({ invalidateLater(1000); read_progress(pf) })
progress_poller(poller)   <-- store new poller
    |
    v
network_task$invoke(...)   <-- mirai worker runs BFS in separate process
    |
    (time passes)
    |
    v
observe({ result <- network_task$result(); req(result) })   <-- result handler fires
    |
    v
isolate({
    progress_poller()$destroy()    <-- clean up poller
    progress_poller(NULL)
    # process result, update current_network_data()
})
```

## Scaling Considerations

This is a local-first single-user application. Scaling is not relevant to this milestone. The reactive cleanup work improves correctness and memory efficiency within a single session.

| Concern | Relevance to This Milestone |
|---------|----------------------------|
| Long-running session | Observer accumulation is worst here — user opens/closes many items over hours without restarting |
| High paper count | More papers = more delete_observers registered; the registry guard prevents the O(N^2) accumulation |
| Repeated network builds | Multiple build cycles without fix = multiple live pollers consuming invalidateLater ticks per second |

## Anti-Patterns

### Anti-Pattern 1: observe() Reading and Writing the Same reactiveVal Without isolate()

**What people do:**
```r
observe({
  result <- task$result()
  refresh(refresh() + 1)   # reads AND writes refresh()
})
```

**Why it's wrong:** Reading `refresh()` inside `observe()` creates a reactive dependency. Writing `refresh()` invalidates that dependency. The observer re-fires. Infinite loop. This is the exact scenario documented in CLAUDE.md.

**Do this instead:**
```r
observe({
  result <- task$result()        # only trigger — unguarded
  isolate({
    refresh(refresh() + 1)       # isolated read + write
    showNotification(...)        # any other reactive ops also go here
  })
})
```

### Anti-Pattern 2: Registering Dynamic Observers Inside renderUI Without a Registry Guard

**What people do:**
```r
output$gallery <- renderUI({
  fig_refresh()   # reads counter to trigger re-render
  lapply(figures, function(fig) {
    observeEvent(input[[paste0("keep_", fig$id)]], { ... })
    # renders UI AND registers observers in the same block
  })
})
```

**Why it's wrong:** renderUI fires every time `fig_refresh()` changes. Each fire creates a new set of observers for the same input IDs. After N clicks, there are N live observers per figure.

**Do this instead:** Register observers outside renderUI, in a dedicated `observe()` keyed off the figure list. Use a `reactiveValues` registry to prevent duplicates. renderUI renders HTML only.

### Anti-Pattern 3: Missing req() on Resolved LLM Provider/Model

**What people do:**
```r
observeEvent(input$generate_btn, {
  req(input$nl_query)
  cfg <- config()
  provider <- provider_from_config(cfg, con())
  model    <- resolve_model_for_operation(cfg, "query_build")
  # No guard — if provider or model is NULL, next line throws
  result <- provider_chat_completion(provider, model, messages)
})
```

**Why it's wrong:** `provider_from_config()` can return a list with NULL fields or NULL itself. `resolve_model_for_operation()` can return NULL when no model is configured. The downstream call throws an uninformative error.

**Do this instead:**
```r
req(provider, model)
```
Placed immediately after resolution. The existing manual `if (is.null(provider$api_key)...)` check handles the API key guidance message but does not prevent the crash when `provider` itself is NULL.

### Anti-Pattern 4: ensure_ragnar_store() Opening a Connection Without Closing It on Error

**What happens:** `ensure_ragnar_store()` calls `ragnar::ragnar_store_connect()` which opens a DuckDB connection. If the function errors partway through setup (e.g., embed function attachment fails), the partially-initialized `store` object falls out of scope without `DBI::dbDisconnect(store@con)` being called.

**Why it's wrong:** DuckDB connections are file locks. Orphaned connections block future opens to the same store file until GC collects them — timing is non-deterministic.

**Do this instead:** Wrap the creation path in `tryCatch` with an explicit disconnect on the error branch:
```r
store <- tryCatch({
  s <- ragnar::ragnar_store_connect(store_path)
  s@embed <- make_embed_function(provider, embed_model)
  s
}, error = function(e) {
  if (exists("s") && !is.null(s)) {
    try(DBI::dbDisconnect(s@con), silent = TRUE)
  }
  NULL
})
```

### Anti-Pattern 5: Poller Not Destroyed Before Starting a New Build

**What people do:**
```r
observeEvent(input$build_network, {
  poller <- observe({ invalidateLater(1000); ... })
  progress_poller(poller)   # overwrites old value but old poller keeps running
})
```

**Why it's wrong:** The old `observe()` instance continues to fire every second indefinitely. After N builds, N pollers are running simultaneously, all reading from files that may no longer exist.

**Do this instead:**
```r
observeEvent(input$build_network, {
  old <- progress_poller()
  if (!is.null(old)) old$destroy()
  poller <- observe({ invalidateLater(1000); ... })
  progress_poller(poller)
})
```

## Integration Points

### Cross-Module Reactive Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `mod_document_notebook` to `mod_slides` | `slides_trigger` reactiveVal passed as argument | Correct — one-directional push, no mutual dependency |
| Discovery modules to `mod_search_notebook` | `discovery_request` reactiveVal in app.R | Producer-consumer; search nb polls for new requests |
| `mod_citation_network` from `mod_search_notebook` | `seed_ids_r` reactive argument | Search nb pushes selected paper IDs as seeds |
| `mod_citation_network` from `mod_bulk_import` / `mod_citation_audit` | Same `seed_ids_r` mechanism | Consistent pattern across all entry points |
| All modules to `con()` | Passed as reactive argument to every module | Single shared DuckDB connection — all modules share the same DB |
| All modules to `config()` | Passed as reactive argument | YAML config reactive, re-reads on change |

### Observer Accumulation Integration Points (the fix targets)

| Module | Observer Type | Accumulation Trigger | Fix |
|--------|--------------|---------------------|-----|
| `mod_document_notebook.R` | `fig_action_observers` (keep/ban/retry per figure) | `output$figure_gallery` renderUI re-fires on every `fig_refresh()` increment | Registry guard at line 1023 exists. Verify destroy block at lines 932-937 is reached by all code paths that change document selection. |
| `mod_document_notebook.R` | `extract_observers[["view_"]]` (view figures toggle per doc) | `output$doc_list` renderUI re-fires on every `doc_refresh()` increment | Registry guard at line 782 exists. Confirm no bypass paths. |
| `mod_search_notebook.R` | `type_chip_observers` (document type chips 1-N) | Chip UI rebuilt when type list changes | `type_chip_observers[[i]] <<- observeEvent(...)` always overwrites without destroying old. Add `if (!is.null(type_chip_observers[[i]])) type_chip_observers[[i]]$destroy()` before re-registering. |
| `mod_search_notebook.R` | `delete_observers` (delete paper per paper) | `observe({ papers <- filtered_papers() })` re-fires on filter change | Registry guard at line 1540 exists and is correct. No change needed. |
| `mod_search_notebook.R` | `block_journal_observers` / `unblock_journal_observers` | `observe({ papers <- filtered_papers() })` or blocklist reload | Registry guards at lines 2094 and 2162 follow the same pattern. Confirm `unblock_journal_observers` guard is exhaustive across all re-render paths. |
| `mod_slides.R` | Chip click handlers 1-10 | Registered once at module init via `lapply` | No accumulation. Add `isolate()` on `current_chips()` read inside handlers for consistency. |
| `mod_citation_network.R` | `progress_poller` polling observer | New build started before old one is canceled | Verify old poller is destroyed before creating new one in `observeEvent(input$build_network)`. |

### New vs Modified Components

All changes are modifications to existing files. No new modules or helper files are required for this milestone.

| File | Change Type | What Changes |
|------|-------------|-------------|
| `R/mod_document_notebook.R` | Modify | Verify fig_action_observer destroy path is always reached; audit remaining `fig_refresh()` calls for missing `isolate()` |
| `R/mod_search_notebook.R` | Modify | Fix `type_chip_observers` registration — add destroy-before-replace; verify `block_journal_observers` and `unblock_journal_observers` guards are exhaustive |
| `R/mod_citation_network.R` | Modify | Add old-poller destroy before new poller creation; add `isolate()` wrapping on secondary reactive writes in network task result handler |
| `R/mod_slides.R` | Modify | Add `isolate()` on `current_chips()` read inside chip click handlers; verify `generation_state` writes in ExtendedTask result handler use `isolate()` |
| `R/mod_query_builder.R` | Modify | Add `req(provider, model)` after resolution in `observeEvent(input$generate_btn)` |
| `R/db_migrations.R` and `migrations/*.sql` | Investigate + possibly modify | Audit fresh-install bootstrap: confirm `init_schema()` and migration SQL do not conflict; ensure all migration files use `CREATE TABLE IF NOT EXISTS` |
| `R/_ragnar.R` | Modify | Fix `ensure_ragnar_store()` connection leak — add explicit `DBI::dbDisconnect(store@con)` on the error path |

## Suggested Build Order

Build order is driven by two constraints: risk of regression, and logical dependency between fixes.

**Phase 1 — Pure additive guards (lowest risk, no behavior change)**

- `R/mod_query_builder.R`: add `req(provider, model)` after resolution
- `R/mod_slides.R`: add `isolate()` on `current_chips()` reads inside chip handlers

These are additive-only changes. They add defensive guards without modifying any control flow. Risk of regression is near-zero. Smoke test after: `shiny::runApp()` to confirm app starts cleanly.

**Phase 2 — Observer lifecycle fixes (moderate risk, targeted)**

- `R/mod_citation_network.R`: add old-poller destroy in build handler; audit isolate() in result handler
- `R/mod_document_notebook.R`: verify and patch fig_action_observer destroy path; audit fig_refresh isolate() calls
- `R/mod_search_notebook.R`: fix type_chip_observers registration (highest accumulation risk in search module); verify block/unblock journal observer guards

Each change should be followed by a smoke test before the next. mod_citation_network.R first because the poller fix is the simplest to verify (trigger two builds in sequence, confirm only one poller fires).

**Phase 3 — Infrastructure investigation (isolated from reactive work)**

- `R/db_migrations.R` + `migrations/*.sql`: audit fresh-install bootstrap ordering; test with empty database
- `R/_ragnar.R`: fix `ensure_ragnar_store()` connection leak on error path

The ragnar fix is last because it touches async infrastructure exercised by integration tests. Run `testthat::test_dir("tests/testthat")` after this phase.

**Phase 4 — Error handling standardization (cross-cutting polish)**

- Standardize error toast pattern across document and search notebook preset handlers
- Verify z-index for error toasts behind synthesis modal (CSS-only)
- Add input validation to `match_aa_model()` for NULL provider/model inputs
- Reduce unnecessary `renderUI` re-queries during processing (add `req(!is_processing())` guard before reactive reads that trigger DB queries)

These are polish and defensive hardening. All reactive and infrastructure fixes should pass smoke tests before starting this phase.

## Sources

- Direct code inspection: `R/mod_slides.R`, `R/mod_document_notebook.R`, `R/mod_search_notebook.R`, `R/mod_citation_network.R`, `R/mod_query_builder.R`, `R/db_migrations.R`, `R/_ragnar.R`
- Project context: `.planning/PROJECT.md` (v20.0 milestone description, known tech debt section)
- CLAUDE.md project instructions: `observe()` + `isolate()` pattern documentation (authoritative for this codebase)

---
*Architecture research for: Shiny Reactivity Cleanup (v20.0)*
*Researched: 2026-03-26*
