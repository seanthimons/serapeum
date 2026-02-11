# Phase 3: Topic Explorer - Research

**Researched:** 2026-02-11
**Domain:** OpenAlex Topics API, hierarchical data navigation in Shiny, DuckDB bulk caching
**Confidence:** HIGH

## Summary

Phase 3 implements a topic hierarchy browser that lets users explore OpenAlex's 4,500+ topics organized in a 4-level taxonomy (domain > field > subfield > topic). Users navigate the hierarchy to discover research areas and create search notebooks filtered by topic.

The implementation follows the producer-consumer pattern established in Phase 1: a discovery module (`mod_topic_explorer`) returns a reactive request that app.R consumes to create a topic-filtered search notebook. The topics table (already created in Phase 0) caches the full taxonomy locally in DuckDB to enable fast browsing without repeated API calls.

Technical challenges include: (1) fetching and caching ~4,500 topics from OpenAlex with pagination, (2) building a hierarchical UI that works well with Shiny's reactive model, and (3) handling cache staleness and updates.

**Primary recommendation:** Use standard Shiny reactives for cascading selectInput widgets (domain -> field -> subfield -> topic). Cache the full topic taxonomy in DuckDB on first use with a cache metadata table to track freshness. Follow the producer-consumer pattern from Phase 1 for consistency.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| OpenAlex Topics API | 2026 | Topic taxonomy data source | Official API for academic topic classification, ~4,500 topics with hierarchy |
| DuckDB | ≥0.9.0 | Local topic cache | Already in use, excellent bulk insert performance, SQL aggregation for hierarchy queries |
| Shiny modules | 1.7+ | Component isolation | Standard Shiny pattern, established in Phase 1/2 |
| bslib cards | 0.6+ | UI layout | Project standard, consistent with existing modules |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| httr2 | Latest | OpenAlex API requests | Already in R/api_openalex.R, consistent with existing API code |
| jsonlite | Latest | JSON parsing for keywords | Already in use for OpenAlex responses |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Cascading selectInputs | collapsibleTree package | collapsibleTree provides D3.js tree visualization but adds dependency and complexity. Standard selectInputs are simpler, more accessible, and fit Shiny's reactive model better. Tree viz could be added later for "browse mode" vs "select mode". |
| collapsibleTree | shinytreeview package | Similar tradeoff - adds JS dependency for tree UI. Good for visual exploration but overkill for topic selection workflow. |
| Full cache refresh | Incremental updates | OpenAlex topics change slowly (~monthly). Full refresh on staleness is simpler than tracking individual topic updates. Cache is small (~4,500 rows). |

**Installation:**
No new R packages required. All dependencies already in project.

## Architecture Patterns

### Recommended Project Structure
```
R/
├── api_openalex.R          # Add get_topics(), get_topic() functions
├── db.R                    # Add topic cache functions (cache_topics, get_cached_topics)
├── mod_topic_explorer.R    # New module (UI + server)
└── mod_search_notebook.R   # Consumer (no changes needed)

migrations/
└── 002_create_topics_table.sql  # Already exists from Phase 0
```

