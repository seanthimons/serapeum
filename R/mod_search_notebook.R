#' OpenAlex work type taxonomy (Phase 55)
#' Full 16-type taxonomy with Catppuccin color families
OPENALEX_WORK_TYPES <- list(
  # Primary research (lavender/blue family)
  list(slug = "article", label = "Article", category = "primary", class = "bg-primary"),
  list(slug = "book", label = "Book", category = "primary", class = "bg-primary"),
  list(slug = "book-chapter", label = "Book Chapter", category = "primary", class = "bg-primary-subtle text-primary-emphasis"),
  list(slug = "dissertation", label = "Dissertation", category = "primary", class = "bg-info-subtle text-info-emphasis"),

  # Reviews/editorials (sapphire/info family)
  list(slug = "review", label = "Review", category = "review", class = "bg-info"),
  list(slug = "editorial", label = "Editorial", category = "review", class = "bg-info text-info-emphasis"),
  list(slug = "letter", label = "Letter", category = "review", class = "bg-info-subtle text-info-emphasis"),
  list(slug = "peer-review", label = "Peer Review", category = "review", class = "bg-info-subtle text-info-emphasis"),

  # Preprints/reports (yellow/warning family)
  list(slug = "preprint", label = "Preprint", category = "preprint", class = "bg-warning text-body"),
  list(slug = "report", label = "Report", category = "preprint", class = "bg-warning-subtle text-warning-emphasis"),
  list(slug = "standard", label = "Standard", category = "preprint", class = "bg-warning-subtle text-warning-emphasis"),

  # Metadata/other (gray/neutral family)
  list(slug = "dataset", label = "Dataset", category = "other", class = "bg-body-tertiary text-body"),
  list(slug = "erratum", label = "Erratum", category = "other", class = "bg-body-tertiary text-body"),
  list(slug = "paratext", label = "Paratext", category = "other", class = "bg-body-tertiary text-body"),
  list(slug = "grant", label = "Grant", category = "other", class = "bg-body-tertiary text-body"),
  list(slug = "supplementary-materials", label = "Supplementary Materials", category = "other", class = "bg-body-tertiary text-body")
)

#' Default ON types (common scholarly outputs)
DEFAULT_ON_TYPES <- c("article", "review", "preprint", "book", "book-chapter", "dissertation")

#' Get badge class and label for work type (Phase 55)
#' @param work_type OpenAlex work type slug
#' @return List with class and label
get_type_badge <- function(work_type) {
  if (is.null(work_type) || is.na(work_type) || work_type == "") {
    return(list(class = "bg-body-tertiary text-body", label = "Unknown"))
  }
  match <- Filter(function(t) t$slug == work_type, OPENALEX_WORK_TYPES)
  if (length(match) > 0) {
    return(list(class = match[[1]]$class, label = match[[1]]$label))
  }
  # Fallback for unknown types
  list(class = "bg-body-tertiary text-body", label = tools::toTitleCase(gsub("-", " ", work_type)))
}

#' Validate URL is safe for use in href (HTTP/HTTPS only)
#' @param url URL to validate
#' @return TRUE if URL is safe, FALSE otherwise
is_safe_url <- function(url) {
  if (is.na(url) || is.null(url) || nchar(url) == 0) return(FALSE)
  grepl("^https?://", url, ignore.case = TRUE)
}

#' Show a user-friendly error toast notification
#' @param message Plain language error message
#' @param details Technical details (HTTP status, raw error)
#' @param severity "error" or "warning"
#' @param duration Auto-dismiss seconds (default 8 for errors, 5 for warnings)
show_error_toast <- function(message, details = NULL, severity = "error", duration = NULL) {
  if (is.null(duration)) {
    duration <- if (severity == "warning") 5 else 8
  }

  # Build notification content with optional expandable details
  content <- if (!is.null(details) && nchar(details) > 0) {
    HTML(paste0(
      '<div>', htmltools::htmlEscape(message), '</div>',
      '<details class="mt-1"><summary class="small text-muted" style="cursor:pointer;">Show details</summary>',
      '<div class="small text-muted mt-1 font-monospace" style="word-break:break-all;">',
      htmltools::htmlEscape(details),
      '</div></details>'
    ))
  } else {
    message
  }

  type <- if (severity == "warning") "warning" else "error"
  showNotification(content, type = type, duration = duration)
}

#' Format result count for display (Phase 51)
#' @param fetched Total papers in notebook
#' @param total Total matching results from API
#' @return Character string like "25 of 100 results" or ""
format_result_count <- function(fetched, total) {
  if (is.null(total) || total == 0) return("")
  if (fetched >= total) return(paste(total, "results"))
  paste(fetched, "of", total, "results")
}

#' Format large number for display (Phase 53)
#' @param n Number to format
#' @return Character string like "1.6M" or "234K"
format_large_number <- function(n) {
  if (is.null(n) || is.na(n) || n <= 0) return("0")
  if (n >= 1e6) return(paste0(round(n / 1e6, 1), "M"))
  if (n >= 1e3) return(paste0(round(n / 1e3, 1), "K"))
  as.character(n)
}

