#' Document Notebook Module UI
#' @param id Module ID
mod_document_notebook_ui <- function(id) {
  ns <- NS(id)

  layout_columns(
    col_widths = c(4, 8),
    # Left: Document list
    card(
      card_header("Documents"),
      card_body(
        fileInput(ns("upload_pdf"), "Upload PDF",
                  accept = ".pdf",
                  buttonLabel = "Browse...",
                  placeholder = "No file selected"),
        hr(),
        div(
          id = ns("doc_list_container"),
          style = "max-height: 400px; overflow-y: auto;",
          uiOutput(ns("document_list"))
        )
      )
    ),
    # Right: Chat
    card(
      card_header(
        class = "d-flex justify-content-between align-items-center flex-wrap gap-2",
        span("Chat"),
        div(
          class = "btn-group",
          actionButton(ns("btn_summarize"), "Summarize",
                       class = "btn-sm btn-outline-primary"),
          actionButton(ns("btn_keypoints"), "Key Points",
                       class = "btn-sm btn-outline-primary"),
          actionButton(ns("btn_studyguide"), "Study Guide",
                       class = "btn-sm btn-outline-primary"),
          actionButton(ns("btn_outline"), "Outline",
                       class = "btn-sm btn-outline-primary"),
          actionButton(ns("btn_slides"), "Slides",
                       class = "btn-sm btn-outline-secondary",
                       icon = icon("presentation-screen"))
        )
      ),
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
                      placeholder = "Ask a question about your documents...",
                      width = "100%")
          ),
          actionButton(ns("send"), "Send", class = "btn-primary")
        )
      )
    )
  )
}