### Pattern 1: Topic Taxonomy Caching
**What:** Fetch full topic list from OpenAlex on first use, bulk insert to DuckDB, track freshness with metadata table
**When to use:** On app startup if cache is empty or stale (>30 days)
**Example:**
```r
# R/db.R - Add topic cache functions

#' Cache OpenAlex topics locally
#' @param con DuckDB connection
#' @param topics_df Data frame from OpenAlex with columns: topic_id, display_name, description, keywords, works_count, domain_id, domain_name, field_id, field_name, subfield_id, subfield_name
#' @return Number of topics cached
cache_topics <- function(con, topics_df) {
  message("[topic_cache] Caching ", nrow(topics_df), " topics...")

  # Clear existing data
  dbExecute(con, "DELETE FROM topics")

  if (nrow(topics_df) == 0) return(0)

  # Prepare clean data frame
  topics_clean <- data.frame(
    topic_id = as.character(topics_df$topic_id),
    display_name = as.character(topics_df$display_name),
    description = as.character(topics_df$description),
    keywords = as.character(topics_df$keywords),  # JSON string
    works_count = as.integer(topics_df$works_count),
    domain_id = as.character(topics_df$domain_id),
    domain_name = as.character(topics_df$domain_name),
    field_id = as.character(topics_df$field_id),
    field_name = as.character(topics_df$field_name),
    subfield_id = as.character(topics_df$subfield_id),
    subfield_name = as.character(topics_df$subfield_name),
    updated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    stringsAsFactors = FALSE
  )

  # Bulk insert using DuckDB's dbWriteTable (fast)
  dbWriteTable(con, "topics", topics_clean, append = TRUE)

  # Update cache metadata (reuse quality_cache_meta pattern)
  update_quality_cache_meta(con, "openalex_topics", nrow(topics_clean))

  nrow(topics_clean)
}

#' Get cached topics (or empty if cache missing/stale)
#' @param con DuckDB connection
#' @param max_age_days Cache considered stale after this many days
#' @return Data frame of topics, or empty data frame if cache stale/missing
get_cached_topics <- function(con, max_age_days = 30) {
  # Check cache metadata
  meta <- get_quality_cache_meta(con, "openalex_topics")

  if (is.null(meta)) {
    message("[topic_cache] No cache found")
    return(data.frame())  # Empty, triggers fetch
  }

  # Check staleness
  age_days <- as.numeric(difftime(Sys.time(), meta$last_updated, units = "days"))
  if (age_days > max_age_days) {
    message("[topic_cache] Cache stale (", round(age_days, 1), " days old)")
    return(data.frame())  # Empty, triggers fetch
  }

  # Return cached data
  dbGetQuery(con, "SELECT * FROM topics ORDER BY domain_name, field_name, subfield_name, display_name")
}

#' Get hierarchy level options (for selectInput choices)
#' @param con DuckDB connection
#' @param level One of: "domain", "field", "subfield", "topic"
#' @param parent_id Optional parent filter (e.g., domain_id when fetching fields)
#' @return Named character vector for selectInput choices
get_hierarchy_choices <- function(con, level = "domain", parent_id = NULL) {
  if (level == "domain") {
    # Top level - distinct domains
    result <- dbGetQuery(con, "
      SELECT DISTINCT domain_id, domain_name
      FROM topics
      WHERE domain_id IS NOT NULL
      ORDER BY domain_name
    ")
    choices <- setNames(result$domain_id, result$domain_name)
  } else if (level == "field") {
    # Filter by domain
    if (is.null(parent_id)) return(character(0))
    result <- dbGetQuery(con, "
      SELECT DISTINCT field_id, field_name
      FROM topics
      WHERE domain_id = ? AND field_id IS NOT NULL
      ORDER BY field_name
    ", list(parent_id))
    choices <- setNames(result$field_id, result$field_name)
  } else if (level == "subfield") {
    # Filter by field
    if (is.null(parent_id)) return(character(0))
    result <- dbGetQuery(con, "
      SELECT DISTINCT subfield_id, subfield_name
      FROM topics
      WHERE field_id = ? AND subfield_id IS NOT NULL
      ORDER BY subfield_name
    ", list(parent_id))
    choices <- setNames(result$subfield_id, result$subfield_name)
  } else if (level == "topic") {
    # Filter by subfield
    if (is.null(parent_id)) return(character(0))
    result <- dbGetQuery(con, "
      SELECT topic_id, display_name, works_count
      FROM topics
      WHERE subfield_id = ?
      ORDER BY display_name
    ", list(parent_id))
    # Include works_count in label for context
    labels <- sprintf("%s (%s works)", result$display_name, format(result$works_count, big.mark = ","))
    choices <- setNames(result$topic_id, labels)
  }

  choices
}
```

