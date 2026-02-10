# Architecture Research: Discovery Features in Shiny

**Domain:** Research discovery tools (seed paper search, query builder, topic exploration)
**Researched:** 2026-02-10
**Confidence:** HIGH

## Recommended Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      app.R (Orchestrator)                        │
│  - Notebook lifecycle management                                │
│  - Current view state                                            │
│  - Module coordination                                           │
├─────────────────────────────────────────────────────────────────┤
│                      Discovery Features Layer                    │
├──────────────┬──────────────┬──────────────┬───────────────────┤
│   Startup    │ Seed Paper   │ Query        │  Topic Explorer   │
│   Wizard     │ Search       │ Builder      │                   │
│   Module     │ Module       │ Module       │  Module           │
│              │              │              │                   │
│  (1st-time   │  (DOI/URL    │  (Visual     │  (Concept/field   │
│   guidance)  │   lookup)    │   filters)   │   navigation)     │
└──────┬───────┴──────┬───────┴──────┬───────┴───────┬───────────┘
       │              │              │               │
       ├──────────────┴──────────────┴───────────────┘
       │
┌──────┴──────────────────────────────────────────────────────────┐
│              Existing Search Notebook Module                     │
│  - Paper list, keyword panel, abstract viewer                   │
│  - Receives initial query from discovery modules                │
│  - Already 1,760 lines (DO NOT EXPAND FURTHER)                  │
└─────────────────────────────────┬───────────────────────────────┘
                                  │
┌─────────────────────────────────┴───────────────────────────────┐
│                    Infrastructure Layer                          │
├─────────────────────┬────────────────────┬──────────────────────┤
│  R/api_openalex.R   │  R/db.R            │  R/_ragnar.R         │
│  - Paper search     │  - DuckDB queries  │  - Vector search     │
│  - DOI lookup       │  - Schema          │  - Embedding         │
│  - Facet queries    │  - Migrations      │                      │
└─────────────────────┴────────────────────┴──────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **app.R** | Orchestration, notebook lifecycle, view switching | Reactive state management, module server calls |
| **mod_startup_wizard** | First-time user guidance, choice between seed/search/topic entry | Multi-step UI with conditional progression |
| **mod_seed_paper_search** | DOI/URL lookup, related paper discovery, relevance ranking | API calls to OpenAlex works endpoint, citation graph traversal |
| **mod_query_builder** | Visual query construction with facets (year, field, type, venue) | Reactive filter panel, OpenAlex filter syntax generation |
| **mod_topic_explorer** | Browse OpenAlex topics/concepts, navigate hierarchy | Tree/accordion UI, concept search, drill-down navigation |
| **mod_search_notebook** | Display results, keyword filtering, embedding, chat | Existing 1,760-line module - receives query from discovery features |
| **api_openalex.R** | External API communication, response parsing | httr2 requests, JSON handling, pagination |
| **db.R** | Data persistence, query execution, migrations | DuckDB operations, schema management |

## Recommended Project Structure

```
R/
├── mod_startup_wizard.R          # New: First-time user onboarding
├── mod_seed_paper_search.R       # New: Seed paper discovery
├── mod_query_builder.R           # New: Visual query construction
├── mod_topic_explorer.R          # New: Topic/concept browsing
├── mod_search_notebook.R         # Existing: DO NOT EXPAND (1,760 lines)
├── mod_document_notebook.R       # Existing: 420 lines
├── mod_settings.R                # Existing
├── mod_about.R                   # Existing
├── mod_slides.R                  # Existing
├── api_openalex.R                # Extend: Add DOI lookup, topic queries
├── api_openrouter.R              # Existing: LLM/embedding
├── db.R                          # Extend: Add startup state tracking (1,030 lines)
└── _ragnar.R                     # Existing: Vector search
```

### Structure Rationale

- **One module per feature**: Each discovery mode gets its own module to avoid bloating mod_search_notebook.R
- **Shared infrastructure**: All modules use common api_openalex.R and db.R
- **Module composition**: Startup wizard orchestrates calls to other discovery modules
- **Clear boundaries**: Discovery modules **output** a query/filter set; search notebook **receives** and executes it

## Architectural Patterns

### Pattern 1: Module as Query Producer/Consumer

**What:** Discovery modules produce query parameters, search notebook consumes them

**When to use:** When you need clean separation between "how query is built" and "what happens with query"

**Trade-offs:**
- **Pro:** Search notebook doesn't need to know about seed papers, query builders, or topic trees
- **Pro:** Discovery modules can be tested independently
- **Con:** Requires clear contract for query parameter format

