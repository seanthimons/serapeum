#' Topic Explorer Module UI
#' @param id Module ID
mod_topic_explorer_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header("Explore Topics"),
    card_body(
      # Cache status indicator
      uiOutput(ns("cache_status")),

      # Refresh topics link button
      actionLink(ns("refresh_topics"), "Refresh Topics", icon = icon("refresh"),
                 class = "small text-muted"),

      hr(),

      # Topic search box
      textInput(
        ns("topic_search"),
        "Search topics:",
        placeholder = "Type to filter topics..."
      ),

      # Four cascading selectInput widgets
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

      # Topic details panel
      uiOutput(ns("topic_details")),

      hr(),

      # Create notebook button
      actionButton(
        ns("create_notebook_btn"),
        "Explore This Topic",
        class = "btn-success w-100",
        icon = icon("book")
      )
    )
  )
}

#' Topic Explorer Module Server
#' @param id Module ID
#' @param con Reactive database connection
#' @param config Reactive config
#' @return Reactive topic_request for app.R to consume
mod_topic_explorer_server <- function(id, con, config) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Internal state
    topics_cache <- reactiveVal(data.frame())
    topic_request <- reactiveVal(NULL)
    search_active <- reactiveVal(FALSE)

    # Cache loading (run once on module init)
    observe({
      # Get cached topics
      cached <- get_cached_topics(con(), max_age_days = 30)

      if (nrow(cached) == 0) {
        # Cache is empty, need to fetch from API
        cfg <- config()
        email <- get_setting(cfg, "openalex", "email")
        api_key <- get_setting(cfg, "openalex", "api_key")

        # Fetch topics from API
        withProgress(message = "Fetching topic taxonomy from OpenAlex...", {
          topics_df <- tryCatch({
            fetch_all_topics(email, api_key)
          }, error = function(e) {
            if (inherits(e, "api_error")) {
              show_error_toast(e$message, e$details, e$severity)
            } else {
              err <- classify_api_error(e, "OpenAlex")
              show_error_toast(err$message, err$details, err$severity)
            }
            NULL
          })

          if (!is.null(topics_df) && nrow(topics_df) > 0) {
            # Cache topics
            cache_topics(con(), topics_df)
            topics_cache(topics_df)
            showNotification(
              paste("Loaded", nrow(topics_df), "topics from OpenAlex"),
              type = "message",
              duration = 3
            )
          }
        })
      } else {
        # Cache is fresh
        topics_cache(cached)
      }
    }) |> bindEvent(TRUE, once = TRUE)

    # Cache status output
    output$cache_status <- renderUI({
      topics <- topics_cache()
      if (nrow(topics) == 0) {
        return(div(class = "text-muted small", "No topics cached yet"))
      }

      # Get cache metadata
      cache_meta <- get_quality_cache_meta(con(), "openalex_topics")
      last_updated <- if (!is.null(cache_meta)) {
        cache_meta$last_updated[1]
      } else {
        "unknown"
      }

      div(
        class = "text-muted small",
        paste(nrow(topics), "topics cached (last updated:", last_updated, ")")
      )
    })

    # Refresh button
    observeEvent(input$refresh_topics, {
      cfg <- config()
      email <- get_setting(cfg, "openalex", "email")
      api_key <- get_setting(cfg, "openalex", "api_key")

      withProgress(message = "Refreshing topic taxonomy from OpenAlex...", {
        topics_df <- tryCatch({
          fetch_all_topics(email, api_key)
        }, error = function(e) {
          if (inherits(e, "api_error")) {
            show_error_toast(e$message, e$details, e$severity)
          } else {
            err <- classify_api_error(e, "OpenAlex")
            show_error_toast(err$message, err$details, err$severity)
          }
          NULL
        })

        if (!is.null(topics_df) && nrow(topics_df) > 0) {
          cache_topics(con(), topics_df)
          topics_cache(topics_df)
          showNotification(
            paste("Refreshed", nrow(topics_df), "topics"),
            type = "message",
            duration = 3
          )
        }
      })
    })

    # Topic search filtering (debounced)
    search_text_debounced <- reactive({
      input$topic_search
    }) |> debounce(300)

    observe({
      search_text <- search_text_debounced()

      if (is.null(search_text) || nchar(trimws(search_text)) < 2) {
        # Clear search mode, restore hierarchy
        search_active(FALSE)
        # Load domain choices
        domains <- get_hierarchy_choices(con(), "domain")
        updateSelectInput(session, "domain", choices = c("Select domain..." = "", domains))
        updateSelectInput(session, "field", choices = c("Select domain first" = ""))
        updateSelectInput(session, "subfield", choices = c("Select field first" = ""))
        updateSelectInput(session, "topic", choices = c("Select subfield first" = ""))
      } else {
        # Search mode active
        search_active(TRUE)
        search_pattern <- paste0("%", tolower(trimws(search_text)), "%")

        # Query topics matching search
        results <- dbGetQuery(con(), "
          SELECT DISTINCT topic_id, display_name, works_count, domain_name, field_name, subfield_name
          FROM topics
          WHERE LOWER(display_name) LIKE ? OR LOWER(description) LIKE ? OR LOWER(keywords) LIKE ?
          ORDER BY works_count DESC
          LIMIT 50
        ", list(search_pattern, search_pattern, search_pattern))

        if (nrow(results) > 0) {
          # Format as "TopicName -- Domain > Field > Subfield (N works)"
          choices <- setNames(
            results$topic_id,
            sprintf("%s -- %s > %s > %s (%s works)",
                    results$display_name,
                    results$domain_name,
                    results$field_name,
                    results$subfield_name,
                    format(results$works_count, big.mark = ","))
          )

          # Clear hierarchy selects and update topic select directly
          updateSelectInput(session, "domain", choices = c("(using search)" = ""), selected = "")
          updateSelectInput(session, "field", choices = c("(using search)" = ""), selected = "")
          updateSelectInput(session, "subfield", choices = c("(using search)" = ""), selected = "")
          updateSelectInput(session, "topic", choices = c("Select a topic..." = "", choices))
        } else {
          # No results
          updateSelectInput(session, "topic", choices = c("No matches found" = ""))
        }
      }
    })

    # Hierarchy cascade: Domain selected
    observe({
      if (search_active()) return()  # Skip if search mode active

      domain_id <- input$domain
      req(domain_id, nchar(domain_id) > 0)

      # Update field choices
      fields <- get_hierarchy_choices(con(), "field", domain_id)
      updateSelectInput(session, "field", choices = c("Select field..." = "", fields), selected = "")

      # Reset downstream
      updateSelectInput(session, "subfield", choices = c("Select field first" = ""), selected = "")
      updateSelectInput(session, "topic", choices = c("Select subfield first" = ""), selected = "")
    }) |> bindEvent(input$domain)

    # Hierarchy cascade: Field selected
    observe({
      if (search_active()) return()

      field_id <- input$field
      req(field_id, nchar(field_id) > 0)

      # Update subfield choices
      subfields <- get_hierarchy_choices(con(), "subfield", field_id)
      updateSelectInput(session, "subfield", choices = c("Select subfield..." = "", subfields), selected = "")

      # Reset downstream
      updateSelectInput(session, "topic", choices = c("Select subfield first" = ""), selected = "")
    }) |> bindEvent(input$field)

    # Hierarchy cascade: Subfield selected
    observe({
      if (search_active()) return()

      subfield_id <- input$subfield
      req(subfield_id, nchar(subfield_id) > 0)

      # Update topic choices
      topics <- get_hierarchy_choices(con(), "topic", subfield_id)
      updateSelectInput(session, "topic", choices = c("Select topic..." = "", topics), selected = "")
    }) |> bindEvent(input$subfield)

    # Topic details panel
    output$topic_details <- renderUI({
      topic_id <- input$topic
      if (is.null(topic_id) || nchar(topic_id) == 0) return(NULL)

      # Query topic row from DB
      topic_row <- dbGetQuery(con(), "
        SELECT display_name, description, works_count, keywords
        FROM topics
        WHERE topic_id = ?
        LIMIT 1
      ", list(topic_id))

      if (nrow(topic_row) == 0) return(NULL)

      # Parse keywords from JSON
      keywords <- tryCatch({
        if (!is.na(topic_row$keywords) && nchar(topic_row$keywords) > 0) {
          jsonlite::fromJSON(topic_row$keywords)
        } else {
          NULL
        }
      }, error = function(e) NULL)

      div(
        class = "border rounded p-3 bg-light mt-3",
        h5(topic_row$display_name),
        p(class = "small text-muted", topic_row$description),
        p(class = "mb-2",
          strong("Works: "),
          format(topic_row$works_count, big.mark = ",")
        ),
        if (!is.null(keywords) && length(keywords) > 0) {
          div(
            class = "mb-0",
            strong("Keywords: "),
            lapply(keywords, function(kw) {
              tags$span(class = "badge bg-secondary me-1", kw)
            })
          )
        }
      )
    })

    # Create notebook button
    observeEvent(input$create_notebook_btn, {
      topic_id <- input$topic
      req(topic_id, nchar(topic_id) > 0)

      # Query topic display name
      topic_row <- dbGetQuery(con(), "
        SELECT display_name
        FROM topics
        WHERE topic_id = ?
        LIMIT 1
      ", list(topic_id))

      if (nrow(topic_row) == 0) {
        showNotification("Topic not found", type = "error")
        return()
      }

      # Set topic request for app.R to consume
      topic_request(list(
        topic_id = topic_id,
        topic_name = topic_row$display_name,
        notebook_name = paste("Topic:", topic_row$display_name)
      ))
    })

    # Return topic request reactive
    return(topic_request)
  })
}
