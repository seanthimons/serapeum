# Async Result Reactive Loop Diagnosis

**Date:** 2026-03-13
**Trigger:** Adding or rebuilding the embedding index caused an infinite cascade of success toasts like "Re-indexed 6 items successfully."
**Status:** Re-index handlers fixed in search and document notebooks. Broader audit still needed.

## Summary

This was not a modal bug. The UI was stacking repeated `showNotification()` toasts because the async task result handler re-triggered itself after task completion.

The root pattern is:

1. A module uses `observe({ result <- task$result(); ... })` to handle an async completion.
2. Inside that same observer, the code reads and writes other reactives such as:
   - poller state (`reindex_poller()`)
   - temp-file state (`current_interrupt_flag()`, `current_progress_file()`)
   - refresh counters (`paper_refresh()`, `doc_refresh()`)
3. Those reads establish reactive dependencies.
4. When the handler later writes one of those same reactives, the observer invalidates and runs again.
5. The task result is still cached as complete, so the success branch replays and emits the same notification again.

This is a recurring Shiny failure mode for async work: a result observer is accidentally allowed to depend on cleanup or UI-refresh state that should be treated as write-only side effects.

## Confirmed Affected Code

- `R/mod_search_notebook.R`
  - Re-index result handler used `observe({ ... })`
  - Success branch bumped `paper_refresh(paper_refresh() + 1)`
- `R/mod_document_notebook.R`
  - Re-index result handler used `observe({ ... })`
  - Success branch bumped `doc_refresh(doc_refresh() + 1)`

## Applied Fix

Both re-index handlers were changed to use the same safe pattern:

- `observeEvent(reindex_task$result(), ignoreNULL = TRUE, { ... })`
- `last_processed_reindex <- reactiveVal(NULL)` guard
- reset dedupe state before each new task invocation
- `isolate({ ... })` around cleanup + UI side effects
- `paper_refresh(isolate(paper_refresh()) + 1)` / `doc_refresh(isolate(doc_refresh()) + 1)`
- stable notification id `ns("reindex_status")` so replacement occurs even if duplication regresses

## Why This Keeps Recurring

The codebase has several async modules built from similar patterns:

- create temp files
- start poller
- invoke `ExtendedTask`
- consume `task$result()`
- clean up reactives
- refresh UI counters
- show a toast

That structure is easy to copy, but it is only safe when the result handler is carefully isolated from every reactive except the task result itself.

The existing bulk import code already contains the correct pattern:

- `last_processed_result <- reactiveVal(NULL)`
- `if (identical(result, isolate(last_processed_result()))) return()`
- `isolate({ ... })`

That pattern should be treated as the standard for async result handlers.

## Follow-Up Audit Targets

These handlers should be reviewed for the same anti-pattern:

- `R/mod_search_notebook.R`
  - batch import result handler around `batch_import_task$result()`
- `R/mod_citation_network.R`
  - network build result handler around `network_task$result()`
- any other `observe({ result <- <task>$result() ... })` blocks

The specific risk signs are:

- result handled in plain `observe()` instead of `observeEvent()`
- cleanup code reading/writing reactiveVals in the same block
- refresh counters updated inline with `x(x() + 1)`
- notifications or modal teardown done in the same observer without `isolate()`

## Recommended Standard

For all async result handlers, standardize on:

```r
last_processed_result <- reactiveVal(NULL)

observeEvent(task$result(), ignoreNULL = TRUE, {
  result <- task$result()
  if (identical(result, isolate(last_processed_result()))) return()
  last_processed_result(result)

  isolate({
    # cleanup
    # state updates
    # notifications
  })
})
```

Additionally:

- reset `last_processed_result(NULL)` immediately before each fresh task invoke
- prefer stable notification ids for status toasts
- avoid inline self-read increments without `isolate()`

## Notes

This class of bug can present as:

- infinite toasts
- repeated `removeModal()` / modal flicker
- duplicated writes to DB
- repeated import-result dialogs
- repeated "partial result" or "failed" notifications after cancellation

The visible symptom depends on which side effects the handler performs after the task completes.
