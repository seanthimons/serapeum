# Phase 13: Export-to-Seed Workflow - Research

**Researched:** 2026-02-12
**Domain:** R Shiny cross-module communication, navigation state preservation, reactive value passing
**Confidence:** HIGH

## Summary

Phase 13 implements seamless transition from viewing an abstract to launching a new seeded search, creating fluid discovery workflows. The core challenge is cross-module communication: the abstract detail view in mod_search_notebook needs to trigger navigation to mod_seed_discovery with pre-filled DOI, then create a new search notebook and navigate back to view it.

The existing codebase already has a working pattern for this: mod_seed_discovery, mod_query_builder, and mod_topic_explorer all return reactive values that app.R consumes to create notebooks and navigate to them. Phase 13 extends this pattern to work bidirectionally - instead of only flowing from discovery modules to search notebooks, we now need search notebooks to trigger discovery with a specific paper.

**Primary recommendation:** Use a reactiveVal in app.R as a bridge between modules. The search notebook sets a "seed request" reactive when user clicks "Use as Seed", and app.R observes this to navigate to discovery view and pre-fill the DOI input using updateTextInput().

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | Latest | Module communication via reactive values | Project standard, moduleServer pattern |
| bslib | Latest | UI framework | Project standard |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| None required | - | All functionality exists in base Shiny | - |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| reactiveVal bridge | URL query parameters | Query params add complexity (parsing, encoding), don't preserve state as cleanly |
| reactiveVal bridge | Session storage with JavaScript | Requires custom JS, less idiomatic for Shiny |
| Bidirectional reactive | Create new discovery module | Duplicates existing mod_seed_discovery logic unnecessarily |

**Installation:**
```r
# No new packages required - all functionality exists in current stack
```

## Architecture Patterns

### Recommended Project Structure
```
R/
├── mod_search_notebook.R   # MODIFY: Add "Use as Seed" button, return seed_request reactive
├── mod_seed_discovery.R    # MODIFY: Accept pre_fill_doi reactive, use updateTextInput
├── app.R                   # MODIFY: Wire seed_request -> navigation -> pre_fill_doi
└── db.R                    # NO CHANGES: Schema already supports all needed data
```

### Pattern 1: Bidirectional Module Communication via reactiveVal Bridge

**What:** Parent scope (app.R) mediates communication between peer modules using reactiveVal bridges. Module A returns a "request" reactive, app.R observes it and passes result to Module B as input.

**When to use:** When two peer modules need to communicate but neither should depend on the other directly.

**Example:**
```r
# In app.R (parent scope):
# Bridge reactive - set by search notebook, consumed by discovery
seed_request <- reactiveVal(NULL)

# Discovery module's pre-fill input - set by app.R
pre_fill_doi <- reactiveVal(NULL)

# Search notebook returns request when "Use as Seed" clicked
search_seed_request <- mod_search_notebook_server("search", con, notebook_id, pre_fill_doi = NULL)

# Discovery module accepts pre-fill
mod_seed_discovery_server("discover", con, config, pre_fill_doi)

# Wire the bridge
observeEvent(search_seed_request(), {
  req <- search_seed_request()
  if (is.null(req)) return()

  # Navigate to discovery view
  current_view("discover")

  # Pre-fill DOI
  pre_fill_doi(req$doi)
})

# Discovery module triggers notebook creation (existing pattern)
observeEvent(discovery_request(), {
  # ... existing notebook creation logic ...
  # After creation, navigate back to notebook view
  current_view("notebook")
  current_notebook(new_notebook_id)
})
```

**Source:** Existing pattern in app.R lines 862-952 (seed discovery), 954-1051 (query builder), 1053-1127 (topic explorer)

### Pattern 2: Programmatic Input Updates with updateTextInput

**What:** Server-side function to update input values, triggering reactive dependencies.

**When to use:** Pre-filling form fields based on navigation state or external triggers.

