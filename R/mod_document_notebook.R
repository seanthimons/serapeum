#' Document Notebook Module UI
#' @param id Module ID
mod_document_notebook_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # JavaScript: show spinner on send button while chat is processing
    tags$script(HTML(sprintf("
      $(document).on('click', '#%s', function() {
        var btn = $(this);
        btn.data('original-html', btn.html());
        btn.html('<span class=\"spinner-border spinner-border-sm\" role=\"status\"></span> Thinking\\u2026');
        btn.prop('disabled', true);
      });
      if (!window._docChatReadyRegistered) {
        window._docChatReadyRegistered = true;
        Shiny.addCustomMessageHandler('docChatReady', function(ns) {
          var btn = $('#' + ns + 'send');
          var orig = btn.data('original-html');
          if (orig) btn.html(orig);
          btn.prop('disabled', false);
        });
      }
    ", ns("send")))),

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

    # JavaScript handler for figure extraction progress updates
    tags$script(HTML("
      Shiny.addCustomMessageHandler('updateExtractProgress', function(data) {
        var bar = document.getElementById('extract-bar');
        var msg = document.getElementById('extract-status');
        if (bar) {
          bar.style.width = data.pct + '%';
          bar.setAttribute('aria-valuenow', data.pct);
        }
        if (msg) msg.textContent = data.message;
      });
    ")),

    div(class = "text-muted mb-3 d-flex align-items-center gap-2",
      icon_circle_info(class = "text-primary"),
      "Upload PDFs and use AI to chat with your documents, generate summaries, and extract insights."
    ),

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
          uiOutput(ns("index_action_ui")),
          hr(),
          div(
            id = ns("doc_list_container"),
            style = "max-height: 400px; overflow-y: auto;",
            uiOutput(ns("document_list"))
          ),
          # Figure gallery (shown when a document with figures is selected)
          uiOutput(ns("figure_gallery"))
        )
      ),
      # Right: Chat
      card(
        card_header(
          class = "d-flex justify-content-between align-items-center flex-wrap gap-2",
          span("Chat"),
          div(
            class = "d-flex flex-wrap gap-2",
            # Row 1: Quick presets
            div(
              class = "d-flex gap-1",
              div(
                class = "btn-group btn-group-sm",
                popover(
                  trigger = actionButton(
                    ns("btn_overview"), "Overview",
                    class = "btn-sm btn-outline-primary",
                    icon = icon_layer_group()
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
                             icon = icon_lightbulb()),
                actionButton(ns("btn_outline"), "Outline",
                             class = "btn-sm btn-outline-primary",
                             icon = icon_list_ol())
              )
            ),
            # Row 2: Deep presets + Export
            div(
              class = "d-flex gap-1",
              div(
                class = "btn-group btn-group-sm",
                actionButton(ns("btn_conclusions"), "Conclusions",
                             class = "btn-sm btn-outline-primary",
                             icon = icon_microscope()),
                actionButton(ns("btn_lit_review"), "Lit Review",
                             class = "btn-sm btn-outline-primary",
                             icon = icon_table()),
                actionButton(ns("btn_methods"), "Methods",
                             class = "btn-sm btn-outline-primary",
                             icon = icon_flask()),
                actionButton(ns("btn_gaps"), "Research Gaps",
                             class = "btn-sm btn-outline-primary",
                             icon = icon_search()),
                actionButton(ns("btn_slides"), "Slides",
                             class = "btn-sm btn-outline-primary",
                             icon = icon_file_powerpoint())
              ),
              div(
                class = "btn-group btn-group-sm",
                tags$button(
                  class = "btn btn-outline-secondary dropdown-toggle",
                  `data-bs-toggle` = "dropdown",
                  icon_download(), " Export"
                ),
                tags$ul(
                  class = "dropdown-menu",
                  tags$li(downloadLink(ns("download_chat_md"), class = "dropdown-item", icon_paper(), " Markdown (.md)")),
                  tags$li(downloadLink(ns("download_chat_html"), class = "dropdown-item", icon_file_code(), " HTML (.html)"))
                )
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
            style = "background-color: var(--bs-tertiary-bg); border-radius: 0.5rem;",
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
    # Track which document IDs already have delete observers to prevent duplicates
    delete_doc_observers <- reactiveValues()

    # Figure gallery state
    selected_fig_doc <- reactiveVal(NULL)  # Document ID whose figures are shown
    fig_refresh <- reactiveVal(0)          # Trigger gallery re-render
    gallery_view <- reactiveVal("list")    # "list" or "grid"
    extract_observers <- reactiveValues()  # Track extract button observers
    fig_action_observers <- reactiveValues()  # Track per-figure action observers

    # Reactive: processing state
    is_processing <- reactiveVal(FALSE)
    processing_doc_count <- reactiveVal(0L)

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
    # Data (documents/abstracts) is pre-fetched in main process to avoid cross-process DuckDB locks
    reindex_task <- ExtendedTask$new(function(notebook_id, documents, abstracts, provider, embed_model, interrupt_flag, progress_file, app_dir) {
      mirai::mirai({
        source(file.path(app_dir, "R", "interrupt.R"))
        source(file.path(app_dir, "R", "config.R"))
        source(file.path(app_dir, "R", "api_openalex.R"))
        source(file.path(app_dir, "R", "api_openrouter.R"))
        source(file.path(app_dir, "R", "api_provider.R"))
        source(file.path(app_dir, "R", "_ragnar.R"))

        result <- rebuild_notebook_store(
          notebook_id = notebook_id,
          provider = provider,
          embed_model = embed_model,
          documents = documents,
          abstracts = abstracts,
          interrupt_flag = interrupt_flag,
          progress_file = progress_file,
          progress_callback = NULL
        )
        result
      }, notebook_id = notebook_id, documents = documents, abstracts = abstracts,
         provider = provider, embed_model = embed_model, interrupt_flag = interrupt_flag,
         progress_file = progress_file, app_dir = app_dir)
    })

    # Phase 22: RAG operations check both store_healthy and rag_ready
    rag_available <- reactive({
      isTRUE(store_healthy()) && isTRUE(rag_ready())
    })

    index_status_message <- reactiveVal(NULL)

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

    output$index_action_ui <- renderUI({
      nb_id <- notebook_id()
      req(nb_id)

      docs <- list_documents(con(), nb_id)
      if (nrow(docs) == 0) {
        return(NULL)
      }

      store_exists <- file.exists(get_notebook_ragnar_path(nb_id))
      repair_button <- if (!isTRUE(rag_available())) {
        button_id <- if (store_exists) ns("rebuild_index") else ns("reindex_notebook")
        button_label <- if (store_exists) "Rebuild Search Index" else "Build Search Index"
        actionButton(button_id, button_label, class = "btn-warning w-100 btn-sm")
      } else {
        NULL
      }

      current_status <- if (isTRUE(rag_available())) {
        "Current status: search index available."
      } else if (store_exists) {
        "Current status: search index needs rebuild."
      } else {
        "Current status: search index has not been built yet."
      }

      tags$details(
        class = "mt-2",
        tags$summary(
          class = "text-muted small",
          style = "cursor: pointer;",
          "Index Tools"
        ),
        div(
          class = "mt-2 d-grid gap-2",
          tags$div(class = "text-muted small", current_status),
          repair_button,
          actionButton(ns("check_index_status"), "Check Search Index Status", class = "btn btn-outline-secondary btn-sm w-100"),
          {
            msg <- index_status_message()
            if (!is.null(msg) && nchar(msg) > 0) {
              tags$div(class = "text-muted small", msg)
            }
          }
        )
      )
    })

    observeEvent(input$check_index_status, {
      nb_id <- notebook_id()
      req(nb_id)

      sync_result <- sync_document_ragnar_statuses(con(), nb_id)
      integrity <- check_store_integrity(get_notebook_ragnar_path(nb_id))

      if (sync_result$documents == 0) {
        store_healthy(TRUE)
        rag_ready(TRUE)
        msg <- "No documents in this notebook yet."
        index_status_message(msg)
        showNotification(msg, type = "message", duration = 4)
        return()
      }

      store_healthy(integrity$ok)
      rag_ready(integrity$ok)
      doc_refresh(doc_refresh() + 1)

      if (!sync_result$store_exists) {
        msg <- "No search index store found. Use Build Search Index to create it."
        index_status_message(msg)
        showNotification(msg, type = "warning", duration = 6)
        return()
      }

      msg <- paste(
        "Checked", sync_result$documents, "document(s):",
        sync_result$marked, "confirmed in the search index,",
        sync_result$cleared, "status marker(s) cleared."
      )

      if (!integrity$ok) {
        msg <- paste(msg, summarize_store_integrity_error(integrity$error))
        showNotification(msg, type = "warning", duration = 8)
      } else {
        showNotification(msg, type = "message", duration = 5)
      }

      index_status_message(msg)
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
                 summarize_store_integrity_error(result$error)),
          footer = tagList(
            actionButton(ns("rebuild_index"), "Rebuild Index", class = "btn-primary"),
            modalButton("Later")
          ),
          easyClose = FALSE
        ))
      } else if (has_content) {
        # Store is healthy — sync brain icon markers and check for unembedded docs
        sync <- tryCatch(
          sync_document_ragnar_statuses(con(), nb_id),
          error = function(e) NULL
        )
        if (!is.null(sync) && sync$documents > sync$marked) {
          missing <- sync$documents - sync$marked
          # Surface rebuild button by marking index as incomplete
          rag_ready(FALSE)
          showNotification(
            paste0(missing, " of ", sync$documents,
                   " document(s) not in the search index. Use Rebuild Search Index to embed them."),
            type = "warning", duration = 8
          )
        }
        doc_refresh(doc_refresh() + 1)
      }
    })

    # Rebuild index handler (Phase 21) — for corruption recovery, NOT migration
    observeEvent(input$rebuild_index, {
      removeModal()

      nb_id <- notebook_id()
      req(nb_id)

      cfg <- config()
      provider <- provider_from_config(cfg, con())
      embed_model <- resolve_model_for_operation(cfg, "embedding")

      # Rebuild with progress (per user decision: withProgress with document count)
      withProgress(message = "Rebuilding search index...", value = 0, {
        result <- rebuild_notebook_store(
          notebook_id = nb_id,
          con = con(),
          provider = provider,
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
        # Mark all documents as ragnar-indexed so brain icons show
        tryCatch({
          mark_as_ragnar_indexed(con(),
            DBI::dbGetQuery(con(), "SELECT id FROM documents WHERE notebook_id = ?", list(nb_id))$id,
            source_type = "document")
        }, error = function(e) message("[ragnar] Sentinel update failed: ", e$message))
        doc_refresh(doc_refresh() + 1)
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
      provider <- provider_from_config(cfg, con())
      embed_model <- resolve_model_for_operation(cfg, "embedding")

      # Pre-fetch data in main process (avoids cross-process DuckDB lock)
      documents <- list_documents(con(), nb_id)
      abstracts <- list_abstracts(con(), nb_id)

      # Delete existing store in main process (mirai worker can't delete cross-process locked files)
      delete_notebook_store(nb_id)

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
      reindex_task$invoke(nb_id, documents, abstracts, provider, embed_model, flag_file, progress_file, getwd())
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
    # NOTE: isolate() all reactive reads except reindex_task$result() to prevent
    # reactive loops — doc_refresh(doc_refresh() + 1) inside observe() creates
    # a self-triggering cycle without isolate (UAT finding)
    observe({
      result <- reindex_task$result()

      # Clean up poller
      poller <- isolate(reindex_poller())
      if (!is.null(poller)) poller$destroy()
      reindex_poller(NULL)

      # Clean up flag/progress files
      clear_interrupt_flag(isolate(current_interrupt_flag()))
      clear_progress_file(isolate(current_progress_file()))
      current_interrupt_flag(NULL)
      current_progress_file(NULL)

      removeModal()

      if (isTRUE(result$partial)) {
        # Cancelled mid-way — delete partial store, set rag_ready FALSE
        tryCatch(delete_notebook_store(isolate(notebook_id())), error = function(e) NULL)
        rag_ready(FALSE)
        store_healthy(FALSE)
        showNotification("Re-indexing cancelled. Partial index removed.", type = "warning", duration = 5)
      } else if (isTRUE(result$success)) {
        rag_ready(TRUE)
        store_healthy(TRUE)
        # Mark chunks as ragnar-indexed
        tryCatch({
          mark_as_ragnar_indexed(isolate(con()),
            DBI::dbGetQuery(isolate(con()), "SELECT id FROM documents WHERE notebook_id = ?", list(isolate(notebook_id())))$id,
            source_type = "document")
        }, error = function(e) message("[ragnar] Sentinel update failed: ", e$message))
        doc_refresh(isolate(doc_refresh()) + 1)
        showNotification(paste("Re-indexed", result$count, "items successfully."), type = "message", duration = 5)
      } else {
        rag_ready(FALSE)
        store_healthy(FALSE)
        showNotification(paste("Re-indexing failed:", result$error), type = "error", duration = NULL)
      }
    })

    # Document list
    # Set of document IDs that have been embedded (for brain icon)
    embedded_doc_ids <- reactive({
      doc_refresh()
      nb_id <- notebook_id()
      req(nb_id)

      result <- dbGetQuery(con(), "
        SELECT DISTINCT c.source_id
        FROM chunks c
        WHERE c.source_type = 'document'
          AND c.embedding IS NOT NULL
          AND c.source_id IN (SELECT id FROM documents WHERE notebook_id = ?)
      ", list(nb_id))

      result$source_id
    })

    output$document_list <- renderUI({
      doc_refresh()
      nb_id <- notebook_id()
      req(nb_id)

      docs <- list_documents(con(), nb_id)

      if (nrow(docs) == 0) {
        return(
          div(
            class = "text-center text-muted py-4",
            icon_file_pdf(class = "fa-3x mb-2"),
            p("No documents yet"),
            p(class = "small", "Upload a PDF to get started")
          )
        )
      }

      # Write text files for abstract-imported documents (no PDF on disk)
      pdf_dir <- file.path(".temp", "pdfs", nb_id)
      sanitize_filename <- function(name) gsub('[/:*?"<>|\\\\]', "_", name)
      text_docs <- which(
        (is.na(docs$filepath) | nchar(docs$filepath) == 0) &
        !is.na(docs$full_text) & nchar(docs$full_text) > 0
      )
      if (length(text_docs) > 0) {
        dir.create(pdf_dir, recursive = TRUE, showWarnings = FALSE)
        for (j in text_docs) {
          safe_name <- sanitize_filename(docs$filename[j])
          txt_path <- file.path(pdf_dir, safe_name)
          if (!file.exists(txt_path)) {
            header <- docs$filename[j]
            if (!is.na(docs$title[j])) header <- docs$title[j]
            meta <- character(0)
            if (!is.na(docs$authors[j])) meta <- c(meta, paste("Authors:", docs$authors[j]))
            if (!is.na(docs$year[j])) meta <- c(meta, paste("Year:", docs$year[j]))
            if (!is.na(docs$doi[j])) meta <- c(meta, paste("DOI:", docs$doi[j]))
            content <- paste0(
              header, "\n",
              paste(rep("=", nchar(header)), collapse = ""), "\n",
              if (length(meta) > 0) paste0(paste(meta, collapse = "\n"), "\n\n") else "\n",
              docs$full_text[j]
            )
            writeLines(content, txt_path)
          }
        }
      }

      # Register resource path for PDF/text downloads
      if (dir.exists(pdf_dir)) {
        resource_name <- paste0("pdfs_", gsub("-", "", nb_id))
        addResourcePath(resource_name, normalizePath(pdf_dir))
      }

      embedded <- embedded_doc_ids()

      # Register resource path for figure images
      figures_dir <- file.path("data", "figures", nb_id)
      if (dir.exists(figures_dir)) {
        fig_resource <- paste0("figures_", gsub("-", "", nb_id))
        addResourcePath(fig_resource, normalizePath(figures_dir))
      }

      lapply(seq_len(nrow(docs)), function(i) {
        doc <- docs[i, ]
        is_embedded <- doc$id %in% embedded
        is_pdf <- grepl("\\.pdf$", doc$filename, ignore.case = TRUE)
        delete_id <- paste0("delete_doc_", doc$id)
        extract_id <- paste0("extract_figs_", doc$id)
        view_figs_id <- paste0("view_figs_", doc$id)

        # Check for existing figures
        fig_count <- tryCatch(
          nrow(db_get_figures_for_document(con(), doc$id)),
          error = function(e) 0L
        )

        # Build download URL (sanitize filename for non-PDF docs)
        resource_name <- paste0("pdfs_", gsub("-", "", nb_id))
        disk_filename <- if (is_pdf) doc$filename else sanitize_filename(doc$filename)
        download_url <- file.path(resource_name, disk_filename)

        # Register delete observer (once per document ID)
        if (is.null(delete_doc_observers[[doc$id]])) {
          delete_doc_observers[[doc$id]] <- observeEvent(input[[delete_id]], {
            delete_document(con(), doc$id)
            delete_document_chunks_from_ragnar(nb_id, doc$filename)
            disk_name <- if (grepl("\\.pdf$", doc$filename, ignore.case = TRUE)) {
              doc$filename
            } else {
              sanitize_filename(doc$filename)
            }
            pdf_path <- file.path(".temp", "pdfs", nb_id, disk_name)
            if (file.exists(pdf_path)) file.remove(pdf_path)
            # Clear figure gallery if showing this doc
            if (identical(selected_fig_doc(), doc$id)) selected_fig_doc(NULL)
            doc_refresh(doc_refresh() + 1)
            showNotification(paste("Removed", doc$filename), type = "message")
          }, ignoreInit = TRUE, once = TRUE)
        }

        # Register extract figures observer (once per document ID)
        if (is_pdf && is.null(extract_observers[[doc$id]])) {
          local({
            d_id <- doc$id
            d_filename <- doc$filename
            d_filepath <- doc$filepath

            extract_observers[[d_id]] <- observeEvent(input[[extract_id]], {
              # Check for existing figures -> confirmation
              existing <- tryCatch(
                nrow(db_get_figures_for_document(con(), d_id)),
                error = function(e) 0L
              )
              if (existing > 0) {
                showModal(modalDialog(
                  title = "Replace existing figures?",
                  tags$p(sprintf("This will replace %d existing figures for %s.",
                                 existing, d_filename)),
                  footer = tagList(
                    actionButton(ns(paste0("confirm_reextract_", d_id)),
                                 "Replace", class = "btn-warning"),
                    modalButton("Cancel")
                  ),
                  easyClose = TRUE
                ))
                # Register one-time confirm observer (guarded to prevent accumulation)
                confirm_key <- paste0("confirm_reextract_", d_id)
                if (is.null(extract_observers[[confirm_key]])) {
                  extract_observers[[confirm_key]] <- observeEvent(input[[confirm_key]], {
                    removeModal()
                    extract_observers[[confirm_key]] <- NULL
                    run_figure_extraction(d_id, nb_id, d_filepath, d_filename)
                  }, ignoreInit = TRUE, once = TRUE)
                }
                return()
              }
              run_figure_extraction(d_id, nb_id, d_filepath, d_filename)
            }, ignoreInit = TRUE)
          })
        }

        # Register view-figures observer
        if (fig_count > 0 && is.null(extract_observers[[paste0("view_", doc$id)]])) {
          local({
            d_id <- doc$id
            extract_observers[[paste0("view_", d_id)]] <- observeEvent(input[[view_figs_id]], {
              if (identical(selected_fig_doc(), d_id)) {
                selected_fig_doc(NULL)  # Toggle off
              } else {
                selected_fig_doc(d_id)  # Toggle on
                fig_refresh(fig_refresh() + 1)
              }
            }, ignoreInit = TRUE)
          })
        }

        div(
          class = "d-flex justify-content-between align-items-center py-2 px-2 border-bottom position-relative",
          div(
            class = "d-flex align-items-center flex-grow-1 overflow-hidden",
            icon_file_pdf(class = "text-danger me-2"),
            if (is_embedded) {
              span(
                class = "text-primary me-1",
                style = "cursor: help; opacity: 0.7;",
                title = "Embedded in search index",
                icon_brain()
              )
            },
            span(doc$filename, class = "text-truncate", style = "max-width: 120px;",
                 title = doc$filename)
          ),
          div(
            class = "d-flex align-items-center gap-2",
            span(paste(doc$page_count, "pg"), class = "text-muted small"),
            # Figures: single button — badge toggles gallery, icon extracts
            if (is_pdf && fig_count > 0) {
              actionLink(
                ns(view_figs_id),
                span(paste0(fig_count, " fig", if (fig_count != 1) "s"),
                     class = "badge bg-success"),
                title = "View/hide figures"
              )
            } else if (is_pdf) {
              actionLink(
                ns(extract_id),
                icon_image(),
                class = "text-muted",
                style = "cursor: pointer; opacity: 0.7;",
                title = "Extract figures"
              )
            },
            tags$a(
              href = download_url,
              download = doc$filename,
              class = "btn btn-sm btn-outline-secondary py-0 px-1",
              title = if (is_pdf) "Download PDF" else "Download text",
              icon_download()
            ),
            actionLink(
              ns(delete_id),
              icon_close(),
              class = "text-muted",
              style = "cursor: pointer; opacity: 0.5;",
              title = "Remove document"
            )
          )
        )
      })
    })

    # =========================================================================
    # Figure extraction + gallery
    # =========================================================================

    # Helper: run figure extraction with blocking progress modal
    run_figure_extraction <- function(doc_id, nb_id, pdf_path, filename) {
      # Verify PDF exists
      if (!file.exists(pdf_path)) {
        showNotification(
          paste0("PDF file not found: ", filename,
                 ". Re-upload the document to extract figures."),
          type = "error", duration = NULL
        )
        return()
      }

      showModal(modalDialog(
        title = "Extracting Figures",
        tags$div(
          tags$p(id = "extract-status", "Starting extraction..."),
          tags$div(class = "progress",
            tags$div(id = "extract-bar", class = "progress-bar progress-bar-striped progress-bar-animated",
                     role = "progressbar", style = "width: 0%",
                     `aria-valuenow` = "0", `aria-valuemin` = "0", `aria-valuemax` = "100")
          )
        ),
        footer = NULL, easyClose = FALSE
      ))

      cfg <- config()
      api_key <- cfg$openrouter$api_key

      result <- tryCatch(
        extract_and_describe_figures(
          con = con(), api_key = api_key,
          document_id = doc_id, notebook_id = nb_id,
          pdf_path = pdf_path, session_id = session$token,
          progress = function(value, detail) {
            session$sendCustomMessage("updateExtractProgress", list(
              pct = round(value * 100),
              message = detail
            ))
          }
        ),
        error = function(e) {
          message(sprintf("[figure-ui] Extraction error: %s", conditionMessage(e)))
          list(n_extracted = 0L, n_described = 0L, n_failed = 0L,
               error = conditionMessage(e))
        }
      )

      removeModal()

      if (!is.null(result$error)) {
        showNotification(
          paste0("Extraction failed: ", result$error),
          type = "error", duration = NULL
        )
        return()
      }

      if (result$n_extracted == 0) {
        showNotification(
          paste0("No figures found in ", filename,
                 ". This may be a text-only document."),
          type = "warning", duration = 6
        )
      } else {
        desc_msg <- if (result$n_described > 0) {
          sprintf(" (%d described)", result$n_described)
        } else if (is.null(api_key) || nchar(api_key) == 0) {
          " (no API key — descriptions skipped)"
        } else {
          ""
        }
        showNotification(
          sprintf("Extracted %d figures%s from %s",
                  result$n_extracted, desc_msg, filename),
          type = "message"
        )
        # Destroy and clear old figure action observers (figure IDs changed)
        for (old_id in names(fig_action_observers)) {
          obs_list <- fig_action_observers[[old_id]]
          if (is.list(obs_list)) {
            for (obs in obs_list) if (!is.null(obs)) obs$destroy()
          }
          fig_action_observers[[old_id]] <- NULL
        }
        selected_fig_doc(doc_id)
        fig_refresh(fig_refresh() + 1)
      }
      doc_refresh(doc_refresh() + 1)  # Refresh doc list to show figure count badge
    }

    # Gallery view toggle
    observeEvent(input$gallery_view_list, {
      gallery_view("list")
      fig_refresh(fig_refresh() + 1)
    })
    observeEvent(input$gallery_view_grid, {
      gallery_view("grid")
      fig_refresh(fig_refresh() + 1)
    })

    # Re-extract from gallery header
    observeEvent(input$gallery_reextract, {
      doc_id <- selected_fig_doc()
      req(doc_id)
      nb_id <- notebook_id()
      req(nb_id)

      doc <- get_document(con(), doc_id)
      req(doc)

      existing <- tryCatch(
        nrow(db_get_figures_for_document(con(), doc_id)),
        error = function(e) 0L
      )

      showModal(modalDialog(
        title = "Re-extract figures?",
        tags$p(sprintf("This will replace %d existing figures for %s.",
                       existing, doc$filename)),
        footer = tagList(
          actionButton(ns("confirm_gallery_reextract"), "Replace", class = "btn-warning"),
          modalButton("Cancel")
        ),
        easyClose = TRUE
      ))
    })

    observeEvent(input$confirm_gallery_reextract, {
      removeModal()
      doc_id <- selected_fig_doc()
      nb_id <- notebook_id()
      doc <- get_document(con(), doc_id)
      run_figure_extraction(doc_id, nb_id, doc$filepath, doc$filename)
    }, ignoreInit = TRUE)

    # Figure gallery renderUI
    output$figure_gallery <- renderUI({
      fig_refresh()
      doc_id <- selected_fig_doc()
      if (is.null(doc_id)) return(NULL)

      nb_id <- notebook_id()
      req(nb_id)

      figures <- tryCatch(
        db_get_figures_for_document(con(), doc_id),
        error = function(e) data.frame()
      )
      if (nrow(figures) == 0) return(NULL)

      fig_resource <- paste0("figures_", gsub("-", "", nb_id))
      view <- gallery_view()

      # Build figure cards
      fig_cards <- lapply(seq_len(nrow(figures)), function(i) {
        fig <- figures[i, ]
        is_excluded <- isTRUE(fig$is_excluded)
        has_desc <- !is.na(fig$llm_description) && nchar(fig$llm_description) > 0
        img_src <- file.path(fig_resource, doc_id, basename(fig$file_path))

        # Figure label
        label_text <- if (!is.na(fig$figure_label) && nchar(fig$figure_label) > 0) {
          fig$figure_label
        } else {
          paste("Page", fig$page_number)
        }

        # Register per-figure action observers
        if (is.null(fig_action_observers[[fig$id]])) {
          local({
            f_id <- fig$id
            f_path <- fig$file_path
            f_label <- fig$figure_label
            f_caption <- fig$extracted_caption

            # Keep
            obs_keep <- observeEvent(input[[paste0("keep_", f_id)]], {
              db_update_figure(con(), f_id, is_excluded = FALSE)
              fig_refresh(isolate(fig_refresh()) + 1)
            }, ignoreInit = TRUE)

            # Ban
            obs_ban <- observeEvent(input[[paste0("ban_", f_id)]], {
              db_update_figure(con(), f_id, is_excluded = TRUE)
              fig_refresh(isolate(fig_refresh()) + 1)
            }, ignoreInit = TRUE)

            # Retry vision description
            obs_retry <- observeEvent(input[[paste0("retry_", f_id)]], {
              cfg <- config()
              api_key <- cfg$openrouter$api_key
              if (is.null(api_key) || nchar(api_key) == 0) {
                showNotification(
                  "Configure an API key in Settings to describe figures.",
                  type = "warning"
                )
                return()
              }

              showNotification("Describing figure...", id = "retry_progress",
                               duration = NULL, type = "message")

              desc <- tryCatch(
                describe_figure(
                  api_key = api_key,
                  image_data = f_path,
                  figure_label = f_label,
                  extracted_caption = f_caption
                ),
                error = function(e) {
                  list(success = FALSE, error = conditionMessage(e))
                }
              )

              removeNotification("retry_progress")

              if (desc$success) {
                description_text <- desc$summary
                if (!is.na(desc$details) && nchar(desc$details) > 0) {
                  description_text <- paste0(description_text, "\n\n", desc$details)
                }
                db_update_figure(con(), f_id,
                  llm_description = description_text,
                  image_type = desc$type,
                  presentation_hint = desc$presentation_hint
                )
                # Log cost
                if (desc$prompt_tokens > 0 || desc$completion_tokens > 0) {
                  cost <- estimate_cost(desc$model_used,
                                        desc$prompt_tokens, desc$completion_tokens)
                  log_cost(con(), "figure_description", desc$model_used,
                           desc$prompt_tokens, desc$completion_tokens,
                           desc$prompt_tokens + desc$completion_tokens,
                           cost, session$token)
                }
                showNotification("Description updated", type = "message", duration = 3)
              } else {
                showNotification("Failed to describe figure", type = "error", duration = 5)
              }
              fig_refresh(isolate(fig_refresh()) + 1)
            }, ignoreInit = TRUE)
            fig_action_observers[[f_id]] <- list(obs_keep, obs_ban, obs_retry)
          })
        }

        # Build card based on view mode
        if (view == "list") {
          figure_card_list(fig, ns, img_src, label_text, is_excluded, has_desc)
        } else {
          figure_card_grid(fig, ns, img_src, label_text, is_excluded)
        }
      })

      # Gallery header with view toggle and re-extract
      header <- div(
        class = "d-flex justify-content-between align-items-center py-2 px-2 border-bottom",
        tags$strong(
          sprintf("Figures (%d)", nrow(figures))
        ),
        div(
          class = "d-flex gap-2",
          div(
            class = "btn-group btn-group-sm",
            actionButton(ns("gallery_view_list"), icon_list(),
              class = if (view == "list") "btn-primary" else "btn-outline-secondary",
              title = "List view"
            ),
            actionButton(ns("gallery_view_grid"), icon_grid(),
              class = if (view == "grid") "btn-primary" else "btn-outline-secondary",
              title = "Grid view"
            )
          ),
          actionButton(ns("gallery_reextract"), icon_refresh(),
            class = "btn-outline-warning btn-sm",
            title = "Re-extract figures"
          )
        )
      )

      tagList(
        hr(),
        header,
        div(
          style = "max-height: 500px; overflow-y: auto; padding: 4px;",
          fig_cards
        )
      )
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

        provider <- provider_from_config(cfg, con())
        embed_model <- resolve_model_for_operation(cfg, "embedding")

        # Insert into per-notebook ragnar store (Phase 22: per-notebook store)
        if (nrow(result$chunks) > 0 && !is.null(provider$api_key) && nchar(provider$api_key) > 0) {
          incProgress(0.55, detail = "Building search index")
          tryCatch({
            # Phase 22: Use per-notebook ragnar store
            store <- tryCatch(
              ensure_ragnar_store(nb_id, session, provider, embed_model),
              error = function(e) {
                message("[ragnar] Failed to open per-notebook store: ", e$message)
                showNotification(
                  paste("PDF saved but search index unavailable:", e$message,
                        "— use Rebuild Search Index to retry."),
                  type = "warning", duration = 8
                )
                NULL
              }
            )
            on.exit(disconnect_ragnar_store(store), add = TRUE)

            if (!is.null(store)) {
              # Insert chunks (ragnar handles embedding via OpenRouter)
              insert_chunks_to_ragnar(store, result$chunks, doc_id, "document")

              # Build/update the search index
              build_ragnar_index(store)

              # Mark chunks as embedded so brain icon shows
              mark_as_ragnar_indexed(con(), doc_id, source_type = "document")

              rag_ready(TRUE)
              store_healthy(TRUE)
              message("Ragnar store updated for document: ", file$name)
            }
          }, error = function(e) {
            message("Ragnar indexing failed: ", e$message)
            showNotification(
              paste("PDF saved but embedding failed:", e$message,
                    "— use Rebuild Search Index to retry."),
              type = "warning", duration = 8
            )
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
              icon_warning(class = "me-2"),
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
            icon_comments(class = "fa-2x mb-2"),
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
          is_synthesis <- !is.null(msg$preset_type) && msg$preset_type %in% c("overview", "conclusions", "research_questions", "lit_review", "methodology_extractor", "gap_analysis")

          content_html <- div(
            class = "bg-white border p-2 rounded chat-markdown",
            style = "max-width: 90%;",
            if (is_synthesis) {
              div(
                class = "alert alert-warning py-2 px-3 mb-2 small",
                role = "alert",
                tags$strong(icon_warning(), " AI-Generated Content"),
                " - Verify all claims against original sources before use."
              )
            },
            {
              rendered_html <- commonmark::markdown_html(msg$content, extensions = TRUE)
              if (!is.null(msg$preset_type) && identical(msg$preset_type, "lit_review")) {
                # Wrap table in scrollable container with frozen first column support
                rendered_html <- gsub(
                  "<table>",
                  '<div class="lit-review-scroll"><table class="table table-striped table-bordered">',
                  rendered_html)
                rendered_html <- gsub("</table>", "</table></div>", rendered_html)
              }
              HTML(rendered_html)
            }
          )

          div(class = "d-flex justify-content-start mb-2", content_html)
        }
      })

      # Add loading spinner if processing
      if (is_processing()) {
        doc_count <- processing_doc_count()
        status_text <- if (doc_count > 0) {
          sprintf("Analyzing %d document%s...", doc_count, if (doc_count == 1) "" else "s")
        } else {
          "Thinking..."
        }
        msg_list <- c(msg_list, list(
          div(
            class = "d-flex justify-content-start mb-2",
            div(
              class = "bg-white border p-2 rounded d-flex align-items-center gap-2",
              div(class = "spinner-border spinner-border-sm text-primary", role = "status"),
              span(class = "text-muted", status_text)
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
      processing_doc_count(tryCatch(nrow(list_documents(con(), notebook_id())), error = function(e) 0L))
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
      session$sendCustomMessage("docChatReady", ns(""))
    })

    # Also send on Enter key
    observeEvent(input$user_input, {
      # This won't work directly - need JS for Enter key
    }, ignoreInit = TRUE)

    # Synthesis progress modal helpers
    show_synthesis_modal <- function(label) {
      showModal(modalDialog(
        title = tagList(icon_spinner(class = "fa-spin"), paste(" Generating:", label)),
        div(
          class = "text-center py-3",
          div(class = "spinner-border text-primary mb-3", role = "status",
              style = "width: 3rem; height: 3rem;"),
          div(id = ns("synthesis_status"), class = "text-muted", "Preparing context...")
        ),
        footer = NULL,
        easyClose = FALSE,
        size = "m"
      ))
    }

    update_synthesis_status <- function(message) {
      session$sendCustomMessage("updateSynthesisStatus", list(
        msg_id = ns("synthesis_status"),
        message = message
      ))
    }

    # Preset buttons
    handle_preset <- function(preset_type, label) {
      req(!is_processing())
      req(has_api_key())

      # Empty notebook guard: skip modal and show inline warning if no content
      nb_id <- notebook_id()
      doc_count <- tryCatch(nrow(list_documents(con(), nb_id)), error = function(e) 0L)
      if (doc_count == 0L) {
        showNotification(
          "This notebook has no documents yet. Upload a PDF first, then try again.",
          type = "warning", duration = 5
        )
        return()
      }

      processing_doc_count(doc_count)
      is_processing(TRUE)

      show_synthesis_modal(label)

      msgs <- messages()
      msgs <- c(msgs, list(list(role = "user", content = paste("Generate:", label), timestamp = Sys.time())))
      messages(msgs)

      nb_id <- notebook_id()
      cfg <- config()

      update_synthesis_status("Sending to LLM...")
      response <- tryCatch({
        generate_preset(con(), cfg, nb_id, preset_type,
                        session_id = session$token)
      }, error = function(e) {
        sprintf("Error: %s", e$message)
      })

      update_synthesis_status("Processing response...")
      msgs <- c(msgs, list(list(role = "assistant", content = response, timestamp = Sys.time())))
      messages(msgs)
      is_processing(FALSE)
      removeModal()
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

      # Empty notebook guard
      nb_id <- notebook_id()
      doc_count <- tryCatch(nrow(list_documents(con(), nb_id)), error = function(e) 0L)
      if (doc_count == 0L) {
        showNotification("This notebook has no documents yet. Upload a PDF first, then try again.",
                         type = "warning", duration = 5)
        toggle_popover(id = ns("overview_popover"))
        return()
      }

      depth <- input$overview_depth %||% "concise"
      mode <- input$overview_mode %||% "quick"

      depth_label <- if (identical(depth, "detailed")) "Detailed" else "Concise"
      mode_label <- if (identical(mode, "thorough")) "Thorough" else "Quick"

      processing_doc_count(doc_count)
      is_processing(TRUE)

      toggle_popover(id = ns("overview_popover"))
      show_synthesis_modal(paste0("Overview (", depth_label, ", ", mode_label, ")"))

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

      update_synthesis_status("Sending to LLM...")
      response <- tryCatch({
        generate_overview_preset(con(), cfg, nb_id, notebook_type = "document",
                                 depth = depth, mode = mode, session_id = session$token)
      }, error = function(e) {
        sprintf("Error: %s", e$message)
      })

      update_synthesis_status("Processing response...")
      msgs <- c(msgs, list(list(
        role = "assistant",
        content = response,
        timestamp = Sys.time(),
        preset_type = "overview"
      )))
      messages(msgs)
      is_processing(FALSE)
      removeModal()
    })

    observeEvent(input$btn_studyguide, handle_preset("studyguide", "Study Guide"))
    observeEvent(input$btn_outline, handle_preset("outline", "Outline"))

    # Conclusions preset handler
    observeEvent(input$btn_conclusions, {
      req(!is_processing())
      req(has_api_key())

      # Empty notebook guard
      nb_id <- notebook_id()
      doc_count <- tryCatch(nrow(list_documents(con(), nb_id)), error = function(e) 0L)
      if (doc_count == 0L) {
        showNotification("This notebook has no documents yet. Upload a PDF first, then try again.",
                         type = "warning", duration = 5)
        return()
      }

      processing_doc_count(doc_count)
      is_processing(TRUE)
      show_synthesis_modal("Conclusion Synthesis")

      msgs <- messages()
      msgs <- c(msgs, list(list(role = "user", content = "Generate: Conclusion Synthesis", timestamp = Sys.time(), preset_type = "conclusions")))
      messages(msgs)

      nb_id <- notebook_id()
      cfg <- config()

      update_synthesis_status("Sending to LLM...")
      response <- tryCatch({
        generate_conclusions_preset(con(), cfg, nb_id, notebook_type = "document", session_id = session$token)
      }, error = function(e) {
        sprintf("Error: %s", e$message)
      })

      update_synthesis_status("Processing response...")
      msgs <- c(msgs, list(list(role = "assistant", content = response, timestamp = Sys.time(), preset_type = "conclusions")))
      messages(msgs)
      is_processing(FALSE)
      removeModal()
    })

    # Literature Review Table preset handler
    observeEvent(input$btn_lit_review, {
      req(!is_processing())
      req(has_api_key())

      # Guard: RAG must be available
      if (!isTRUE(rag_available())) {
        showNotification("Synthesis unavailable - re-index this notebook first.", type = "warning")
        return()
      }

      # Empty notebook guard
      nb_id <- notebook_id()
      doc_count <- tryCatch(nrow(list_documents(con(), nb_id)), error = function(e) 0L)
      if (doc_count == 0L) {
        showNotification("This notebook has no documents yet. Upload a PDF first, then try again.",
                         type = "warning", duration = 5)
        return()
      }

      # Warning toast for large notebooks (20+ papers)
      if (doc_count >= 20L) {
        showNotification(
          sprintf("Analyzing %d papers - output quality may degrade with large collections.", doc_count),
          type = "warning", duration = 8
        )
      }

      processing_doc_count(doc_count)
      is_processing(TRUE)
      show_synthesis_modal("Literature Review Table")

      msgs <- messages()
      msgs <- c(msgs, list(list(
        role = "user",
        content = "Generate: Literature Review Table",
        timestamp = Sys.time(),
        preset_type = "lit_review"
      )))
      messages(msgs)

      cfg <- config()

      update_synthesis_status("Sending to LLM...")
      response <- tryCatch({
        generate_lit_review_table(con(), cfg, nb_id, session_id = session$token)
      }, error = function(e) {
        sprintf("Error: %s", e$message)
      })

      update_synthesis_status("Processing response...")
      msgs <- c(msgs, list(list(
        role = "assistant",
        content = response,
        timestamp = Sys.time(),
        preset_type = "lit_review"
      )))
      messages(msgs)
      is_processing(FALSE)
      removeModal()
    })

    # Methodology Extractor preset handler
    observeEvent(input$btn_methods, {
      req(!is_processing())
      req(has_api_key())

      # Guard: RAG must be available
      if (!isTRUE(rag_available())) {
        showNotification("Synthesis unavailable - re-index this notebook first.", type = "warning")
        return()
      }

      # Empty notebook guard
      nb_id <- notebook_id()
      doc_count <- tryCatch(nrow(list_documents(con(), nb_id)), error = function(e) 0L)
      if (doc_count == 0L) {
        showNotification("This notebook has no documents yet. Upload a PDF first, then try again.",
                         type = "warning", duration = 5)
        return()
      }

      # Warning toast for large notebooks (20+ papers)
      if (doc_count >= 20L) {
        showNotification(
          sprintf("Analyzing %d papers - output quality may degrade with large collections.", doc_count),
          type = "warning", duration = 8
        )
      }

      processing_doc_count(doc_count)
      is_processing(TRUE)
      show_synthesis_modal("Methodology Extractor")

      msgs <- messages()
      msgs <- c(msgs, list(list(
        role = "user",
        content = "Generate: Methodology Extractor",
        timestamp = Sys.time(),
        preset_type = "methodology_extractor"
      )))
      messages(msgs)

      cfg <- config()

      update_synthesis_status("Sending to LLM...")
      response <- tryCatch({
        generate_methodology_extractor(con(), cfg, nb_id, session_id = session$token)
      }, error = function(e) {
        sprintf("Error: %s", e$message)
      })

      update_synthesis_status("Processing response...")
      msgs <- c(msgs, list(list(
        role = "assistant",
        content = response,
        timestamp = Sys.time(),
        preset_type = "methodology_extractor"
      )))
      messages(msgs)
      is_processing(FALSE)
      removeModal()
    })

    # Gap Analysis preset handler
    observeEvent(input$btn_gaps, {
      req(!is_processing())
      req(has_api_key())

      # Guard: RAG must be available
      if (!isTRUE(rag_available())) {
        showNotification("Synthesis unavailable - re-index this notebook first.", type = "warning")
        return()
      }

      # Minimum 3 papers required for gap analysis (also serves as empty guard)
      nb_id <- notebook_id()
      doc_count <- tryCatch(nrow(list_documents(con(), nb_id)), error = function(e) 0L)
      if (doc_count < 3L) {
        if (doc_count == 0L) {
          showNotification("This notebook has no documents yet. Upload a PDF first, then try again.",
                           type = "warning", duration = 5)
          return()
        }
        showNotification(
          "Gap analysis requires at least 3 papers. Add more papers to this notebook.",
          type = "error", duration = 8
        )
        return()
      }

      # Warning toast for large notebooks (15+ papers)
      if (doc_count >= 15L) {
        showNotification(
          sprintf("Analyzing %d papers - output quality may degrade with large collections.", doc_count),
          type = "warning", duration = 8
        )
      }

      processing_doc_count(doc_count)
      is_processing(TRUE)
      show_synthesis_modal("Research Gaps")

      msgs <- messages()
      msgs <- c(msgs, list(list(
        role = "user",
        content = "Generate: Research Gaps",
        timestamp = Sys.time(),
        preset_type = "gap_analysis"
      )))
      messages(msgs)

      cfg <- config()

      update_synthesis_status("Sending to LLM...")
      response <- tryCatch({
        generate_gap_analysis(con(), cfg, nb_id, session_id = session$token)
      }, error = function(e) {
        sprintf("Error: %s", e$message)
      })

      update_synthesis_status("Processing response...")
      msgs <- c(msgs, list(list(
        role = "assistant",
        content = response,
        timestamp = Sys.time(),
        preset_type = "gap_analysis"
      )))
      messages(msgs)
      is_processing(FALSE)
      removeModal()
    })

    # Slides module
    mod_slides_server("slides", con, notebook_id, config, slides_trigger)

    # Slides button
    observeEvent(input$btn_slides, {
      slides_trigger(slides_trigger() + 1)
    })
  })
}


# =============================================================================
# Figure card helpers (used by gallery renderUI)
# =============================================================================

#' Render a figure card in list view (large image + full metadata)
#' @keywords internal
figure_card_list <- function(fig, ns, img_src, label_text, is_excluded, has_desc) {
  card(
    class = if (is_excluded) "mb-2 opacity-50 border-danger" else "mb-2",
    card_body(
      class = "p-2",
      layout_columns(
        col_widths = c(5, 7),
        tags$img(
          src = img_src,
          class = "img-fluid rounded",
          style = "max-height: 200px; object-fit: contain; width: 100%;",
          alt = label_text
        ),
        tags$div(
          tags$div(
            class = "d-flex justify-content-between align-items-start mb-1",
            tags$strong(label_text),
            if (is_excluded) {
              span(class = "badge bg-danger", "Excluded")
            }
          ),
          if (!is.na(fig$extracted_caption) && nchar(fig$extracted_caption) > 0) {
            tags$p(class = "text-muted small mb-1",
                   style = "line-height: 1.3;",
                   substr(fig$extracted_caption, 1, 200),
                   if (nchar(fig$extracted_caption) > 200) "...")
          },
          if (has_desc) {
            tags$p(class = "small mb-1",
                   style = "line-height: 1.3;",
                   icon_brain(class = "text-primary me-1"),
                   substr(fig$llm_description, 1, 150),
                   if (nchar(fig$llm_description) > 150) "...")
          } else {
            tags$p(class = "text-warning small mb-1",
                   icon_warning(), " No description")
          },
          tags$div(
            class = "btn-group btn-group-sm mt-1",
            actionButton(
              ns(paste0("keep_", fig$id)),
              label = tagList(icon_check(), "Keep"),
              class = if (!is_excluded) "btn-success" else "btn-outline-success"
            ),
            actionButton(
              ns(paste0("retry_", fig$id)),
              label = tagList(icon_refresh(), "Retry"),
              class = "btn-outline-primary"
            ),
            actionButton(
              ns(paste0("ban_", fig$id)),
              label = tagList(icon_ban(), "Ban"),
              class = if (is_excluded) "btn-danger" else "btn-outline-danger"
            )
          )
        )
      )
    )
  )
}

#' Render a figure card in grid/thumbnail view
#' @keywords internal
figure_card_grid <- function(fig, ns, img_src, label_text, is_excluded) {
  tags$div(
    class = "d-inline-block p-1 align-top",
    style = "width: 180px;",
    card(
      class = if (is_excluded) "opacity-50 border-danger" else "",
      card_body(
        class = "p-1 text-center",
        tags$img(
          src = img_src,
          class = "img-fluid rounded",
          style = "max-height: 120px; object-fit: contain;",
          alt = label_text
        ),
        tags$small(class = "d-block text-muted mt-1", label_text),
        tags$div(
          class = "btn-group btn-group-sm mt-1",
          actionButton(
            ns(paste0("keep_", fig$id)),
            icon_check(),
            class = if (!is_excluded) "btn-success" else "btn-outline-success",
            title = "Keep"
          ),
          actionButton(
            ns(paste0("retry_", fig$id)),
            icon_refresh(),
            class = "btn-outline-primary",
            title = "Retry description"
          ),
          actionButton(
            ns(paste0("ban_", fig$id)),
            icon_ban(),
            class = if (is_excluded) "btn-danger" else "btn-outline-danger",
            title = "Exclude"
          )
        )
      )
    )
  )
}
