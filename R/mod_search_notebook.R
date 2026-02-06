# Note: ragnar_available() is defined in R/_ragnar.R (sourced first alphabetically)

#' Validate URL is safe for use in href (HTTP/HTTPS only)
#' @param url URL to validate
#' @return TRUE if URL is safe, FALSE otherwise
is_safe_url <- function(url) {
  if (is.na(url) || is.null(url) || nchar(url) == 0) return(FALSE)
  grepl("^https?://", url, ignore.case = TRUE)
}

#' Search Notebook Module UI
#' @param id Module ID
mod_search_notebook_ui <- function(id) {

  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(4, 8),
      # Left: Paper list
      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          span("Papers"),
          div(
            class = "d-flex gap-2",
            actionButton(ns("edit_search"), NULL,
                         class = "btn-sm btn-outline-secondary",
                         icon = icon("pen-to-square"),
                         title = "Edit Search"),
            actionButton(ns("refresh_search"), "Refresh",
                         class = "btn-sm btn-outline-secondary",
                         icon = icon("rotate"))
          )
        ),
        card_body(
          # Filter controls
          div(
            class = "mb-2",
            checkboxInput(
              ns("filter_has_abstract"),
              "Show only papers with abstracts",
              value = TRUE
            )
          ),
          div(
            id = ns("paper_list_container"),
            style = "max-height: 400px; overflow-y: auto;",
            uiOutput(ns("paper_list"))
          ),
          hr(),
          uiOutput(ns("selection_info")),
          actionButton(ns("import_selected"), "Import Selected to Notebook",
                       class = "btn-primary w-100",
                       icon = icon("download"))
        )
      ),
      # Right: Keyword panel + Abstract detail view
      div(
        # Keyword filter panel
        card(
          card_header("Keywords"),
          card_body(
            style = "max-height: 200px; overflow-y: auto;",
            uiOutput(ns("keyword_panel"))
          ),
          card_footer(
            class = "d-flex flex-column gap-2",
            uiOutput(ns("embed_button")),
            uiOutput(ns("exclusion_info"))
          )
        ),
        # Abstract detail view
        card(
          class = "mt-2",
          card_header(
            class = "d-flex justify-content-between align-items-center",
            span("Abstract Details"),
            uiOutput(ns("detail_actions"))
          ),
          card_body(
            style = "height: 350px; overflow-y: auto;",
            uiOutput(ns("abstract_detail"))
          )
        )
      )
    ),

    # Floating chat button with dynamic badge
    div(
      style = "position: fixed; bottom: 24px; right: 24px; z-index: 1000;",
      uiOutput(ns("chat_button"))
    ),

    # Offcanvas chat panel
    div(
      id = ns("chat_offcanvas"),
      class = "offcanvas offcanvas-end",
      style = "width: 400px;",
      `data-bs-scroll` = "true",
      `data-bs-backdrop` = "false",
      tabindex = "-1",

      # Header
      div(
        class = "offcanvas-header border-bottom",
        h5(class = "offcanvas-title", "Chat with Abstracts"),
        tags$button(
          type = "button",
          class = "btn-close",
          `data-bs-dismiss` = "offcanvas",
          `aria-label` = "Close"
        )
      ),

      # Body
      div(
        class = "offcanvas-body d-flex flex-column p-0",
        # Messages area
        div(
          id = ns("chat_messages"),
          class = "flex-grow-1 overflow-auto p-3",
          style = "background-color: var(--bs-light);",
          uiOutput(ns("messages"))
        ),
        # Input area
        div(
          class = "border-top p-3",
          div(
            class = "d-flex gap-2",
            div(
              class = "flex-grow-1",
              textInput(ns("user_input"), NULL,
                        placeholder = "Ask about these papers...",
                        width = "100%")
            ),
            actionButton(ns("send"), NULL, class = "btn-primary",
                         icon = icon("paper-plane"))
          )
        )
      )
    )
  )
}