**Example:**
```r
# In mod_seed_discovery_server:
observeEvent(pre_fill_doi(), {
  doi <- pre_fill_doi()
  if (!is.null(doi)) {
    updateTextInput(session, "doi_input", value = doi)
    # Optionally auto-trigger lookup
    # updateActionButton(session, "lookup_btn", label = "Look Up")
    # Or use shinyjs::click("lookup_btn") to simulate click
  }
})
```

**Source:** Context7 Shiny module examples, R/mod_settings.R:285-289 (existing usage)

### Pattern 3: Navigation State Preservation with current_view/current_notebook

**What:** App-level reactiveVals track current view and notebook. Modules read these but don't set them directly. Navigation happens in app.R.

**When to use:** Single-page app with multiple views, need consistent navigation.

**Example:**
```r
# In app.R:
current_view <- reactiveVal("welcome")  # "notebook", "discover", "settings", etc.
current_notebook <- reactiveVal(NULL)   # Notebook ID or NULL

# Navigation pattern:
observeEvent(input$discover_paper, {
  current_view("discover")
  current_notebook(NULL)  # Clear notebook selection when switching views
})

# Main content switches based on view
output$main_content <- renderUI({
  view <- current_view()
  nb_id <- current_notebook()

  if (view == "discover") return(mod_seed_discovery_ui("discover"))
  if (view == "notebook" && !is.null(nb_id)) return(mod_search_notebook_ui("search"))
  # ... etc
})
```

**Source:** app.R:176-179, 434-447 (existing navigation pattern)

### Anti-Patterns to Avoid

- **Direct module-to-module calls:** Don't have mod_search_notebook call mod_seed_discovery directly - breaks encapsulation and creates circular dependencies
- **Global state outside app.R:** Don't use <<- or global variables - use reactive bridges in parent scope
- **Implicit navigation:** Don't change current_view() from inside modules - navigation should be explicit in app.R

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| DOI validation | Custom regex | utils_doi::normalize_doi() | Already exists in codebase, handles edge cases |
| Module communication | Custom event system | Shiny reactive() + observeEvent() | Built-in, well-tested, idiomatic |
| Input pre-filling | Custom JS messages | updateTextInput() | Built-in, type-safe, reactive-aware |
| State persistence | localStorage + JS | reactiveVal() in app.R | Simpler, server-side, no serialization issues |

**Key insight:** Shiny's reactive programming model already solves cross-module communication elegantly. Don't fight it by adding custom event systems or global state.

## Common Pitfalls

### Pitfall 1: Reactive Loop with Bidirectional Updates

**What goes wrong:** Module A updates reactive that triggers Module B, which updates a reactive that triggers Module A again, creating infinite loop.

**Why it happens:** Not using isolate() or ignoreInit = TRUE when observing reactive bridges.

**How to avoid:** Always use `ignoreInit = TRUE` on observers watching bridge reactiveVals, and use `req()` to gate on non-NULL values.

**Warning signs:** Browser becomes unresponsive, R session uses 100% CPU, repeated console messages.

**Example fix:**
```r
observeEvent(seed_request(), {
  req(seed_request())  # Only proceed if not NULL
  # ... handle request ...
  # Clear request after handling to prevent re-trigger
  seed_request(NULL)
}, ignoreInit = TRUE)
```

### Pitfall 2: Lost State During Navigation

**What goes wrong:** User navigates from search notebook → discovery → creates new notebook, but original search notebook's filters/selections are lost.

**Why it happens:** Modules are re-rendered when switching views, losing local reactiveVal state.

**How to avoid:** Persist view-specific state to database (existing pattern: search_filters in notebooks table).

**Warning signs:** User complains filters reset, sort order forgotten, keyword selections cleared.