**Example:**
```r
# In mod_seed_paper_search.R
mod_seed_paper_search_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    # Returns reactive containing query parameters
    query_params <- reactive({
      list(
        search_query = paste("related_to:", input$seed_doi),
        filters = list(
          from_year = input$year_start,
          to_year = input$year_end,
          is_oa = input$open_access_only
        )
      )
    })

    return(query_params)
  })
}

# In app.R
seed_query <- mod_seed_paper_search_server("seed_search")

observeEvent(input$start_seed_search, {
  params <- seed_query()
  # Create search notebook with these parameters
  create_notebook(con, params$search_query, params$filters)
})
```

### Pattern 2: Wizard with Conditional Routing

**What:** Multi-step wizard that routes to different discovery modules based on user choice

**When to use:** First-time user experience, onboarding flows

**Trade-offs:**
- **Pro:** Guides users to the right starting point
- **Pro:** Can be shown once or on-demand
- **Con:** Requires state management for "has user seen wizard?"

**Example:**
```r
# In mod_startup_wizard.R
mod_startup_wizard_ui <- function(id) {
  ns <- NS(id)
  tagList(
    # Step 1: Choose entry mode
    radioButtons(ns("entry_mode"), "How would you like to start?",
      choices = c("I have a seed paper (DOI/URL)" = "seed",
                  "I want to search by keywords" = "search",
                  "I want to explore topics" = "topics")
    ),
    # Step 2: Conditional content based on choice
    uiOutput(ns("entry_content")),
    # Step 3: Confirmation
    actionButton(ns("start_search"), "Create Search Notebook")
  )
}

# Conditionally render the appropriate discovery module
output$entry_content <- renderUI({
  switch(input$entry_mode,
    "seed" = mod_seed_paper_search_ui(ns("seed")),
    "search" = mod_query_builder_ui(ns("query")),
    "topics" = mod_topic_explorer_ui(ns("topics"))
  )
})
```

### Pattern 3: Reactive Parameter Passing

**What:** Pass reactive expressions (not values) between modules

**When to use:** Always, when modules need to react to changes in other modules

**Trade-offs:**
- **Pro:** Proper reactive chain
- **Pro:** Modules update automatically
- **Con:** Must validate inputs are reactive

**Example:**
```r
# In mod_query_builder.R
mod_query_builder_server <- function(id, config) {
  moduleServer(id, function(input, output, session) {
    # Validate config is reactive
    stopifnot(is.reactive(config))

    # Build query reactively
    query_params <- reactive({
      # Uses config() to access reactive value
      build_openalex_query(
        input$keywords,
        from_year = input$year_start,
        to_year = input$year_end,
        openalex_email = config()$openalex$email
      )
    })

    return(query_params)
  })
}
```

### Pattern 4: Namespace Composition for Nested Modules

**What:** Use ns() when calling child modules from parent modules

**When to use:** Whenever a module contains another module

**Trade-offs:**
- **Pro:** Prevents ID collisions
- **Pro:** Proper Shiny namespacing
- **Con:** Must remember to use ns() in UI calls

**Example:**
```r
# In mod_startup_wizard.R (parent)
mod_startup_wizard_ui <- function(id) {
  ns <- NS(id)
  tagList(
    # Nest child module with ns()
    mod_seed_paper_search_ui(ns("seed_module"))
  )
}

# Server side
mod_startup_wizard_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    # Call child module server (no ns needed here)
    seed_params <- mod_seed_paper_search_server("seed_module")
  })
}
```

## Data Flow

### Request Flow: Discovery → Search Notebook

```
User Action (e.g., "Search with this seed paper")
    ↓
Discovery Module (e.g., mod_seed_paper_search)
    ↓
Build query parameters
    ↓
Return reactive(list(search_query, filters))
    ↓
app.R observeEvent
    ↓
create_notebook(con, query, filters)
    ↓
current_notebook(new_id)
    ↓
mod_search_notebook_server receives notebook_id
    ↓
Fetches papers from OpenAlex
    ↓
Displays results
```

### State Management

```
Startup State (db.R: settings table)
    ↓
app.R checks: has_seen_wizard?
    ↓ NO
Show Startup Wizard
    ↓
User selects entry mode → Discovery Module
    ↓
Query parameters generated
    ↓
Create search notebook
    ↓
Set has_seen_wizard = TRUE
    ↓
Navigate to search notebook view
```

### Key Data Flows

1. **Seed paper flow:** DOI input → OpenAlex works API (cited_by/references) → Related papers → Query parameters → Search notebook
2. **Query builder flow:** User selections → OpenAlex filter syntax → Query parameters → Search notebook
3. **Topic explorer flow:** Topic selection → OpenAlex concepts API → Works filtered by concept → Query parameters → Search notebook
4. **Notebook refresh flow:** Existing in mod_search_notebook.R → Do NOT modify (already complex)

