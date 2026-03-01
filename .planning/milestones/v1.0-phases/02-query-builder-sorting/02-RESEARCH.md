# Phase 2: Query Builder + Sorting - Research

**Researched:** 2026-02-10
**Domain:** LLM-assisted query generation, OpenAlex API filtering, R Shiny UI controls
**Confidence:** HIGH

## Summary

Phase 2 implements two complementary features: (1) rich sorting controls for search results by citation metrics already stored in the database, and (2) an LLM-powered query builder that translates natural language into validated OpenAlex filter syntax. The codebase already captures FWCI, cited_by_count, and referenced_works_count during paper ingestion, so sorting is primarily a UI+SQL problem. The query builder requires careful prompt engineering and filter validation against OpenAlex's documented filter attributes to prevent API errors.

The OpenAlex API provides extensive filter capabilities with well-documented syntax. The challenge is constraining LLM output to valid filter attributes only. Research shows that structured prompts (JSON schemas) with explicit validation steps outperform free-form generation. The project already uses httr2 for API requests and jsonlite for structured data, providing a solid foundation for filter validation.

**Primary recommendation:** Implement sorting first (Plan 02-01) as it's low-risk and immediately valuable. Then build the query builder (Plan 02-02) as a separate module following the producer-consumer pattern validated in Phase 1. Use a filter allowlist from official OpenAlex docs rather than attempting to infer valid filters dynamically.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| httr2 | Latest | OpenAlex API requests | Already used in api_openalex.R, proven stable |
| jsonlite | Latest | JSON serialization, filter storage | Already used for config and filter persistence |
| shiny | Latest | UI inputs (selectInput, radioButtons) | Project's UI framework |
| bslib | Latest | Card layouts, modern Bootstrap 5 UI | Project's design system |
| DBI + duckdb | Latest | Query results with ORDER BY | Already used for all data storage |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| jsonvalidate | 1.5.0+ | Optional: validate LLM JSON output against schemas | If LLM produces malformed JSON frequently (validation alternative: tryCatch + fromJSON) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Simple R list allowlist | jsonvalidate package | List is sufficient for filter name validation; jsonvalidate adds complexity for marginal benefit |
| ORDER BY in DuckDB | Sort in R with order() | SQL sorting is faster and works with pagination; R sorting loads all rows into memory |
| radioButtons for sort | selectInput dropdown | radioButtons show all options without click (better UX for 3-4 options) |

**Installation:**
No new packages required. All dependencies already in project.

## Architecture Patterns

### Recommended Project Structure
```
R/
├── mod_query_builder.R      # New: LLM query generation module
├── mod_search_notebook.R    # Modified: add sort controls to UI
├── api_openalex.R           # No changes needed (already supports filters)
├── db.R                     # No changes needed (metrics already stored)
└── utils_filters.R          # New: filter validation utilities
```

### Pattern 1: Sort Controls in Search Notebook UI
**What:** Add radioButtons or selectInput above paper list to control ORDER BY clause
**When to use:** Sorting 3-5 options where user should see all choices
**Example:**
```r
# In mod_search_notebook_ui
radioButtons(
  ns("sort_by"),
  "Sort by:",
  choices = c(
    "Most cited" = "cited_by_count",
    "Highest impact (FWCI)" = "fwci",
    "Most references" = "referenced_works_count",
    "Newest first" = "year"
  ),
  selected = "cited_by_count"
)
```

SQL implementation in papers_data reactive:
```r
papers_data <- reactive({
  nb <- get_notebook(con(), notebook_id())
  sort_by <- input$sort_by %||% "year"

  # Map UI values to SQL columns with DESC
  order_clause <- switch(sort_by,
    cited_by_count = "cited_by_count DESC",
    fwci = "fwci DESC NULLS LAST",
    referenced_works_count = "referenced_works_count DESC",
    year = "year DESC",
    "year DESC"  # fallback
  )

  query <- sprintf("SELECT * FROM abstracts WHERE notebook_id = ? ORDER BY %s", order_clause)
  dbGetQuery(con(), query, list(nb$id))
})
```

