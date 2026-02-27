# Phase 38: Select-All Import - Research

**Researched:** 2026-02-26
**Domain:** R/Shiny UI state management + async batch import
**Confidence:** HIGH

## Summary

Phase 38 adds a "select all" checkbox to search notebook results and converts the existing synchronous single-paper import into an async batch import with progress tracking. The codebase already has all the building blocks: individual paper checkboxes, a synchronous import modal with notebook selector, ExtendedTask + mirai patterns (from Phase 35 bulk import and citation network), and cross-process interrupt/progress infrastructure.

The main work is: (1) adding a select-all checkbox header with tri-state logic, (2) refactoring the existing synchronous import into an ExtendedTask-based async flow for batches >= 50, (3) adding a confirmation modal for 100+ papers, and (4) showing categorized results.

**Primary recommendation:** Reuse the `mod_bulk_import` ExtendedTask + progress pattern directly. The existing `run_bulk_import` function already handles batch OpenAlex queries, progress reporting, and interrupt/cancel. The select-all import can delegate to the same backend after converting abstract IDs to documents.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Select-all selects ALL papers matching current filters (not just visible/rendered papers)
- Tri-state checkbox: unchecked -> indeterminate (some selected) -> checked (all selected)
- Checkbox placed in the header row above search results (near result count/sort controls)
- Changing any filter resets the select-all state and clears all individual selections
- After select-all, clicking an individual paper's checkbox deselects just that paper (rest stay selected)
- Select-all checkbox transitions to indeterminate state when some papers are deselected
- If user has partial individual selections and clicks select-all, it adds the remaining unselected papers (additive, not toggle-off)
- Selection count displayed on the import button: "Import Selected (12)" -- not a separate live counter
- Confirmation modal when importing 100+ papers: "You're about to import X papers. This may take a few minutes. Continue?"
- Import is cancellable mid-way -- papers already imported stay, remaining are skipped
- Progress display matches the existing network graph building modal pattern
- After completion: categorized results summary (Imported: X, Duplicates skipped: Y, Failed: Z) with expandable details
- Uses ExtendedTask for large batches (50+ papers) per success criteria
- Modal with notebook selector dropdown -- user picks which document notebook to import into
- Include a "+ New Notebook" option that allows creating a notebook inline from the import modal
- Duplicates (papers already in target notebook) are skipped silently and reported in the results summary
- After import completes, user stays on the search results page (no auto-navigation)

### Claude's Discretion
- Exact checkbox styling and positioning within the header row
- How to efficiently track select-all state internally (set-based vs flag-based)
- ExtendedTask configuration and progress reporting implementation details
- Error handling for individual paper import failures within a batch
- How the "+ New Notebook" inline creation UI is implemented

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SLCT-01 | User can select all filtered abstracts with a single checkbox | Tri-state checkbox in header row; `filtered_papers()` reactive provides all matching papers; select-all toggles a flag that includes all filtered IDs |
| SLCT-02 | User can import all selected abstracts into a document notebook | Existing import modal pattern (lines 2223-2313 mod_search_notebook.R) extended for batch; notebook selector + "+ New Notebook" reused from current flow |
| SLCT-03 | Batch import shows progress for large selections (>50 papers) | ExtendedTask + mirai pattern from mod_bulk_import.R; progress file + JS polling; confirmation at 100+ |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | 1.9+ | Reactive framework | Already in use; ExtendedTask support |
| mirai | 1.0+ | Async worker execution | Already in use for Phase 35, 37 bulk imports |
| bslib | 0.7+ | Bootstrap 5 UI components | Already in use; card/modal/layout primitives |
| DuckDB | 1.1+ | Local SQL database | Already in use; abstract/document storage |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| shinyjs (via custom JS) | N/A | Tri-state checkbox manipulation | No R-native tri-state checkbox; use custom JS message handler |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom JS tri-state | shinyWidgets | shinyWidgets doesn't have tri-state; custom JS is simpler |
| New ExtendedTask | Reuse bulk_import backend | Reusing run_bulk_import would require DOI-based workflow; creating documents directly from abstracts is simpler for this use case |

## Architecture Patterns