## Integration Points

### Between Discovery Modules and Search Notebook

| Boundary | Communication | Contract |
|----------|---------------|----------|
| Discovery → Search | Return reactive query params | `list(search_query = string, filters = list(...))` |
| Search → Discovery | None (one-way) | Discovery modules don't know about search results |
| app.R → Discovery | Pass config reactive | `config()$openalex$email`, `config()$openrouter$api_key` |
| app.R → Search | Pass notebook_id reactive | `current_notebook()` triggers search notebook to load |

### Module Communication Pattern

```r
# Discovery modules return standardized query format
query_params <- reactive({
  list(
    search_query = "...",          # OpenAlex search string
    filters = list(
      from_year = 2020,
      to_year = 2025,
      search_field = "title_and_abstract",
      is_oa = FALSE,
      exclude_retracted = TRUE,
      flag_predatory = TRUE,
      min_citations = NULL
    )
  )
})
```

### External API Integration

| Service | Endpoints Needed | Response Format | Notes |
|---------|------------------|-----------------|-------|
| **OpenAlex** (existing) | `/works` (search) | JSON, paginated | Already implemented |
| **OpenAlex** (new) | `/works/{doi}` (seed paper lookup) | JSON, single work | Need to add DOI normalization |
| **OpenAlex** (new) | `/works/{id}/cited_by` | JSON, paginated | For seed paper related works |
| **OpenAlex** (new) | `/concepts` | JSON, hierarchical | For topic explorer |
| **OpenRouter** (existing) | Embeddings | JSON | Already implemented |

### Internal Module Boundaries

```
mod_startup_wizard
    ↓ (contains)
mod_seed_paper_search / mod_query_builder / mod_topic_explorer
    ↓ (outputs to)
app.R
    ↓ (creates)
Search Notebook with query parameters
    ↓ (uses)
mod_search_notebook (existing, DO NOT MODIFY STRUCTURE)
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: God Module

**What people do:** Add all new features to mod_search_notebook.R (already 1,760 lines)

**Why it's wrong:**
- Module becomes unmaintainable
- Testing becomes nightmare
- Multiple developers can't work on features simultaneously
- Mixing concerns (query building vs result display)

**Do this instead:** Create separate modules for each discovery mode, keep search notebook focused on displaying/managing results

### Anti-Pattern 2: Direct Module-to-Module Communication

**What people do:** Have mod_seed_paper_search directly call functions from mod_search_notebook

**Why it's wrong:**
- Tight coupling
- Breaks module encapsulation
- Hard to test in isolation
- Violates single responsibility principle

**Do this instead:** Route all module communication through app.R using reactive values

### Anti-Pattern 3: Passing Reactive Values Instead of Expressions

**What people do:**
```r
# WRONG
config_value <- config()  # Evaluate immediately
mod_query_builder_server("query", config_value)
```

**Why it's wrong:** Module only gets current value, doesn't react to changes

**Do this instead:**
```r
# CORRECT
mod_query_builder_server("query", config)  # Pass reactive expression
```

### Anti-Pattern 4: Monolithic UI Function

**What people do:** Put all wizard steps in one giant UI function with conditional panels

**Why it's wrong:**
- Hard to read
- Difficult to extract for reuse
- Poor separation of concerns

**Do this instead:** Use nested modules with proper namespacing

## Build Order and Dependencies

### Phase 1: Infrastructure (No UI dependencies)

**Build first:**
1. **api_openalex.R extensions**
   - Add `get_work_by_doi()` function
   - Add `get_related_works()` function (cited_by + references)
   - Add `get_concepts_tree()` function
   - Add `build_concept_filter()` function

2. **db.R extensions**
   - Add `has_seen_wizard` setting to track first-time users
   - Add helper: `save_db_setting(con, "has_seen_wizard", TRUE)`
   - Add helper: `get_db_setting(con, "has_seen_wizard")`

**Why first:** These have no UI dependencies, can be tested in isolation, used by all discovery modules

### Phase 2: Individual Discovery Modules (Parallel work possible)

**Build in parallel:**

1. **mod_seed_paper_search.R**
   - UI: DOI/URL input, related paper preview, relevance slider
   - Server: Validate DOI, fetch seed paper, get cited_by/references, rank by relevance
   - Output: Query parameters for search notebook
   - **Dependencies:** api_openalex.R (get_work_by_doi, get_related_works)

2. **mod_query_builder.R**
   - UI: Year range, field selector, document type checkboxes, venue search
   - Server: Build OpenAlex filter syntax, preview query
   - Output: Query parameters for search notebook
   - **Dependencies:** None (pure UI → query string transformation)

3. **mod_topic_explorer.R**
   - UI: Concept search, tree navigation, breadcrumb trail
   - Server: Search concepts, fetch hierarchy, build filters
   - Output: Query parameters for search notebook
   - **Dependencies:** api_openalex.R (get_concepts_tree, build_concept_filter)

**Why parallel:** These modules are independent, different developers can work on them simultaneously

### Phase 3: Wizard Orchestration (Depends on Phase 2)

**Build third:**

1. **mod_startup_wizard.R**
   - UI: Step 1 (choose mode), Step 2 (conditional module), Step 3 (confirm)
   - Server: Manage wizard state, route to appropriate discovery module
   - Output: Trigger notebook creation with discovery module's query parameters
   - **Dependencies:** All Phase 2 modules

**Why third:** Needs all discovery modules to exist first, orchestrates them

### Phase 4: App Integration (Depends on all above)

**Build last:**

1. **app.R modifications**
   - Check `has_seen_wizard` on startup
   - Add wizard modal/view
   - Wire discovery module outputs to `create_notebook()`
   - Update view switching logic
   - **Dependencies:** All modules above

2. **mod_search_notebook.R modifications** (MINIMAL)
   - **ONLY** modify to accept initial query parameters on creation
   - **DO NOT** add discovery UI here
   - Keep at current scope (1,760 lines is enough)

**Why last:** Integrates everything, most complex interactions

### Dependency Graph

```
Phase 1: Infrastructure
  ├── api_openalex.R (DOI lookup, concepts)
  └── db.R (wizard state)
       ↓