**Example fix:**
```r
# In mod_search_notebook:
# Save filter state to database when changed
observeEvent(input$filter_has_abstract, {
  nb_id <- notebook_id()
  req(nb_id)

  filters <- get_current_filters()
  filters$has_abstract <- input$filter_has_abstract
  update_notebook(con(), nb_id, search_filters = filters)
}, ignoreInit = TRUE)

# Restore filter state when notebook loads
observe({
  nb_id <- notebook_id()
  req(nb_id)

  nb <- get_notebook(con(), nb_id)
  filters <- parse_filters(nb$search_filters)
  updateCheckboxInput(session, "filter_has_abstract", value = filters$has_abstract)
})
```

**Source:** R/mod_search_notebook.R:323-363 (existing pattern for filter persistence)

### Pitfall 3: DOI Pre-fill Without Auto-Lookup

**What goes wrong:** DOI is pre-filled but user still has to manually click "Look Up" button, breaking seamless workflow.

**Why it happens:** updateTextInput() doesn't trigger action button automatically.

**How to avoid:** Consider auto-triggering lookup when pre_fill_doi is set, OR change UI to show paper preview immediately if DOI is known.

**Warning signs:** User feedback that workflow feels clunky, requires extra click.

**Example fix:**
```r
# Option 1: Auto-trigger lookup button (requires shinyjs)
observeEvent(pre_fill_doi(), {
  doi <- pre_fill_doi()
  if (!is.null(doi) && nchar(doi) > 0) {
    updateTextInput(session, "doi_input", value = doi)
    shinyjs::click("lookup_btn")  # Simulate button click
  }
})

# Option 2: Fetch paper directly without requiring button click
observeEvent(pre_fill_doi(), {
  doi <- pre_fill_doi()
  if (!is.null(doi) && nchar(doi) > 0) {
    updateTextInput(session, "doi_input", value = doi)
    # Trigger lookup logic directly
    paper <- get_paper(doi, email, api_key)
    seed_paper(paper)
  }
})
```

### Pitfall 4: Unclear Return Path After Seed Search

**What goes wrong:** User launches seed search, creates notebook, but has no obvious way to return to original notebook.

**Why it happens:** Navigation to new notebook is one-way - no "back" affordance.

**How to avoid:** Consider breadcrumbs, back button, or notification with link to return to original notebook.

**Warning signs:** User confusion about navigation, complaints about lost context.

**Example fix:**
```r
# In app.R after creating seed notebook:
showNotification(
  div(
    "Created seed notebook: ", strong(new_notebook_name),
    br(),
    actionLink("return_to_original", "Return to previous notebook")
  ),
  type = "message",
  duration = NULL  # Keep until dismissed
)

observeEvent(input$return_to_original, {
  current_notebook(original_notebook_id)
  current_view("notebook")
  removeNotification(notification_id)
})
```

## Code Examples

Verified patterns from existing codebase:

### Cross-Module Communication via Reactive Return

```r
# From app.R:862-870 (seed discovery pattern)
discovery_request <- mod_seed_discovery_server("seed_discovery", reactive(con), config_file_r)

observeEvent(discovery_request(), {
  req <- discovery_request()
  if (is.null(req)) return()

  # Create notebook with citation filter
  filters <- list(
    citation_filter = citation_filter,
    citation_type = req$citation_type,
    seed_paper_id = req$seed_paper$paper_id
  )

  nb_id <- create_notebook(con, req$notebook_name, "search",
                           search_query = NULL,
                           search_filters = filters)

  # Navigate to new notebook
  notebook_refresh(notebook_refresh() + 1)
  current_notebook(nb_id)
  current_view("notebook")
})
```

### Input Pre-filling with updateTextInput

```r
# From R/mod_settings.R:285-289 (settings initialization)
observe({
  cfg <- config_rv()

  or_key <- get_db_setting(con(), "openrouter_api_key") %||%
            get_setting(cfg, "openrouter", "api_key") %||% ""
  updateTextInput(session, "openrouter_key", value = or_key)

  oa_email <- get_db_setting(con(), "openalex_email") %||%
              get_setting(cfg, "openalex", "email") %||% ""
  updateTextInput(session, "openalex_email", value = oa_email)
})
```