### Pattern 1: Select-All State Management (Flag + Exception Set)
**What:** Track select-all using a boolean flag + a set of individually toggled exceptions, rather than storing every selected paper ID.
**When to use:** When "all filtered" could be hundreds of papers and the filter set changes dynamically.
**Example:**
```r
# State: list(all_selected = TRUE/FALSE, exceptions = character())
# When select-all is TRUE, effective selection = all filtered IDs - exceptions
# When select-all is FALSE, effective selection = exceptions (individually checked)
select_all_state <- reactiveVal(list(all_selected = FALSE, exceptions = character()))

# Compute effective selected set
effective_selected <- reactive({
  state <- select_all_state()
  all_ids <- filtered_papers()$id
  if (state$all_selected) {
    setdiff(all_ids, state$exceptions)
  } else {
    intersect(state$exceptions, all_ids)  # Only keep valid IDs
  }
})
```

### Pattern 2: Tri-State Checkbox via Custom JS Message
**What:** R has no native tri-state checkbox. Use `session$sendCustomMessage` to toggle the indeterminate property.
**When to use:** Whenever selection state is partial (some but not all selected).
**Example:**
```javascript
// In www/js/select-all.js
Shiny.addCustomMessageHandler('setCheckboxState', function(data) {
  var cb = document.getElementById(data.id);
  if (cb) {
    cb.checked = data.checked;
    cb.indeterminate = data.indeterminate;
  }
});
```

### Pattern 3: Async Import with ExtendedTask (from mod_bulk_import.R)
**What:** For batches >= 50, use ExtendedTask + mirai to run import in background worker.
**When to use:** Large batch imports that would block the Shiny session.
**Example:**
```r
# Follows exact same pattern as mod_bulk_import.R lines 50-68
import_task <- ExtendedTask$new(function(abstract_ids, notebook_id, db_path, ...) {
  mirai::mirai({
    source("R/db.R")
    # Import logic here
  }, abstract_ids = abstract_ids, ...)
})
```

### Pattern 4: Filter Reset Clears Selection
**What:** Any filter change resets select-all state.
**When to use:** Per user decision -- filter changes invalidate the selection context.
**Example:**
```r
# Watch filtered_papers() -- when it changes, reset selection state
observeEvent(filtered_papers(), {
  select_all_state(list(all_selected = FALSE, exceptions = character()))
  # Reset select-all checkbox UI to unchecked
  session$sendCustomMessage('setCheckboxState', list(
    id = ns("select_all_cb"), checked = FALSE, indeterminate = FALSE
  ))
}, ignoreInit = TRUE)
```

### Anti-Patterns to Avoid
- **Storing all selected IDs in a reactiveVal for large sets:** O(n) on every filter change; use flag + exception pattern instead
- **Synchronous import for large batches:** Blocks UI; always use ExtendedTask for 50+ papers
- **Polling individual checkbox inputs in a loop:** Current code iterates all checkboxes on every change (lines 1270-1283); this is fine for <100 papers but the select-all pattern should bypass it

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tri-state checkbox | Custom R widget | JS message handler + HTML checkbox | Browser natively supports `indeterminate` property; tiny JS |
| Progress polling | Custom timer | Existing `read_import_progress` + JS handler | Proven pattern in bulk import |
| Interrupt/cancel | Custom mechanism | `interrupt.R` functions | Cross-process flag files already battle-tested |
| Duplicate detection | SQL per-paper | Single SQL `IN (...)` query | One query vs N queries for duplicate checking |

## Common Pitfalls

### Pitfall 1: Checkbox Observer Loop
**What goes wrong:** Select-all sets individual checkboxes, which fires their observers, which updates selection state, which fires select-all state change.
**Why it happens:** Circular reactive dependency between select-all and individual checkboxes.
**How to avoid:** Use a "programmatic_update" flag to skip observer logic when changes are triggered by select-all. Or better: decouple the select-all state entirely from individual checkbox inputs (use the flag + exception pattern so individual checkboxes read from state, not the other way around).
**Warning signs:** Infinite reactivity loop, browser hang.

### Pitfall 2: Filter Change Race Condition
**What goes wrong:** User clicks select-all, then quickly changes a filter. The old select-all set gets imported.
**Why it happens:** Selection state and filter state are separate reactives.
**How to avoid:** Always compute effective selection from current `filtered_papers()` at import time, not from a cached set.
**Warning signs:** Importing papers that are no longer visible.