Phase 2: Discovery Modules (parallel)
  ├── mod_seed_paper_search.R → uses api_openalex
  ├── mod_query_builder.R → no deps
  └── mod_topic_explorer.R → uses api_openalex
       ↓
Phase 3: Wizard
  └── mod_startup_wizard.R → uses all Phase 2 modules
       ↓
Phase 4: Integration
  ├── app.R → uses wizard + all discovery modules
  └── mod_search_notebook.R → receives output from discovery
```

## Suggested Implementation Order

1. **Week 1: Infrastructure + Seed Paper**
   - api_openalex.R extensions (DOI lookup, related works)
   - db.R wizard state tracking
   - mod_seed_paper_search.R (most valuable, test end-to-end flow)

2. **Week 2: Query Builder + Topic Explorer**
   - mod_query_builder.R (simplest, no API)
   - api_openalex.R concepts extension
   - mod_topic_explorer.R

3. **Week 3: Wizard + Integration**
   - mod_startup_wizard.R
   - app.R integration
   - mod_search_notebook.R minimal modifications

**Rationale:** Start with highest-value feature (seed paper), validate architecture, then parallelize remaining discovery modes, finally integrate everything.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1-10 notebooks | Current architecture is fine, modules in memory per session |
| 10-100 notebooks | Consider caching OpenAlex concept trees in database (avoid repeated API calls) |
| 100+ notebooks | Add background job queue for embedding (don't block UI), consider concept tree materialized view |

### Scaling Priorities

1. **First bottleneck:** OpenAlex API rate limits (600 req/hr for polite pool, 100k/day for authenticated)
   - **Fix:** Cache concept hierarchies, implement request pooling, show rate limit status

2. **Second bottleneck:** Embedding generation cost/time for large paper sets
   - **Fix:** Already addressed with deferred embedding (user-triggered), add batch size limits

## Sources

- [Shiny modules - Official Posit documentation](https://shiny.posit.co/r/articles/improve/modules/)
- [Mastering Shiny: Chapter 19 - Shiny modules](https://mastering-shiny.org/scaling-modules.html)
- [Engineering Production-Grade Shiny Apps: Chapter 3 - Structuring Your Project](https://engineering-shiny.org/structuring-project.html)
- [Communication between modules - Official Posit documentation](https://shiny.posit.co/r/articles/improve/communicate-bet-modules/)
- [Wizard UI Pattern: When to Use It and How to Get It Right](https://www.eleken.co/blog-posts/wizard-ui-pattern-explained)
- [shinyQueryBuilder: Construct Complex Filtering Queries in 'Shiny'](https://rdrr.io/cran/shinyQueryBuilder/)
- [Build Interactive Data Explorer Dashboard: Complete Shiny Tutorial](https://www.datanovia.com/learn/tools/shiny-apps/practical-projects/data-explorer.html)
- [Shiny Code Organization: Professional Project Structure Guide](https://www.datanovia.com/learn/tools/shiny-apps/best-practices/code-organization.html)

---
*Architecture research for: Serapeum discovery features*
*Researched: 2026-02-10*