### Pattern 2: OpenAlex Topics API Pagination
**What:** Fetch all topics from OpenAlex with offset-based pagination
**When to use:** When cache is empty or stale (on-demand, not every startup)
**Example:**
```r
# R/api_openalex.R - Add topic fetching

#' Fetch all topics from OpenAlex (paginated)
#' @param email User email
#' @param api_key OpenAlex API key (required as of Feb 2026)
#' @param per_page Results per page (max 200, default 100)
#' @return Data frame with all topics
fetch_all_topics <- function(email, api_key, per_page = 100) {
  if (is.null(api_key) || nchar(api_key) == 0) {
    stop("OpenAlex API key required (as of Feb 2026). Please configure in Settings.")
  }

  all_topics <- list()
  page <- 1
  total_fetched <- 0

  repeat {
    message("[openalex] Fetching topics page ", page, "...")

    # Build paginated request
    req <- build_openalex_request("topics", email, api_key) |>
      req_url_query(
        per_page = per_page,
        page = page,
        select = "id,display_name,description,keywords,works_count,domain,field,subfield"
      )

    resp <- tryCatch({
      req_perform(req)
    }, error = function(e) {
      stop("OpenAlex API error: ", e$message)
    })

    body <- resp_body_json(resp)

    if (is.null(body$results) || length(body$results) == 0) {
      break  # No more results
    }

    # Parse topics
    page_topics <- lapply(body$results, parse_topic)
    all_topics <- c(all_topics, page_topics)
    total_fetched <- total_fetched + length(page_topics)

    # Check if we've fetched everything
    total_count <- body$meta$count %||% 0
    if (total_fetched >= total_count) {
      message("[openalex] Fetched all ", total_fetched, " topics")
      break
    }

    page <- page + 1
    Sys.sleep(0.1)  # Polite: 10 req/sec max
  }

  # Convert list to data frame
  do.call(rbind, lapply(all_topics, as.data.frame, stringsAsFactors = FALSE))
}

#' Parse OpenAlex topic object
#' @param topic Raw topic object from API
#' @return List with flattened fields
parse_topic <- function(topic) {
  # Extract topic ID (remove URL prefix)
  topic_id <- gsub("https://openalex.org/", "", topic$id)

  # Keywords to JSON string
  keywords_json <- if (!is.null(topic$keywords) && length(topic$keywords) > 0) {
    jsonlite::toJSON(topic$keywords, auto_unbox = FALSE)
  } else {
    "[]"
  }

  list(
    topic_id = topic_id,
    display_name = topic$display_name %||% NA_character_,
    description = topic$description %||% NA_character_,
    keywords = keywords_json,
    works_count = topic$works_count %||% 0,
    domain_id = if (!is.null(topic$domain)) gsub("https://openalex.org/", "", topic$domain$id) else NA_character_,
    domain_name = if (!is.null(topic$domain)) topic$domain$display_name else NA_character_,
    field_id = if (!is.null(topic$field)) gsub("https://openalex.org/", "", topic$field$id) else NA_character_,
    field_name = if (!is.null(topic$field)) topic$field$display_name else NA_character_,
    subfield_id = if (!is.null(topic$subfield)) gsub("https://openalex.org/", "", topic$subfield$id) else NA_character_,
    subfield_name = if (!is.null(topic$subfield)) topic$subfield$display_name else NA_character_
  )
}
```