#' Search Notebook Module UI
#' @param id Module ID
mod_search_notebook_ui <- function(id) {

  ns <- NS(id)

  tagList(
    # Phase 38: Select-all checkbox tri-state JS handler
    tags$script(src = "js/select-all.js"),
    # JavaScript: show spinner on send button while chat is processing
    tags$script(HTML(sprintf("
      $(document).on('click', '#%s', function() {
        var btn = $(this);
        btn.data('original-html', btn.html());
        btn.html('<span class=\"spinner-border spinner-border-sm\" role=\"status\"></span>');
        btn.prop('disabled', true);
      });
      if (!window._searchChatReadyRegistered) {
        window._searchChatReadyRegistered = true;
        Shiny.addCustomMessageHandler('searchChatReady', function(ns) {
          var btn = $('#' + ns + 'send');
          var orig = btn.data('original-html');
          if (orig) btn.html(orig);
          btn.prop('disabled', false);
        });
      }
    ", ns("send")))),

    layout_columns(
      col_widths = c(5, 7),
      # Left: Paper list
      card(
        card_header(
          # 3x2 button grid — single CSS grid for perfect column alignment
          div(
            style = "display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 0.5rem;",
            bslib::tooltip(
              actionButton(ns("open_bulk_import"), "Import",
                           class = "btn-sm btn-outline-primary",
                           style = "white-space: nowrap;",
                           icon = icon_file_import()),
              "Add papers by pasting DOIs or uploading a BibTeX file",
              placement = "bottom",
              options = list(delay = list(show = 300, hide = 100))
            ),
            bslib::tooltip(
              actionButton(ns("edit_search"), "Edit Search",
                           class = "btn-sm btn-outline-secondary",
                           style = "white-space: nowrap;",
                           icon = icon_edit()),
              "Change your search query, filters, or discovery method",
              placement = "bottom",
              options = list(delay = list(show = 300, hide = 100))
            ),
            bslib::tooltip(
              actionButton(ns("seed_citation_network"), "Cit Network",
                           class = "btn-sm btn-outline-primary",
                           style = "white-space: nowrap;",
                           icon = icon_share_nodes()),
              "Build a citation network from a seed paper in your results",
              placement = "bottom",
              options = list(delay = list(show = 300, hide = 100))
            ),
            # Row 2: Export | Refresh | Load More
            bslib::tooltip(
              div(
                class = "btn-group btn-group-sm w-100",
                tags$button(
                  class = "btn btn-outline-primary dropdown-toggle w-100",
                  `data-bs-toggle` = "dropdown",
                  icon_download(), " Export"
                ),
                tags$ul(
                  class = "dropdown-menu",
                  tags$li(downloadLink(ns("download_bibtex"), class = "dropdown-item", icon_file_code(), " BibTeX (.bib)")),
                  tags$li(downloadLink(ns("download_csv"), class = "dropdown-item", icon_file_csv(), " CSV (.csv)"))
                )
              ),
              "Download your current papers as BibTeX or CSV",
              placement = "bottom",
              options = list(delay = list(show = 300, hide = 100), container = "body")
            ),
            bslib::tooltip(
              actionButton(ns("refresh_search"), "Refresh",
                           class = "btn-sm btn-outline-secondary",
                           style = "white-space: nowrap;",
                           icon = icon_rotate()),
              "Re-run your current search to check for new results",
              placement = "bottom",
              options = list(delay = list(show = 300, hide = 100))
            ),
            bslib::tooltip(
              actionButton(ns("load_more"), "Load More",
                           class = "btn-sm btn-outline-primary",
                           style = "white-space: nowrap;",
                           icon = icon_angles_down()),
              "Fetch the next batch of results from OpenAlex",
              placement = "bottom",
              options = list(delay = list(show = 300, hide = 100))
            )
          )
        ),
        card_body(
          # Sort controls
          div(
            class = "d-flex flex-wrap justify-content-around mb-2",
            radioButtons(
              ns("sort_by"),
              NULL,
              choices = c(
                "Newest" = "year",
                "Most cited" = "cited_by_count",
                "Impact (FWCI)" = "fwci",
                "Most refs" = "referenced_works_count"
              ),
              selected = "year",
              inline = TRUE
            )
          ),
          # Filter controls
          div(
            class = "mb-2",
            checkboxInput(
              ns("filter_has_abstract"),
              "Show only papers with abstracts",
              value = TRUE
            )
          ),
          # Year range filter panel
          div(
            class = "mb-2",
            sliderInput(
              ns("year_range"),
              "Publication Year",
              min = 1900,
              max = 2026,
              value = c(1900, 2026),
              step = 1,
              sep = "",
              ticks = FALSE
            ),
            plotOutput(ns("year_histogram"), height = "60px"),
            div(
              class = "d-flex justify-content-between align-items-center",
              checkboxInput(
                ns("include_unknown_year"),
                "Include unknown year",
                value = TRUE
              ),
              textOutput(ns("unknown_year_count"), inline = TRUE) |>
                tagAppendAttributes(class = "text-muted small")
            )
          ),
          # Phase 38: Select-all checkbox
          div(
            class = "d-flex align-items-center gap-2 mb-2",
            tags$input(
              type = "checkbox",
              id = ns("select_all_cb"),
              class = "form-check-input",
              onclick = sprintf("Shiny.setInputValue('%s', this.checked, {priority: 'event'})", ns("select_all_click"))
            ),
            tags$label(
              `for` = ns("select_all_cb"),
              class = "form-check-label small text-muted",
              "Select all"
            )
          ),
          div(
            id = ns("paper_list_container"),
            style = "max-height: 400px; overflow-y: auto;",
            uiOutput(ns("paper_list"))
          ),
          hr(),
          uiOutput(ns("import_button_ui"))
        )
      ),
      # Right: Keyword panel + Abstract detail view
      div(
        # Keyword filter panel
        card(
          card_header(
            class = "d-flex justify-content-between align-items-center",
            style = "cursor: pointer;",
            `data-bs-toggle` = "collapse",
            `data-bs-target` = paste0("#", ns("keyword_filter_body")),
            span(icon_key(), " Keywords"),
            icon_chevron_down(class = "text-muted")
          ),
          card_body(
            id = ns("keyword_filter_body"),
            class = "collapse show",
            style = "max-height: 200px; overflow-y: auto;",
            mod_keyword_filter_ui(ns("keyword_filter"))
          ),
          card_footer(
            class = "d-flex flex-column gap-2",
            uiOutput(ns("embed_button")),
            uiOutput(ns("exclusion_info"))
          )
        ),
        # Journal quality filter panel
        card(
          class = "mt-2",
          card_header(
            class = "d-flex justify-content-between align-items-center",
            style = "cursor: pointer;",
            `data-bs-toggle` = "collapse",
            `data-bs-target` = paste0("#", ns("journal_quality_body")),
            span(icon_shield(), " Journal Quality"),
            div(
              class = "d-flex align-items-center gap-2",
              tags$span(
                onclick = "event.stopPropagation();",
                actionLink(ns("manage_blocklist"), icon_list(), class = "text-muted", title = "Manage blocklist")
              ),
              icon_chevron_down(class = "text-muted")
            )
          ),
          card_body(
            id = ns("journal_quality_body"),
            class = "collapse show",
            mod_journal_filter_ui(ns("journal_filter"))
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
        div(
          class = "d-flex align-items-center gap-2 ms-auto",
          div(
            class = "btn-group btn-group-sm",
            tags$button(
              class = "btn btn-outline-secondary dropdown-toggle",
              `data-bs-toggle` = "dropdown",
              icon_download()
            ),
            tags$ul(
              class = "dropdown-menu dropdown-menu-end",
              tags$li(downloadLink(ns("download_chat_md"), class = "dropdown-item", icon_paper(), " Markdown (.md)")),
              tags$li(downloadLink(ns("download_chat_html"), class = "dropdown-item", icon_file_code(), " HTML (.html)"))
            )
          ),
          tags$button(
            type = "button",
            class = "btn-close",
            `data-bs-dismiss` = "offcanvas",
            `aria-label` = "Close"
          )
        )
      ),

      # Body
      div(
        class = "offcanvas-body d-flex flex-column p-0",
        # Preset buttons row (above messages)
        div(
          class = "border-bottom px-3 py-2",
          div(
            class = "btn-group btn-group-sm w-100",
            uiOutput(ns("overview_btn_ui")),
            uiOutput(ns("conclusions_btn_ui")),
            uiOutput(ns("research_questions_btn_ui"))
          )
        ),
        # Messages area
        div(
          id = ns("chat_messages"),
          class = "flex-grow-1 overflow-auto p-3",
          style = "background-color: var(--bs-tertiary-bg);",
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
            uiOutput(ns("send_btn_ui"))
          )
        )
      )
    ),
    # Phase 22: JS handler for async re-index progress bar updates
    tags$script(HTML("
      Shiny.addCustomMessageHandler('updateSearchReindexProgress', function(data) {
        var bar = document.getElementById(data.bar_id);
        var msg = document.getElementById(data.msg_id);
        if (bar) {
          bar.style.width = data.pct + '%';
          bar.setAttribute('aria-valuenow', data.pct);
        }
        if (msg) msg.textContent = data.message;
      });
    ")),

    # Phase 35: Bulk DOI import module UI (modals + history)
    mod_bulk_import_ui(ns("bulk_import"), show_history = TRUE)
  )
}

#' Search Notebook Module Server
#' @param id Module ID
#' @param con Database connection (reactive)
#' @param notebook_id Reactive notebook ID
#' @param config App config (reactive)
mod_search_notebook_server <- function(id, con, notebook_id, config, notebook_refresh = NULL, db_path = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    messages <- reactiveVal(list())
    selected_papers <- reactiveVal(character())
    viewed_paper <- reactiveVal(NULL)

    # Phase 38: Select-all state management (flag + exception set)
    # When all_selected=TRUE, effective selection = all filtered IDs minus exceptions
    # When all_selected=FALSE, effective selection = exceptions (individually checked)
    select_all_state <- reactiveVal(list(all_selected = FALSE, exceptions = character()))
    paper_refresh <- reactiveVal(0)
    is_processing <- reactiveVal(FALSE)
    seed_request <- reactiveVal(NULL)
    network_seed_request <- reactiveVal(NULL)
    # Track which paper IDs already have delete observers to prevent duplicates
    delete_observers <- reactiveValues()
    # Track block/unblock journal observers to prevent duplicates
    block_journal_observers <- reactiveValues()
    unblock_journal_observers <- reactiveValues()

    # Phase 51: Pagination state for cursor-based pagination
    pagination_state <- reactiveValues(
      cursor = NULL,          # NULL = page 1, string = continuation token
      has_more = FALSE,       # TRUE if next_cursor was non-NULL in last response
      total_fetched = 0L,     # Total papers in notebook (from DB count)
      api_total = 0L          # Total matching papers from OpenAlex meta.count
    )

    # Phase 55: Type filter chip toggle states
    type_states <- reactiveValues()
    type_states_initialized <- reactiveVal(FALSE)

    # Phase 38: Batch import state
    batch_import_interrupt <- reactiveVal(NULL)
    batch_import_progress <- reactiveVal(NULL)
    batch_import_poller <- reactiveVal(NULL)

    # Phase 22: Per-notebook store migration state
    rag_ready <- reactiveVal(TRUE)
    store_healthy <- reactiveVal(NULL)
    current_interrupt_flag <- reactiveVal(NULL)
    current_progress_file <- reactiveVal(NULL)
    reindex_poller <- reactiveVal(NULL)

    # Phase 35: Bulk DOI import module
    # db_path can be a reactive or a plain value — wrap in reactive for the module
    db_path_r <- if (is.function(db_path)) db_path else reactive(db_path)
    bulk_import_api <- mod_bulk_import_server("bulk_import", con, notebook_id, config,
                                              paper_refresh, db_path_r, show_history = TRUE)

    # Phase 35: Open bulk import modal
    observeEvent(input$open_bulk_import, {
      bulk_import_api$show_import_modal()
    })

    # Phase 22: rag_available = store exists and is healthy
    rag_available <- reactive({
      isTRUE(store_healthy()) && isTRUE(rag_ready())
    })

    # Phase 22: Async re-index task (mirai worker)
    # Data (documents/abstracts) is pre-fetched in main process to avoid cross-process DuckDB locks
    reindex_task <- ExtendedTask$new(function(notebook_id, documents, abstracts, api_key, embed_model, interrupt_flag, progress_file, app_dir) {
      mirai::mirai({
        source(file.path(app_dir, "R", "interrupt.R"))
        source(file.path(app_dir, "R", "api_openalex.R"))
        source(file.path(app_dir, "R", "api_openrouter.R"))
        source(file.path(app_dir, "R", "_ragnar.R"))

        result <- rebuild_notebook_store(
          notebook_id = notebook_id,
          api_key = api_key,
          embed_model = embed_model,
          documents = documents,
          abstracts = abstracts,
          interrupt_flag = interrupt_flag,
          progress_file = progress_file,
          progress_callback = NULL
        )
        result
      }, notebook_id = notebook_id, documents = documents, abstracts = abstracts,
         api_key = api_key, embed_model = embed_model, interrupt_flag = interrupt_flag,
         progress_file = progress_file, app_dir = app_dir)
    })

    # Phase 38: ExtendedTask for batch abstract import (50+ papers)
    batch_import_task <- ExtendedTask$new(function(abstract_ids, target_notebook_id,
                                                    db_path, interrupt_flag, progress_file, app_dir) {
      mirai::mirai({
        setwd(app_dir)
        source("R/db_migrations.R")
        source("R/db.R")
        source("R/interrupt.R")
        source("R/bulk_import.R")  # For write_import_progress / read_import_progress

        # Open own DB connection (mirai workers can't share)
        con <- get_connection(db_path)
        on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

        # Check which abstracts are already in the target notebook (duplicates)
        existing_docs <- DBI::dbGetQuery(con, sprintf(
          "SELECT abstract_id FROM documents WHERE notebook_id = '%s' AND abstract_id IS NOT NULL",
          target_notebook_id
        ))
        existing_abstract_ids <- existing_docs$abstract_id

        to_import <- setdiff(abstract_ids, existing_abstract_ids)
        duplicates <- intersect(abstract_ids, existing_abstract_ids)

        imported <- 0L
        failed <- 0L
        failed_details <- list()
        total <- length(to_import)

        for (i in seq_along(to_import)) {
          # Check for interrupt
          if (check_interrupt(interrupt_flag)) {
            break
          }

          aid <- to_import[i]

          tryCatch({
            abs <- DBI::dbGetQuery(con, sprintf("SELECT * FROM abstracts WHERE id = '%s'", aid))
            if (nrow(abs) == 0) {
              failed <- failed + 1L
              failed_details[[length(failed_details) + 1]] <- list(id = aid, reason = "Abstract not found")
              next
            }
            abs <- abs[1, ]

            if (is.na(abs$abstract) || nchar(abs$abstract) == 0) {
              failed <- failed + 1L
              failed_details[[length(failed_details) + 1]] <- list(id = aid, reason = "No abstract text")
              next
            }

            doc_doi <- if (!is.null(abs$doi) && !is.na(abs$doi)) abs$doi else NA_character_
            doc_authors <- if (!is.null(abs$authors) && !is.na(abs$authors)) abs$authors else NA_character_
            doc_year <- if (!is.null(abs$year) && !is.na(abs$year)) as.integer(abs$year) else NA_integer_

            doc_id <- create_document(
              con, target_notebook_id,
              paste0(abs$title, ".txt"),
              "",
              abs$abstract,
              1,
              title = abs$title,
              authors = doc_authors,
              year = doc_year,
              doi = doc_doi,
              abstract_id = abs$id
            )

            create_chunk(con, doc_id, "document", 0, abs$abstract, page_number = 1)
            imported <- imported + 1L
          }, error = function(e) {
            failed <<- failed + 1L
            failed_details[[length(failed_details) + 1]] <<- list(id = aid, reason = conditionMessage(e))
          })

          # Write progress
          pct_msg <- sprintf("Importing paper %d of %d...", i, total)
          write_import_progress(progress_file, i, total, imported, failed, pct_msg)
        }

        cancelled <- check_interrupt(interrupt_flag)

        list(
          imported = imported,
          failed = failed,
          duplicates = length(duplicates),
          duplicate_ids = duplicates,
          failed_details = failed_details,
          cancelled = cancelled,
          total_requested = length(abstract_ids)
        )
      }, abstract_ids = abstract_ids, target_notebook_id = target_notebook_id,
         db_path = db_path, interrupt_flag = interrupt_flag,
         progress_file = progress_file, app_dir = app_dir)
    })

    # Phase 22: Check for per-notebook store migration on notebook open
    observeEvent(notebook_id(), {
      nb_id <- notebook_id()
      req(nb_id)

      # Reset state
      rag_ready(TRUE)
      store_healthy(NULL)

      store_path <- get_notebook_ragnar_path(nb_id)

      # Check if notebook has embedded content but no per-notebook store
      has_content <- tryCatch({
        abstracts <- DBI::dbGetQuery(con(), "
          SELECT COUNT(*) as cnt FROM abstracts WHERE notebook_id = ?
        ", list(nb_id))
        abstracts$cnt[1] > 0
      }, error = function(e) FALSE)

      if (has_content && !file.exists(store_path)) {
        # Has abstracts but no per-notebook store — needs migration
        # Modal is shown by mod_document_notebook; we just disable features here
        rag_ready(FALSE)
        store_healthy(FALSE)
      } else if (file.exists(store_path)) {
        # Store exists — check integrity
        result <- check_store_integrity(store_path)
        store_healthy(result$ok)
        rag_ready(result$ok)
      } else {
        # No content, no store — fine, lazy creation later
        store_healthy(TRUE)
        rag_ready(TRUE)
      }
    })

    # Phase 22: Re-index handler (launched from migration prompt)
    observeEvent(input$reindex_search_nb, {
      removeModal()
      nb_id <- notebook_id()
      req(nb_id)

      cfg <- config()
      api_key <- get_setting(cfg, "openrouter", "api_key")
      embed_model <- get_setting(cfg, "defaults", "embedding_model") %||% "openai/text-embedding-3-small"

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
        title = "Re-indexing Search Notebook",
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
        session$sendCustomMessage("updateSearchReindexProgress", list(
          bar_id = ns("reindex_bar"),
          msg_id = ns("reindex_message"),
          pct = prog$pct,
          message = prog$message
        ))
      })
      reindex_poller(poller)

      # Launch async task
      reindex_task$invoke(nb_id, documents, abstracts, api_key, embed_model, flag_file, progress_file, getwd())
    })

    # Phase 22: Rebuild handler (corruption recovery — same async pattern)
    observeEvent(input$rebuild_search_index, {
      removeModal()
      nb_id <- notebook_id()
      req(nb_id)

      cfg <- config()
      api_key <- get_setting(cfg, "openrouter", "api_key")
      embed_model <- get_setting(cfg, "defaults", "embedding_model") %||% "openai/text-embedding-3-small"

      # Pre-fetch data in main process (avoids cross-process DuckDB lock)
      documents <- list_documents(con(), nb_id)
      abstracts <- list_abstracts(con(), nb_id)

      # Delete existing store in main process (mirai worker can't delete cross-process locked files)
      delete_notebook_store(nb_id)

      flag_file <- create_interrupt_flag(session$token)
      progress_file <- create_progress_file(session$token)
      current_interrupt_flag(flag_file)
      current_progress_file(progress_file)

      showModal(modalDialog(
        title = "Rebuilding Search Index",
        div(
          div(id = ns("reindex_message"), "Initializing rebuild..."),
          div(class = "progress mt-2",
            div(class = "progress-bar progress-bar-striped progress-bar-animated",
                id = ns("reindex_bar"), role = "progressbar",
                style = "width: 0%")
          )
        ),
        footer = actionButton(ns("cancel_reindex"), "Stop", class = "btn-warning"),
        easyClose = FALSE
      ))

      poller <- observe({
        invalidateLater(1000)
        prog <- read_reindex_progress(current_progress_file())
        session$sendCustomMessage("updateSearchReindexProgress", list(
          bar_id = ns("reindex_bar"), msg_id = ns("reindex_message"),
          pct = prog$pct, message = prog$message
        ))
      })
      reindex_poller(poller)

      reindex_task$invoke(nb_id, documents, abstracts, api_key, embed_model, flag_file, progress_file, getwd())
    })

    # Phase 22: Cancel re-index handler
    observeEvent(input$cancel_reindex, {
      flag <- current_interrupt_flag()
      if (!is.null(flag)) signal_interrupt(flag)

      poller <- reindex_poller()
      if (!is.null(poller)) poller$destroy()
      reindex_poller(NULL)

      showModal(modalDialog(
        title = "Stopping Re-index",
        tags$p("Cancelling... please wait for current item to finish."),
        footer = NULL,
        easyClose = FALSE
      ))
    })

    # Phase 22: Handle re-index task result
    observe({
      result <- reindex_task$result()

      poller <- reindex_poller()
      if (!is.null(poller)) poller$destroy()
      reindex_poller(NULL)

      clear_interrupt_flag(current_interrupt_flag())
      clear_progress_file(current_progress_file())
      current_interrupt_flag(NULL)
      current_progress_file(NULL)

      removeModal()

      if (isTRUE(result$partial)) {
        # Cancelled — delete partial store
        tryCatch(delete_notebook_store(notebook_id()), error = function(e) NULL)
        rag_ready(FALSE)
        store_healthy(FALSE)
        showNotification("Re-indexing cancelled. Partial index removed.", type = "warning", duration = 5)
      } else if (isTRUE(result$success)) {
        rag_ready(TRUE)
        store_healthy(TRUE)
        tryCatch({
          abstract_ids <- DBI::dbGetQuery(con(), "SELECT id FROM abstracts WHERE notebook_id = ?", list(notebook_id()))$id
          mark_as_ragnar_indexed(con(), abstract_ids, source_type = "abstract")
        }, error = function(e) message("[ragnar] Sentinel update failed: ", e$message))
        showNotification(paste("Re-indexed", result$count, "items successfully."), type = "message", duration = 5)
      } else {
        rag_ready(FALSE)
        store_healthy(FALSE)
        showNotification(paste("Re-indexing failed:", result$error), type = "error", duration = NULL)
      }
    })

    # Phase 22: Render send button (disabled when rag_available is FALSE)
    output$send_btn_ui <- renderUI({
      if (isTRUE(rag_available())) {
        actionButton(ns("send"), NULL, class = "btn-primary", icon = icon_paper_plane())
      } else {
        tags$button(
          class = "btn btn-primary disabled",
          disabled = "disabled",
          title = "Chat unavailable \u2014 re-index this notebook first",
          icon_paper_plane()
        )
      }
    })

    # Phase 26: Render overview button (disabled when rag_available is FALSE)
    output$overview_btn_ui <- renderUI({
      if (isTRUE(rag_available())) {
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
        )
      } else {
        tags$button(
          class = "btn btn-sm btn-outline-primary disabled",
          disabled = "disabled",
          title = "Synthesis unavailable \u2014 re-index this notebook first",
          icon_layer_group(), " Overview"
        )
      }
    })

    # Phase 22: Render conclusions button (disabled when rag_available is FALSE)
    output$conclusions_btn_ui <- renderUI({
      if (isTRUE(rag_available())) {
        actionButton(ns("btn_conclusions"), "Conclusions",
                     class = "btn-sm btn-outline-primary",
                     icon = icon_microscope())
      } else {
        tags$button(
          class = "btn btn-sm btn-outline-primary disabled",
          disabled = "disabled",
          title = "Synthesis unavailable \u2014 re-index this notebook first",
          icon_microscope(), " Conclusions"
        )
      }
    })

    # Phase 27: Render research questions button (disabled when rag_available is FALSE)
    output$research_questions_btn_ui <- renderUI({
      if (isTRUE(rag_available())) {
        actionButton(ns("btn_research_questions"), "Research Questions",
                     class = "btn-sm btn-outline-primary",
                     icon = icon_lightbulb())
      } else {
        tags$button(
          class = "btn btn-sm btn-outline-primary disabled",
          disabled = "disabled",
          title = "Synthesis unavailable \u2014 re-index this notebook first",
          icon_lightbulb(), " Research Questions"
        )
      }
    })

    # Phase 53: Remaining count reactive for keyword filter
    remaining_count <- reactive({
      total <- pagination_state$api_total
      fetched <- pagination_state$total_fetched
      if (is.null(total) || total == 0) return(NULL)
      remaining <- total - fetched
      if (remaining <= 0) return(NULL)
      remaining
    })

    # Keyword filter module - returns filtered papers reactive
    keyword_filtered_papers <- mod_keyword_filter_server("keyword_filter", papers_data, remaining_count)

    # Journal filter module - returns filtered papers reactive + block_journal function
    journal_filter_result <- mod_journal_filter_server("journal_filter", keyword_filtered_papers, con)
    journal_filtered_papers <- journal_filter_result$filtered_papers

    # Helper: Get OA status badge info (Phase 2)
    get_oa_badge <- function(oa_status) {
      if (is.null(oa_status) || is.na(oa_status) || oa_status == "") {
        return(NULL)  # Don't show badge if unknown
      }
      switch(oa_status,
        "diamond" = list(class = "bg-info", icon = "gem", tooltip = "Diamond OA: Free to read & publish"),
        "gold" = list(class = "bg-warning text-body", icon = "unlock", tooltip = "Gold OA: Open access journal"),
        "green" = list(class = "bg-success", icon = "leaf", tooltip = "Green OA: Repository copy"),
        "hybrid" = list(class = "bg-primary", icon = "code-branch", tooltip = "Hybrid OA: Open in toll-access journal"),
        "bronze" = list(class = "bg-secondary", icon = "lock-open", tooltip = "Bronze OA: Free but no license"),
        "closed" = list(class = "bg-dark", icon = "lock", tooltip = "Closed access"),
        NULL
      )
    }

    # Helper: Format citation metrics row (Phase 2)
    format_citation_metrics <- function(cited_by, fwci, refs) {
      metrics <- list()

      # Cited by (always show)
      metrics <- c(metrics, list(
        span(
          class = "text-muted",
          style = "cursor: help;",
          title = "Cited by count",
          icon_arrow_down(class = "small me-1"),
          format(cited_by %||% 0, big.mark = ",")
        )
      ))

      # FWCI (only if available)
      if (!is.null(fwci) && !is.na(fwci)) {
        fwci_class <- if (fwci >= 1.0) "text-success" else "text-muted"
        metrics <- c(metrics, list(
          span(
            class = fwci_class,
            style = "cursor: help;",
            title = "Field-weighted citation impact (>1.0 = above average)",
            icon_scale_balanced(class = "small me-1"),
            sprintf("%.1f", fwci)
          )
        ))
      }

      # Referenced works (always show)
      metrics <- c(metrics, list(
        span(
          class = "text-muted",
          style = "cursor: help;",
          title = "References (outgoing citations)",
          icon_arrow_up(class = "small me-1"),
          format(refs %||% 0, big.mark = ",")
        )
      ))

      div(
        class = "small d-flex gap-2",
        metrics
      )
    }

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
      filters <- if (!is.null(nb$search_filters) && !is.na(nb$search_filters) && nchar(nb$search_filters) > 0) {
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
      filters <- if (!is.null(nb$search_filters) && !is.na(nb$search_filters) && nchar(nb$search_filters) > 0) {
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
      sort_by <- input$sort_by %||% "year"
      # Always fetch with default DB sort (Phase 51)
      papers <- list_abstracts(con(), nb_id, sort_by = "year")

      # Client-side re-sort if user selected different sort (Phase 51)
      # Sort dropdown is display-only, does not affect API cursor
      if (nrow(papers) > 0 && sort_by != "year") {
        papers <- switch(sort_by,
          cited_by_count = papers[order(papers$cited_by_count, decreasing = TRUE, na.last = TRUE), ],
          fwci = papers[order(papers$fwci, decreasing = TRUE, na.last = TRUE), ],
          referenced_works_count = papers[order(papers$referenced_works_count, decreasing = TRUE, na.last = TRUE), ],
          papers
        )
        rownames(papers) <- NULL
      }

      # BUGF-01 Part B: Pin seed paper to row 1 for seed-discovery notebooks
      if (nrow(papers) > 1) {
        nb <- tryCatch(get_notebook(con(), nb_id), error = function(e) NULL)
        if (!is.null(nb) && !is.null(nb$search_filters) && !is.na(nb$search_filters) && nchar(nb$search_filters) > 0) {
          filters <- tryCatch(jsonlite::fromJSON(nb$search_filters), error = function(e) list())
          seed_id <- filters$seed_paper_id
          if (!is.null(seed_id) && !is.na(seed_id) && nchar(seed_id) > 0) {
            seed_idx <- which(papers$paper_id == seed_id)
            if (length(seed_idx) == 1 && seed_idx != 1) {
              papers <- rbind(papers[seed_idx, ], papers[-seed_idx, ])
            }
          }
        }
      }

      papers
    })

    # Phase 55: Initialize type chip states from saved filters or defaults (runs once)
    observe({
      if (isTRUE(type_states_initialized())) return()

      nb_id <- notebook_id()
      req(nb_id)

      nb <- tryCatch(get_notebook(con(), nb_id), error = function(e) NULL)
      if (is.null(nb)) return()

      filters <- if (!is.null(nb$search_filters) && !is.na(nb$search_filters) && nchar(nb$search_filters) > 0) {
        tryCatch(jsonlite::fromJSON(nb$search_filters), error = function(e) list())
      } else {
        list()
      }

      saved_types <- filters$work_types
      all_slugs <- sapply(OPENALEX_WORK_TYPES, function(t) t$slug)

      for (slug in all_slugs) {
        if (!is.null(saved_types)) {
          type_states[[slug]] <- slug %in% saved_types
        } else {
          type_states[[slug]] <- slug %in% DEFAULT_ON_TYPES
        }
      }

      type_states_initialized(TRUE)
    })

    # Dynamic slider bounds - updates when papers change
    observe({
      papers <- papers_data()
      nb_id <- notebook_id()
      req(nb_id)

      bounds <- get_year_bounds(con(), nb_id)
      updateSliderInput(
        session,
        "year_range",
        min = bounds$min_year,
        max = bounds$max_year,
        value = c(bounds$min_year, bounds$max_year)
      )
    })

    # Debounced year range reactive
    year_range_raw <- reactive({ input$year_range })
    year_range <- debounce(year_range_raw, 400)

    # Year histogram
    output$year_histogram <- renderPlot({
      nb_id <- notebook_id()
      req(nb_id)
      paper_refresh()  # React to paper changes

      year_counts <- get_year_distribution(con(), nb_id)

      if (nrow(year_counts) == 0) {
        # Empty plot
        ggplot2::ggplot() + ggplot2::theme_void()
      } else {
        # Minimal histogram
        ggplot2::ggplot(year_counts, ggplot2::aes(x = year, y = count)) +
          ggplot2::geom_col(fill = LATTE$lavender, width = 0.8, alpha = 0.7) +
          ggplot2::theme_void() +
          ggplot2::theme(
            plot.background = ggplot2::element_blank(),
            panel.background = ggplot2::element_blank(),
            plot.margin = ggplot2::margin(0, 0, 0, 0)
          )
      }
    }, bg = "transparent")

    # Unknown year count display
    output$unknown_year_count <- renderText({
      nb_id <- notebook_id()
      req(nb_id)
      paper_refresh()  # React to paper changes

      count <- get_unknown_year_count(con(), nb_id)
      if (count > 0) {
        paste0("(", count, " unknown)")
      } else {
        ""
      }
    })

    # Filtered papers - chain keyword filter -> journal filter -> has_abstract filter -> year filter
    filtered_papers <- reactive({
      papers <- journal_filtered_papers()
      if (nrow(papers) == 0) return(papers)

      # Has abstract filter
      if (isTRUE(input$filter_has_abstract)) {
        papers <- papers[!is.na(papers$abstract) & nchar(papers$abstract) > 0, ]
      }

      # Year range filter
      range <- year_range()
      if (!is.null(range) && length(range) == 2) {
        include_null <- input$include_unknown_year
        if (isTRUE(include_null)) {
          # Keep rows where year is NULL OR in range
          papers <- papers[is.na(papers$year) | (papers$year >= range[1] & papers$year <= range[2]), ]
        } else {
          # Keep only rows with non-NULL year in range
          papers <- papers[!is.na(papers$year) & papers$year >= range[1] & papers$year <= range[2], ]
        }
      }

      papers
    })

    # Download handlers for citation export
    output$download_bibtex <- downloadHandler(
      filename = function() {
        paste0("citations-", Sys.Date(), ".bib")
      },
      content = function(file) {
        papers <- filtered_papers()
        if (nrow(papers) == 0) {
          writeLines("% No papers to export", file)
          return()
        }
        bibtex_content <- generate_bibtex_batch(papers)
        # Write with UTF-8 encoding, add BOM for compatibility
        con_file <- file(file, "wb")
        writeBin(charToRaw("\xEF\xBB\xBF"), con_file)  # UTF-8 BOM
        writeLines(bibtex_content, con_file, useBytes = TRUE)
        close(con_file)
      }
    )

    output$download_csv <- downloadHandler(
      filename = function() {
        paste0("citations-", Sys.Date(), ".csv")
      },
      content = function(file) {
        papers <- filtered_papers()
        if (nrow(papers) == 0) {
          write.csv(data.frame(note = "No papers to export"), file, row.names = FALSE)
          return()
        }
        export_df <- format_csv_export(papers)
        write.csv(export_df, file, fileEncoding = "UTF-8", row.names = FALSE)
      }
    )

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

    # Set of paper IDs that have been embedded (for per-paper brain icon)
    embedded_paper_ids <- reactive({
      paper_refresh()  # Dependency to update when papers change
      nb_id <- notebook_id()
      req(nb_id)

      result <- dbGetQuery(con(), "
        SELECT DISTINCT c.source_id
        FROM chunks c
        WHERE c.source_type = 'abstract'
          AND c.embedding IS NOT NULL
          AND c.source_id IN (SELECT id FROM abstracts WHERE notebook_id = ?)
      ", list(nb_id))

      result$source_id
    })

    # Check if papers need embedding (based on filtered view)
    papers_need_embedding <- reactive({
      papers <- filtered_papers()  # Use filtered set, not all papers
      if (nrow(papers) == 0) return(0)

      # Get IDs of papers with abstracts in the filtered set
      papers_with_abstract <- papers[!is.na(papers$abstract) & nchar(papers$abstract) > 0, ]
      if (nrow(papers_with_abstract) == 0) return(0)

      embedded <- embedded_paper_ids()
      sum(!papers_with_abstract$id %in% embedded)
    })


    # Embed button
    output$embed_button <- renderUI({
      papers <- papers_data()
      need_embed <- papers_need_embedding()

      if (nrow(papers) == 0) {
        return(
          tags$button(
            class = "btn btn-secondary w-100",
            disabled = "disabled",
            "No Papers to Embed"
          )
        )
      }

      if (need_embed == 0) {
        return(
          tags$button(
            class = "btn btn-outline-success w-100",
            disabled = "disabled",
            HTML("&#10003; All Papers Embedded")
          )
        )
      }

      actionButton(
        ns("embed_papers"),
        HTML(paste0("&#129504; Embed ", need_embed, " Papers")),
        class = "btn-primary w-100"
      )
    })

    # Exclusion info
    output$exclusion_info <- renderUI({
      paper_refresh()  # Dependency to update when papers change
      nb <- tryCatch({
        get_notebook(con(), notebook_id())
      }, error = function(e) NULL)

      if (is.null(nb)) return(NULL)

      excluded <- tryCatch({
        if (!is.na(nb$excluded_paper_ids) && nchar(nb$excluded_paper_ids) > 0) {
          jsonlite::fromJSON(nb$excluded_paper_ids)
        } else {
          character()
        }
      }, error = function(e) character())

      if (length(excluded) == 0) return(NULL)

      div(
        class = "text-muted small text-center",
        paste(length(excluded), "papers excluded"),
        actionLink(ns("clear_exclusions"), "(clear)", class = "ms-1")
      )
    })

    # Clear exclusions - show confirmation
    observeEvent(input$clear_exclusions, {
      showModal(modalDialog(
        title = "Clear Exclusions",
        "Clear all exclusions? Excluded papers may reappear on next refresh.",
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("confirm_clear_exclusions"), "Clear", class = "btn-warning")
        )
      ))
    })

    # Handle clear exclusions confirmation
    observeEvent(input$confirm_clear_exclusions, {
      removeModal()
      update_notebook(con(), notebook_id(), excluded_paper_ids = character())
      paper_refresh(paper_refresh() + 1)
      showNotification("Exclusions cleared", type = "message")
    })



    # Handle individual paper delete (no confirmation needed)
    observe({
      papers <- filtered_papers()
      if (nrow(papers) == 0) return()

      lapply(seq_len(nrow(papers)), function(i) {
        paper <- papers[i, ]
        paper_id <- as.character(paper$id)

        # Only create observer if one doesn't exist for this paper ID
        if (is.null(delete_observers[[paper_id]])) {
          delete_id <- paste0("delete_paper_", paper$id)

          delete_observers[[paper_id]] <- observeEvent(input[[delete_id]], {
            # Add to exclusion list
            nb <- get_notebook(con(), notebook_id())
            existing_excluded <- tryCatch({
              if (!is.null(nb$excluded_paper_ids) && !is.na(nb$excluded_paper_ids) && nchar(nb$excluded_paper_ids) > 0) {
                jsonlite::fromJSON(nb$excluded_paper_ids)
              } else {
                character()
              }
            }, error = function(e) character())

            new_excluded <- unique(c(existing_excluded, paper$paper_id))
            update_notebook(con(), notebook_id(), excluded_paper_ids = new_excluded)

            # Delete from database
            delete_abstract(con(), paper$id)

            # Phase 22: Delete chunks from per-notebook ragnar store
            tryCatch({
              delete_abstract_chunks_from_ragnar(notebook_id(), paper$id)
            }, error = function(e) {
              message("[ragnar] Failed to delete chunks for removed paper: ", e$message)
            })

            # Trigger refresh
            paper_refresh(paper_refresh() + 1)

            showNotification("Paper removed", type = "message", duration = 2)

            # Clean up this observer after it fires
            delete_observers[[paper_id]] <- NULL
          }, ignoreInit = TRUE, once = TRUE)
        }
      })
    })

    # Paper list
    output$paper_list <- renderUI({
      papers <- filtered_papers()
      current_viewed <- viewed_paper()

      if (nrow(papers) == 0) {
        return(
          div(
            class = "text-center text-muted py-4",
            icon_search(class = "fa-3x mb-2"),
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

        # Check quality flags
        is_flagged <- isTRUE(paper$is_flagged)
        flag_tooltip <- if (!is.na(paper$quality_flag_text) && nchar(paper$quality_flag_text) > 0) {
          paper$quality_flag_text
        } else {
          ""
        }

        # Get type badge info
        type_badge <- get_type_badge(paper$work_type)

        # Get OA badge info (Phase 2)
        oa_badge <- get_oa_badge(paper$oa_status)

        div(
          class = paste("border-bottom py-2 position-relative", if (is_viewed) "bg-body-tertiary"),
          # Delete button (top-right)
          actionLink(
            ns(paste0("delete_paper_", paper$id)),
            icon_close(),
            class = "position-absolute text-muted",
            style = "top: 4px; right: 4px; cursor: pointer; opacity: 0.5;",
            title = "Remove paper"
          ),
          div(
            class = "d-flex align-items-start gap-2 pe-4",
            # Phase 38: Raw checkbox with JS click handler for select-all integration
            tags$div(
              style = "width: 25px; flex-shrink: 0;",
              tags$input(
                type = "checkbox",
                id = ns(checkbox_id),
                class = "form-check-input",
                checked = if (paper$id %in% selected_papers()) "checked" else NULL,
                onclick = sprintf(
                  "Shiny.setInputValue('%s', {id: '%s', checked: this.checked, nonce: Math.random()}, {priority: 'event'})",
                  ns("paper_checkbox_click"), paper$id
                )
              )
            ),
            # Warning icon for flagged papers
            if (is_flagged) {
              span(
                class = "text-warning",
                style = "cursor: help;",
                title = flag_tooltip,
                icon_warning()
              )
            },
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
                div(
                  class = "d-flex align-items-center gap-2 small flex-wrap",
                  span(class = "text-muted", paste(author_str, "-", paper$year %||% "N/A")),
                  # Type badge
                  span(
                    class = paste("badge", type_badge$class),
                    style = type_badge$style %||% "",
                    type_badge$label
                  ),
                  # OA badge (Phase 2)
                  if (!is.null(oa_badge)) {
                    span(
                      class = paste("badge", oa_badge$class),
                      style = "cursor: help;",
                      title = oa_badge$tooltip,
                      icon(oa_badge$icon, class = "small")
                    )
                  }
                ),
                if (!is.na(paper$venue) && nchar(paper$venue) > 0) {
                  div(class = "text-muted small fst-italic text-truncate", paper$venue)
                },
                # Citation metrics (Phase 2)
                format_citation_metrics(paper$cited_by_count, paper$fwci, paper$referenced_works_count)
              )
            ),
            # PDF download link (if available)
            if (has_pdf) {
              tags$a(
                href = paper$pdf_url,
                target = "_blank",
                class = "btn btn-sm btn-outline-danger py-0 px-1 ms-1",
                title = "View PDF",
                icon_file_pdf()
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

    # Phase 38: Compute effective selection from select-all state
    effective_selected <- reactive({
      state <- select_all_state()
      all_ids <- filtered_papers()$id
      if (state$all_selected) {
        setdiff(all_ids, state$exceptions)
      } else {
        intersect(state$exceptions, all_ids)
      }
    })

    # Phase 38: Sync effective selection into selected_papers reactiveVal
    observe({
      selected_papers(effective_selected())
    })

    # Phase 38: Handle select-all checkbox click
    observeEvent(input$select_all_click, {
      if (isTRUE(input$select_all_click)) {
        # Select all: set flag, clear exceptions
        select_all_state(list(all_selected = TRUE, exceptions = character()))
      } else {
        # Deselect all: clear flag, clear exceptions
        select_all_state(list(all_selected = FALSE, exceptions = character()))
      }
    }, ignoreInit = TRUE)

    # Phase 38: Handle individual paper checkbox click
    observeEvent(input$paper_checkbox_click, {
      click <- input$paper_checkbox_click
      req(click$id)
      state <- select_all_state()

      if (state$all_selected) {
        # In select-all mode: toggle exception
        if (isTRUE(click$checked)) {
          # Re-checking a deselected paper: remove from exceptions
          state$exceptions <- setdiff(state$exceptions, click$id)
        } else {
          # Unchecking a paper: add to exceptions
          state$exceptions <- union(state$exceptions, click$id)
        }
      } else {
        # In individual mode: toggle in exceptions set
        if (isTRUE(click$checked)) {
          state$exceptions <- union(state$exceptions, click$id)
        } else {
          state$exceptions <- setdiff(state$exceptions, click$id)
        }
      }
      select_all_state(state)
    }, ignoreInit = TRUE)

    # Phase 38: Update select-all checkbox visual state
    observe({
      state <- select_all_state()
      all_ids <- filtered_papers()$id
      n_selected <- length(effective_selected())
      n_total <- length(all_ids)

      if (n_total == 0) {
        session$sendCustomMessage("setCheckboxState", list(
          id = ns("select_all_cb"), checked = FALSE, indeterminate = FALSE
        ))
      } else if (n_selected == n_total) {
        session$sendCustomMessage("setCheckboxState", list(
          id = ns("select_all_cb"), checked = TRUE, indeterminate = FALSE
        ))
      } else if (n_selected > 0) {
        session$sendCustomMessage("setCheckboxState", list(
          id = ns("select_all_cb"), checked = FALSE, indeterminate = TRUE
        ))
      } else {
        session$sendCustomMessage("setCheckboxState", list(
          id = ns("select_all_cb"), checked = FALSE, indeterminate = FALSE
        ))
      }
    })

    # Phase 38: Reset select-all when filters change
    observeEvent(filtered_papers(), {
      select_all_state(list(all_selected = FALSE, exceptions = character()))
      session$sendCustomMessage("setCheckboxState", list(
        id = ns("select_all_cb"), checked = FALSE, indeterminate = FALSE
      ))
    }, ignoreInit = TRUE)

    # Phase 38: Dynamic import button with selection count
    output$import_button_ui <- renderUI({
      n <- length(selected_papers())
      label <- if (n > 0) paste0("Import Selected (", n, ")") else "Import Selected"
      actionButton(ns("import_selected"), label,
                   class = "btn-primary w-100",
                   icon = icon_download())
    })

    # Abstract detail view
    output$abstract_detail <- renderUI({
      paper_id <- viewed_paper()

      if (is.null(paper_id)) {
        return(
          div(
            class = "text-center text-muted py-5",
            icon_paper(class = "fa-3x mb-3"),
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

      # Get type badge info
      type_badge <- get_type_badge(paper$work_type)

      # Get OA badge info (Phase 2)
      oa_badge <- get_oa_badge(paper$oa_status)

      tagList(
        # Title
        h5(class = "mb-3", paper$title),

        # Metadata
        div(
          class = "mb-3",
          div(
            class = "d-flex flex-wrap gap-2 mb-2 align-items-center",
            if (!is.null(paper$year) && !is.na(paper$year)) {
              span(class = "badge bg-secondary", paper$year)
            },
            # Type badge
            span(
              class = paste("badge", type_badge$class),
              style = type_badge$style %||% "",
              type_badge$label
            ),
            # OA badge (Phase 2)
            if (!is.null(oa_badge)) {
              span(
                class = paste("badge", oa_badge$class),
                style = "cursor: help;",
                title = oa_badge$tooltip,
                icon(oa_badge$icon, class = "small me-1"),
                oa_badge$tooltip
              )
            },
            if (!is.na(paper$venue) && nchar(paper$venue) > 0) {
              span(class = "badge bg-body-tertiary text-body border", paper$venue)
            }
            ,
            if (!is.na(paper$venue) && nchar(paper$venue) > 0) {
              actionLink(
                ns(paste0("block_journal_", paper$id)),
                span(class = "badge bg-danger", icon_ban(), " Block"),
                title = paste("Block all papers from", paper$venue),
                style = "text-decoration: none; line-height: 1;"
              )
            }
          ),
          div(class = "text-muted", author_str),
          # Citation metrics (Phase 2)
          format_citation_metrics(paper$cited_by_count, paper$fwci, paper$referenced_works_count),
          # DOI or citation key fallback
          if (!is.null(paper$doi) && !is.na(paper$doi) && nchar(paper$doi) > 0) {
            div(
              class = "mt-2",
              tags$small(class = "text-muted", "DOI: "),
              tags$a(
                href = paste0("https://doi.org/", paper$doi),
                target = "_blank",
                rel = "noopener noreferrer",
                class = "text-primary",
                paper$doi
              )
            )
          } else {
            citation_key <- generate_citation_key(paper$title, paper$year)
            div(
              class = "mt-2",
              tags$small(class = "text-muted", "Citation Key: "),
              tags$code(citation_key),
              tags$small(class = "text-muted ms-2", "(DOI unavailable)")
            )
          }
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
            icon_circle_info(class = "me-2"),
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
              icon_file_pdf(class = "me-1"),
              "View PDF ",
              icon_external_link(class = "ms-1 small")
            )
          )
        }
      )
    })

    # Detail actions (close button and optional "Use as Seed" button)
    output$detail_actions <- renderUI({
      if (is.null(viewed_paper())) return(NULL)

      # Look up the paper to check for DOI (same pattern as abstract_detail)
      papers <- papers_data()
      paper <- papers[papers$id == viewed_paper(), ]

      seed_btn <- NULL
      if (nrow(paper) > 0 && !is.na(paper$doi) && nchar(paper$doi) > 0) {
        seed_btn <- actionButton(
          ns("use_as_seed"),
          "Use as Seed",
          icon = icon_seedling(),
          class = "btn-sm btn-outline-success me-1"
        )
      }

      close_btn <- actionButton(
        ns("close_detail"),
        icon_close(),
        class = "btn-sm btn-outline-secondary"
      )

      div(class = "d-flex gap-1", seed_btn, close_btn)
    })

    observeEvent(input$close_detail, {
      viewed_paper(NULL)
    })

    # "Use as Seed" button handler
    observeEvent(input$use_as_seed, {
      # Get the current viewed paper
      paper_id <- viewed_paper()
      if (is.null(paper_id)) return()

      # Look up the paper to get its DOI
      papers <- papers_data()
      paper <- papers[papers$id == paper_id, ]

      if (nrow(paper) > 0 && !is.na(paper$doi) && nchar(paper$doi) > 0) {
        # Set seed_request with DOI and timestamp
        # Timestamp ensures each click produces a unique value
        seed_request(list(doi = paper$doi, ts = Sys.time()))
      }
    }, ignoreInit = TRUE)

    # Block journal observers
    observe({
      papers <- filtered_papers()
      if (nrow(papers) == 0) return()
      lapply(papers$id, function(paper_id) {
        paper_id_str <- as.character(paper_id)

        # Only create observer if one doesn't exist for this paper ID
        if (is.null(block_journal_observers[[paper_id_str]])) {
          block_journal_observers[[paper_id_str]] <- observeEvent(input[[paste0("block_journal_", paper_id)]], {
            paper <- papers[papers$id == paper_id, ]
            if (nrow(paper) > 0 && !is.na(paper$venue) && nchar(paper$venue) > 0) {
              journal_filter_result$block_journal(paper$venue)
              showNotification(
                paste("Blocked:", paper$venue),
                type = "message", duration = 3
              )
            }
            # Clean up this observer after it fires
            block_journal_observers[[paper_id_str]] <- NULL
          }, ignoreInit = TRUE)
        }
      })
    })

    # Manage blocklist modal
    observeEvent(input$manage_blocklist, {
      blocked <- list_blocked_journals(con())

      if (nrow(blocked) == 0) {
        body_content <- div(
          class = "text-center text-muted py-4",
          icon_check_circle(class = "fa-2x mb-2"),
          p("No journals blocked yet."),
          p(class = "small", "You can block journals from the paper detail view.")
        )
      } else {
        body_content <- div(
          style = "max-height: 400px; overflow-y: auto;",
          lapply(seq_len(nrow(blocked)), function(i) {
            j <- blocked[i, ]
            div(
              class = "d-flex justify-content-between align-items-center border-bottom py-2",
              div(
                span(class = "fw-semibold", j$journal_name),
                div(class = "text-muted small", paste("Blocked:", format(as.POSIXct(j$added_at), "%Y-%m-%d")))
              ),
              actionButton(
                ns(paste0("unblock_", j$id)),
                icon_delete(),
                class = "btn-sm btn-outline-danger",
                title = "Remove from blocklist"
              )
            )
          })
        )
      }

      showModal(modalDialog(
        title = span(icon_shield(), " Blocked Journals"),
        body_content,
        size = "m",
        easyClose = TRUE,
        footer = modalButton("Close")
      ))
    })

    # Unblock journal observers
    observe({
      blocked <- tryCatch(list_blocked_journals(con()), error = function(e) data.frame())
      if (nrow(blocked) == 0) return()

      lapply(blocked$id, function(block_id) {
        block_id_str <- as.character(block_id)

        # Only create observer if one doesn't exist for this block ID
        if (is.null(unblock_journal_observers[[block_id_str]])) {
          unblock_journal_observers[[block_id_str]] <- observeEvent(input[[paste0("unblock_", block_id)]], {
            remove_blocked_journal(con(), block_id)
            showNotification("Journal unblocked", type = "message", duration = 3)
            removeModal()
            # Trigger blocklist refresh in the journal filter module
            journal_filter_result$block_journal("")  # Empty string signals refresh without adding
            # Clean up this observer after it fires
            unblock_journal_observers[[block_id_str]] <- NULL
          }, ignoreInit = TRUE)
        }
      })
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
        icon_comments(),
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
      filters <- if (!is.null(nb$search_filters) && !is.na(nb$search_filters) && nchar(nb$search_filters) > 0) {
        tryCatch(jsonlite::fromJSON(nb$search_filters), error = function(e) list())
      } else {
        list()
      }

      showModal(modalDialog(
        title = tagList(icon_edit(), " Edit Search"),
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

        hr(),

        # Document type filters (Phase 55 - chip toggles)
        div(
          class = "mb-3",
          h6(class = "text-muted", icon_paper(), " Document Types"),
          # Distribution panel ABOVE chips
          uiOutput(ns("type_distribution")),
          # Select All / Deselect All links
          div(
            class = "d-flex justify-content-end gap-2 mb-2",
            actionLink(ns("select_all_types"), "Select All", class = "small text-muted"),
            span(class = "text-muted", "|"),
            actionLink(ns("deselect_all_types"), "Deselect All", class = "small text-muted")
          ),
          # Chip toggle grid
          uiOutput(ns("type_chips"))
        ),

        hr(),

        # Quality filters section
        div(
          class = "mb-3",
          h6(class = "text-muted", icon_shield(), " Quality Filters"),

          checkboxInput(ns("edit_exclude_retracted"), "Exclude retracted papers",
                        value = if (!is.null(filters$exclude_retracted)) filters$exclude_retracted else TRUE),

          numericInput(ns("edit_min_citations"), "Minimum citations (optional)",
                       value = filters$min_citations,
                       min = 0, max = 10000, step = 1),

          # Cache status
          uiOutput(ns("quality_cache_status"))
        ),

        # Query preview (collapsible)
        tags$details(
          class = "mt-3",
          tags$summary(class = "text-muted small cursor-pointer", "Show API Query"),
          div(
            class = "mt-2 p-2 bg-body-secondary rounded small font-monospace",
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

    # Phase 55: Collect selected work types from chip toggle states
    get_selected_work_types <- reactive({
      all_slugs <- sapply(OPENALEX_WORK_TYPES, function(t) t$slug)
      selected <- all_slugs[sapply(all_slugs, function(s) isTRUE(type_states[[s]]))]
      # If all types selected or none selected, return NULL (no filter)
      if (length(selected) == length(all_slugs) || length(selected) == 0) return(NULL)
      selected
    })

    # Query preview (reactive)
    output$query_preview <- renderUI({
      query <- input$edit_query %||% ""
      from_year <- input$edit_from_year
      to_year <- input$edit_to_year
      search_field <- input$edit_search_field %||% "default"
      is_oa <- input$edit_is_oa %||% FALSE
      min_citations <- input$edit_min_citations
      exclude_retracted <- input$edit_exclude_retracted %||% TRUE
      work_types <- get_selected_work_types()

      preview <- build_query_preview(
        query,
        from_year,
        to_year,
        search_field,
        is_oa,
        min_citations = min_citations,
        has_abstract = input$filter_has_abstract %||% TRUE,
        exclude_retracted = exclude_retracted,
        work_types = work_types
      )

      tagList(
        if (!is.null(preview$search)) {
          div(tags$strong("search="), preview$search)
        },
        div(tags$strong("filter="), preview$filter)
      )
    })

    # Phase 55: Type distribution panel (shows ALL 16 types with pre-filter counts)
    output$type_distribution <- renderUI({
      papers <- papers_data()
      if (nrow(papers) == 0) return(NULL)

      # Count work types (handle missing column gracefully)
      if (!"work_type" %in% names(papers)) {
        return(
          tags$details(
            open = "open",
            class = "mb-2",
            tags$summary(class = "text-muted small", style = "cursor: pointer;",
                         icon_chart_bar(), " Type Distribution (All Loaded Papers)"),
            div(class = "mt-2 p-2 bg-body-secondary rounded small text-muted",
                "Type data not available. Re-run search to fetch type information.")
          )
        )
      }

      # Count all 16 types (including zeros)
      type_counts <- table(papers$work_type, useNA = "ifany")
      all_slugs <- sapply(OPENALEX_WORK_TYPES, function(t) t$slug)
      counts_list <- lapply(all_slugs, function(slug) {
        list(
          slug = slug,
          count = if (slug %in% names(type_counts)) type_counts[[slug]] else 0L,
          badge = get_type_badge(slug)
        )
      })

      # Sort by count descending
      counts_list <- counts_list[order(sapply(counts_list, function(x) x$count), decreasing = TRUE)]

      max_count <- max(sapply(counts_list, function(x) x$count))
      if (max_count == 0) return(NULL)

      tags$details(
        open = "open",
        class = "mb-2",
        tags$summary(class = "text-muted small", style = "cursor: pointer;",
                     icon_chart_bar(), " Type Distribution (All Loaded Papers)"),
        div(
          class = "mt-2 p-2 bg-body-secondary rounded",
          lapply(counts_list, function(type_info) {
            count <- type_info$count
            pct <- if (max_count > 0) (count / max_count) * 100 else 0
            badge <- type_info$badge

            div(
              class = "d-flex align-items-center gap-2 mb-1",
              span(
                class = paste("badge small", badge$class),
                style = "width: 120px; font-size: 0.75em;",
                badge$label
              ),
              div(
                class = "flex-grow-1",
                div(
                  class = paste("rounded", badge$class),
                  style = paste0("width: ", pct, "%; height: 8px;")
                )
              ),
              span(class = "text-muted small", style = "width: 40px; text-align: right;",
                   if (count >= 1000) format_large_number(count) else count)
            )
          })
        )
      )
    })

    # Phase 55: Render chip toggles with dynamic observers
    type_chip_observers <- list()

    output$type_chips <- renderUI({
      papers <- papers_data()

      # Destroy previous observers
      for (obs in type_chip_observers) {
        obs$destroy()
      }
      type_chip_observers <<- list()

      # Count types in current papers
      type_counts <- if (nrow(papers) > 0 && "work_type" %in% names(papers)) {
        table(papers$work_type, useNA = "ifany")
      } else {
        NULL
      }

      # Render chips for all 16 types
      chips <- lapply(seq_along(OPENALEX_WORK_TYPES), function(i) {
        type_info <- OPENALEX_WORK_TYPES[[i]]
        slug <- type_info$slug
        label <- type_info$label
        badge_class <- type_info$class

        # Get state and count
        is_on <- isTRUE(type_states[[slug]])
        count <- if (!is.null(type_counts) && slug %in% names(type_counts)) {
          type_counts[[slug]]
        } else {
          0L
        }

        # Chip class: ON = type color, OFF = gray
        chip_class <- if (is_on) badge_class else "bg-secondary text-white"

        # Create chip button with observer
        chip_id <- paste0("type_chip_", i)

        type_chip_observers[[i]] <<- observeEvent(input[[chip_id]], {
          type_states[[slug]] <- !isTRUE(type_states[[slug]])
        }, ignoreInit = TRUE)

        actionLink(
          ns(chip_id),
          paste0(label, " (", count, ")"),
          class = paste("badge", chip_class),
          style = "cursor: pointer; font-size: 0.85em; padding: 0.35em 0.65em; text-decoration: none;"
        )
      })

      div(
        class = "d-flex flex-wrap gap-2",
        chips
      )
    })

    # Phase 55: Select All / Deselect All observers
    observeEvent(input$select_all_types, {
      for (t in OPENALEX_WORK_TYPES) {
        type_states[[t$slug]] <- TRUE
      }
    })

    observeEvent(input$deselect_all_types, {
      for (t in OPENALEX_WORK_TYPES) {
        type_states[[t$slug]] <- FALSE
      }
    })

    # Quality cache status
    output$quality_cache_status <- renderUI({
      # Check cache status
      status <- tryCatch({
        check_quality_cache_status(con())
      }, error = function(e) {
        list(is_empty = TRUE, is_stale = TRUE, last_updated = NULL)
      })

      status_text <- format_cache_status(status)

      div(
        class = "mt-2 small",
        div(
          class = if (status$is_empty || status$is_stale) "text-warning" else "text-muted",
          icon(if (status$is_empty || status$is_stale) "triangle-exclamation" else "circle-check"),
          " ", status_text
        ),
        actionLink(ns("refresh_quality_cache"), "Refresh quality data", class = "small")
      )
    })

    # Handle quality cache refresh
    observeEvent(input$refresh_quality_cache, {
      showNotification("Refreshing quality data...", type = "message", id = "quality_refresh")

      result <- tryCatch({
        refresh_quality_cache(con(), progress_callback = function(msg, step, total) {
          showNotification(msg, type = "message", id = "quality_refresh")
        })
      }, error = function(e) {
        list(success = FALSE, error = e$message)
      })

      removeNotification("quality_refresh")

      if (result$success) {
        showNotification(
          sprintf("Quality data updated: %d publishers, %d journals, %d retractions",
                  result$predatory_publishers$count,
                  result$predatory_journals$count,
                  result$retraction_watch$count),
          type = "message", duration = 5
        )
      } else {
        # Show which sources failed with reasons
        failed_msgs <- character()
        if (!result$predatory_publishers$success) {
          failed_msgs <- c(failed_msgs, paste("Publishers:", result$predatory_publishers$error %||% "unknown error"))
        }
        if (!result$predatory_journals$success) {
          failed_msgs <- c(failed_msgs, paste("Journals:", result$predatory_journals$error %||% "unknown error"))
        }
        if (!result$retraction_watch$success) {
          failed_msgs <- c(failed_msgs, paste("Retractions:", result$retraction_watch$error %||% "unknown error"))
        }
        showNotification(
          paste("Failed to update:", paste(failed_msgs, collapse = "; ")),
          type = "error", duration = 10
        )
      }
    })

    # Trigger for programmatic refresh
    search_refresh_trigger <- reactiveVal(0)

    # Auto-search on first load: if notebook has a query but no papers yet, trigger search
    observe({
      nb_id <- notebook_id()
      req(nb_id)

      nb <- get_notebook(con(), nb_id)
      req(nb$type == "search")
      req(!is.null(nb$search_query) && nchar(nb$search_query) > 0)

      # Only auto-search if notebook has zero papers (i.e., freshly created)
      paper_count <- nrow(list_abstracts(con(), nb_id))
      if (paper_count == 0) {
        search_refresh_trigger(search_refresh_trigger() + 1)
      }
    }) |> bindEvent(notebook_id(), once = TRUE)

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
      existing_filters <- if (!is.null(nb$search_filters) && !is.na(nb$search_filters) && nchar(nb$search_filters) > 0) {
        tryCatch(jsonlite::fromJSON(nb$search_filters), error = function(e) list())
      } else {
        list()
      }

      # Phase 55: Collect selected work types from chip toggle states
      all_slugs <- sapply(OPENALEX_WORK_TYPES, function(t) t$slug)
      work_types <- all_slugs[sapply(all_slugs, function(s) isTRUE(type_states[[s]]))]

      # If all types selected or none selected, store NULL (no filter)
      if (length(work_types) == length(all_slugs) || length(work_types) == 0) {
        work_types <- NULL
      }

      filters <- list(
        from_year = input$edit_from_year,
        to_year = input$edit_to_year,
        search_field = input$edit_search_field %||% "default",
        is_oa = input$edit_is_oa %||% FALSE,
        has_abstract = if (!is.null(existing_filters$has_abstract)) existing_filters$has_abstract else TRUE,
        # Quality filters
        exclude_retracted = input$edit_exclude_retracted %||% TRUE,
        min_citations = input$edit_min_citations,
        # Document type filter
        work_types = work_types
      )

      # Update notebook
      update_notebook(con(), nb_id, search_query = query, search_filters = filters)

      removeModal()
      showNotification("Search updated", type = "message")

      # Trigger main content refresh (updates the header query display)
      if (!is.null(notebook_refresh)) {
        notebook_refresh(notebook_refresh() + 1)
      }

      # Reset pagination cursor — API query is changing (Phase 51)
      pagination_state$cursor <- NULL
      pagination_state$has_more <- FALSE

      # Trigger search refresh
      search_refresh_trigger(search_refresh_trigger() + 1)
    })

    # Unified search function for both Refresh and Load More (Phase 52.1)
    do_search <- function(mode = c("refresh", "load_more")) {
      mode <- match.arg(mode)

      # Common preamble
      nb_id <- notebook_id()
      req(nb_id)

      nb <- get_notebook(con(), nb_id)
      req(nb$type == "search")

      # Mode-specific guards (BEFORE common logic)
      if (mode == "refresh") {
        req(!is.null(nb$search_query) && nchar(nb$search_query) > 0)
      } else {
        # load_more mode
        # BUG-02 FIX: Use isTRUE() instead of bare req() to catch NULL has_more
        if (!isTRUE(pagination_state$has_more)) {
          showNotification("No more results available", type = "message")
          return()
        }
        req(!is_processing())
        is_processing(TRUE)

        # Swap icon to spinner with guaranteed restore via on.exit()
        updateActionButton(session, "load_more", icon = icon_spinner())

        on.exit({
          updateActionButton(session, "load_more", icon = icon_angles_down())
          is_processing(FALSE)
        })
      }

      # Common config and cursor setup
      cfg <- config()
      count_before <- nrow(list_abstracts(con(), nb_id))
      cursor <- if (mode == "refresh") NULL else pagination_state$cursor
      progress_msg <- if (mode == "refresh") "Searching OpenAlex..." else "Loading more papers..."

      # BUG-01 FIX: Wrap entire withProgress in tryCatch, error handler returns early
      tryCatch({
        withProgress(message = progress_msg, value = 0, {

          email <- get_setting(cfg, "openalex", "email") %||% ""
          api_key <- get_setting(cfg, "openalex", "api_key")

          filters <- if (!is.null(nb$search_filters) && !is.na(nb$search_filters) && nchar(nb$search_filters) > 0) {
            tryCatch(jsonlite::fromJSON(nb$search_filters), error = function(e) list())
          } else {
            list()
          }

          abstracts_count <- get_setting(cfg, "app", "abstracts_per_search") %||% 25


          # API call (no internal tryCatch - outer one handles errors)
          result <- search_papers(
            nb$search_query,
            email,
            api_key,
            from_year = filters$from_year,
            to_year = filters$to_year,
            per_page = abstracts_count,
            search_field = filters$search_field %||% "default",
            is_oa = filters$is_oa %||% FALSE,
            min_citations = filters$min_citations,
            has_abstract = if (!is.null(filters$has_abstract)) filters$has_abstract else TRUE,
            exclude_retracted = if (!is.null(filters$exclude_retracted)) filters$exclude_retracted else TRUE,
            work_types = filters$work_types,
            cursor = cursor
          )


          # Update pagination state
          pagination_state$cursor <- result$next_cursor
          pagination_state$has_more <- !is.null(result$next_cursor)
          pagination_state$api_total <- result$count

          papers <- result$papers

          if (length(papers) == 0) {
            msg <- if (mode == "refresh") "No papers found" else "No more papers found"
            showNotification(msg, type = "warning")
            return()
          }

          incProgress(0.4, detail = paste("Found", length(papers), "papers"))

          incProgress(0.6, detail = if (mode == "refresh") "Processing papers..." else "Saving papers...")


          # Filter out excluded papers
          nb <- get_notebook(con(), nb_id)
          excluded_ids <- tryCatch({
            if (!is.null(nb$excluded_paper_ids) && !is.na(nb$excluded_paper_ids) && nchar(nb$excluded_paper_ids) > 0) {
              jsonlite::fromJSON(nb$excluded_paper_ids)
            } else {
              character()
            }
          }, error = function(e) character())

          if (length(excluded_ids) > 0) {
            original_count <- length(papers)
            papers <- Filter(function(p) !(p$paper_id %in% excluded_ids), papers)
            excluded_count <- original_count - length(papers)
            if (excluded_count > 0) {
              message("Filtered out ", excluded_count, " previously excluded papers")
            }
            if (length(papers) == 0) {
              showNotification("All papers were previously excluded", type = "warning")
              return()
            }
          }


          # Save papers — track newly added vs duplicates
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
              keywords = paper$keywords,
              work_type = paper$work_type,
              work_type_crossref = paper$work_type_crossref,
              oa_status = paper$oa_status,
              is_oa = paper$is_oa,
              cited_by_count = paper$cited_by_count,
              referenced_works_count = paper$referenced_works_count,
              fwci = paper$fwci,
              doi = paper$doi
            )

            # Create chunk for abstract if available
            if (!is.null(paper$abstract) && !is.na(paper$abstract) && nchar(paper$abstract) > 0) {
              create_chunk(con(), abstract_id, "abstract", 0, paper$abstract)
            }

          }

          # NOTE: Embedding is now deferred - user must click "Embed Papers" button

          incProgress(1.0, detail = "Done")
        })


        # Post-withProgress (only reached on success)
        paper_refresh(paper_refresh() + 1)

        total_in_nb <- nrow(list_abstracts(con(), nb_id))
        pagination_state$total_fetched <- total_in_nb
        newly_added <- total_in_nb - count_before

        # Mode-specific success toast
        if (mode == "refresh") {
          if (newly_added == 0L) {
            showNotification("No new papers found", type = "message")
          } else {
            showNotification(
              paste0("Added ", newly_added, " new paper", if (newly_added != 1L) "s" else "",
                     " (", total_in_nb, " total in notebook)"),
              type = "message"
            )
          }
        } else {
          # load_more mode
          if (newly_added > 0L) {
            showNotification(
              paste0("Loaded ", newly_added, " more paper", if (newly_added != 1L) "s" else "",
                     " (", total_in_nb, " total)"),
              type = "message"
            )
          } else {
            showNotification("No new papers (all duplicates)", type = "message")
          }
        }
      }, error = function(e) {
        # BUG-01 FIX: Show error toast then return() - no downstream toasts
        if (inherits(e, "api_error")) {
          show_error_toast(e$message, e$details, e$severity)
        } else {
          err <- classify_api_error(e, "OpenAlex")
          show_error_toast(err$message, err$details, err$severity)
        }
        return()
      })
    }

    # Explicit refresh button - use ignoreInit = TRUE and also ignoreNULL = TRUE
    observeEvent(input$refresh_search, {
      do_search("refresh")
    }, ignoreInit = TRUE, ignoreNULL = TRUE)

    # Load More button
    observeEvent(input$load_more, {
      do_search("load_more")
    }, ignoreInit = TRUE, ignoreNULL = TRUE)

    # Seed citation network button
    observeEvent(input$seed_citation_network, {
      nb_id <- notebook_id()
      req(nb_id)
      con_val <- con()
      papers <- dbGetQuery(con_val, "SELECT paper_id FROM abstracts WHERE notebook_id = ?", list(nb_id))
      if (nrow(papers) == 0) {
        showNotification("No papers in notebook to seed network", type = "warning")
        return()
      }
      network_seed_request(list(
        seed_ids = papers$paper_id,
        source_notebook_id = nb_id,
        timestamp = Sys.time()
      ))
      # Note: No notification here - switching to network view is sufficient feedback
    })

    # Programmatic refresh (from save_search)
    observeEvent(search_refresh_trigger(), {
      do_search("refresh")
    }, ignoreInit = TRUE)

    # Sync total_fetched with DB when papers change (delete, import, etc.) (Phase 51)
    observeEvent(paper_refresh(), {
      nb_id <- notebook_id()
      if (!is.null(nb_id)) {
        pagination_state$total_fetched <- nrow(list_abstracts(con(), nb_id))
      }
    }, ignoreInit = TRUE)

    # Result count display moved to keyword filter in Phase 53
    # output$result_count <- renderText({
    #   format_result_count(pagination_state$total_fetched, pagination_state$api_total)
    # })

    # Enable/disable Load More based on pagination state
    observe({
      has_more <- pagination_state$has_more
      processing <- is_processing()
      if (has_more && !processing) {
        shinyjs::enable("load_more")
      } else {
        shinyjs::disable("load_more")
      }
    })

    # Handle embed button click (embeds only filtered papers)
    observeEvent(input$embed_papers, {
      nb_id <- notebook_id()
      req(nb_id)

      # Get filtered papers to embed (matches the count shown on button)
      papers <- filtered_papers()
      papers_with_abstract <- papers[!is.na(papers$abstract) & nchar(papers$abstract) > 0, ]

      if (nrow(papers_with_abstract) == 0) {
        showNotification("No papers with abstracts to embed", type = "warning")
        return()
      }

      paper_ids <- papers_with_abstract$id

      withProgress(message = "Embedding papers...", value = 0, {
        cfg <- config()
        api_key_or <- get_setting(cfg, "openrouter", "api_key")
        embed_model <- get_setting(cfg, "defaults", "embedding_model") %||% "openai/text-embedding-3-small"

        if (is.null(api_key_or) || nchar(api_key_or) == 0) {
          showNotification("OpenRouter API key required for embedding", type = "error")
          return()
        }

        incProgress(0.1, detail = "Preparing...")

        # Index with ragnar unconditionally
        tryCatch({
          # Query only filtered papers (not all papers in notebook)
          placeholders <- paste(rep("?", length(paper_ids)), collapse = ", ")
          abstracts_to_index <- dbGetQuery(con(), sprintf("
            SELECT a.id, a.title, a.abstract
            FROM abstracts a
            WHERE a.id IN (%s) AND a.abstract IS NOT NULL AND LENGTH(a.abstract) > 0
          ", placeholders), as.list(paper_ids))

          if (nrow(abstracts_to_index) > 0) {
            incProgress(0.2, detail = "Building search index...")

            # Phase 22: Use per-notebook ragnar store
            store <- tryCatch(
              ensure_ragnar_store(nb_id, session, api_key_or, embed_model),
              error = function(e) {
                message("[ragnar] Failed to open per-notebook store: ", e$message)
                store_healthy(FALSE)
                NULL
              }
            )

            if (!is.null(store)) {
              for (i in seq_len(nrow(abstracts_to_index))) {
                abs_row <- abstracts_to_index[i, ]
                abs_chunks <- data.frame(
                  content = abs_row$abstract,
                  page_number = 1L,
                  chunk_index = 0L,
                  context = abs_row$title,
                  origin = encode_origin_metadata(
                    paste0("abstract:", abs_row$id),
                    section_hint = "general",
                    doi = NULL,
                    source_type = "abstract"
                  ),
                  stringsAsFactors = FALSE
                )
                insert_chunks_to_ragnar(store, abs_chunks, abs_row$id, "abstract")
                incProgress(0.6 * i / nrow(abstracts_to_index),
                           detail = paste0("Indexing ", i, "/", nrow(abstracts_to_index)))
              }

              build_ragnar_index(store)
              incProgress(0.9, detail = "Finalizing index...")

              # Mark embedded abstracts with sentinel value
              tryCatch({
                mark_as_ragnar_indexed(con(), paper_ids, source_type = "abstract")
              }, error = function(e) message("[ragnar] Sentinel marking failed: ", e$message))

              # Update rag state
              rag_ready(TRUE)
              store_healthy(TRUE)
            }
          }
        }, error = function(e) {
          message("Ragnar indexing error: ", e$message)
        })

        incProgress(1.0, detail = "Done!")
      })

      showNotification("Embedding complete!", type = "message")
      paper_refresh(paper_refresh() + 1)
    })

    # Phase 38: Import selected papers to document notebook (async for 50+, confirm for 100+)
    observeEvent(input$import_selected, {
      selected <- selected_papers()
      req(length(selected) > 0)

      if (length(selected) >= 100) {
        # Show confirmation modal for large imports
        showModal(modalDialog(
          title = tagList(icon_warning(class = "text-warning"), "Large Import"),
          p(sprintf("You're about to import %d papers. This may take a few minutes.", length(selected))),
          p(class = "text-muted small", "You can cancel the import at any time. Papers already imported will be kept."),
          footer = tagList(
            modalButton("Cancel"),
            actionButton(ns("confirm_large_import"), "Continue", class = "btn-primary")
          )
        ))
      } else {
        # Show notebook selector directly
        show_import_notebook_modal()
      }
    })

    # Phase 38: Confirm large import -> show notebook selector
    observeEvent(input$confirm_large_import, {
      removeModal()
      show_import_notebook_modal()
    })

    # Phase 38: Helper to show the notebook selector modal
    show_import_notebook_modal <- function() {
      selected <- selected_papers()
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
    }

    # Phase 38: Results modal helper
    show_import_results <- function(imported, duplicates, failed, cancelled = FALSE) {
      title <- if (cancelled) {
        tagList(icon_circle_pause(class = "text-warning"), "Import Cancelled")
      } else {
        tagList(icon_check_circle(class = "text-success"), "Import Complete")
      }

      showModal(modalDialog(
        title = title,
        tags$div(
          class = "d-flex gap-4 mb-3",
          tags$div(
            class = "text-center",
            tags$h3(class = "text-success mb-0", imported),
            tags$small(class = "text-muted", "imported")
          ),
          tags$div(
            class = "text-center",
            tags$h3(class = if (duplicates > 0) "text-warning mb-0" else "text-muted mb-0", duplicates),
            tags$small(class = "text-muted", "duplicates skipped")
          ),
          tags$div(
            class = "text-center",
            tags$h3(class = if (failed > 0) "text-danger mb-0" else "text-muted mb-0", failed),
            tags$small(class = "text-muted", "failed")
          )
        ),
        if (cancelled) {
          p(class = "text-muted small", "Import was cancelled. Papers already imported have been kept.")
        },
        footer = modalButton("Close"),
        size = "m",
        easyClose = TRUE
      ))
    }

    # Phase 38: Do import (synchronous for < 50, async for >= 50)
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

      removeModal()

      if (length(selected) < 50) {
        # Synchronous import for small batches
        abstracts <- dbGetQuery(con(), sprintf("
          SELECT * FROM abstracts WHERE id IN (%s)
        ", paste(sprintf("'%s'", selected), collapse = ",")))

        # Check for duplicates
        existing <- tryCatch(
          dbGetQuery(con(), sprintf(
            "SELECT abstract_id FROM documents WHERE notebook_id = '%s' AND abstract_id IN (%s)",
            target, paste(sprintf("'%s'", selected), collapse = ",")
          )),
          error = function(e) data.frame(abstract_id = character(0))
        )
        dup_ids <- existing$abstract_id
        abstracts <- abstracts[!abstracts$id %in% dup_ids, ]

        imported <- 0
        for (i in seq_len(nrow(abstracts))) {
          abs <- abstracts[i, ]
          if (!is.na(abs$abstract) && nchar(abs$abstract) > 0) {
            doc_doi <- if (!is.null(abs$doi) && !is.na(abs$doi)) abs$doi else NA_character_
            doc_authors <- if (!is.null(abs$authors) && !is.na(abs$authors)) abs$authors else NA_character_
            doc_year <- if (!is.null(abs$year) && !is.na(abs$year)) as.integer(abs$year) else NA_integer_

            doc_id <- create_document(
              con(), target, paste0(abs$title, ".txt"), "",
              abs$abstract, 1,
              title = abs$title, authors = doc_authors,
              year = doc_year, doi = doc_doi, abstract_id = abs$id
            )
            create_chunk(con(), doc_id, "document", 0, abs$abstract, page_number = 1)
            imported <- imported + 1
          }
        }

        dups <- length(dup_ids)
        failed <- length(selected) - imported - dups
        show_import_results(imported, dups, failed, cancelled = FALSE)
        paper_refresh(paper_refresh() + 1)
      } else {
        # Async import for large batches (50+ papers)
        flag_file <- create_interrupt_flag(session$token)
        batch_import_interrupt(flag_file)
        prog_file <- create_progress_file(session$token)
        batch_import_progress(prog_file)

        db_path_val <- if (is.function(db_path)) db_path() else db_path

        # Show progress modal (matches bulk import modal pattern)
        showModal(modalDialog(
          title = tagList(icon_spinner(class = "fa-spin"), "Importing Papers"),
          tags$div(
            class = "progress",
            style = "height: 25px;",
            tags$div(
              id = ns("batch_progress_bar"),
              class = "progress-bar progress-bar-striped progress-bar-animated",
              role = "progressbar",
              style = "width: 5%;",
              `aria-valuenow` = "5",
              `aria-valuemin` = "0",
              `aria-valuemax` = "100",
              "5%"
            )
          ),
          tags$div(
            id = ns("batch_progress_message"),
            class = "text-muted mt-2",
            sprintf("Importing %d papers...", length(selected))
          ),
          footer = actionButton(ns("cancel_batch_import"), "Cancel",
                                 class = "btn-warning", icon = icon_stop()),
          easyClose = FALSE
        ))

        # Launch async import
        batch_import_task$invoke(
          abstract_ids = selected,
          target_notebook_id = target,
          db_path = db_path_val,
          interrupt_flag = flag_file,
          progress_file = prog_file,
          app_dir = getwd()
        )

        # Start progress polling
        poller <- observe({
          invalidateLater(1000)
          pf <- isolate(batch_import_progress())
          prog <- read_import_progress(pf)
          session$sendCustomMessage("updateImportProgress", list(
            bar_id = ns("batch_progress_bar"),
            msg_id = ns("batch_progress_message"),
            percent = max(prog$pct, 5),
            message = prog$message
          ))
        })
        batch_import_poller(poller)
      }
    })

    # Phase 38: Cancel batch import handler
    observeEvent(input$cancel_batch_import, {
      flag_file <- batch_import_interrupt()
      if (!is.null(flag_file)) {
        signal_interrupt(flag_file)
      }
      poller <- batch_import_poller()
      if (!is.null(poller)) {
        poller$destroy()
        batch_import_poller(NULL)
      }
      session$sendCustomMessage("updateImportProgress", list(
        bar_id = ns("batch_progress_bar"),
        msg_id = ns("batch_progress_message"),
        percent = 100,
        message = "Stopping... keeping partial results"
      ))
    })

    # Phase 38: Handle async batch import result
    observe({
      result <- batch_import_task$result()
      req(result)

      # Destroy poller
      poller <- batch_import_poller()
      if (!is.null(poller)) {
        poller$destroy()
        batch_import_poller(NULL)
      }

      removeModal()

      # Clean up temp files
      clear_interrupt_flag(batch_import_interrupt())
      batch_import_interrupt(NULL)
      clear_progress_file(batch_import_progress())
      batch_import_progress(NULL)

      # Show results
      show_import_results(result$imported, result$duplicates, result$failed,
                          cancelled = isTRUE(result$cancelled))

      # Refresh paper list
      paper_refresh(paper_refresh() + 1)
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
              icon_warning(class = "me-2"),
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
            icon_comments(class = "fa-2x mb-2"),
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
          is_synthesis <- !is.null(msg$preset_type) && msg$preset_type %in% c("overview", "conclusions", "research_questions")

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

    # Send message
    observeEvent(input$send, {
      # Phase 22: Block chat when per-notebook store is unavailable
      if (!isTRUE(rag_available())) {
        showNotification("Chat unavailable \u2014 re-index this notebook first.", type = "warning")
        return()
      }
      req(input$user_input)
      req(!is_processing())
      req(has_api_key())

      user_msg <- trimws(input$user_input)
      if (nchar(user_msg) == 0) return()

      updateTextInput(session, "user_input", value = "")
      is_processing(TRUE)

      msgs <- messages()
      msgs <- c(msgs, list(list(role = "user", content = user_msg, timestamp = Sys.time())))
      messages(msgs)

      nb_id <- notebook_id()
      cfg <- config()

      response <- tryCatch({
        rag_query(con(), cfg, user_msg, nb_id, session_id = session$token)
      }, error = function(e) {
        if (inherits(e, "api_error")) {
          show_error_toast(e$message, e$details, e$severity)
        } else {
          err <- classify_api_error(e, "OpenRouter")
          show_error_toast(err$message, err$details, err$severity)
        }
        paste("Sorry, I encountered an error processing your question.")
      })

      msgs <- c(msgs, list(list(role = "assistant", content = response, timestamp = Sys.time())))
      messages(msgs)
      is_processing(FALSE)
      session$sendCustomMessage("searchChatReady", ns(""))
    })

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
        generate_overview_preset(con(), cfg, nb_id, notebook_type = "search",
                                 depth = depth, mode = mode, session_id = session$token)
      }, error = function(e) {
        if (inherits(e, "api_error")) {
          show_error_toast(e$message, e$details, e$severity)
        } else {
          err <- classify_api_error(e, "OpenRouter")
          show_error_toast(err$message, err$details, err$severity)
        }
        "Sorry, I encountered an error generating the overview."
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

    # Conclusions preset handler
    observeEvent(input$btn_conclusions, {
      # Phase 22: Block synthesis when per-notebook store is unavailable
      if (!isTRUE(rag_available())) {
        showNotification("Synthesis unavailable \u2014 re-index this notebook first.", type = "warning")
        return()
      }
      req(!is_processing())
      req(has_api_key())
      is_processing(TRUE)

      msgs <- messages()
      msgs <- c(msgs, list(list(role = "user", content = "Generate: Conclusion Synthesis", timestamp = Sys.time(), preset_type = "conclusions")))
      messages(msgs)

      nb_id <- notebook_id()
      cfg <- config()

      response <- tryCatch({
        generate_conclusions_preset(con(), cfg, nb_id, notebook_type = "search", session_id = session$token)
      }, error = function(e) {
        if (inherits(e, "api_error")) {
          show_error_toast(e$message, e$details, e$severity)
        } else {
          err <- classify_api_error(e, "OpenRouter")
          show_error_toast(err$message, err$details, err$severity)
        }
        "Sorry, I encountered an error generating the synthesis."
      })

      msgs <- c(msgs, list(list(role = "assistant", content = response, timestamp = Sys.time(), preset_type = "conclusions")))
      messages(msgs)
      is_processing(FALSE)
    })

    # Phase 27: Research Questions preset handler
    observeEvent(input$btn_research_questions, {
      if (!isTRUE(rag_available())) {
        showNotification("Synthesis unavailable \u2014 re-index this notebook first.", type = "warning")
        return()
      }
      req(!is_processing())
      req(has_api_key())
      is_processing(TRUE)

      msgs <- messages()
      msgs <- c(msgs, list(list(
        role = "user",
        content = "Generate: Research Questions",
        timestamp = Sys.time(),
        preset_type = "research_questions"
      )))
      messages(msgs)

      nb_id <- notebook_id()
      cfg <- config()

      response <- tryCatch({
        generate_research_questions(con(), cfg, nb_id, notebook_type = "search", session_id = session$token)
      }, error = function(e) {
        if (inherits(e, "api_error")) {
          show_error_toast(e$message, e$details, e$severity)
        } else {
          err <- classify_api_error(e, "OpenRouter")
          show_error_toast(err$message, err$details, err$severity)
        }
        "Sorry, I encountered an error generating research questions."
      })

      msgs <- c(msgs, list(list(
        role = "assistant",
        content = response,
        timestamp = Sys.time(),
        preset_type = "research_questions"
      )))
      messages(msgs)
      is_processing(FALSE)
    })

    # Return reactives for app.R to consume
    list(
      seed_request = seed_request,
      network_seed_request = network_seed_request
    )
  })
}