### Pitfall 3: DuckDB Connection in mirai Worker
**What goes wrong:** Passing a DuckDB connection to mirai fails silently (connections can't be serialized across processes).
**Why it happens:** mirai workers run in separate R processes.
**How to avoid:** Pass `db_path` and open a new connection in the worker (established pattern from bulk_import).
**Warning signs:** "external pointer is not valid" errors.

### Pitfall 4: Large IN Clause for Abstract Queries
**What goes wrong:** SQL `WHERE id IN (...)` with 500+ values can hit parser limits.
**Why it happens:** DuckDB has generous limits but string-building gets unwieldy.
**How to avoid:** Use batch queries (50 at a time) matching the OpenAlex batch pattern, or use temp tables for very large sets.
**Warning signs:** SQL syntax errors with large selections.

## Code Examples

### Current Import Flow (mod_search_notebook.R lines 2223-2313)
The existing synchronous import:
1. User clicks "Import Selected to Notebook" button
2. Modal shows with notebook selector (selectInput with "Create new..." option)
3. User selects target notebook and clicks "Import"
4. Synchronous loop: for each selected abstract, create_document + create_chunk
5. Notification: "Imported N paper(s)"

This must be replaced with async flow for 50+ papers.

### Current Selection Tracking (lines 1270-1283)
```r
observe({
  papers <- filtered_papers()
  if (nrow(papers) == 0) return()
  selected <- character()
  for (i in seq_len(nrow(papers))) {
    paper <- papers[i, ]
    checkbox_id <- paste0("select_", paper$id)
    if (isTRUE(input[[checkbox_id]])) {
      selected <- c(selected, paper$id)
    }
  }
  selected_papers(selected)
})
```
This iterates all checkboxes. For select-all, we should NOT programmatically check each checkbox (too many DOM updates). Instead, manage state separately.

### Existing Notebook Selector Pattern (lines 2246-2254)
```r
notebooks <- list_notebooks(con())
doc_notebooks <- notebooks[notebooks$type == "document", ]
choices <- c("Create new..." = "__new__")
if (nrow(doc_notebooks) > 0) {
  nb_choices <- setNames(doc_notebooks$id, doc_notebooks$name)
  choices <- c(choices, nb_choices)
}
updateSelectInput(session, "target_notebook", choices = choices)
```
Reuse this exact pattern for the batch import modal.

### Bulk Import ExtendedTask Pattern (mod_bulk_import.R lines 50-68)
```r
import_task <- ExtendedTask$new(function(...) {
  mirai::mirai({
    setwd(app_dir)
    source("R/db.R")
    # ... import logic
  }, ...)
})
```
Follow this pattern for the batch abstract import worker.

## Open Questions

1. **Individual checkbox DOM management with select-all**
   - What we know: Current checkboxes are rendered per-paper in `output$paper_list`. Select-all needs to visually update all of them.
   - What's unclear: Whether to actually toggle each checkbox DOM element or just show a visual overlay/state.
   - Recommendation: Don't toggle individual checkbox DOM elements. Instead, when select-all is active, render checkboxes as checked via `renderUI` re-render (the paper list already re-renders on filter changes). For performance, the select-all flag drives checkbox `value` parameter in the next render cycle.

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `R/mod_search_notebook.R` - Current import flow, selection tracking, paper list rendering
- Codebase analysis: `R/mod_bulk_import.R` - ExtendedTask + mirai pattern, progress modal, results modal
- Codebase analysis: `R/interrupt.R` - Cross-process interrupt and progress file infrastructure
- Codebase analysis: `R/bulk_import.R` - `write_import_progress` / `read_import_progress` functions
- Codebase analysis: `www/js/import-progress.js` - JS message handler for progress updates

### Secondary (MEDIUM confidence)
- Shiny ExtendedTask documentation - async task execution pattern
- Bootstrap 5 checkbox indeterminate state - native browser support for tri-state

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all libraries already in use in the project
- Architecture: HIGH - patterns directly derived from existing codebase (bulk import, citation network)
- Pitfalls: HIGH - based on actual Shiny reactive programming experience and codebase patterns

**Research date:** 2026-02-26
**Valid until:** 2026-03-26 (stable codebase patterns)
