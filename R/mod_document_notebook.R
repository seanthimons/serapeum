#' Document Notebook Module UI
#' @param id Module ID
mod_document_notebook_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # JavaScript handler for re-index progress updates
    tags$script(HTML("
      Shiny.addCustomMessageHandler('updateReindexProgress', function(data) {
        var bar = document.getElementById(data.bar_id);
        var msg = document.getElementById(data.msg_id);
        if (bar) {
          bar.style.width = data.pct + '%';
          bar.setAttribute('aria-valuenow', data.pct);
        }
        if (msg) msg.textContent = data.message;
      });
    ")),

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
              popover(
                trigger = actionButton(
                  ns("btn_overview"), "Overview",
                  class = "btn-sm btn-outline-primary",
                  icon = icon("layer-group")
                ),
                title = "Overview Options",
                id = ns("overview_popover"),
                placement = "bottom",
                radioButtons(
                  ns("overview_depth"), "Summary Depth",
                  choices = c("Concise (1-2 paragraphs)" = "concise",
                              "Detailed (3-4 paragraphs)" = "detailed"),
                  selected = "concise"
                ),
                radioButtons(
                  ns("overview_mode"), "Quality Mode",
                  choices = c("Quick (single call)" = "quick",
                              "Thorough (two calls)" = "thorough"),
                  selected = "quick"
                ),
                actionButton(ns("btn_overview_generate"), "Generate",
                             class = "btn-primary btn-sm w-100")
              ),
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
            uiOutput(ns("send_button_ui"))
          )
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

    # Reactive: store health (Phase 21)
    store_healthy <- reactiveVal(NULL)  # NULL = unchecked, TRUE = ok, FALSE = corrupted/missing

    # Reactive: rag_ready (Phase 22)
    rag_ready <- reactiveVal(TRUE)  # FALSE = needs migration, greyed-out controls

    # Async re-index state (Phase 22)
    current_interrupt_flag <- reactiveVal(NULL)
    current_progress_file <- reactiveVal(NULL)
    reindex_poller <- reactiveVal(NULL)

    # Async re-index task (Phase 22) — follows mod_citation_network.R ExtendedTask pattern
    reindex_task <- ExtendedTask$new(function(notebook_id, db_path, api_key, embed_model, interrupt_flag, progress_file, app_dir) {
      mirai::mirai({
        source(file.path(app_dir, "R", "interrupt.R"), local = TRUE)
        source(file.path(app_dir, "R", "_ragnar.R"), local = TRUE)
        source(file.path(app_dir, "R", "db.R"), local = TRUE)

        result <- rebuild_notebook_store(
          notebook_id = notebook_id,
          con = NULL,
          db_path = db_path,
          api_key = api_key,
          embed_model = embed_model,
          interrupt_flag = interrupt_flag,
          progress_file = progress_file,
          progress_callback = NULL
        )
        result
      }, notebook_id = notebook_id, db_path = db_path, api_key = api_key,
         embed_model = embed_model, interrupt_flag = interrupt_flag,
         progress_file = progress_file, app_dir = app_dir)
    })

    # Phase 22: RAG operations check both store_healthy and rag_ready
    rag_available <- reactive({
      isTRUE(store_healthy()) && isTRUE(rag_ready())
    })

    # Render send button — greyed out when RAG is unavailable
    output$send_button_ui <- renderUI({
      if (isTRUE(rag_available())) {
        actionButton(ns("send"), "Send", class = "btn-primary")
      } else {
        tags$button(
          class = "btn btn-primary disabled",
          disabled = "disabled",
          title = "Chat unavailable \u2014 re-index this notebook first",
          "Send"
        )
      }
    })

    # Proactive integrity check + migration detection when notebook is opened (Phase 21/22)
    observeEvent(notebook_id(), {
      nb_id <- notebook_id()
      req(nb_id)

      # Reset state
      store_healthy(NULL)
      rag_ready(TRUE)

      store_path <- get_notebook_ragnar_path(nb_id)

      # Check if notebook has content
      docs <- list_documents(con(), nb_id)
      has_content <- nrow(docs) > 0

      if (!file.exists(store_path)) {
        if (has_content) {
          # Phase 22: Documents exist but no store — show migration prompt
          rag_ready(FALSE)
          store_healthy(FALSE)
          showModal(modalDialog(
            title = "Search Index Setup Required",
            tags$p("This notebook has documents but no search index. Chat and synthesis will be unavailable until you re-index."),
            tags$p(class = "text-muted small", paste(nrow(docs), "document(s) to index.")),
            footer = tagList(
              actionButton(ns("reindex_notebook"), "Re-index Now", class = "btn-primary"),
              modalButton("Later")
            ),
            easyClose = FALSE
          ))
        } else {
          # Empty notebook — no store yet, lazy creation will handle it
          store_healthy(TRUE)
          rag_ready(TRUE)
        }
        return()
      }

      # Store file exists — check integrity
      result <- check_store_integrity(store_path)
      store_healthy(result$ok)
      rag_ready(result$ok)

      if (!result$ok) {
        # Persistent error: show modal with rebuild option (per user decision)
        showModal(modalDialog(
          title = "Search Index Needs Rebuild",
          tags$p("The search index for this notebook appears to be corrupted or damaged.
                  This can happen after crashes or disk errors."),
          tags$p("Your documents and notes are safe. Only the search index needs rebuilding."),
          tags$p(class = "text-muted small",
                 paste("Error:", result$error)),
          footer = tagList(
            actionButton(ns("rebuild_index"), "Rebuild Index", class = "btn-primary"),
            modalButton("Later")
          ),
          easyClose = FALSE
        ))
      }
    })

    # Rebuild index handler (Phase 21) — for corruption recovery, NOT migration
    observeEvent(input$rebuild_index, {
      removeModal()

      nb_id <- notebook_id()
      req(nb_id)

      cfg <- config()
      api_key <- get_setting(cfg, "openrouter", "api_key")
      embed_model <- get_setting(cfg, "defaults", "embedding_model") %||% "openai/text-embedding-3-small"

      # Rebuild with progress (per user decision: withProgress with document count)
      withProgress(message = "Rebuilding search index...", value = 0, {
        result <- rebuild_notebook_store(
          notebook_id = nb_id,
          con = con(),
          api_key = api_key,
          embed_model = embed_model,
          progress_callback = function(count, total) {
            incProgress(
              1 / total,
              detail = paste("Re-embedding", count, "/", total, "items")
            )
          }
        )
      })

      if (result$success) {
        store_healthy(TRUE)
        rag_ready(TRUE)
        showNotification(
          paste("Search index rebuilt successfully.", result$count, "items re-embedded."),
          type = "message"
        )
      } else {
        store_healthy(FALSE)
        rag_ready(FALSE)
        showNotification(
          paste("Rebuild failed:", result$error),
          type = "error",
          duration = NULL
        )
      }
    })

    # Re-index handler (Phase 22) — async migration for notebooks with content but no store
    observeEvent(input$reindex_notebook, {
      removeModal()
      nb_id <- notebook_id()
      req(nb_id)

      cfg <- config()
      api_key <- get_setting(cfg, "openrouter", "api_key")
      embed_model <- get_setting(cfg, "defaults", "embedding_model") %||% "openai/text-embedding-3-small"
      db_path <- get_setting(cfg, "app", "db_path") %||% "data/notebooks.duckdb"

      # Create interrupt and progress files
      flag_file <- create_interrupt_flag(session$token)
      progress_file <- create_progress_file(session$token)
      current_interrupt_flag(flag_file)
      current_progress_file(progress_file)

      # Show progress modal with Stop button
      showModal(modalDialog(
        title = "Re-indexing Notebook",
        div(
          div(id = ns("reindex_message"), "Initializing..."),
          div(class = "progress mt-2",
            div(class = "progress-bar progress-bar-striped progress-bar-animated",
                id = ns("reindex_bar"), role = "progressbar",
                style = "width: 0%", `aria-valuenow` = "0",
                `aria-valuemin` = "0", `aria-valuemax` = "100")
          )
        ),
        footer = actionButton(ns("cancel_reindex"), "Stop", class = "btn-warning"),
        easyClose = FALSE
      ))

      # Start progress poller
      poller <- observe({
        invalidateLater(1000)
        prog <- read_reindex_progress(current_progress_file())
        session$sendCustomMessage("updateReindexProgress", list(
          bar_id = ns("reindex_bar"),
          msg_id = ns("reindex_message"),
          pct = prog$pct,
          message = prog$message
        ))
      })
      reindex_poller(poller)

      # Launch async task
      reindex_task$invoke(nb_id, db_path, api_key, embed_model, flag_file, progress_file, getwd())
    })

    # Cancel re-index handler (Phase 22)
    observeEvent(input$cancel_reindex, {
      flag <- current_interrupt_flag()
      if (!is.null(flag)) signal_interrupt(flag)

      # Stop polling
      poller <- reindex_poller()
      if (!is.null(poller)) poller$destroy()
      reindex_poller(NULL)

      # Update modal to show stopping state
      showModal(modalDialog(
        title = "Stopping Re-index",
        tags$p("Cancelling... please wait for current item to finish."),
        footer = NULL,
        easyClose = FALSE
      ))
    })

    # Task result handler (Phase 22)
    observe({
      result <- reindex_task$result()

      # Clean up poller
      poller <- reindex_poller()
      if (!is.null(poller)) poller$destroy()
      reindex_poller(NULL)

      # Clean up flag/progress files
      clear_interrupt_flag(current_interrupt_flag())
      clear_progress_file(current_progress_file())
      current_interrupt_flag(NULL)
      current_progress_file(NULL)

      removeModal()

      if (isTRUE(result$partial)) {
        # Cancelled mid-way — delete partial store, set rag_ready FALSE
        tryCatch(delete_notebook_store(notebook_id()), error = function(e) NULL)
        rag_ready(FALSE)
        store_healthy(FALSE)
        showNotification("Re-indexing cancelled. Partial index removed.", type = "warning", duration = 5)
      } else if (isTRUE(result$success)) {
        rag_ready(TRUE)
        store_healthy(TRUE)
        # Mark chunks as ragnar-indexed
        tryCatch({
          mark_as_ragnar_indexed(con(),
            DBI::dbGetQuery(con(), "SELECT id FROM documents WHERE notebook_id = ?", list(notebook_id()))$id,
            source_type = "document")
        }, error = function(e) message("[ragnar] Sentinel update failed: ", e$message))
        showNotification(paste("Re-indexed", result$count, "items successfully."), type = "message", duration = 5)
      } else {
        rag_ready(FALSE)
        store_healthy(FALSE)
        showNotification(paste("Re-indexing failed:", result$error), type = "error", duration = NULL)
      }
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

        # Insert into per-notebook ragnar store (Phase 22: per-notebook store)
        # Uses same OpenRouter API key for embeddings
        if (nrow(result$chunks) > 0 && !is.null(api_key) && nchar(api_key) > 0) {
          incProgress(0.55, detail = "Building search index")
          tryCatch({
            # Phase 22: Use per-notebook ragnar store
            store <- tryCatch(
              ensure_ragnar_store(nb_id, session, api_key, embed_model),
              error = function(e) {
                message("[ragnar] Failed to open per-notebook store: ", e$message)
                NULL
              }
            )

            if (!is.null(store)) {
              # Insert chunks (ragnar handles embedding via OpenRouter)
              insert_chunks_to_ragnar(store, result$chunks, doc_id, "document")

              # Build/update the search index
              build_ragnar_index(store)

              rag_ready(TRUE)
              store_healthy(TRUE)
              message("Ragnar store updated for document: ", file$name)
            }
          }, error = function(e) {
            message("Ragnar indexing skipped: ", e$message)
          })
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
          is_synthesis <- !is.null(msg$preset_type) && msg$preset_type %in% c("conclusions", "overview")

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

      # Defense in depth: button should be disabled, but guard anyway
      if (!isTRUE(rag_available())) {
        showNotification("Chat unavailable \u2014 re-index this notebook first.", type = "warning")
        return()
      }

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
        rag_query(con(), cfg, user_msg, nb_id, session_id = session$token)
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

    # Reset Overview popover to defaults each time it opens
    observeEvent(input$btn_overview, {
      updateRadioButtons(session, "overview_depth", selected = "concise")
      updateRadioButtons(session, "overview_mode", selected = "quick")
    })

    # Overview preset handler
    observeEvent(input$btn_overview_generate, {
      req(!is_processing())
      req(has_api_key())
      is_processing(TRUE)

      depth <- input$overview_depth %||% "concise"
      mode <- input$overview_mode %||% "quick"

      depth_label <- if (identical(depth, "detailed")) "Detailed" else "Concise"
      mode_label <- if (identical(mode, "thorough")) "Thorough" else "Quick"

      toggle_popover(id = ns("overview_popover"))

      msgs <- messages()
      msgs <- c(msgs, list(list(
        role = "user",
        content = paste0("Generate: Overview (", depth_label, ", ", mode_label, ")"),
        timestamp = Sys.time(),
        preset_type = "overview"
      )))
      messages(msgs)

      nb_id <- notebook_id()
      cfg <- config()

      response <- tryCatch({
        generate_overview_preset(con(), cfg, nb_id, notebook_type = "document",
                                 depth = depth, mode = mode, session_id = session$token)
      }, error = function(e) {
        sprintf("Error: %s", e$message)
      })

      msgs <- c(msgs, list(list(
        role = "assistant",
        content = response,
        timestamp = Sys.time(),
        preset_type = "overview"
      )))
      messages(msgs)
      is_processing(FALSE)
    })

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
