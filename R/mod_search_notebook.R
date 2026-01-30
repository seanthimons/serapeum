#' Search Notebook Module UI
#' @param id Module ID
mod_search_notebook_ui <- function(id) {
  ns <- NS(id)

  layout_columns(
    col_widths = c(4, 8),
    # Left: Paper list
    card(
      card_header(
        class = "d-flex justify-content-between align-items-center",
        span("Papers"),
        actionButton(ns("refresh_search"), "Refresh",
                     class = "btn-sm btn-outline-secondary",
                     icon = icon("rotate"))
      ),
      card_body(
        div(
          id = ns("paper_list_container"),
          style = "max-height: 350px; overflow-y: auto;",
          uiOutput(ns("paper_list"))
        ),
        hr(),
        uiOutput(ns("selection_info")),
        actionButton(ns("import_selected"), "Import Selected to Notebook",
                     class = "btn-primary w-100",
                     icon = icon("download"))
      )
    ),
    # Right: Chat
    card(
      card_header("Chat with Abstracts"),
      card_body(
        class = "d-flex flex-column",
        style = "height: 500px;",
        div(
          id = ns("chat_messages"),
          class = "flex-grow-1 overflow-auto mb-3 p-2",
          style = "background-color: var(--bs-light); border-radius: 0.5rem;",
          uiOutput(ns("messages"))
        ),
        div(
          class = "d-flex gap-2",
          div(
            class = "flex-grow-1",
            textInput(ns("user_input"), NULL,
                      placeholder = "Ask about these papers...",
                      width = "100%")
          ),
          actionButton(ns("send"), "Send", class = "btn-primary")
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
    paper_refresh <- reactiveVal(0)
    is_processing <- reactiveVal(FALSE)

    # Reactive: check if API key is configured
    has_api_key <- reactive({
      cfg <- config()
      api_key <- get_setting(cfg, "openrouter", "api_key")
      !is.null(api_key) && nchar(api_key) > 0
    })

    # Get papers for this notebook
    papers_data <- reactive({
      paper_refresh()
      nb_id <- notebook_id()
      req(nb_id)
      list_abstracts(con(), nb_id)
    })

    # Paper list
    output$paper_list <- renderUI({
      papers <- papers_data()

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

        div(
          class = "border-bottom py-2",
          div(
            class = "d-flex align-items-start gap-2",
            checkboxInput(ns(checkbox_id), label = NULL, width = "25px"),
            div(
              class = "flex-grow-1",
              style = "min-width: 0;",
              div(class = "fw-semibold text-truncate", title = paper$title,
                  paper$title),
              div(class = "text-muted small",
                  paste(author_str, "-", paper$year %||% "N/A")),
              if (!is.na(paper$venue) && nchar(paper$venue) > 0) {
                div(class = "text-muted small fst-italic", paper$venue)
              }
            )
          )
        )
      })
    })

    # Track selected papers
    observe({
      papers <- papers_data()
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

    # Refresh search
    observeEvent(input$refresh_search, {
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

        papers <- tryCatch({
          search_papers(
            nb$search_query,
            email,
            api_key,
            from_year = filters$from_year,
            to_year = filters$to_year,
            per_page = 25
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
            paper$year, paper$venue, paper$pdf_url
          )

          # Create chunk for abstract if available
          if (!is.na(paper$abstract) && nchar(paper$abstract) > 0) {
            create_chunk(con(), abstract_id, "abstract", 0, paper$abstract)
          }
        }

        incProgress(0.8, detail = "Generating embeddings")

        # Embed new abstracts
        api_key_or <- get_setting(cfg, "openrouter", "api_key")
        embed_model <- get_setting(cfg, "defaults", "embedding_model") %||% "openai/text-embedding-3-small"

        if (!is.null(api_key_or) && nchar(api_key_or) > 0) {
          # Get chunks without embeddings
          chunks <- dbGetQuery(con(), "
            SELECT c.* FROM chunks c
            JOIN abstracts a ON c.source_id = a.id
            WHERE a.notebook_id = ? AND c.embedding IS NULL
          ", list(nb_id))

          if (nrow(chunks) > 0) {
            batch_size <- 10
            for (i in seq(1, nrow(chunks), by = batch_size)) {
              batch_end <- min(i + batch_size - 1, nrow(chunks))
              batch <- chunks[i:batch_end, ]

              embeddings <- tryCatch({
                get_embeddings(api_key_or, embed_model, batch$content)
              }, error = function(e) NULL)

              if (!is.null(embeddings)) {
                for (j in seq_along(embeddings)) {
                  update_chunk_embedding(con(), batch$id[j], embeddings[[j]])
                }
              }
            }
          }
        }

        incProgress(1, detail = "Done!")
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
            class = "text-center py-5",
            div(
              class = "alert alert-warning",
              icon("triangle-exclamation", class = "me-2"),
              strong("OpenRouter API key not configured"),
              p(class = "mb-0 mt-2 small",
                "Go to Settings to add your API key. ",
                "Get one at ", tags$a(href = "https://openrouter.ai/keys",
                                      target = "_blank", "openrouter.ai/keys"))
            )
          )
        )
      }

      if (length(msgs) == 0) {
        return(
          div(
            class = "text-center text-muted py-5",
            icon("comments", class = "fa-2x mb-2"),
            p("Ask questions about these papers"),
            p(class = "small", "Query across all abstracts in this collection")
          )
        )
      }

      tagList(
        lapply(msgs, function(msg) {
          if (msg$role == "user") {
            div(
              class = "d-flex justify-content-end mb-2",
              div(class = "bg-primary text-white p-2 rounded",
                  style = "max-width: 80%;", msg$content)
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
      )
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
