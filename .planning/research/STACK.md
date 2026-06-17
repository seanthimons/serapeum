# Stack Research — v20.0 Shiny Reactivity Cleanup

**Domain:** R/Shiny reactive lifecycle correctness — observer leaks, isolate() guards, req() guards, error handling
**Researched:** 2026-03-26
**Confidence:** HIGH

## Executive Summary

**No new production dependencies required.** Everything needed to fix observer leaks, add isolate()/req() guards, and clean up lifecycle management is already in the existing stack. Shiny 1.11.1 (currently installed) provides all the primitives. The work is surgical code correction, not library acquisition.

One development tool — `reactlog` — is recommended for diagnosing observer dependency graphs during the audit. It is a dev-only tool, not shipped to users.

### Key Findings

- Shiny's `observe()` + `$destroy()` + `isolate()` are the correct primitives. They are already in use in the codebase — the problem is inconsistent application, not missing capabilities.
- The `lapply(seq_len(10), function(i) { observeEvent(...) })` pattern in `mod_slides.R` (chip handlers, line 1218) accumulates 10 permanent observers per modal open. These are never destroyed. This is the canonical observer accumulation bug.
- `mod_document_notebook.R` uses `reactiveValues()` to track per-document observers and explicit `$destroy()` calls (lines 722–935). This is the correct pattern and should be the template for fixing the slides module.
- Shiny 1.6+ `bindEvent()` is equivalent to `observeEvent()` but composable. No migration is warranted for this milestone — the benefit is marginal for the fixes targeted.
- `gargoyle` (event-based Shiny framework) is a full architectural shift — not appropriate for targeted cleanup.
- `reactlog` 1.1.1 is available on CRAN. It visualizes the reactive dependency graph and identifies over-utilized, never-utilized, and incorrectly-wired observers. Useful during audit but must not be enabled in production (memory leak, exposes reactive source).

---

## Recommended Stack (NO NEW PRODUCTION DEPENDENCIES)

### Core Technologies — Already Installed

| Technology | Version | Relevant Capabilities | Status |
|------------|---------|----------------------|--------|
| **shiny** | 1.11.1 | `observe()`, `observeEvent()`, `isolate()`, `req()`, `$destroy()`, `session$onSessionEnded()` | Current |
| **shiny** | 1.11.1 | `bindEvent()` (Shiny 1.6+) — composable event scoping | Current |
| **shiny** | 1.11.1 | `reactiveValues()` — named list for tracking dynamic observer handles | Current |
| **testthat** | 3.2.3 | `shiny::testServer()` for module-level reactive testing | Current |

### Development Tool — Add for This Milestone Only

| Tool | Version | Purpose | How to Use |
|------|---------|---------|------------|
| **reactlog** | 1.1.1 | Visualizes reactive dependency graph; identifies observer accumulation and orphaned dependencies | Dev session only — `reactlog::reactlog_enable()` before `runApp()`, then Ctrl+F3 in browser |

**Install:**
```r
install.packages("reactlog")
```

**CRITICAL:** Never enable `reactlog` in production. It is a memory leak and exposes reactive source code to any browser user. Use only in local dev sessions.

---

## What NOT to Add

| Library | Why Not | What to Use Instead |
|---------|---------|---------------------|
| **gargoyle** | Full architectural shift from reactive to event-based paradigm — requires rewriting all reactive logic across 18 modules. This milestone is targeted cleanup, not redesign. | `observeEvent()` with proper `$destroy()` lifecycle management |
| **shinyjs** | Its `disable()`, `enable()`, `show()`, `hide()` are useful but irrelevant to observer lifecycle bugs. Already used implicitly via bslib. | Native Shiny `req()` for guard patterns |
| **shinytest2** | Browser-level automation testing. Reactive correctness issues are diagnosed and tested more cheaply via `testServer()` for unit-level tests. | `shiny::testServer()` already in test suite |
| **shinyloadtest** | Performance load testing — completely out of scope for this milestone. | N/A |
| **bindEvent()** migration | Converting all `observeEvent()` to `observe() |> bindEvent()` is a refactor with no behavioral change. Mastering Shiny recommends `observeEvent()` for single-trigger cases. | Keep `observeEvent()`, use `bindEvent()` only for new code combining caching |