#' Document Notebook Module Server
#' @param id Module ID
#' @param con Database connection (reactive)
#' @param notebook_id Reactive notebook ID
#' @param config App config (reactive)
mod_document_notebook_server <- function(id, con, notebook_id, config) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive: messages
    messages <- reactiveVal(list())

    # Reactive: refresh trigger
    doc_refresh <- reactiveVal(0)

    # Reactive: processing state
    is_processing <- reactiveVal(FALSE)

    # Reactive: slides trigger
    slides_trigger <- reactiveVal(0)

    # Reactive: check if API key is configured
    has_api_key <- reactive({
      cfg <- config()
      api_key <- get_setting(cfg, "openrouter", "api_key")
      !is.null(api_key) && nchar(api_key) > 0
    })

    # Document list
    output$document_list <- renderUI({
      doc_refresh()
      nb_id <- notebook_id()
      req(nb_id)

      docs <- list_documents(con(), nb_id)

      if (nrow(docs) == 0) {
        return(
          div(
            class = "text-center text-muted py-4",
            icon("file-pdf", class = "fa-3x mb-2"),
            p("No documents yet"),
            p(class = "small", "Upload a PDF to get started")
          )
        )
      }

      lapply(seq_len(nrow(docs)), function(i) {
        doc <- docs[i, ]
        div(
          class = "d-flex justify-content-between align-items-center py-2 px-2 border-bottom",
          div(
            icon("file-pdf", class = "text-danger me-2"),
            span(doc$filename, class = "text-truncate", style = "max-width: 150px;")
          ),
          span(paste(doc$page_count, "pg"), class = "text-muted small")
        )
      })
    })

    # Handle PDF upload
    observeEvent(input$upload_pdf, {
      req(input$upload_pdf)
      nb_id <- notebook_id()
      req(nb_id)

      file <- input$upload_pdf
      cfg <- config()

      # Create storage directory
      storage_dir <- file.path("storage", nb_id)
      dir.create(storage_dir, showWarnings = FALSE, recursive = TRUE)

      # Copy file to storage
      dest_path <- file.path(storage_dir, file$name)
      file.copy(file$datapath, dest_path, overwrite = TRUE)

      # Process PDF
      withProgress(message = "Processing PDF...", value = 0, {
        incProgress(0.1, detail = "Extracting text")

        result <- tryCatch({
          process_pdf(dest_path,
                      chunk_size = get_setting(cfg, "app", "chunk_size") %||% 500,
                      overlap = get_setting(cfg, "app", "chunk_overlap") %||% 50)
        }, error = function(e) {
          showNotification(paste("Error processing PDF:", e$message),
                           type = "error", duration = 10)
          return(NULL)
        })

        if (is.null(result)) return()

        incProgress(0.3, detail = "Saving to database")

        doc_id <- create_document(
          con(), nb_id, file$name, dest_path,
          result$full_text, result$page_count
        )

        incProgress(0.4, detail = "Creating chunks")

        if (nrow(result$chunks) > 0) {
          for (i in seq_len(nrow(result$chunks))) {
            chunk <- result$chunks[i, ]
            create_chunk(con(), doc_id, "document",
                         chunk$chunk_index, chunk$content,
                         page_number = chunk$page_number)
          }
        }

        incProgress(0.5, detail = "Generating embeddings")

        api_key <- get_setting(cfg, "openrouter", "api_key")
        embed_model <- get_setting(cfg, "defaults", "embedding_model") %||% "openai/text-embedding-3-small"

        if (!is.null(api_key) && nchar(api_key) > 0 && nrow(result$chunks) > 0) {
          chunks_db <- list_chunks(con(), doc_id)

          # Batch embed
          batch_size <- 10
          for (i in seq(1, nrow(chunks_db), by = batch_size)) {
            batch_end <- min(i + batch_size - 1, nrow(chunks_db))
            batch <- chunks_db[i:batch_end, ]

            embeddings <- tryCatch({
              get_embeddings(api_key, embed_model, batch$content)
            }, error = function(e) {
              showNotification(paste("Embedding error:", e$message),
                               type = "warning", duration = 5)
              return(NULL)
            })

            if (!is.null(embeddings)) {
              for (j in seq_along(embeddings)) {
                update_chunk_embedding(con(), batch$id[j], embeddings[[j]])
              }
            }

            incProgress(0.5 * (batch_end / nrow(chunks_db)), detail = "Generating embeddings")
          }
        }

        incProgress(1, detail = "Done!")
      })

      doc_refresh(doc_refresh() + 1)
      showNotification("PDF uploaded and processed successfully!", type = "message")
    })

    # Render messages
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
            p("Ask a question about your documents"),
            p(class = "small", "Or use the preset buttons above")
          )
        )
      }

      # Build message list
      msg_list <- lapply(msgs, function(msg) {
        if (msg$role == "user") {
          div(
            class = "d-flex justify-content-end mb-2",
            div(
              class = "bg-primary text-white p-2 rounded",
              style = "max-width: 80%;",
              msg$content
            )
          )
        } else {
          div(
            class = "d-flex justify-content-start mb-2",
            div(
              class = "bg-white border p-2 rounded",
              style = "max-width: 90%;",
              HTML(gsub("\n", "<br/>", msg$content))
            )
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

      # Add user message
      msgs <- messages()
      msgs <- c(msgs, list(list(role = "user", content = user_msg)))
      messages(msgs)

      # Generate response
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

    # Also send on Enter key
    observeEvent(input$user_input, {
      # This won't work directly - need JS for Enter key
    }, ignoreInit = TRUE)

    # Preset buttons
    handle_preset <- function(preset_type, label) {
      req(!is_processing())
      req(has_api_key())
      is_processing(TRUE)

      msgs <- messages()
      msgs <- c(msgs, list(list(role = "user", content = paste("Generate:", label))))
      messages(msgs)

      nb_id <- notebook_id()
      cfg <- config()

      response <- tryCatch({
        generate_preset(con(), cfg, nb_id, preset_type)
      }, error = function(e) {
        sprintf("Error: %s", e$message)
      })

      msgs <- c(msgs, list(list(role = "assistant", content = response)))
      messages(msgs)
      is_processing(FALSE)
    }

    observeEvent(input$btn_summarize, handle_preset("summarize", "Summary"))
    observeEvent(input$btn_keypoints, handle_preset("keypoints", "Key Points"))
    observeEvent(input$btn_studyguide, handle_preset("studyguide", "Study Guide"))
    observeEvent(input$btn_outline, handle_preset("outline", "Outline"))

    # Slides module
    mod_slides_server("slides", con, notebook_id, config, slides_trigger)

    # Slides button
    observeEvent(input$btn_slides, {
      slides_trigger(slides_trigger() + 1)
    })
  })
}