### Pattern 2: Producer-Consumer for Discovery Modules
**What:** Discovery modules return reactive request objects; app.R consumes them to create notebooks
**When to use:** Any new discovery feature (already validated in Phase 1 with mod_seed_discovery)
**Example:**
```r
# In mod_query_builder.R
mod_query_builder_server <- function(id, con, config) {
  moduleServer(id, function(input, output, session) {
    discovery_request <- reactiveVal(NULL)

    observeEvent(input$execute_query, {
      # Set request for app.R to consume
      discovery_request(list(
        query = input$nl_query,
        filters = validated_filters(),
        notebook_name = paste("Search:", substr(input$nl_query, 1, 50))
      ))
    })

    return(discovery_request)  # app.R observes this
  })
}

# In app.R
query_builder_request <- mod_query_builder_server("query_builder", con_r, effective_config)

observeEvent(query_builder_request(), {
  req(query_builder_request())
  request <- query_builder_request()

  # Create notebook with LLM-generated query
  nb_id <- create_notebook(con, request$notebook_name, "search",
                          search_query = request$query,
                          search_filters = request$filters)
  # ... switch to notebook view
})
```

### Pattern 3: Filter Validation with Allowlist
**What:** Validate LLM-generated filters against static list of OpenAlex filter attributes before API call
**When to use:** Before every query execution; prevents API errors from hallucinated filters
**Example:**
```r
# In R/utils_filters.R
OPENALEX_FILTER_ALLOWLIST <- c(
  # Metrics
  "publication_year", "cited_by_count", "fwci", "authors_count",
  # Boolean
  "is_oa", "has_abstract", "is_retracted", "has_fulltext",
  # Categorical
  "type", "oa_status", "language",
  # Relationships
  "cites", "cited_by", "related_to",
  # Dates
  "from_publication_date", "to_publication_date",
  # Search
  "title.search", "abstract.search", "default.search"
)

validate_filters <- function(filter_string) {
  # Parse filter string: "attr1:val1,attr2:val2"
  parts <- strsplit(filter_string, ",")[[1]]

  for (part in parts) {
    # Extract attribute name (before colon)
    attr <- sub(":.*", "", trimws(part))

    # Check if attribute in allowlist
    if (!attr %in% OPENALEX_FILTER_ALLOWLIST) {
      return(list(
        valid = FALSE,
        error = paste("Invalid filter:", attr, "- not in OpenAlex schema")
      ))
    }
  }

  list(valid = TRUE, error = NULL)
}
```

### Pattern 4: LLM Prompt for Query Generation
**What:** Structured prompt with filter schema and validation instructions
**When to use:** Query builder module when translating natural language to OpenAlex filters
**Example:**
```r
system_prompt <- '
You are an OpenAlex query builder. Translate user research questions into OpenAlex filter syntax.

**FILTER SYNTAX:**
- Format: attribute:value  (e.g., publication_year:2020)
- Multiple filters: attribute1:value1,attribute2:value2  (comma = AND)
- OR values: attribute:value1|value2  (pipe = OR)
- Comparison: cited_by_count:>100, publication_year:<2020
- Negation: type:!book

**ALLOWED FILTERS (you MUST only use these):**
publication_year, cited_by_count, fwci, is_oa, has_abstract, is_retracted,
type, oa_status, language, from_publication_date, to_publication_date,
title.search, abstract.search, default.search

**OUTPUT FORMAT (JSON only):**
{
  "search": "keyword search terms or null",
  "filter": "comma-separated filters",
  "explanation": "what this query does"
}

**RULES:**
- Only use filters from allowed list
- Always include has_abstract:true
- Year filters: use publication_year for single year, from/to_publication_date for ranges
- Return valid JSON only, no markdown
'

user_message <- paste0("Research question: ", input$nl_query)

response <- chat_completion(api_key, model,
                            format_chat_messages(system_prompt, user_message))
parsed <- jsonlite::fromJSON(response)

# Validate before using
validation <- validate_filters(parsed$filter)
if (!validation$valid) {
  showNotification(validation$error, type = "error")
  return()
}
```