#' Search Notebook Module Server
#' @param id Module ID
#' @param con Database connection (reactive)
#' @param notebook_id Reactive notebook ID
#' @param config App config (reactive)
mod_search_notebook_server <- function(id, con, notebook_id, config, notebook_refresh = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    messages <- reactiveVal(list())
    selected_papers <- reactiveVal(character())
    viewed_paper <- reactiveVal(NULL)
    paper_refresh <- reactiveVal(0)
    is_processing <- reactiveVal(FALSE)

    # Reactive: check if API key is configured
    has_api_key <- reactive({
      cfg <- config()
      api_key <- get_setting(cfg, "openrouter", "api_key")
      !is.null(api_key) && nchar(api_key) > 0
    })

    # Restore filter state when notebook changes
    observe({
      nb_id <- notebook_id()
      req(nb_id)

      nb <- get_notebook(con(), nb_id)
      req(nb$type == "search")

      # Parse stored filters
      filters <- if (!is.na(nb$search_filters) && nchar(nb$search_filters) > 0) {
        tryCatch(jsonlite::fromJSON(nb$search_filters), error = function(e) list())
      } else {
        list()
      }

      # Restore has_abstract filter (default TRUE for backward compatibility)
      has_abstract <- if (!is.null(filters$has_abstract)) filters$has_abstract else TRUE
      updateCheckboxInput(session, "filter_has_abstract", value = has_abstract)
    })

    # Save has_abstract filter when changed
    observeEvent(input$filter_has_abstract, {
      nb_id <- notebook_id()
      req(nb_id)

      nb <- get_notebook(con(), nb_id)
      req(nb$type == "search")

      # Parse existing filters
      filters <- if (!is.na(nb$search_filters) && nchar(nb$search_filters) > 0) {
        tryCatch(jsonlite::fromJSON(nb$search_filters), error = function(e) list())
      } else {
        list()
      }

      # Update has_abstract filter
      filters$has_abstract <- input$filter_has_abstract

      # Save back to database
      update_notebook(con(), nb_id, search_filters = filters)
    }, ignoreInit = TRUE)

    # Get papers for this notebook
    papers_data <- reactive({
      paper_refresh()
      nb_id <- notebook_id()
      req(nb_id)
      list_abstracts(con(), nb_id)
    })

    # Filtered papers based on "has abstract" checkbox
    filtered_papers <- reactive({
      papers <- papers_data()
      if (nrow(papers) == 0) return(papers)

      if (isTRUE(input$filter_has_abstract)) {
        papers <- papers[!is.na(papers$abstract) & nchar(papers$abstract) > 0, ]
      }
      papers
    })

    # Aggregate keywords from all papers
    all_keywords <- reactive({
      papers <- papers_data()
      if (nrow(papers) == 0) return(data.frame(keyword = character(), count = integer()))

      # Parse keywords from each paper and count
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
      kw_df[order(-kw_df$count), ]
    })

    # Keyword panel
    output$keyword_panel <- renderUI({
      keywords <- all_keywords()
      papers <- papers_data()

      if (nrow(papers) == 0) {
        return(div(class = "text-muted text-center py-2", "No papers loaded"))
      }

      if (nrow(keywords) == 0) {
        return(div(class = "text-muted text-center py-2", "No keywords available"))
      }

      # Limit to top 30 keywords
      keywords <- head(keywords, 30)

      div(
        div(class = "mb-2 text-muted small",
            paste(nrow(papers), "papers")),
        div(
          class = "d-flex flex-wrap gap-1",
          lapply(seq_len(nrow(keywords)), function(i) {
            kw <- keywords[i, ]
            actionLink(
              ns(paste0("kw_", gsub("[^a-zA-Z0-9]", "_", kw$keyword))),
              span(
                class = "badge bg-secondary",
                style = "cursor: pointer;",
                paste0(kw$keyword, " (", kw$count, ")")
              ),
              title = paste("Click to remove", kw$count, "papers")
            )
          })
        )
      )
    })

    # Paper list
    output$paper_list <- renderUI({
      papers <- filtered_papers()
      current_viewed <- viewed_paper()

      if (nrow(papers) == 0) {
        return(
          div(
            class = "text-center text-muted py-4",
            icon("magnifying-glass", class = "fa-3x mb-2"),
            p("No papers loaded yet"),
            p(class = "small", "Click 'Refresh' to search")
          )
        )
      }

      lapply(seq_len(nrow(papers)), function(i) {
        paper <- papers[i, ]
        authors <- tryCatch({
          jsonlite::fromJSON(paper$authors)
        }, error = function(e) {
          character()
        })

        author_str <- if (length(authors) == 0) {
          "Unknown authors"
        } else if (length(authors) > 2) {
          paste0(authors[1], " et al.")
        } else {
          paste(authors, collapse = ", ")
        }

        checkbox_id <- paste0("select_", paper$id)
        is_viewed <- !is.null(current_viewed) && current_viewed == paper$id

        # Check if PDF is available (validate URL is safe HTTP/HTTPS)
        has_pdf <- is_safe_url(paper$pdf_url)

        div(
          class = paste("border-bottom py-2", if (is_viewed) "bg-light"),
          div(
            class = "d-flex align-items-start gap-2",
            checkboxInput(ns(checkbox_id), label = NULL, width = "25px"),
            actionLink(
              ns(paste0("view_", paper$id)),
              div(
                class = "flex-grow-1",
                style = "min-width: 0; cursor: pointer;",
                div(
                  class = paste("fw-semibold", if (is_viewed) "text-primary"),
                  style = "word-wrap: break-word;",
                  paper$title
                ),
                div(class = "text-muted small",
                    paste(author_str, "-", paper$year %||% "N/A")),
                if (!is.na(paper$venue) && nchar(paper$venue) > 0) {
                  div(class = "text-muted small fst-italic text-truncate", paper$venue)
                }
              )
            ),
            # PDF download link (if available)
            if (has_pdf) {
              tags$a(
                href = paper$pdf_url,
                target = "_blank",
                class = "btn btn-sm btn-outline-danger py-0 px-1 ms-1",
                title = "View PDF",
                icon("file-pdf")
              )
            }
          )
        )
      })
    })

    # Observe paper view clicks
    observe({
      papers <- filtered_papers()
      if (nrow(papers) == 0) return()

      lapply(papers$id, function(paper_id) {
        observeEvent(input[[paste0("view_", paper_id)]], {
          viewed_paper(paper_id)
        }, ignoreInit = TRUE)
      })
    })

    # Track selected papers (for import)
    observe({
      papers <- filtered_papers()
      if (nrow(papers) == 0) return()

      selected <- character()
      for (i in seq_len(nrow(papers))) {
        paper <- papers[i, ]
        checkbox_id <- paste0("select_", paper$id)
        if (isTRUE(input[[checkbox_id]])) {
          selected <- c(selected, paper$id)
        }
      }
      selected_papers(selected)
    })

    # Selection info
    output$selection_info <- renderUI({
      n <- length(selected_papers())
      if (n == 0) {
        span(class = "text-muted small", "Select papers to import")
      } else {
        span(class = "text-primary small fw-semibold",
             paste(n, "paper(s) selected"))
      }
    })

    # Abstract detail view
    output$abstract_detail <- renderUI({
      paper_id <- viewed_paper()

      if (is.null(paper_id)) {
        return(
          div(
            class = "text-center text-muted py-5",
            icon("file-lines", class = "fa-3x mb-3"),
            h5("No paper selected"),
            p("Click on a paper title to view its abstract")
          )
        )
      }

      papers <- papers_data()
      paper <- papers[papers$id == paper_id, ]

      if (nrow(paper) == 0) {
        viewed_paper(NULL)
        return(NULL)
      }

      paper <- paper[1, ]

      # Parse authors
      authors <- tryCatch({
        jsonlite::fromJSON(paper$authors)
      }, error = function(e) {
        character()
      })

      author_str <- if (length(authors) == 0) {
        "Unknown authors"
      } else {
        paste(authors, collapse = ", ")
      }

      # Parse keywords
      keywords_ui <- NULL
      if (!is.null(paper$keywords) && !is.na(paper$keywords) && nchar(paper$keywords) > 0) {
        keywords <- tryCatch({
          jsonlite::fromJSON(paper$keywords)
        }, error = function(e) character())

        if (length(keywords) > 0) {
          keywords_ui <- div(
            class = "mt-2",
            tags$small(class = "text-muted", "Keywords: "),
            lapply(keywords, function(k) {
              span(class = "badge bg-secondary me-1", k)
            })
          )
        }
      }

      tagList(
        # Title
        h5(class = "mb-3", paper$title),

        # Metadata
        div(
          class = "mb-3",
          div(
            class = "d-flex flex-wrap gap-2 mb-2",
            if (!is.null(paper$year) && !is.na(paper$year)) {
              span(class = "badge bg-secondary", paper$year)
            },
            if (!is.na(paper$venue) && nchar(paper$venue) > 0) {
              span(class = "badge bg-light text-dark border", paper$venue)
            }
          ),
          div(class = "text-muted", author_str)
        ),

        hr(),

        # Abstract
        if (!is.na(paper$abstract) && nchar(paper$abstract) > 0) {
          div(
            h6(class = "text-muted mb-2", "Abstract"),
            p(style = "line-height: 1.6;", paper$abstract)
          )
        } else {
          div(
            class = "alert alert-light",
            icon("circle-info", class = "me-2"),
            "No abstract available for this paper."
          )
        },

        # Keywords
        keywords_ui,

        # PDF link if available (validate URL is safe HTTP/HTTPS)
        if (is_safe_url(paper$pdf_url)) {
          div(
            class = "mt-3",
            tags$a(
              href = paper$pdf_url,
              target = "_blank",
              rel = "noopener noreferrer",
              class = "btn btn-outline-primary btn-sm",
              icon("file-pdf", class = "me-1"),
              "View PDF ",
              icon("arrow-up-right-from-square", class = "ms-1 small")
            )
          )
        }
      )
    })

    # Detail actions (close button)
    output$detail_actions <- renderUI({
      if (is.null(viewed_paper())) return(NULL)

      actionButton(
        ns("close_detail"),
        icon("xmark"),
        class = "btn-sm btn-outline-secondary"
      )
    })

    observeEvent(input$close_detail, {
      viewed_paper(NULL)
    })

    # Chat button with message count badge
    output$chat_button <- renderUI({
      msgs <- messages()
      msg_count <- length(msgs)

      # Badge showing message count (only if there are messages)
      badge <- if (msg_count > 0) {
        span(
          class = "position-absolute top-0 start-100 translate-middle badge rounded-pill bg-danger",
          msg_count,
          span(class = "visually-hidden", "messages")
        )
      }

      tags$button(
        id = ns("toggle_chat"),
        class = "btn btn-primary btn-lg rounded-pill shadow position-relative",
        onclick = sprintf("
          var offcanvas = new bootstrap.Offcanvas(document.getElementById('%s'));
          offcanvas.toggle();
        ", ns("chat_offcanvas")),
        icon("comments"),
        " Chat",
        badge
      )
    })

    # Edit search modal
    observeEvent(input$edit_search, {
      nb_id <- notebook_id()
      req(nb_id)

      nb <- get_notebook(con(), nb_id)
      req(nb$type == "search")

      # Parse existing filters
      filters <- if (!is.na(nb$search_filters) && nchar(nb$search_filters) > 0) {
        tryCatch(jsonlite::fromJSON(nb$search_filters), error = function(e) list())
      } else {
        list()
      }

      showModal(modalDialog(
        title = tagList(icon("pen-to-square"), " Edit Search"),
        size = "m",

        # Search terms
        textInput(ns("edit_query"), "Search Terms",
                  value = nb$search_query %||% "",
                  placeholder = "e.g., deep learning medical imaging"),

        # Search field selector
        selectInput(ns("edit_search_field"), "Search In",
                    choices = c(
                      "All Fields" = "default",
                      "Title Only" = "title",
                      "Abstract Only" = "abstract",
                      "Title & Abstract" = "title_and_abstract"
                    ),
                    selected = filters$search_field %||% "default"),

        # Year range
        layout_columns(
          col_widths = c(6, 6),
          numericInput(ns("edit_from_year"), "From Year",
                       value = filters$from_year %||% 2020,
                       min = 1900, max = 2030),
          numericInput(ns("edit_to_year"), "To Year",
                       value = filters$to_year %||% 2025,
                       min = 1900, max = 2030)
        ),

        # Open access filter
        checkboxInput(ns("edit_is_oa"), "Open Access Only",
                      value = isTRUE(filters$is_oa)),

        # Query preview (collapsible)
        tags$details(
          class = "mt-3",
          tags$summary(class = "text-muted small cursor-pointer", "Show API Query"),
          div(
            class = "mt-2 p-2 bg-light rounded small font-monospace",
            style = "word-break: break-all;",
            uiOutput(ns("query_preview"))
          )
        ),

        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("save_search"), "Save & Refresh", class = "btn-primary")
        )
      ))
    })

    # Query preview (reactive)
    output$query_preview <- renderUI({
      query <- input$edit_query %||% ""
      from_year <- input$edit_from_year
      to_year <- input$edit_to_year
      search_field <- input$edit_search_field %||% "default"
      is_oa <- input$edit_is_oa %||% FALSE

      preview <- build_query_preview(query, from_year, to_year, search_field, is_oa)

      tagList(
        if (!is.null(preview$search)) {
          div(tags$strong("search="), preview$search)
        },
        div(tags$strong("filter="), preview$filter)
      )
    })

    # Trigger for programmatic refresh
    search_refresh_trigger <- reactiveVal(0)

    # Save edited search
    observeEvent(input$save_search, {
      nb_id <- notebook_id()
      req(nb_id)

      query <- trimws(input$edit_query %||% "")
      if (nchar(query) == 0) {
        showNotification("Search query cannot be empty", type = "error")
        return()
      }

      # Get existing filters to preserve has_abstract setting
      nb <- get_notebook(con(), nb_id)
      existing_filters <- if (!is.na(nb$search_filters) && nchar(nb$search_filters) > 0) {
        tryCatch(jsonlite::fromJSON(nb$search_filters), error = function(e) list())
      } else {
        list()
      }

      filters <- list(
        from_year = input$edit_from_year,
        to_year = input$edit_to_year,
        search_field = input$edit_search_field %||% "default",
        is_oa = input$edit_is_oa %||% FALSE,
        has_abstract = if (!is.null(existing_filters$has_abstract)) existing_filters$has_abstract else TRUE
      )

      # Update notebook
      update_notebook(con(), nb_id, search_query = query, search_filters = filters)

      removeModal()
      showNotification("Search updated", type = "message")

      # Trigger main content refresh (updates the header query display)
      if (!is.null(notebook_refresh)) {
        notebook_refresh(notebook_refresh() + 1)
      }

      # Trigger search refresh
      search_refresh_trigger(search_refresh_trigger() + 1)
    })

    # Refresh search (triggered by button or save)
    observeEvent(list(input$refresh_search, search_refresh_trigger()), ignoreInit = TRUE, {
      nb_id <- notebook_id()
      req(nb_id)

      nb <- get_notebook(con(), nb_id)
      req(nb$type == "search")
      req(!is.null(nb$search_query) && nchar(nb$search_query) > 0)

      cfg <- config()

      withProgress(message = "Searching OpenAlex...", value = 0, {
        email <- get_setting(cfg, "openalex", "email") %||% ""
        api_key <- get_setting(cfg, "openalex", "api_key")

        filters <- if (!is.na(nb$search_filters) && nchar(nb$search_filters) > 0) {
          tryCatch(jsonlite::fromJSON(nb$search_filters), error = function(e) list())
        } else {
          list()
        }

        incProgress(0.2, detail = "Querying API")

        # Get configured abstracts per search
        abstracts_count <- get_setting(cfg, "app", "abstracts_per_search") %||% 25

        papers <- tryCatch({
          search_papers(
            nb$search_query,
            email,
            api_key,
            from_year = filters$from_year,
            to_year = filters$to_year,
            per_page = abstracts_count,
            search_field = filters$search_field %||% "default",
            is_oa = filters$is_oa %||% FALSE
          )
        }, error = function(e) {
          showNotification(paste("Search error:", e$message),
                           type = "error", duration = 10)
          return(list())
        })

        if (length(papers) == 0) {
          showNotification("No papers found", type = "warning")
          return()
        }

        incProgress(0.5, detail = paste("Found", length(papers), "papers"))

        # Save papers
        for (paper in papers) {
          # Check if already exists
          existing <- dbGetQuery(con(), "
            SELECT id FROM abstracts WHERE notebook_id = ? AND paper_id = ?
          ", list(nb_id, paper$paper_id))

          if (nrow(existing) > 0) next

          abstract_id <- create_abstract(
            con(), nb_id, paper$paper_id, paper$title,
            paper$authors, paper$abstract,
            paper$year, paper$venue, paper$pdf_url,
            keywords = paper$keywords
          )

          # Create chunk for abstract if available
          if (!is.na(paper$abstract) && nchar(paper$abstract) > 0) {
            create_chunk(con(), abstract_id, "abstract", 0, paper$abstract)
          }
        }

        # NOTE: Embedding is now deferred - user must click "Embed Papers" button
        # Old auto-embedding code removed (2026-02-06)

        incProgress(1.0, detail = "Done")
      })

      paper_refresh(paper_refresh() + 1)
      showNotification(paste("Loaded", length(papers), "papers"), type = "message")
    })

    # Import selected to document notebook
    observeEvent(input$import_selected, {
      selected <- selected_papers()
      req(length(selected) > 0)

      # Show modal to select target notebook
      showModal(modalDialog(
        title = "Import Papers",
        p(paste("Import", length(selected), "paper(s) to a document notebook.")),
        selectInput(ns("target_notebook"), "Target Notebook",
                    choices = c("Create new..." = "__new__")),
        conditionalPanel(
          condition = sprintf("input['%s'] == '__new__'", ns("target_notebook")),
          textInput(ns("new_nb_name"), "New Notebook Name")
        ),
        p(class = "text-muted small",
          "Note: Only papers with open access PDFs can be fully imported."),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("do_import"), "Import", class = "btn-primary")
        )
      ))

      # Update notebook choices
      notebooks <- list_notebooks(con())
      doc_notebooks <- notebooks[notebooks$type == "document", ]
      choices <- c("Create new..." = "__new__")
      if (nrow(doc_notebooks) > 0) {
        nb_choices <- setNames(doc_notebooks$id, doc_notebooks$name)
        choices <- c(choices, nb_choices)
      }
      updateSelectInput(session, "target_notebook", choices = choices)
    })

    # Do import
    observeEvent(input$do_import, {
      selected <- selected_papers()
      req(length(selected) > 0)

      target <- input$target_notebook

      if (target == "__new__") {
        req(input$new_nb_name)
        target <- create_notebook(con(), input$new_nb_name, "document")
        # Trigger sidebar refresh if callback provided
        if (!is.null(notebook_refresh)) {
          notebook_refresh(notebook_refresh() + 1)
        }
      }

      # Get selected abstracts
      abstracts <- dbGetQuery(con(), sprintf("
        SELECT * FROM abstracts WHERE id IN (%s)
      ", paste(sprintf("'%s'", selected), collapse = ",")))

      imported <- 0
      for (i in seq_len(nrow(abstracts))) {
        abs <- abstracts[i, ]

        # For now, just create a document record with the abstract as content
        # Full PDF download would require additional logic
        if (!is.na(abs$abstract) && nchar(abs$abstract) > 0) {
          doc_id <- create_document(
            con(), target,
            paste0(abs$title, ".txt"),
            "",
            abs$abstract,
            1
          )

          create_chunk(con(), doc_id, "document", 0, abs$abstract, page_number = 1)
          imported <- imported + 1
        }
      }

      removeModal()
      showNotification(paste("Imported", imported, "paper(s)"), type = "message")
    })

    # Messages
    output$messages <- renderUI({
      msgs <- messages()

      # Check for API key first
      if (!has_api_key()) {
        return(
          div(
            class = "text-center py-4",
            div(
              class = "alert alert-warning mb-0",
              icon("triangle-exclamation", class = "me-2"),
              strong("API key not configured"),
              p(class = "mb-0 mt-2 small",
                "Go to Settings to add your OpenRouter API key.")
            )
          )
        )
      }

      if (length(msgs) == 0) {
        return(
          div(
            class = "text-center text-muted py-4",
            icon("comments", class = "fa-2x mb-2"),
            p("Ask questions about these papers"),
            p(class = "small", "Query across all abstracts")
          )
        )
      }

      # Build message list
      msg_list <- lapply(msgs, function(msg) {
        if (msg$role == "user") {
          div(
            class = "d-flex justify-content-end mb-2",
            div(class = "bg-primary text-white p-2 rounded",
                style = "max-width: 85%;", msg$content)
          )
        } else {
          div(
            class = "d-flex justify-content-start mb-2",
            div(class = "bg-white border p-2 rounded",
                style = "max-width: 90%;",
                HTML(gsub("\n", "<br/>", msg$content)))
          )
        }
      })

      # Add loading spinner if processing
      if (is_processing()) {
        msg_list <- c(msg_list, list(
          div(
            class = "d-flex justify-content-start mb-2",
            div(
              class = "bg-white border p-2 rounded d-flex align-items-center gap-2",
              div(class = "spinner-border spinner-border-sm text-primary", role = "status"),
              span(class = "text-muted", "Thinking...")
            )
          )
        ))
      }

      tagList(msg_list)
    })

    # Send message
    observeEvent(input$send, {
      req(input$user_input)
      req(!is_processing())
      req(has_api_key())

      user_msg <- trimws(input$user_input)
      if (nchar(user_msg) == 0) return()

      updateTextInput(session, "user_input", value = "")
      is_processing(TRUE)

      msgs <- messages()
      msgs <- c(msgs, list(list(role = "user", content = user_msg)))
      messages(msgs)

      nb_id <- notebook_id()
      cfg <- config()

      response <- tryCatch({
        rag_query(con(), cfg, user_msg, nb_id)
      }, error = function(e) {
        sprintf("Error: %s", e$message)
      })

      msgs <- c(msgs, list(list(role = "assistant", content = response)))
      messages(msgs)
      is_processing(FALSE)
    })
  })
}