### Pattern 3: Cascading Hierarchy SelectInputs
**What:** Four-level selectInput cascade using Shiny reactives and updateSelectInput
**When to use:** Standard Shiny UI for hierarchical data selection
**Example:**
```r
# R/mod_topic_explorer.R - UI section

mod_topic_explorer_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header("Explore Topics"),
    card_body(
      # Cache status indicator
      uiOutput(ns("cache_status")),

      hr(),

      # Hierarchical selection
      selectInput(
        ns("domain"),
        "1. Domain",
        choices = c("Loading..." = "")
      ),

      selectInput(
        ns("field"),
        "2. Field",
        choices = c("Select domain first" = "")
      ),

      selectInput(
        ns("subfield"),
        "3. Subfield",
        choices = c("Select field first" = "")
      ),

      selectInput(
        ns("topic"),
        "4. Topic",
        choices = c("Select subfield first" = "")
      ),

      # Topic details
      uiOutput(ns("topic_details")),

      # Create notebook button
      hr(),
      actionButton(
        ns("create_notebook_btn"),
        "Create Notebook for This Topic",
        class = "btn-success w-100",
        icon = icon("book")
      )
    )
  )
}

# R/mod_topic_explorer.R - Server section (reactive cascade)

mod_topic_explorer_server <- function(id, con, config) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Internal state
    topics_cache <- reactiveVal(data.frame())
    topic_request <- reactiveVal(NULL)

    # Load topics on module init
    observe({
      cached <- get_cached_topics(con(), max_age_days = 30)

      if (nrow(cached) == 0) {
        # Cache empty/stale - fetch from API
        cfg <- config()
        email <- get_setting(cfg, "openalex", "email")
        api_key <- get_setting(cfg, "openalex", "api_key")

        withProgress(message = "Fetching topic taxonomy from OpenAlex...", {
          topics_df <- tryCatch({
            fetch_all_topics(email, api_key, per_page = 100)
          }, error = function(e) {
            showNotification(
              paste("Error fetching topics:", e$message),
              type = "error",
              duration = 10
            )
            data.frame()
          })

          if (nrow(topics_df) > 0) {
            cache_topics(con(), topics_df)
            topics_cache(topics_df)
          }
        })
      } else {
        topics_cache(cached)
      }
    }) |> bindEvent(TRUE, once = TRUE)

    # Update domain choices when cache loads
    observe({
      req(nrow(topics_cache()) > 0)
      choices <- get_hierarchy_choices(con(), "domain")
      updateSelectInput(session, "domain", choices = c("Select domain..." = "", choices))
    })

    # Update field choices when domain selected
    observe({
      req(input$domain)
      choices <- get_hierarchy_choices(con(), "field", parent_id = input$domain)
      updateSelectInput(session, "field", choices = c("Select field..." = "", choices))
    }) |> bindEvent(input$domain)

    # Update subfield choices when field selected
    observe({
      req(input$field)
      choices <- get_hierarchy_choices(con(), "subfield", parent_id = input$field)
      updateSelectInput(session, "subfield", choices = c("Select subfield..." = "", choices))
    }) |> bindEvent(input$field)

    # Update topic choices when subfield selected
    observe({
      req(input$subfield)
      choices <- get_hierarchy_choices(con(), "topic", parent_id = input$subfield)
      updateSelectInput(session, "topic", choices = c("Select topic..." = "", choices))
    }) |> bindEvent(input$subfield)

    # Show topic details when topic selected
    output$topic_details <- renderUI({
      req(input$topic)

      topic <- dbGetQuery(con(), "
        SELECT * FROM topics WHERE topic_id = ?
      ", list(input$topic))

      if (nrow(topic) == 0) return(NULL)

      div(
        class = "border rounded p-3 bg-light mt-3",
        h5(topic$display_name),
        p(class = "small text-muted", topic$description),
        p(class = "small",
          tags$strong("Works: "), format(topic$works_count, big.mark = ",")
        )
      )
    })

    # Create notebook button
    observeEvent(input$create_notebook_btn, {
      req(input$topic)

      topic <- dbGetQuery(con(), "SELECT * FROM topics WHERE topic_id = ?", list(input$topic))

      if (nrow(topic) == 0) {
        showNotification("Topic not found", type = "error")
        return()
      }

      # Set topic request for app.R to consume
      topic_request(list(
        topic_id = topic$topic_id,
        topic_name = topic$display_name,
        notebook_name = paste("Topic:", topic$display_name)
      ))
    })

    # Return topic request reactive (producer pattern)
    return(topic_request)
  })
}
```

### Pattern 4: Producer-Consumer for Discovery Modules
**What:** Module returns reactive request, app.R observes and creates search notebook
**When to use:** All discovery modules (seed paper, query builder, topic explorer)
**Example:**
```r
# app.R - Consumer side (follows Phase 1 pattern)

# Topic explorer module
topic_request <- mod_topic_explorer_server("topic_explorer", reactive(con), config_file_r)

# Consume topic request to create search notebook
observeEvent(topic_request(), {
  req <- topic_request()
  if (is.null(req)) return()

  # Create notebook with topic filter
  # OpenAlex filter syntax: primary_topic.id:T12345
  filters <- list(
    topic_filter = paste0("primary_topic.id:", req$topic_id),
    topic_id = req$topic_id,
    topic_name = req$topic_name
  )

  nb_id <- create_notebook(
    con,
    name = req$notebook_name,
    type = "search",
    search_query = "",  # No text query, just topic filter
    search_filters = jsonlite::toJSON(filters, auto_unbox = TRUE)
  )

  # Clear request
  topic_request(NULL)

  # Navigate to new notebook
  notebook_refresh(notebook_refresh() + 1)
  current_notebook(nb_id)
  current_view("notebook")

  showNotification(
    paste("Created notebook for topic:", req$topic_name),
    type = "message",
    duration = 5
  )
})
```

