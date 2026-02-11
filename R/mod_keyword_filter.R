#' Keyword Filter Module UI
#' @param id Module ID
mod_keyword_filter_ui <- function(id) {
  ns <- NS(id)

  div(
    # Summary line
    uiOutput(ns("summary")),
    # Keyword badges
    uiOutput(ns("keyword_badges")),
    # Active filter summary
    uiOutput(ns("filter_summary")),
    # Clear filters link
    uiOutput(ns("clear_link"))
  )
}

#' Keyword Filter Module Server
#' @param id Module ID
#' @param papers_data Reactive returning data.frame with keywords column (JSON-encoded)
mod_keyword_filter_server <- function(id, papers_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactively store keyword states: "neutral", "include", "exclude"
    keyword_states <- reactiveValues()

    # Track which keyword observers are active
    observer_tracking <- reactiveValues(active = list())

    # Aggregate keywords from papers_data
    all_keywords <- reactive({
      papers <- papers_data()
      if (nrow(papers) == 0) return(data.frame(keyword = character(), count = integer()))

      # Parse keywords from each paper
      keyword_list <- lapply(seq_len(nrow(papers)), function(i) {
        kw <- papers$keywords[i]
        if (is.na(kw) || is.null(kw) || nchar(kw) == 0) return(character())
        tryCatch({
          jsonlite::fromJSON(kw)
        }, error = function(e) character())
      })

      all_kw <- unlist(keyword_list)
      if (length(all_kw) == 0) return(data.frame(keyword = character(), count = integer()))

      # Count and sort
      kw_table <- table(all_kw)
      kw_df <- data.frame(
        keyword = names(kw_table),
        count = as.integer(kw_table),
        stringsAsFactors = FALSE
      )
      kw_df <- kw_df[order(-kw_df$count), ]

      # Limit to top 30
      head(kw_df, 30)
    })

    # Reset keyword states when papers_data changes (new search results)
    observe({
      keywords <- all_keywords()

      # Reset all states to neutral
      for (kw in keywords$keyword) {
        keyword_states[[kw]] <- "neutral"
      }
    })

    # Summary line
    output$summary <- renderUI({
      papers <- papers_data()
      keywords <- all_keywords()

      div(
        class = "mb-2 text-muted small",
        paste0(nrow(papers), " papers | ", nrow(keywords), " keywords")
      )
    })

    # Keyword badges
    output$keyword_badges <- renderUI({
      keywords <- all_keywords()

      if (nrow(keywords) == 0) {
        return(div(class = "text-muted text-center py-2", "No keywords available"))
      }

      div(
        class = "d-flex flex-wrap gap-1 mb-2",
        lapply(seq_len(nrow(keywords)), function(i) {
          kw <- keywords[i, ]
          sanitized_id <- gsub("[^a-zA-Z0-9]", "_", kw$keyword)
          input_id <- paste0("kw_", sanitized_id)

          # Get current state
          state <- keyword_states[[kw$keyword]] %||% "neutral"

          # Determine badge class and icon
          badge_class <- switch(state,
            "neutral" = "badge bg-secondary",
            "include" = "badge bg-success",
            "exclude" = "badge bg-danger",
            "badge bg-secondary"  # fallback
          )

          badge_icon <- switch(state,
            "neutral" = NULL,
            "include" = icon("plus", class = "me-1"),
            "exclude" = icon("minus", class = "me-1"),
            NULL
          )

          actionLink(
            ns(input_id),
            span(
              class = badge_class,
              style = "cursor: pointer;",
              badge_icon,
              paste0(kw$keyword, " (", kw$count, ")")
            )
          )
        })
      )
    })

    # Handle keyword clicks with observe() + lapply() pattern
    observe({
      keywords <- all_keywords()
      if (nrow(keywords) == 0) return()

      lapply(seq_len(nrow(keywords)), function(i) {
        kw <- keywords[i, ]
        sanitized_id <- gsub("[^a-zA-Z0-9]", "_", kw$keyword)
        input_id <- paste0("kw_", sanitized_id)

        observeEvent(input[[input_id]], {
          # Get current state
          current_state <- keyword_states[[kw$keyword]] %||% "neutral"

          # Cycle: neutral -> include -> exclude -> neutral
          new_state <- switch(current_state,
            "neutral" = "include",
            "include" = "exclude",
            "exclude" = "neutral",
            "include"  # fallback
          )

          keyword_states[[kw$keyword]] <- new_state
        }, ignoreInit = TRUE)
      })
    })

    # Filter summary
    output$filter_summary <- renderUI({
      # Count active filters
      keywords <- all_keywords()
      if (nrow(keywords) == 0) return(NULL)

      include_count <- sum(sapply(keywords$keyword, function(kw) {
        state <- keyword_states[[kw]] %||% "neutral"
        state == "include"
      }))

      exclude_count <- sum(sapply(keywords$keyword, function(kw) {
        state <- keyword_states[[kw]] %||% "neutral"
        state == "exclude"
      }))

      if (include_count == 0 && exclude_count == 0) return(NULL)

      div(
        class = "small text-muted mb-1",
        if (include_count > 0) {
          span(
            icon("check", class = "text-success me-1"),
            paste0(include_count, " included")
          )
        },
        if (include_count > 0 && exclude_count > 0) " | ",
        if (exclude_count > 0) {
          span(
            icon("xmark", class = "text-danger me-1"),
            paste0(exclude_count, " excluded")
          )
        }
      )
    })

    # Clear filters link
    output$clear_link <- renderUI({
      # Show only if any filter is active
      keywords <- all_keywords()
      if (nrow(keywords) == 0) return(NULL)

      has_active <- any(sapply(keywords$keyword, function(kw) {
        state <- keyword_states[[kw]] %||% "neutral"
        state != "neutral"
      }))

      if (!has_active) return(NULL)

      div(
        class = "mt-2",
        actionLink(ns("clear_filters"), "Clear filters", class = "small text-muted")
      )
    })

    # Clear filters handler
    observeEvent(input$clear_filters, {
      keywords <- all_keywords()
      for (kw in keywords$keyword) {
        keyword_states[[kw]] <- "neutral"
      }
    })

    # Filtered papers reactive (the key output)
    filtered_papers <- reactive({
      papers <- papers_data()
      if (nrow(papers) == 0) return(papers)

      keywords <- all_keywords()
      if (nrow(keywords) == 0) return(papers)

      # Collect included and excluded keywords
      include_set <- character()
      exclude_set <- character()

      for (kw in keywords$keyword) {
        state <- keyword_states[[kw]] %||% "neutral"
        if (state == "include") {
          include_set <- c(include_set, kw)
        } else if (state == "exclude") {
          exclude_set <- c(exclude_set, kw)
        }
      }

      # If no filters active, return all papers
      if (length(include_set) == 0 && length(exclude_set) == 0) {
        return(papers)
      }

      # Apply filters
      keep_indices <- logical(nrow(papers))

      for (i in seq_len(nrow(papers))) {
        paper_kw_json <- papers$keywords[i]

        # Parse paper keywords
        paper_keywords <- if (is.na(paper_kw_json) || is.null(paper_kw_json) || nchar(paper_kw_json) == 0) {
          character()
        } else {
          tryCatch({
            jsonlite::fromJSON(paper_kw_json)
          }, error = function(e) character())
        }

        # Check include filter (must have at least one included keyword)
        include_pass <- if (length(include_set) > 0) {
          any(paper_keywords %in% include_set)
        } else {
          TRUE  # No include filter, passes by default
        }

        # Check exclude filter (must NOT have any excluded keyword)
        exclude_pass <- if (length(exclude_set) > 0) {
          !any(paper_keywords %in% exclude_set)
        } else {
          TRUE  # No exclude filter, passes by default
        }

        # Both filters must pass (AND logic)
        keep_indices[i] <- include_pass && exclude_pass
      }

      papers[keep_indices, ]
    })

    # Return filtered papers reactive
    return(reactive(filtered_papers()))
  })
}