### Anti-Patterns to Avoid
- **Sorting in R after fetching all rows:** DuckDB ORDER BY is faster and allows pagination. Never `papers[order(papers$cited_by_count), ]` for large result sets.
- **Storing sort preference globally:** Sort state should be per-notebook (stored in search_filters JSON), not a global input that affects all notebooks.
- **Accepting arbitrary LLM filter output:** Always validate against allowlist. OpenAlex API returns cryptic errors for invalid filters.
- **Using "relevance_score" sort without search:** OpenAlex only provides relevance_score when search= parameter exists; will error otherwise.
- **Rendering raw NA values:** Use format functions for missing metrics: `cited_by %||% 0`, `if (is.na(fwci)) "—" else sprintf("%.1f", fwci)`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| OpenAlex filter parsing | Regex-based filter extractor | Direct LLM JSON output + validation | LLMs excel at structured output; parsing natural language to filters is LLM's job, not ours |
| JSON schema validation | Custom validator with if/else chains | jsonvalidate package OR simple %in% check | Edge cases are hard (nested JSON, types). Simple allowlist sufficient here. |
| Dynamic SQL query building | String concatenation with user input | sprintf with validated enum + parameterized WHERE | SQL injection risk, subtle bugs. Enum validation makes sprintf safe. |
| Filter syntax auto-complete | Custom parser for partial filters | Show examples in UI, validate complete filter | OpenAlex syntax has edge cases (pipe for OR, comma for AND). Not worth custom parser. |

**Key insight:** The hard problem is LLM prompt engineering, not filter validation. Validation is simple: check filter attribute names against a static list. Invest time in prompt design with 20-30 test queries, not validation infrastructure.

## Common Pitfalls

### Pitfall 1: Forgetting NULLS LAST in FWCI Sort
**What goes wrong:** Papers with missing FWCI (NA) sort to top or bottom unpredictably depending on DuckDB version
**Why it happens:** NULL handling in ORDER BY varies by SQL dialect
**How to avoid:** Always use `ORDER BY fwci DESC NULLS LAST` to push missing values to end
**Warning signs:** User reports "blank FWCI papers at top of results" or inconsistent sort order

### Pitfall 2: LLM Hallucinates Non-Existent Filters
**What goes wrong:** LLM suggests filters like "has_citations:true" or "impact_factor:>5" that don't exist in OpenAlex API
**Why it happens:** LLM training data includes other academic APIs with different schemas
**How to avoid:**
  1. Include explicit allowlist in system prompt
  2. Validate output against allowlist before API call
  3. Show user the generated filter string for manual review
**Warning signs:** OpenAlex API returns 400 errors with "invalid filter" messages

