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
#' @param remaining_count Optional reactive returning remaining result count from pagination
mod_keyword_filter_server <- function(id, papers_data, remaining_count = reactive(NULL)) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactively store keyword states: "neutral", "include", "exclude"
    keyword_states <- reactiveValues()

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

    # Initialize keyword states for new keywords only (preserve existing include/exclude)
    observe({
      keywords <- all_keywords()

      for (kw in keywords$keyword) {
        if (is.null(keyword_states[[kw]])) {
          keyword_states[[kw]] <- "neutral"
        }
      }
    })

    # Summary line
    output$summary <- renderUI({
      papers <- papers_data()
      keywords <- all_keywords()
      remaining <- remaining_count()

      base_text <- paste0(nrow(papers), " papers | ", nrow(keywords), " keywords")

      if (!is.null(remaining) && remaining > 0) {
        div(
          class = "mb-2 text-muted small",
          HTML(paste0(
            base_text, " | ",
            "<strong>", format_large_number(remaining), " remaining</strong>"
          ))
        )
      } else {
        div(
          class = "mb-2 text-muted small",
          base_text
        )
      }
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
          input_id <- paste0("kw_", i)

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
            "include" = icon_add(class = "me-1"),
            "exclude" = icon_minus(class = "me-1"),
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

    # Handle keyword clicks — teardown old observers before creating new ones
    keyword_observers <- list()

    observe({
      keywords <- all_keywords()

      # Destroy previous observers
      for (obs in keyword_observers) {
        obs$destroy()
      }
      keyword_observers <<- list()

      if (nrow(keywords) == 0) return()

      keyword_observers <<- lapply(seq_len(nrow(keywords)), function(i) {
        kw_name <- keywords$keyword[i]
        input_id <- paste0("kw_", i)

        observeEvent(input[[input_id]], {
          current_state <- keyword_states[[kw_name]] %||% "neutral"

          # Cycle: neutral -> include -> exclude -> neutral
          new_state <- switch(current_state,
            "neutral" = "include",
            "include" = "exclude",
            "exclude" = "neutral",
            "include"
          )

          keyword_states[[kw_name]] <- new_state
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
            icon_check(class = "text-success me-1"),
            paste0(include_count, " included")
          )
        },
        if (include_count > 0 && exclude_count > 0) " | ",
        if (exclude_count > 0) {
          span(
            icon_close(class = "text-danger me-1"),
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