### Filter State Persistence

```r
# From R/mod_search_notebook.R:323-363 (filter persistence)
# Restore filter state when notebook changes
observe({
  nb_id <- notebook_id()
  req(nb_id)

  nb <- get_notebook(con(), nb_id)
  req(nb$type == "search")

  filters <- if (!is.na(nb$search_filters) && nchar(nb$search_filters) > 0) {
    tryCatch(jsonlite::fromJSON(nb$search_filters), error = function(e) list())
  } else {
    list()
  }

  has_abstract <- if (!is.null(filters$has_abstract)) filters$has_abstract else TRUE
  updateCheckboxInput(session, "filter_has_abstract", value = has_abstract)
})

# Save filter state when changed
observeEvent(input$filter_has_abstract, {
  nb_id <- notebook_id()
  req(nb_id)

  nb <- get_notebook(con(), nb_id)
  filters <- parse_existing_filters(nb)
  filters$has_abstract <- input$filter_has_abstract

  update_notebook(con(), nb_id, search_filters = filters)
}, ignoreInit = TRUE)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Global variables for module communication | Reactive values in parent scope | Shiny 1.5+ (2020) | Better encapsulation, testability |
| Manual JavaScript for input updates | updateTextInput family | Core Shiny | Type-safe, reactive-aware |
| Custom event systems | observeEvent + reactiveVal | Core Shiny | Simpler, more maintainable |
| Session storage for state | Database persistence | Phase 5-11 (v2.0) | State survives app restart |

**Deprecated/outdated:**
- `observe({})` without explicit dependencies - use `observeEvent()` for clarity
- `reactive({})` without `req()` gating - causes unnecessary re-computation on NULL
- Direct input$X modification in JavaScript - use Shiny's update functions

## Open Questions

1. **Should seed search auto-execute or require confirmation?**
   - What we know: Current seed discovery requires user to click "Fetch" after looking up paper
   - What's unclear: Whether "Use as Seed" should skip lookup step and go straight to results
   - Recommendation: Default to "cites" direction and auto-execute (fewer clicks), but keep direction selector visible so user can change before execution

2. **Should original notebook context be preserved visually?**
   - What we know: Success criteria says "user's current search results persist", implying navigation back should be possible
   - What's unclear: Whether this means breadcrumbs, back button, or just relying on sidebar selection
   - Recommendation: Add notification with actionLink to return to original notebook (see Pitfall 4 example)

3. **Should "Use as Seed" be in abstract detail or on paper cards?**
   - What we know: Issue #67 mentions both "modal" and "UI item on page" as possibilities
   - What's unclear: Exact placement in UI
   - Recommendation: Add to detail_actions output alongside close button (less visual clutter, detail view already has context)

## Sources

### Primary (HIGH confidence)
- /rstudio/shiny - Module communication patterns, reactive expressions, update functions
- /hadley/mastering-shiny - Module design patterns, reactive values
- Existing codebase (app.R, R/mod_seed_discovery.R, R/mod_search_notebook.R) - Working implementation of same patterns

### Secondary (MEDIUM confidence)
- [Shiny updateQueryString](https://shiny.posit.co/r/reference/shiny/latest/updatequerystring.html) - URL state management (not chosen, but viable alternative)
- [bslib navigation containers](https://rstudio.github.io/bslib/reference/navset.html) - Navigation patterns (informational)

### Tertiary (LOW confidence)
- None - all patterns verified against existing codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new libraries needed, all patterns exist in codebase
- Architecture: HIGH - Identical pattern to 3 existing discovery modules
- Pitfalls: HIGH - Verified against actual issues in similar modules (filter persistence, navigation state)

**Research date:** 2026-02-12
**Valid until:** 60 days (stable stack, no fast-moving dependencies)
