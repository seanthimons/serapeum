# Note: ragnar_available() is defined in R/_ragnar.R (sourced first alphabetically)

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
          class = "d-flex gap-2",
          div(
            class = "btn-group",
            actionButton(ns("btn_summarize"), "Summarize",
                         class = "btn-sm btn-outline-primary",
                         icon = icon("file-lines")),
            actionButton(ns("btn_keypoints"), "Key Points",
                         class = "btn-sm btn-outline-primary",
                         icon = icon("list-check")),
            actionButton(ns("btn_studyguide"), "Study Guide",
                         class = "btn-sm btn-outline-primary",
                         icon = icon("lightbulb")),
            actionButton(ns("btn_outline"), "Outline",
                         class = "btn-sm btn-outline-primary",
                         icon = icon("list-ol")),
            actionButton(ns("btn_conclusions"), "Conclusions",
                         class = "btn-sm btn-outline-primary",
                         icon = icon("microscope")),
            actionButton(ns("btn_slides"), "Slides",
                         class = "btn-sm btn-outline-primary",
                         icon = icon("file-powerpoint"))
          ),
          div(
            class = "btn-group btn-group-sm",
            tags$button(
              class = "btn btn-outline-secondary dropdown-toggle",
              `data-bs-toggle` = "dropdown",
              icon("download"), " Export"
            ),
            tags$ul(
              class = "dropdown-menu",
              tags$li(downloadLink(ns("download_chat_md"), class = "dropdown-item", icon("file-lines"), " Markdown (.md)")),
              tags$li(downloadLink(ns("download_chat_html"), class = "dropdown-item", icon("file-code"), " HTML (.html)"))
            )
          )
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

      # Register resource path for PDF downloads
      pdf_dir <- file.path(".temp", "pdfs", nb_id)
      if (dir.exists(pdf_dir)) {
        resource_name <- paste0("pdfs_", gsub("-", "", nb_id))
        addResourcePath(resource_name, normalizePath(pdf_dir))
      }

      lapply(seq_len(nrow(docs)), function(i) {
        doc <- docs[i, ]

        # Build download URL
        resource_name <- paste0("pdfs_", gsub("-", "", nb_id))
        download_url <- file.path(resource_name, doc$filename)

        div(
          class = "d-flex justify-content-between align-items-center py-2 px-2 border-bottom",
          div(
            class = "d-flex align-items-center flex-grow-1 overflow-hidden",
            icon("file-pdf", class = "text-danger me-2"),
            span(doc$filename, class = "text-truncate", style = "max-width: 120px;",
                 title = doc$filename)
          ),
          div(
            class = "d-flex align-items-center gap-2",
            span(paste(doc$page_count, "pg"), class = "text-muted small"),
            tags$a(
              href = download_url,
              download = doc$filename,
              class = "btn btn-sm btn-outline-secondary py-0 px-1",
              title = "Download PDF",
              icon("download")
            )
          )
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

      # Create storage directory (.temp/pdfs for easy access and future image extraction)
      storage_dir <- file.path(".temp", "pdfs", nb_id)
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
            # Extract section_hint if present, default to "general"
            section_hint_val <- if ("section_hint" %in% names(chunk)) chunk$section_hint else "general"
            create_chunk(con(), doc_id, "document",
                         chunk$chunk_index, chunk$content,
                         page_number = chunk$page_number,
                         section_hint = section_hint_val)
          }
        }

        incProgress(0.5, detail = "Generating embeddings")

        api_key <- get_setting(cfg, "openrouter", "api_key")
        embed_model <- get_setting(cfg, "defaults", "embedding_model") %||% "openai/text-embedding-3-small"

        # Track if ragnar indexing succeeds (to avoid double embedding)
        ragnar_indexed <- FALSE

        # Insert into ragnar store if available (for hybrid VSS+BM25 search)
        # Uses same OpenRouter API key for embeddings
        if (ragnar_available() && nrow(result$chunks) > 0 && !is.null(api_key) && nchar(api_key) > 0) {
          incProgress(0.55, detail = "Building search index")
          tryCatch({
            ragnar_store_path <- file.path(dirname(get_setting(cfg, "app", "db_path") %||% "data/notebooks.duckdb"),
                                           "serapeum.ragnar.duckdb")
            store <- get_ragnar_store(ragnar_store_path,
                                       openrouter_api_key = api_key,
                                       embed_model = embed_model)

            # Insert chunks (ragnar handles embedding via OpenRouter)
            insert_chunks_to_ragnar(store, result$chunks, doc_id, "document")

            # Build/update the search index
            build_ragnar_index(store)

            ragnar_indexed <- TRUE
            message("Ragnar store updated for document: ", file$name)
          }, error = function(e) {
            message("Ragnar indexing skipped: ", e$message)
          })
        }

        # Only generate legacy embeddings if ragnar indexing failed
        # This avoids double API calls for the same content
        if (!ragnar_indexed && !is.null(api_key) && nchar(api_key) > 0 && nrow(result$chunks) > 0) {
          chunks_db <- list_chunks(con(), doc_id)

          # Batch embed
          batch_size <- 10
          for (i in seq(1, nrow(chunks_db), by = batch_size)) {
            batch_end <- min(i + batch_size - 1, nrow(chunks_db))
            batch <- chunks_db[i:batch_end, ]

            embeddings_result <- tryCatch({
              get_embeddings(api_key, embed_model, batch$content)
            }, error = function(e) {
              showNotification(paste("Embedding error:", e$message),
                               type = "warning", duration = 5)
              return(NULL)
            })

            if (!is.null(embeddings_result)) {
              # Log cost
              if (!is.null(embeddings_result$usage)) {
                cost <- estimate_cost(embed_model, embeddings_result$usage$prompt_tokens %||% 0, 0)
                log_cost(con(), "embedding", embed_model,
                         embeddings_result$usage$prompt_tokens %||% 0, 0,
                         embeddings_result$usage$total_tokens %||% 0,
                         cost, session$token)
              }

              # Extract embeddings and update chunks
              for (j in seq_along(embeddings_result$embeddings)) {
                update_chunk_embedding(con(), batch$id[j], embeddings_result$embeddings[[j]])
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
          # Check if this is a synthesis response
          is_synthesis <- !is.null(msg$preset_type) && identical(msg$preset_type, "conclusions")

          content_html <- div(
            class = "bg-white border p-2 rounded chat-markdown",
            style = "max-width: 90%;",
            if (is_synthesis) {
              div(
                class = "alert alert-warning py-2 px-3 mb-2 small",
                role = "alert",
                tags$strong(icon("triangle-exclamation"), " AI-Generated Content"),
                " - Verify all claims against original sources before use."
              )
            },
            HTML(commonmark::markdown_html(msg$content, extensions = TRUE))
          )

          div(class = "d-flex justify-content-start mb-2", content_html)
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

    # Download handlers for chat export
    output$download_chat_md <- downloadHandler(
      filename = function() { paste0("chat-", Sys.Date(), ".md") },
      content = function(file) {
        msgs <- messages()
        md_content <- format_chat_as_markdown(msgs)
        con_file <- file(file, "wb")
        writeBin(charToRaw(md_content), con_file)
        close(con_file)
      }
    )

    output$download_chat_html <- downloadHandler(
      filename = function() { paste0("chat-", Sys.Date(), ".html") },
      content = function(file) {
        msgs <- messages()
        html_content <- format_chat_as_html(msgs)
        con_file <- file(file, "wb")
        writeBin(charToRaw("\xEF\xBB\xBF"), con_file)  # UTF-8 BOM
        writeBin(charToRaw(html_content), con_file)
        close(con_file)
      }
    )

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
      msgs <- c(msgs, list(list(role = "user", content = user_msg, timestamp = Sys.time())))
      messages(msgs)

      # Generate response
      nb_id <- notebook_id()
      cfg <- config()

      response <- tryCatch({
        rag_query(con(), cfg, user_msg, nb_id, use_ragnar = TRUE, session_id = session$token)
      }, error = function(e) {
        sprintf("Error: %s", e$message)
      })

      msgs <- c(msgs, list(list(role = "assistant", content = response, timestamp = Sys.time())))
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
      msgs <- c(msgs, list(list(role = "user", content = paste("Generate:", label), timestamp = Sys.time())))
      messages(msgs)

      nb_id <- notebook_id()
      cfg <- config()

      response <- tryCatch({
        generate_preset(con(), cfg, nb_id, preset_type, session_id = session$token)
      }, error = function(e) {
        sprintf("Error: %s", e$message)
      })

      msgs <- c(msgs, list(list(role = "assistant", content = response, timestamp = Sys.time())))
      messages(msgs)
      is_processing(FALSE)
    }

    observeEvent(input$btn_summarize, handle_preset("summarize", "Summary"))
    observeEvent(input$btn_keypoints, handle_preset("keypoints", "Key Points"))
    observeEvent(input$btn_studyguide, handle_preset("studyguide", "Study Guide"))
    observeEvent(input$btn_outline, handle_preset("outline", "Outline"))

    # Conclusions preset handler
    observeEvent(input$btn_conclusions, {
      req(!is_processing())
      req(has_api_key())
      is_processing(TRUE)

      msgs <- messages()
      msgs <- c(msgs, list(list(role = "user", content = "Generate: Conclusion Synthesis", timestamp = Sys.time(), preset_type = "conclusions")))
      messages(msgs)

      nb_id <- notebook_id()
      cfg <- config()

      response <- tryCatch({
        generate_conclusions_preset(con(), cfg, nb_id, notebook_type = "document", session_id = session$token)
      }, error = function(e) {
        sprintf("Error: %s", e$message)
      })

      msgs <- c(msgs, list(list(role = "assistant", content = response, timestamp = Sys.time(), preset_type = "conclusions")))
      messages(msgs)
      is_processing(FALSE)
    })

    # Slides module
    mod_slides_server("slides", con, notebook_id, config, slides_trigger)

    # Slides button
    observeEvent(input$btn_slides, {
      slides_trigger(slides_trigger() + 1)
    })
  })
}