### Anti-Patterns to Avoid
- **Fetching topics on every app startup:** Cache is critical. Only fetch if cache empty/stale (checked via metadata).
- **Individual INSERT statements for 4,500 topics:** Use `dbWriteTable()` bulk insert, not a loop of `dbExecute()` calls. DuckDB is optimized for bulk operations.
- **Using collapsibleTree for selection UI:** Tree visualizations are nice but add complexity. Save for "browse mode" later; start with standard selectInputs for "select mode".
- **Storing full hierarchy as nested JSON:** Denormalized table with hierarchy columns (domain_id, field_id, etc.) enables fast SQL queries for cascading selects. JSON would require parsing in R.
- **Not tracking cache freshness:** Topics change (slowly). Use cache metadata table pattern from quality filters to track last_updated and auto-refresh when stale.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hierarchical data structures | Custom tree traversal | SQL queries on denormalized table | DuckDB aggregates (DISTINCT domain_id) are fast and simple. Denormalized schema avoids joins. |
| Pagination logic | Manual offset tracking | Standard `page` parameter + `meta.count` check | OpenAlex API returns total count in meta. Simple `while (fetched < total)` loop is reliable. |
| Cache invalidation | Custom freshness logic | Reuse `quality_cache_meta` table pattern | Already exists in db.R. Consistent with predatory journals/retraction caching. |
| Topic search/filter | Full-text search implementation | `LIKE` queries on display_name/description | For 4,500 rows, SQL LIKE is instant. Add `LOWER()` for case-insensitivity. No need for FTS index. |
| Select widget cascades | Manual event chains | Shiny's `updateSelectInput` + reactives | Standard Shiny pattern. Well-documented, handles edge cases (clearing downstream selects). |

**Key insight:** Hierarchical browsing is a solved problem in Shiny. Use standard selectInput cascades with reactive updates. The complexity is in the data (fetching/caching), not the UI.

## Common Pitfalls

### Pitfall 1: OpenAlex API Key Requirement
**What goes wrong:** Code fails with authentication error
**Why it happens:** As of February 13, 2026, OpenAlex requires API keys. The old "polite pool" (email-only) system is discontinued.
**How to avoid:**
- Check for API key in settings before fetching topics
- Show clear error message directing user to Settings if key missing
- Include key in all requests via `req_headers("Authorization" = paste("Bearer", api_key))`
**Warning signs:** 401 Unauthorized responses, "API key required" errors

### Pitfall 2: Cache Never Refreshing
**What goes wrong:** Users see outdated topics even after OpenAlex adds new ones
**Why it happens:** Forgot to check cache age or set max_age_days too high
**How to avoid:**
- Use 30-day staleness threshold (topics change monthly, not daily)
- Store `last_updated` timestamp in `quality_cache_meta` table
- Check age on every app startup: `difftime(Sys.time(), meta$last_updated, units = "days")`
- Provide manual "Refresh Topics" button in UI for advanced users
**Warning signs:** Cache metadata shows last_updated > 30 days ago, new topics missing from API but not in cache

### Pitfall 3: Bulk Insert Too Slow
**What goes wrong:** Caching 4,500 topics takes 10+ seconds
**Why it happens:** Using individual INSERT statements in a loop instead of bulk operations
**How to avoid:**
- Use `DBI::dbWriteTable(con, "topics", df, append = TRUE)` for bulk insert
- Prepare full data frame first, then insert once
- DuckDB optimizes bulk writes; single dbWriteTable call is 100x faster than 4,500 dbExecute calls
**Warning signs:** Progress bar stuck during cache update, UI freezes

### Pitfall 4: Cascade Breaks on Reset
**What goes wrong:** Selecting a new domain doesn't clear the old field/subfield/topic selections, causing mismatched hierarchy
**Why it happens:** Forgot to clear downstream selects when parent changes
**How to avoid:**
- In each `observe(input$domain)` block, also reset field/subfield/topic to empty: `updateSelectInput(session, "field", selected = "")`
- Use `ignoreNULL = FALSE` in observeEvent so clearing triggers updates
- Test by selecting deep into hierarchy, then changing domain - should clear all downstream
**Warning signs:** Field list shows fields from old domain after selecting new domain, topic filter doesn't match displayed path