---

## Shiny Reactive Primitives Reference (for This Milestone)

### isolate() — Break Reactive Dependency

Reads a reactive value without registering as a dependency. Required in any `observe()` block that reads AND writes the same reactive.

```r
# WRONG — infinite loop: reading refresh() creates dependency,
# writing refresh() invalidates it, observer re-fires
observe({
  result <- task$result()
  refresh(refresh() + 1)  # self-invalidating
})

# CORRECT — isolate() breaks the dependency chain
observe({
  result <- task$result()  # only reactive trigger
  isolate({
    refresh(refresh() + 1)
    other_reactive_read_or_write()
  })
})
```

**Project pattern (from CLAUDE.md):** This is the established project standard. The fix is applying it consistently.

### req() — Guard Against NULL/Empty Inputs

Stops reactive execution silently when a value is falsy. Does not error the session.

```r
# Guard a single value
req(notebook_id())

# Guard multiple values (all must be truthy)
req(input$model, input$provider)

# Guard with explicit condition
req(!is.null(config()), nchar(config()$api_key) > 0)

# Preserve output on cancel (don't blank screen)
req(input$query, cancelOutput = TRUE)
```

**Missing req() sites identified in PROJECT.md milestone scope:**
- `provider` and `model` in query builder — NULL when settings not yet configured
- `section_filter` fallback — NULL when no sections match

### observer$destroy() — Manual Observer Lifecycle

`observe()` and `observeEvent()` return a handle. Call `$destroy()` to permanently remove the observer and its reactive dependencies.

```r
# Pattern: track handles, destroy before re-creating
obs_list <- reactiveValues()

observe({
  items <- dynamic_items()

  # Destroy previous observers for removed items
  for (id in names(obs_list)) {
    if (!id %in% names(items)) {
      obs_list[[id]]$destroy()
      obs_list[[id]] <- NULL
    }
  }

  # Create observers only for new items
  for (id in names(items)) {
    if (is.null(obs_list[[id]])) {
      local({
        local_id <- id
        obs_list[[local_id]] <<- observeEvent(input[[paste0("btn_", local_id)]], {
          # handle click for local_id
        }, ignoreInit = TRUE)
      })
    }
  }
})
```

**The slides chip bug (mod_slides.R line 1218):** `lapply(seq_len(10), ...)` runs at module load and creates 10 permanent observers. Each modal open does NOT re-run this lapply — the observers persist correctly. The bug is that `current_chips()` is read inside these observers but the `isolate()` guard may be missing if `current_chips` is also written from the same observer scope. **Audit required** to confirm whether this is a true accumulation or a dependency graph issue detectable via reactlog.

### session$onSessionEnded() — Session Cleanup Callback

Runs when the user closes their browser tab. Use for cleanup that must happen on disconnect, not on module lifecycle.

```r
session$onSessionEnded(function() {
  # Close DB connections, clean temp files, etc.
})
```

**Note:** Module sessions end when the module is removed from UI, not when the page closes. Use `on.exit()` for synchronous cleanup within module server functions.

---

## Patterns Already in Use (Template for Fixes)

These are correct patterns already in the codebase. New fixes should follow them.

### Correct: Per-Item Observer Tracking (mod_document_notebook.R)

```r
# Lines 198-206: Correct pattern
delete_doc_observers <- reactiveValues()
extract_observers   <- reactiveValues()
fig_action_observers <- reactiveValues()

# Lines 721-741: Guard before creating
if (is.null(delete_doc_observers[[doc$id]])) {
  delete_doc_observers[[doc$id]] <- observeEvent(input[[delete_id]], {
    # ...
  })
}

# Lines 932-938: Destroy before re-creating
for (old_id in names(fig_action_observers)) {
  obs_list <- fig_action_observers[[old_id]]
  if (is.list(obs_list)) {
    for (obs in obs_list) if (!is.null(obs)) obs$destroy()
  }
  fig_action_observers[[old_id]] <- NULL
}
```

### Correct: Poller with destroy() (mod_search_notebook.R)

```r
# Lines 791-862: Correct poller pattern
poller <- observe({
  result <- task$result()
  isolate({
    if (!is.null(result)) {
      poller$destroy()
      # handle result
    }
  })
})
```

