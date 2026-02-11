#' Query Builder Module UI
#' @param id Module ID
mod_query_builder_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header("Build a Research Query"),
    card_body(
      textAreaInput(
        ns("nl_query"),
        "Describe what you're looking for:",
        placeholder = "Example: Recent high-impact papers on transformer architectures in NLP",
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

#' Query Builder Module Server
#' @param id Module ID
#' @param con Reactive database connection
#' @param config Reactive config
#' @return Reactive discovery_request for app.R to consume
mod_query_builder_server <- function(id, con, config) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Internal state
    generated_query <- reactiveVal(NULL)
    discovery_request <- reactiveVal(NULL)

    # System prompt for LLM
    system_prompt <- "You are an OpenAlex API query builder. Convert research questions to OpenAlex filter syntax.

ALLOWED FILTERS (use ONLY these):
publication_year, cited_by_count, fwci, is_oa, has_abstract, is_retracted,
type, oa_status, language, from_publication_date, to_publication_date,
title.search, abstract.search, default.search

FILTER SYNTAX:
- Single: attribute:value  (e.g., publication_year:2024)
- Multiple (AND): attr1:val1,attr2:val2
- OR values: attr:val1|val2
- Comparison: cited_by_count:>100, publication_year:<2020
- Negation: type:!book

RULES:
- Only use filters from the allowed list above
- Always include has_abstract:true
- For year ranges, use from_publication_date/to_publication_date (format: YYYY-MM-DD)
- For keyword search, use default.search with key terms

OUTPUT (valid JSON only, no markdown, no code fences):
{
  \"search\": \"keyword search terms or null\",
  \"filter\": \"comma-separated filters\",
  \"explanation\": \"plain English summary of what this query does\"
}"

    # Generate button handler
    observeEvent(input$generate_btn, {
      req(input$nl_query)

      # Get config values
      cfg <- config()
      api_key <- get_setting(cfg, "openrouter", "api_key")
      model <- get_setting(cfg, "openrouter", "model") %||% "anthropic/claude-sonnet-4"

      if (is.null(api_key) || nchar(api_key) == 0) {
        showNotification(
          "OpenRouter API key not configured. Please go to Settings.",
          type = "warning",
          duration = 5
        )
        return()
      }

      withProgress(message = "Generating query...", {
        # Call LLM
        response <- tryCatch({
          chat_completion(
            api_key,
            model,
            format_chat_messages(system_prompt, input$nl_query)
          )
        }, error = function(e) {
          showNotification(
            paste("Error calling LLM:", e$message),
            type = "error",
            duration = 5
          )
          NULL
        })

        if (is.null(response)) return()

        # Parse JSON response
        parsed <- tryCatch({
          jsonlite::fromJSON(response)
        }, error = function(e) {
          showNotification(
            paste("Error parsing LLM response:", e$message),
            type = "error",
            duration = 5
          )
          NULL
        })

        if (is.null(parsed)) return()

        # Validate filters
        validation <- validate_openalex_filters(parsed$filter)
        if (!validation$valid) {
          showNotification(
            paste("Invalid filters generated:", validation$error),
            type = "error",
            duration = 5
          )
          return()
        }

        # Success
        generated_query(parsed)
        showNotification(
          "Query generated successfully!",
          type = "message",
          duration = 3
        )
      })
    })

    # Query preview
    output$query_preview <- renderUI({
      query <- generated_query()
      if (is.null(query)) return(NULL)

      div(
        class = "border rounded p-3 bg-light",
        h6("Generated Query"),
        p(class = "mb-2", query$explanation),
        div(
          class = "mb-2",
          strong("Search terms: "),
          if (is.null(query$search) || query$search == "null") "(none)" else query$search
        ),
        div(
          class = "mb-3",
          strong("Filters: "),
          tags$code(query$filter)
        ),
        actionButton(
          ns("execute_btn"),
          "Create Search Notebook",
          class = "btn-success w-100"
        )
      )
    })

    # Execute button handler
    observeEvent(input$execute_btn, {
      query <- generated_query()
      req(query)

      # Build filters list
      filters <- list(
        search = if (is.null(query$search) || query$search == "null") NULL else query$search,
        filter = query$filter
      )

      # Create notebook name from NL query (first 50 chars)
      notebook_name <- paste("Search:", substr(input$nl_query, 1, 50))

      # Set discovery request for app.R to consume
      discovery_request(list(
        query = filters$search,
        filters = filters,
        notebook_name = notebook_name
      ))
    })

    # Return discovery request reactive
    return(discovery_request)
  })
}