### Pitfall 5: Missing Topic Filter Validation
**What goes wrong:** User clicks "Create Notebook" but search returns zero papers
**Why it happens:** Selected topic has no papers (works_count = 0) or filter syntax is wrong
**How to avoid:**
- Show works_count in topic selectInput labels: `"Machine Learning (1,234 works)"`
- Disable "Create Notebook" button if selected topic has works_count = 0
- Verify filter syntax matches OpenAlex docs: `primary_topic.id:T12345` (not `topic_id:...`)
- Test created notebook immediately loads papers
**Warning signs:** Notebook created but abstracts list is empty, OpenAlex API returns 0 results for filter

### Pitfall 6: Race Condition on Cache Load
**What goes wrong:** UI tries to populate domain dropdown before cache finishes loading
**Why it happens:** Async cache fetch completes after UI renders
**How to avoid:**
- Use `bindEvent(TRUE, once = TRUE)` for cache load observer
- Wrap initial domain choices update in `observe({ req(nrow(topics_cache()) > 0) })`
- Show "Loading topics..." message in selectInput until cache ready
- Use `withProgress()` during fetch so user knows what's happening
**Warning signs:** Empty domain dropdown, "Select domain..." placeholder but no choices, console warning about missing topics_cache

## Code Examples

Verified patterns from official sources:

### OpenAlex Topics API Call (Paginated)
```r
# Source: https://docs.openalex.org/api-entities/topics/get-lists-of-topics
# Pagination uses page parameter (offset-based, not cursor)

fetch_topics_page <- function(email, api_key, page = 1, per_page = 100) {
  req <- request("https://api.openalex.org/topics") |>
    req_headers("Authorization" = paste("Bearer", api_key)) |>
    req_url_query(
      mailto = email,
      page = page,
      per_page = per_page,
      select = "id,display_name,description,keywords,works_count,domain,field,subfield"
    ) |>
    req_timeout(30)

  resp <- req_perform(req)
  resp_body_json(resp)
}
```

### DuckDB Bulk Insert with Cache Metadata
```r
# Source: Project db.R cache_predatory_publishers pattern (lines 864-886)
# Adapted for topics

cache_topics <- function(con, topics_df) {
  # Clear existing
  dbExecute(con, "DELETE FROM topics")

  # Prepare clean data frame
  topics_clean <- data.frame(
    topic_id = as.character(topics_df$topic_id),
    display_name = as.character(topics_df$display_name),
    # ... other columns ...
    updated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    stringsAsFactors = FALSE
  )

  # Bulk insert
  dbWriteTable(con, "topics", topics_clean, append = TRUE)

  # Update metadata
  update_quality_cache_meta(con, "openalex_topics", nrow(topics_clean))

  nrow(topics_clean)
}
```

### Filter Works by Topic
```r
# Source: https://docs.openalex.org/api-entities/works/filter-works
# Topic hierarchy filters available at all 4 levels

# Filter by specific topic
filter = "primary_topic.id:T12345"

# Filter by domain (broader)
filter = "primary_topic.domain.id:D1"

# Filter by field
filter = "primary_topic.field.id:F100"

# Filter by subfield
filter = "primary_topic.subfield.id:S1000"

# In search_papers() call:
search_papers(
  query = "",
  email = email,
  api_key = api_key,
  filter = paste0("primary_topic.id:", topic_id),
  per_page = 25
)
```