### Pitfall 3: Overloading search_filters Column
**What goes wrong:** Storing sort preference in search_filters JSON causes merge conflicts when filters update
**Why it happens:** Conflating two concerns: query parameters (filters) and UI state (sort)
**How to avoid:** Store sort preference separately or accept per-session sort (don't persist)
**Warning signs:** Sort order resets when editing search, or sort state from one notebook bleeds into another

### Pitfall 4: Blocking UI During LLM Query Generation
**What goes wrong:** App freezes for 3-10 seconds while waiting for OpenRouter API response
**Why it happens:** chat_completion() is synchronous; Shiny blocks until response arrives
**How to avoid:** Use `withProgress()` wrapper with message like "Generating query..." to show spinner
**Warning signs:** User clicks "Generate Query" and app appears frozen; no visual feedback

### Pitfall 5: Not Handling Filter Syntax Variations
**What goes wrong:** LLM generates valid filter like "type:journal-article" but hyphen causes parsing issues
**Why it happens:** Hyphenated values are valid in OpenAlex but look unusual to parsers
**How to avoid:** Don't parse filter strings beyond validation; pass them directly to API as-is
**Warning signs:** Filters with hyphens fail validation despite being valid OpenAlex syntax

## Code Examples

Verified patterns from official sources and existing codebase:

### Rich Sorting UI in Search Notebook
```r
# In mod_search_notebook_ui() card_header:
div(
  class = "d-flex justify-content-between align-items-center mb-2",
  span("Sort by:"),
  radioButtons(
    ns("sort_by"),
    NULL,  # no label, already in span
    choices = c(
      "Most cited" = "cited_by_count",
      "Impact (FWCI)" = "fwci",
      "Most references" = "referenced_works_count",
      "Newest" = "year"
    ),
    selected = "year",
    inline = TRUE
  )
)

# In mod_search_notebook_server(), modify papers_data reactive:
papers_data <- reactive({
  paper_refresh()  # trigger
  nb <- get_notebook(con(), notebook_id())
  sort_by <- input$sort_by %||% "year"

  # Validate sort_by against enum
  valid_sorts <- c("cited_by_count", "fwci", "referenced_works_count", "year")
  if (!sort_by %in% valid_sorts) sort_by <- "year"

  order_clause <- switch(sort_by,
    cited_by_count = "cited_by_count DESC",
    fwci = "fwci DESC NULLS LAST",
    referenced_works_count = "referenced_works_count DESC",
    year = "year DESC",
    "year DESC"
  )

  query <- sprintf(
    "SELECT * FROM abstracts WHERE notebook_id = ? ORDER BY %s",
    order_clause
  )
  dbGetQuery(con(), query, list(nb$id))
})
```

### Filter Validation Utility
```r
# R/utils_filters.R (new file)

#' OpenAlex filter allowlist (as of 2026-02-10)
#' Source: https://docs.openalex.org/api-entities/works/filter-works
OPENALEX_FILTER_ALLOWLIST <- c(
  # Publication metrics
  "publication_year", "publication_date", "cited_by_count", "fwci",
  "authors_count", "concepts_count", "is_paratext",

  # Open access
  "is_oa", "oa_status", "has_oa_accepted_or_published_version",
  "has_oa_submitted_version",

  # Content availability
  "has_abstract", "has_fulltext", "has_pdf", "is_retracted",

  # Work characteristics
  "type", "language", "doi",

  # Relationships
  "cites", "cited_by", "related_to",

  # Dates
  "from_publication_date", "to_publication_date",
  "from_updated_date", "to_updated_date",

  # Search
  "title.search", "abstract.search", "fulltext.search",
  "title_and_abstract.search", "default.search",

  # Entities
  "author.id", "author.orcid", "institutions.id",
  "institutions.country_code", "concepts.id",
  "primary_topic.id", "primary_topic.domain.id",
  "primary_topic.field.id", "primary_topic.subfield.id",
  "locations.source.id", "primary_location.source.id",
  "grants.funder"
)

#' Validate OpenAlex filter string against allowlist
#' @param filter_string Comma-separated filter string from LLM
#' @return List with valid (boolean) and error (string or NULL)
validate_openalex_filters <- function(filter_string) {
  if (is.null(filter_string) || nchar(trimws(filter_string)) == 0) {
    return(list(valid = TRUE, error = NULL))
  }

  # Split by comma (AND separator)
  parts <- strsplit(filter_string, ",")[[1]]

  for (part in parts) {
    part <- trimws(part)

    # Extract attribute name (before first colon)
    attr <- sub(":.*$", "", part)

    # Check against allowlist
    if (!attr %in% OPENALEX_FILTER_ALLOWLIST) {
      return(list(
        valid = FALSE,
        error = sprintf(
          "Invalid filter '%s': not in OpenAlex schema. See https://docs.openalex.org/api-entities/works/filter-works",
          attr
        )
      ))
    }
  }

  list(valid = TRUE, error = NULL)
}
```

### LLM Query Builder Module
```r
# R/mod_query_builder.R (new file)

mod_query_builder_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header("Ask a Research Question"),
    card_body(
      textAreaInput(
        ns("nl_query"),
        "Describe what you're looking for:",
        placeholder = "Example: Recent machine learning papers on transformers with high impact",
        rows = 3
      ),
      actionButton(
        ns("generate_btn"),
        "Generate Query",
        class = "btn-primary",
        icon = icon("wand-magic-sparkles")
      ),
      hr(),
      uiOutput(ns("query_preview"))
    )
  )
}

mod_query_builder_server <- function(id, con, config) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    generated_query <- reactiveVal(NULL)
    discovery_request <- reactiveVal(NULL)

    # Generate query button
    observeEvent(input$generate_btn, {
      req(input$nl_query)

      cfg <- config()
      api_key <- get_setting(cfg, "openrouter", "api_key")
      model <- get_setting(cfg, "openrouter", "model") %||% "anthropic/claude-3.5-sonnet"

      if (is.null(api_key) || nchar(api_key) == 0) {
        showNotification("OpenRouter API key not configured", type = "warning")
        return()
      }

      withProgress(message = "Generating query...", {
        system_prompt <- '
You are an OpenAlex API query builder. Convert research questions to OpenAlex filter syntax.

**ALLOWED FILTERS:**
publication_year, cited_by_count, fwci, is_oa, has_abstract, is_retracted,
type, oa_status, language, from_publication_date, to_publication_date,
title.search, abstract.search, default.search

**FILTER SYNTAX:**
- Single: attribute:value
- Multiple (AND): attr1:val1,attr2:val2
- OR: attr:val1|val2
- Comparison: cited_by_count:>100
- Negation: type:!book

**ALWAYS include: has_abstract:true**

**OUTPUT (JSON only, no markdown):**
{
  "search": "search keywords or null",
  "filter": "comma-separated filters",
  "explanation": "plain English summary"
}
'

        user_message <- sprintf("Research question: %s", input$nl_query)

        response <- tryCatch({
          chat_completion(
            api_key, model,
            format_chat_messages(system_prompt, user_message)
          )
        }, error = function(e) {
          showNotification(paste("LLM error:", e$message), type = "error")
          NULL
        })

        if (is.null(response)) return()

        # Parse JSON
        parsed <- tryCatch({
          jsonlite::fromJSON(response)
        }, error = function(e) {
          showNotification("LLM returned invalid JSON", type = "error")
          NULL
        })

        if (is.null(parsed)) return()

        # Validate filters
        validation <- validate_openalex_filters(parsed$filter)
        if (!validation$valid) {
          showNotification(validation$error, type = "error", duration = 10)
          return()
        }

        generated_query(parsed)
        showNotification("Query generated! Review before executing.", type = "message")
      })
    })

    # Show preview
    output$query_preview <- renderUI({
      query <- generated_query()
      if (is.null(query)) return(NULL)

      div(
        class = "border rounded p-3 bg-light",
        h6("Generated Query"),
        p(strong("Explanation: "), query$explanation),
        p(strong("Search: "), query$search %||% "(none)"),
        p(strong("Filters: "), code(query$filter)),
        actionButton(
          ns("execute_btn"),
          "Create Search Notebook",
          class = "btn-success w-100",
          icon = icon("book")
        )
      )
    })

    # Execute query button
    observeEvent(input$execute_btn, {
      query <- generated_query()
      req(query)

      # Parse filters back to list for storage
      filters_list <- list()
      if (!is.null(query$search)) {
        filters_list$search <- query$search
      }
      if (!is.null(query$filter)) {
        filters_list$filter <- query$filter
      }

      # Create discovery request for app.R
      discovery_request(list(
        query = query$search,
        filters = filters_list,
        notebook_name = paste("Search:", substr(input$nl_query, 1, 50))
      ))
    })

    return(discovery_request)
  })
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Static filter UI with dropdowns | LLM-generated queries from natural language | 2024-2025 | Users describe intent, not syntax; reduces learning curve |
| Client-side table sorting | Server-side SQL ORDER BY | Always standard | Essential for pagination, handles large result sets |
| Free-form LLM output | Structured JSON with schema validation | 2025-2026 | Reduces hallucination, enables automatic validation |
| Manual filter construction | API-documented filter allowlists | 2024+ | Prevents API errors from invalid filters |

**Deprecated/outdated:**
- **DT package for sortable tables:** Shiny standard is now custom reactive sorting with SQL ORDER BY; DT adds unnecessary JavaScript dependencies for this use case
- **Free-text LLM prompts without structure:** Modern practice uses JSON output schemas; increases reliability
- **Storing sort order in URL params:** Shiny reactive state management is cleaner; URL params are for bookmarkable states only

## Open Questions

1. **Should sort preference persist across sessions?**
   - What we know: search_filters JSON column exists for query state
   - What's unclear: Whether sort is "query parameter" (persist) or "UI preference" (session-only)
   - Recommendation: Start with session-only (simpler); add persistence if users request it

2. **LLM model selection for query generation?**
   - What we know: app uses user-configurable OpenRouter model; seed discovery uses this pattern
   - What's unclear: Whether to use user's default model or pin to specific model for query generation
   - Recommendation: Use user's default model (already configured); if quality is poor, add model override in settings

3. **Maximum number of sort options without overwhelming users?**
   - What we know: Current UI shows 3-4 filters in checkboxes; radioButtons work well for 4-6 options
   - What's unclear: Whether to include publication_date, abstract length, author count, etc.
   - Recommendation: Start with 4 core metrics (cited_by_count, fwci, referenced_works_count, year); expand if users request more

4. **Should filter validation happen client-side or server-side?**
   - What we know: Validation is fast (simple %in% check); server has allowlist
   - What's unclear: Whether to expose allowlist to client for instant feedback
   - Recommendation: Server-side only (simpler); validation is quick, user sees result in preview step before execution

## Sources

### Primary (HIGH confidence)
- [OpenAlex Sort Entity Lists Documentation](https://docs.openalex.org/how-to-use-the-api/get-lists-of-entities/sort-entity-lists) - Confirmed sort parameters: cited_by_count, publication_date, works_count, display_name
- [OpenAlex Filter Works Documentation](https://docs.openalex.org/api-entities/works/filter-works) - Complete filter attribute reference with syntax examples
- [OpenAlex API Guide for LLMs](https://docs.openalex.org/api-guide-for-llms) - Best practices for programmatic query construction
- Serapeum codebase (R/api_openalex.R, R/db.R, R/mod_search_notebook.R) - Existing patterns for filters, metrics storage, reactive UI

### Secondary (MEDIUM confidence)
- [Prompt Engineering for Data Quality & Validation with LLMs](https://dextralabs.com/blog/prompt-engineering-data-quality-validation-llms/) - Structured prompts with validation steps
- [Lakera Prompt Engineering Guide 2026](https://www.lakera.ai/blog/prompt-engineering-guide) - JSON schemas reduce hallucination
- [Shiny Application Layout Guide](https://shiny.posit.co/r/articles/build/layout-guide/) - bslib card patterns
- [Shiny Input Controls Guide](https://www.datanovia.com/learn/tools/shiny-apps/ui-design/input-controls.html) - radioButtons and selectInput usage

### Tertiary (LOW confidence)
- [R Shiny Sortable Package](https://rstudio.github.io/sortable/) - Drag-and-drop sorting (not needed for this phase; SQL sorting is simpler)
- [jsonvalidate Package](https://cran.r-project.org/web/packages/jsonvalidate/vignettes/jsonvalidate.html) - JSON schema validation (overkill for simple filter validation)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in project, proven stable in Phases 0-1
- Architecture: HIGH - Producer-consumer pattern validated in Phase 1; SQL sorting is standard practice
- Pitfalls: MEDIUM - LLM prompt engineering requires empirical testing; documented issues from OpenAlex community
- Filter allowlist: HIGH - Sourced directly from OpenAlex official documentation (linked above)

**Research date:** 2026-02-10
**Valid until:** 2026-03-10 (30 days - stable domain with official API docs)

**Notes:**
- FWCI sorting confirmed NOT available via API sort parameter (only filters); must sort locally after fetch
- OpenAlex API rate limits: 100,000 credits/day free tier, 10 credits per list request
- Phase 1 validated that citation metrics (fwci, cited_by_count, referenced_works_count) are reliably populated by OpenAlex API
- Recommendation: Test LLM prompt with 20-30 sample queries during planning (as noted in ROADMAP.md risk flags) to validate filter generation quality before implementation
