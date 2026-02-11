#' Journal Filter Module UI
#' @param id Module ID
mod_journal_filter_ui <- function(id) {
  ns <- NS(id)

  div(
    # Filter toggle
    div(
      class = "mb-2",
      checkboxInput(
        ns("filter_predatory"),
        "Hide flagged journals",
        value = FALSE
      )
    ),
    # Summary line
    uiOutput(ns("summary")),
    # Blocklist info
    uiOutput(ns("blocklist_info"))
  )
}

#' Journal Filter Module Server
#' @param id Module ID
#' @param papers_data Reactive returning data.frame with venue column
#' @param con Reactive returning DuckDB connection
mod_journal_filter_server <- function(id, papers_data, con) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Trigger for blocklist refresh (incremented when journal added/removed)
    blocklist_refresh <- reactiveVal(0)

    # Load quality filter sets (cached with invalidation)
    quality_sets <- reactive({
      # Depend on blocklist refresh trigger
      blocklist_refresh()

      list(
        predatory_journals = get_predatory_journals_set(con()),
        predatory_publishers = get_predatory_publishers_set(con()),
        blocked_journals = get_blocked_journals_set(con())
      )
    })

    # Annotate papers with quality flags
    quality_annotated_papers <- reactive({
      papers <- papers_data()
      if (nrow(papers) == 0) return(papers)

      sets <- quality_sets()

      # Add quality flag columns
      papers$is_predatory <- logical(nrow(papers))
      papers$is_blocked <- logical(nrow(papers))
      papers$is_flagged <- logical(nrow(papers))
      papers$quality_flag_text <- character(nrow(papers))

      for (i in seq_len(nrow(papers))) {
        venue <- papers$venue[i]

        if (is.null(venue) || is.na(venue) || venue == "") {
          next
        }

        venue_normalized <- normalize_name(venue)

        # Check predatory lists (journals and publishers)
        is_pred_journal <- venue_normalized %in% sets$predatory_journals
        is_pred_publisher <- FALSE  # Would need publisher field from OpenAlex

        # Check personal blocklist
        is_blocked <- venue_normalized %in% sets$blocked_journals

        # Set flags
        papers$is_predatory[i] <- is_pred_journal || is_pred_publisher
        papers$is_blocked[i] <- is_blocked
        papers$is_flagged[i] <- papers$is_predatory[i] || is_blocked

        # Generate flag text
        if (papers$is_predatory[i] && is_blocked) {
          papers$quality_flag_text[i] <- "Predatory journal (blocked)"
        } else if (papers$is_predatory[i]) {
          papers$quality_flag_text[i] <- "Predatory journal"
        } else if (is_blocked) {
          papers$quality_flag_text[i] <- "Blocked journal"
        }
      }

      papers
    })

    # Apply filter toggle
    filtered_papers <- reactive({
      papers <- quality_annotated_papers()

      # If filter is enabled, remove flagged papers
      if (isTRUE(input$filter_predatory)) {
        papers <- papers[!papers$is_flagged, ]
      }

      papers
    })

    # Summary output
    output$summary <- renderUI({
      papers <- quality_annotated_papers()
      flagged_count <- sum(papers$is_flagged)

      if (flagged_count == 0) return(NULL)

      div(
        class = "small text-muted mb-2",
        icon("triangle-exclamation", class = "text-warning me-1"),
        paste0(flagged_count, " of ", nrow(papers), " papers flagged")
      )
    })

    # Blocklist info
    output$blocklist_info <- renderUI({
      blocked_count <- length(quality_sets()$blocked_journals)

      if (blocked_count == 0) {
        return(div(
          class = "small text-muted",
          "No journals blocked"
        ))
      }

      div(
        class = "small text-muted",
        icon("ban", class = "text-danger me-1"),
        paste0(blocked_count, " journal", if (blocked_count != 1) "s", " blocked"),
        " | ",
        actionLink(ns("manage_blocklist"), "Manage", class = "small")
      )
    })

    # Block journal function (callable by parent module)
    block_journal <- function(journal_name) {
      if (is.null(journal_name) || is.na(journal_name) || journal_name == "") {
        return(FALSE)
      }

      result <- add_blocked_journal(con(), journal_name)

      # Invalidate blocklist cache
      if (result) {
        blocklist_refresh(blocklist_refresh() + 1)
      }

      result
    }

    # Blocklist count reactive
    blocklist_count <- reactive({
      length(quality_sets()$blocked_journals)
    })

    # Return API for parent module
    list(
      filtered_papers = filtered_papers,
      block_journal = block_journal,
      blocklist_count = blocklist_count
    )
  })
}