### Shiny Cascading Select Pattern
```r
# Source: https://mastering-shiny.org/reactivity-objects.html
# Standard reactive cascade for hierarchical data

# Update second select when first changes
observe({
  req(input$domain)
  choices <- get_choices_for_domain(input$domain)
  updateSelectInput(session, "field", choices = choices, selected = "")
}) |> bindEvent(input$domain)

# Clear third select when second changes
observe({
  req(input$field)
  choices <- get_choices_for_field(input$field)
  updateSelectInput(session, "subfield", choices = choices, selected = "")
}) |> bindEvent(input$field)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Email-based "polite pool" | API keys required | Feb 13, 2026 | All OpenAlex requests need API key via Authorization header. Email parameter still used but not sufficient alone. |
| Cursor pagination | Offset-based pagination | Current | OpenAlex Topics API uses `page` parameter, not cursor. Simpler for small datasets (4,500 topics). |
| Manual tree UI (collapsibleTree) | Standard selectInput cascade | Current best practice | SelectInputs are more accessible, simpler to maintain, better Shiny integration. Save tree viz for "browse mode" enhancement. |

**Deprecated/outdated:**
- Using `mailto` parameter without API key: No longer grants polite pool access as of Feb 2026
- OpenAlex concepts endpoint: Replaced by topics in 2024, use `/topics` not `/concepts`

## Open Questions

1. **How often do OpenAlex topics change?**
   - What we know: Topics API exists, ~4,500 topics, has `updated_date` field
   - What's unclear: Actual update frequency - weekly? monthly? quarterly?
   - Recommendation: Start with 30-day cache TTL. Monitor `updated_date` field in API responses to detect change frequency. Add admin UI to manually refresh if needed.

2. **Should we support topic search/filtering within the hierarchy?**
   - What we know: 4,500 topics is browsable but might benefit from search. SQL `LIKE` queries are fast for this scale.
   - What's unclear: User workflow preference - do they know topic name (search) or want to explore (browse)?
   - Recommendation: Phase 1 implementation uses hierarchy cascade only. Add search box above domain dropdown in Phase 2 if users request it. Low priority since hierarchy provides clear navigation path.

3. **Multiple topics per notebook or single topic only?**
   - What we know: OpenAlex supports OR filters: `primary_topic.id:T1|T2|T3`
   - What's unclear: UX complexity - how to select multiple topics in hierarchy UI?
   - Recommendation: Start with single-topic notebooks (simpler). If users want multi-topic, add "Add Another Topic" button that creates OR filter. This matches the seed paper pattern (single seed per notebook).

4. **Topic confidence scores - should we filter low-confidence assignments?**
   - What we know: OpenAlex assigns topics with scores, primary_topic is highest-scoring
   - What's unclear: Do topic objects include confidence thresholds? Should we expose this?
   - Recommendation: Use `primary_topic.id` filter (highest confidence) for Phase 1. Explore `topics.id` (includes all assigned topics) if users report missing papers. No UI for confidence adjustment unless explicitly requested.

## Sources

### Primary (HIGH confidence)
- [OpenAlex Topics API Documentation](https://docs.openalex.org/api-entities/topics) - Topic object structure, hierarchy, ~4,500 topics total
- [OpenAlex Get Lists of Topics](https://docs.openalex.org/api-entities/topics/get-lists-of-topics) - Pagination (offset-based), per_page/page parameters
- [OpenAlex Filter Works by Topic](https://docs.openalex.org/api-entities/works/filter-works) - primary_topic.id, primary_topic.domain.id, primary_topic.field.id, primary_topic.subfield.id filters
- [OpenAlex Topic Object](https://docs.openalex.org/api-entities/topics/topic-object) - Complete field inventory, hierarchy relationships
- [OpenAlex Rate Limits 2026](https://docs.openalex.org/how-to-use-the-api/rate-limits-and-authentication) - API keys required as of Feb 13, 2026; 100k credits/day free tier
- [DuckDB INSERT Documentation](https://duckdb.org/docs/stable/data/insert) - Bulk insert best practices
- Project codebase - migrations/002_create_topics_table.sql (schema), R/db.R (cache patterns lines 864-1048)

### Secondary (MEDIUM confidence)
- [Shiny Module Communication](https://shiny.posit.co/r/articles/improve/communicate-bet-modules/) - Producer-consumer pattern, reactive return values
- [Mastering Shiny Reactivity](https://mastering-shiny.org/reactivity-objects.html) - Cascading select pattern, updateSelectInput
- [collapsibleTree Package](https://github.com/AdeelK93/collapsibleTree) - D3.js tree visualization option (evaluated, not recommended for Phase 1)
- [shinytreeview Package](https://github.com/dreamRs/shinytreeview) - Alternative tree UI (evaluated, not recommended for Phase 1)

### Tertiary (LOW confidence)
- Web search results on topic update frequency - no official documentation found, using 30-day TTL as conservative estimate

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All dependencies already in project, OpenAlex API well-documented
- Architecture: HIGH - Reuses established patterns from Phase 0 (migrations), Phase 1 (producer-consumer), Phase 2 (quality cache)
- Pitfalls: MEDIUM - OpenAlex API key requirement verified (official docs), cache staleness based on general best practices not topic-specific guidance

**Research date:** 2026-02-11
**Valid until:** 2026-03-13 (30 days - stable domain, OpenAlex API unlikely to change significantly)