### Correct: Seed observer management (mod_research_refiner.R)

```r
# Lines 309-313: Named observer list with destroy
seed_observers <- list()
observe({
  seeds <- seed_list()
  for (nm in names(seed_observers)) {
    if (!nm %in% names(seeds)) seed_observers[[nm]]$destroy()
  }
})
```

---

## Version Compatibility

| Package | Version | Reactive APIs Available |
|---------|---------|------------------------|
| shiny | 1.11.1 | All: `observe()`, `observeEvent()`, `isolate()`, `req()`, `bindEvent()` (1.6+), `$destroy()`, `$suspend()`, `$resume()` |
| testthat | 3.2.3 | `shiny::testServer()` for module testing |
| reactlog | 1.1.1 | `reactlog_enable()`, `reactlog_reset()`, Ctrl+F3 visualization |

---

## Shiny 1.11.1 Reactive Correctness Notes

From CRAN NEWS verified 2026-03-26:

- **v1.10.0 (2024-12-13):** `ExtendedTask` synchronous errors no longer stop the session — reduces session crashes from unhandled errors in async task handlers. Relevant to the `mod_bulk_import.R` and `mod_citation_audit.R` ExtendedTask observers.
- **v1.11.0 (2025-06-24):** Fix for `InputBinding` implementations that don't pass values to `subscribe` callbacks — no longer silently drop reactive notifications. May explain intermittent reactive misses in custom input patterns.
- **Reactive value GC (recent):** Reactive expressions release references to cached values immediately on invalidation rather than waiting for the next cache fill. This reduces memory pressure from large reactive values (e.g., paper result sets, citation network data frames).

No Shiny upgrade is needed — 1.11.1 is current.

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| `isolate()` inside `observe()` | Migrate to `observeEvent()` everywhere | `observeEvent()` only works when there is one clear trigger; `observe()` is correct when multiple reactive inputs are involved |
| `reactiveValues()` for observer handles | Named list in regular R scope | Named lists are not reactive — observers registered against them don't auto-update when the list changes |
| `req()` for NULL guards | `if (is.null(x)) return()` | `req()` provides cleaner cancellation semantics, integrates with Shiny's output blanking behavior, and is idiomatic |
| `$destroy()` for dynamic observers | Relying on session-end auto-destroy | Auto-destroy only fires on session end, not on reactive re-render — dynamic observers (in loops, per-item) accumulate within a session |

---

## Sources

- Shiny 1.11.1 CRAN NEWS — [https://cran.r-project.org/web/packages/shiny/news/news.html](https://cran.r-project.org/web/packages/shiny/news/news.html) — HIGH confidence (official)
- Shiny changelog — [https://rstudio.github.io/shiny/news/index.html](https://rstudio.github.io/shiny/news/index.html) — HIGH confidence (official)
- reactlog CRAN page — [https://cran.r-project.org/package=reactlog](https://cran.r-project.org/package=reactlog) — HIGH confidence (official, version 1.1.1 confirmed)
- reactlog documentation — [https://rstudio.github.io/reactlog/](https://rstudio.github.io/reactlog/) — HIGH confidence (official)
- Mastering Shiny Ch.15 Reactive building blocks — [https://mastering-shiny.org/reactivity-objects.html](https://mastering-shiny.org/reactivity-objects.html) — HIGH confidence
- Shiny observeEvent reference — [https://rstudio.github.io/shiny/reference/observeEvent.html](https://rstudio.github.io/shiny/reference/observeEvent.html) — HIGH confidence (official)
- bindEvent reference — [https://shiny.posit.co/r/reference/shiny/latest/bindevent.html](https://shiny.posit.co/r/reference/shiny/latest/bindevent.html) — HIGH confidence (official)
- Engineering Production-Grade Shiny Apps Ch.15 — [https://engineering-shiny.org/common-app-caveats.html](https://engineering-shiny.org/common-app-caveats.html) — MEDIUM confidence (community book)
- gargoyle CRAN — [https://cran.r-project.org/package=gargoyle](https://cran.r-project.org/package=gargoyle) — HIGH confidence (verified, ruled out)

---
*Stack research for: Serapeum v20.0 Shiny Reactivity Cleanup*
*Researched: 2026-03-26*
