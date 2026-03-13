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

    # Aggregate keywords from papers_data (top-30 + any user-acted keywords)
    all_keywords <- reactive({
      papers <- papers_data()
      if (nrow(papers) == 0) return(data.frame(keyword = character(), count = integer()))

      # Parse keywords from each paper, normalize to lowercase
      keyword_list <- lapply(seq_len(nrow(papers)), function(i) {
        kw <- papers$keywords[i]
        if (is.na(kw) || is.null(kw) || nchar(kw) == 0) return(character())
        tryCatch({
          tolower(jsonlite::fromJSON(kw))
        }, error = function(e) character())
      })

      all_kw <- unlist(keyword_list)
      if (length(all_kw) == 0) {
        # Even with no paper keywords, promoted keywords should still appear
        all_states <- reactiveValuesToList(keyword_states)
        acted <- names(all_states)[vapply(all_states, function(s) s != "neutral", logical(1))]
        if (length(acted) == 0) return(data.frame(keyword = character(), count = integer()))
        return(data.frame(keyword = acted, count = rep(0L, length(acted)), stringsAsFactors = FALSE))
      }

      # Count and sort
      kw_table <- table(all_kw)
      kw_df <- data.frame(
        keyword = names(kw_table),
        count = as.integer(kw_table),
        stringsAsFactors = FALSE
      )
      kw_df <- kw_df[order(-kw_df$count), ]

      # Top 30 by frequency
      top_30 <- head(kw_df, 30)

      # Append any user-acted keywords not already in top-30 (#151)
      all_states <- reactiveValuesToList(keyword_states)
      acted_keywords <- names(all_states)[vapply(all_states, function(s) s != "neutral", logical(1))]
      promoted <- setdiff(acted_keywords, top_30$keyword)

      if (length(promoted) > 0) {
        promoted_counts <- vapply(promoted, function(k) {
          s <- kw_table[k]
          if (is.na(s)) 0L else as.integer(s)
        }, integer(1))
        promoted_df <- data.frame(
          keyword = promoted,
          count = promoted_counts,
          stringsAsFactors = FALSE
        )
        promoted_df <- promoted_df[order(-promoted_df$count), ]
        top_30 <- rbind(top_30, promoted_df)
      }

      top_30
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

          badge_title <- switch(state,
            "neutral" = paste0("Click to include '", kw$keyword, "' in filter"),
            "include" = paste0("Click to exclude '", kw$keyword, "'"),
            "exclude" = paste0("Click to clear '", kw$keyword, "' filter"),
            ""
          )

          actionLink(
            ns(input_id),
            span(
              class = badge_class,
              style = "cursor: pointer;",
              badge_icon,
              paste0(kw$keyword, " (", kw$count, ")")
            ),
            title = badge_title
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

    # Filter summary — count ALL keyword states, not just top-30
    output$filter_summary <- renderUI({
      all_states <- reactiveValuesToList(keyword_states)
      if (length(all_states) == 0) return(NULL)

      state_values <- unlist(all_states)
      include_count <- sum(state_values == "include")
      exclude_count <- sum(state_values == "exclude")

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

    # Clear filters link — check ALL keyword states
    output$clear_link <- renderUI({
      all_states <- reactiveValuesToList(keyword_states)
      if (length(all_states) == 0) return(NULL)

      has_active <- any(vapply(all_states, function(s) s != "neutral", logical(1)))
      if (!has_active) return(NULL)

      div(
        class = "mt-2",
        actionLink(ns("clear_filters"), "Clear filters", class = "small text-muted")
      )
    })

    # Clear filters handler — reset ALL keyword states including promoted
    observeEvent(input$clear_filters, {
      all_states <- reactiveValuesToList(keyword_states)
      for (kw in names(all_states)) {
        keyword_states[[kw]] <- "neutral"
      }
    })

    # Filtered papers reactive — uses ALL keyword states (including promoted)
    filtered_papers <- reactive({
      papers <- papers_data()
      if (nrow(papers) == 0) return(papers)

      # Collect include/exclude from ALL keyword states, not just all_keywords()
      all_states <- reactiveValuesToList(keyword_states)
      include_set <- names(all_states)[vapply(all_states, function(s) s == "include", logical(1))]
      exclude_set <- names(all_states)[vapply(all_states, function(s) s == "exclude", logical(1))]

      # If no filters active, return all papers
      if (length(include_set) == 0 && length(exclude_set) == 0) {
        return(papers)
      }

      # Apply filters
      keep_indices <- logical(nrow(papers))

      for (i in seq_len(nrow(papers))) {
        paper_kw_json <- papers$keywords[i]

        # Parse paper keywords, normalize to lowercase for matching
        paper_keywords <- if (is.na(paper_kw_json) || is.null(paper_kw_json) || nchar(paper_kw_json) == 0) {
          character()
        } else {
          tryCatch({
            tolower(jsonlite::fromJSON(paper_kw_json))
          }, error = function(e) character())
        }

        # Check include filter (must have at least one included keyword)
        include_pass <- if (length(include_set) > 0) {
          any(paper_keywords %in% include_set)
        } else {
          TRUE
        }

        # Check exclude filter (must NOT have any excluded keyword)
        exclude_pass <- if (length(exclude_set) > 0) {
          !any(paper_keywords %in% exclude_set)
        } else {
          TRUE
        }

        # Both filters must pass (AND logic)
        keep_indices[i] <- include_pass && exclude_pass
      }

      papers[keep_indices, ]
    })

    # Return list with filtered papers + state accessors (like mod_journal_filter pattern)
    return(list(
      filtered_papers = reactive(filtered_papers()),
      set_keyword_state = function(keyword, state) {
        keyword_states[[keyword]] <- state
      },
      get_keyword_state = function(keyword) {
        keyword_states[[keyword]] %||% "neutral"
      }
    ))
  })
}
