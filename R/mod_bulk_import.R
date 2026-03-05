#' Bulk DOI Import Module UI
#' @param id Module ID
mod_bulk_import_ui <- function(id) {
  ns <- NS(id)
  # Module uses modals for workflow — minimal persistent UI
  # Import history is rendered via uiOutput in the parent module
  tagList(
    tags$script(src = "js/import-progress.js"),
    uiOutput(ns("import_history"))
  )
}

#' Bulk DOI Import Module Server
#'
#' Provides bulk DOI import workflow: paste/upload DOIs, preview with
#' validation, async import with progress, categorized results, retry,
#' and import history.
#'
#' @param id Module ID
#' @param con Reactive DuckDB connection
#' @param notebook_id Reactive notebook ID string
#' @param config Reactive config list (for email/API key extraction)
#' @param paper_refresh ReactiveVal to increment for paper list refresh
#' @param db_path_r Reactive DB file path for mirai worker
#' @return List with show_import_modal function
mod_bulk_import_server <- function(id, con, notebook_id, config, paper_refresh, db_path_r,
                                    standalone = FALSE, navigate_to_notebook = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive state for import workflow
    parsed_result <- reactiveVal(NULL)   # Output of parse_doi_list / extract_dois_from_bib
    new_dois <- reactiveVal(character())  # DOIs to actually fetch (after dedup)
    duplicate_dois <- reactiveVal(character())  # DOIs already in notebook
    malformed_dois <- reactiveVal(NULL)   # data.frame of invalid DOIs
    bib_entries_without_doi <- reactiveVal(0L)
    bib_metadata_store <- reactiveVal(NULL)  # Tibble from parse_bibtex_metadata for metadata merge
    bib_diagnostics <- reactiveVal(NULL)     # Diagnostics from parse_bibtex_metadata
    current_run_id <- reactiveVal(NULL)
    last_result <- reactiveVal(NULL)      # Result from run_bulk_import

    # Interrupt and progress state
    current_interrupt_flag <- reactiveVal(NULL)
    current_progress_file <- reactiveVal(NULL)
    progress_poller <- reactiveVal(NULL)

    # History refresh trigger
    history_refresh <- reactiveVal(0)

    # Network seed request
    network_seed_request <- reactiveVal(NULL)

    # ExtendedTask for async import (API-only — no DB access to avoid Windows file locks)
    import_task <- ExtendedTask$new(function(dois, email, api_key,
                                             interrupt_flag, progress_file, app_dir,
                                             bib_metadata = NULL) {
      mirai::mirai({
        setwd(app_dir)
        source("R/utils_doi.R")
        source("R/api_openalex.R")
        source("R/bulk_import.R")
        source("R/interrupt.R")
        fetch_bulk_papers(dois, email, api_key,
                          interrupt_flag, progress_file,
                          bib_metadata = bib_metadata)
      }, dois = dois, email = email, api_key = api_key,
         interrupt_flag = interrupt_flag,
         progress_file = progress_file, app_dir = app_dir,
         bib_metadata = bib_metadata)
    })

    # --- Show Import Modal ---
    show_import_modal <- function() {
      # Reset state
      parsed_result(NULL)
      new_dois(character())
      duplicate_dois(character())
      malformed_dois(NULL)
      bib_entries_without_doi(0L)
      bib_metadata_store(NULL)
      bib_diagnostics(NULL)

      # Build notebook selector UI for standalone mode
      notebook_selector_ui <- NULL
      if (standalone) {
        notebooks <- list_notebooks(con())
        search_nbs <- notebooks[notebooks$type == "search", ]
        choices <- c(
          stats::setNames(search_nbs$id, search_nbs$name),
          "+ New Notebook" = "__new__"
        )
        notebook_selector_ui <- tagList(
          selectInput(ns("target_notebook"), "Target Notebook", choices = choices),
          conditionalPanel(
            condition = sprintf("input['%s'] === '__new__'", ns("target_notebook")),
            textInput(ns("new_nb_name"), "New Notebook Name",
                      placeholder = "e.g., Imported Papers")
          ),
          hr()
        )
      }

      showModal(modalDialog(
        title = tagList(icon_file_import(), "Bulk DOI Import"),
        notebook_selector_ui,
        tabsetPanel(
          id = ns("import_method"),
          tabPanel("Paste DOIs",
            textAreaInput(ns("doi_text"), "Paste DOIs (one per line or comma-separated)",
                          rows = 8,
                          placeholder = "10.1234/abc\nhttps://doi.org/10.5678/xyz\n...")
          ),
          tabPanel("Upload File",
            fileInput(ns("doi_file"), "Upload CSV, text, or .bib file",
                      accept = c(".csv", ".txt", ".bib")),
            uiOutput(ns("file_info"))
          )
        ),
        textInput(ns("run_name"), "Import name (optional)",
                  placeholder = paste0("Import - ", Sys.Date())),
        uiOutput(ns("preview_panel")),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("preview_btn"), "Validate",
                       class = "btn-outline-primary", icon = icon_check_double()),
          actionButton(ns("start_import"), "Import",
                       class = "btn-primary", icon = icon_file_import(),
                       disabled = "disabled")
        ),
        size = "l",
        easyClose = FALSE
      ))
    }

    # --- File Upload Info ---
    output$file_info <- renderUI({
      req(input$doi_file)
      file <- input$doi_file
      ext <- tolower(tools::file_ext(file$name))
      if (ext == "bib") {
        tags$div(
          class = "text-muted small mt-1",
          sprintf("BibTeX file: %s (%s bytes) -- DOIs will be extracted and enriched via OpenAlex",
                  file$name, file$size)
        )
      } else {
        tags$div(
          class = "text-muted small mt-1",
          sprintf("File: %s (%s, %s bytes)", file$name, ext, file$size)
        )
      }
    })

    # --- Preview Logic ---
    observeEvent(input$preview_btn, {
      # Standalone mode: resolve notebook from selector
      if (standalone) {
        target <- input$target_notebook
        req(target)
        if (target == "__new__") {
          name <- trimws(input$new_nb_name %||% "")
          if (nchar(name) == 0) {
            showNotification("Please enter a notebook name.", type = "warning")
            return()
          }
          new_id <- create_notebook(con(), name, "search")
          notebook_id(new_id)
        } else {
          notebook_id(target)
        }
      }

      nb_id <- notebook_id()
      req(nb_id)

      # Determine input source
      doi_input <- NULL
      is_bib <- FALSE
      bib_no_doi_count <- 0L

      if (!is.null(input$doi_file)) {
        file <- input$doi_file
        ext <- tolower(tools::file_ext(file$name))
        file_content <- tryCatch(
          readLines(file$datapath, warn = FALSE, encoding = "UTF-8"),
          error = function(e) {
            tryCatch(readLines(file$datapath, warn = FALSE, encoding = "latin1"),
                     error = function(e2) character(0))
          }
        )

        if (ext == "bib") {
          # Use bib2df for full metadata parsing (Phase 36)
          bib_result <- parse_bibtex_metadata(file$datapath)
          bib_metadata_store(bib_result$data)
          bib_diagnostics(bib_result$diagnostics)

          # Extract DOIs from parsed data
          if (nrow(bib_result$data) > 0 && "DOI" %in% names(bib_result$data)) {
            doi_input <- bib_result$data$DOI[!is.na(bib_result$data$DOI) &
                                              nchar(trimws(as.character(bib_result$data$DOI))) > 0]
          } else {
            doi_input <- character(0)
          }
          is_bib <- TRUE
          bib_no_doi_count <- bib_result$diagnostics$entries_without_doi
        } else {
          # CSV or text file — treat each line as potential DOI
          doi_input <- file_content
        }
      } else if (!is.null(input$doi_text) && nchar(trimws(input$doi_text)) > 0) {
        doi_input <- input$doi_text
      }

      if (is.null(doi_input) || length(doi_input) == 0) {
        showNotification("No DOIs provided. Paste DOIs or upload a file.", type = "warning")
        return()
      }

      # Parse DOIs
      parsed <- parse_doi_list(doi_input)
      parsed_result(parsed)
      bib_entries_without_doi(bib_no_doi_count)

      # Check for duplicates against notebook
      existing_dois <- get_notebook_dois(con(), nb_id)
      valid_lower <- tolower(parsed$valid)
      is_dup <- valid_lower %in% existing_dois
      dups <- parsed$valid[is_dup]
      new <- parsed$valid[!is_dup]

      new_dois(new)
      duplicate_dois(dups)
      malformed_dois(parsed$invalid)

      # Enable/disable import button
      if (length(new) > 0) {
        shinyjs_available <- requireNamespace("shinyjs", quietly = TRUE)
        # Use JS to enable the button since shinyjs may not be loaded
        session$sendCustomMessage("toggleImportBtn", list(
          id = ns("start_import"),
          disabled = FALSE
        ))
      }
    })

    # --- Preview Panel ---
    output$preview_panel <- renderUI({
      parsed <- parsed_result()
      req(parsed)

      new <- new_dois()
      dups <- duplicate_dois()
      invalid <- malformed_dois()
      bib_no_doi <- bib_entries_without_doi()

      items <- list()

      # Valid new DOIs
      items[[length(items) + 1]] <- tags$div(
        class = "d-flex justify-content-between",
        tags$span(icon_check_circle(class = "text-success"), paste(length(new), "valid new DOIs to import")),
        tags$span(class = "text-muted", estimate_import_time(length(new)))
      )

      # Duplicates
      if (length(dups) > 0) {
        items[[length(items) + 1]] <- tags$details(
          tags$summary(
            class = "text-warning",
            icon_copy(), paste(length(dups), "already in notebook (will be skipped)")
          ),
          tags$div(
            class = "small text-muted ms-4 mt-1",
            style = "max-height: 100px; overflow-y: auto;",
            tags$ul(lapply(dups, function(d) tags$li(d)))
          )
        )
      }

      # Malformed DOIs
      if (!is.null(invalid) && nrow(invalid) > 0) {
        items[[length(items) + 1]] <- tags$details(
          tags$summary(
            class = "text-danger",
            icon_circle_xmark(), paste(nrow(invalid), "malformed (will be skipped)")
          ),
          tags$div(
            class = "small text-muted ms-4 mt-1",
            style = "max-height: 100px; overflow-y: auto;",
            tags$table(
              class = "table table-sm",
              tags$thead(tags$tr(tags$th("Input"), tags$th("Reason"))),
              tags$tbody(
                lapply(seq_len(nrow(invalid)), function(i) {
                  tags$tr(
                    tags$td(class = "font-monospace small", invalid$original[i]),
                    tags$td(class = "small", invalid$reason[i])
                  )
                })
              )
            )
          )
        )
      }

      # Input duplicates
      if (!is.null(parsed$duplicates) && nrow(parsed$duplicates) > 0) {
        items[[length(items) + 1]] <- tags$div(
          class = "text-muted small",
          icon_layer_group(), paste(nrow(parsed$duplicates), "duplicates in input (deduplicated)")
        )
      }

      # .bib entries without DOI
      if (bib_no_doi > 0) {
        items[[length(items) + 1]] <- tags$div(
          class = "text-muted small",
          icon_file_question(), paste(bib_no_doi, ".bib entries without DOI field (skipped)")
        )
      }

      # BibTeX diagnostics summary (Phase 36)
      diag <- bib_diagnostics()
      if (!is.null(diag)) {
        items[[length(items) + 1]] <- tags$div(
          class = "text-info small",
          icon_paper(),
          sprintf("BibTeX: %d entries parsed, %d with DOIs, %d without DOIs",
                  diag$total_entries, diag$entries_with_doi, diag$entries_without_doi)
        )
      }

      # Large import warning
      warning_ui <- NULL
      if (!is.null(diag) && diag$total_entries >= 200) {
        warning_ui <- tags$div(
          class = "alert alert-warning mt-2 mb-0",
          icon_warning(),
          sprintf("Large BibTeX file: %d entries. Import may take a while.", diag$total_entries),
          tags$strong(estimate_import_time(length(new))),
          "You can cancel mid-import."
        )
      } else if (length(new) >= 200) {
        warning_ui <- tags$div(
          class = "alert alert-warning mt-2 mb-0",
          icon_warning(),
          paste("Large import:", length(new), "DOIs."),
          tags$strong(estimate_import_time(length(new))),
          "You can cancel mid-import."
        )
      }

      tags$div(
        class = "border rounded p-3 mt-3",
        tags$h6("Validation"),
        do.call(tagList, items),
        warning_ui
      )
    })

    # --- Start Import ---
    observeEvent(input$start_import, {
      dois_to_fetch <- new_dois()
      req(length(dois_to_fetch) > 0)

      nb_id <- notebook_id()
      req(nb_id)

      cfg <- config()
      email <- get_setting(cfg, "openalex", "email") %||% ""
      api_key <- get_setting(cfg, "openalex", "api_key")

      # Generate run name
      run_name <- if (!is.null(input$run_name) && nchar(trimws(input$run_name)) > 0) {
        trimws(input$run_name)
      } else {
        paste0("Import - ", Sys.Date())
      }

      # Create import run in main session (before mirai)
      total_count <- length(dois_to_fetch) + length(duplicate_dois()) +
        (if (!is.null(malformed_dois())) nrow(malformed_dois()) else 0L)
      import_source <- if (!is.null(bib_metadata_store())) "bibtex" else "doi_bulk"
      run_id <- create_import_run(con(), nb_id, run_name, total_count, source = import_source)
      current_run_id(run_id)

      # Record duplicate items immediately (no API call needed)
      dups <- duplicate_dois()
      if (length(dups) > 0) {
        for (d in dups) {
          create_import_run_item(con(), run_id, d, "duplicate")
        }
      }

      # Record malformed items immediately
      invalid <- malformed_dois()
      if (!is.null(invalid) && nrow(invalid) > 0) {
        for (i in seq_len(nrow(invalid))) {
          create_import_run_item(con(), run_id, invalid$original[i], "malformed", invalid$reason[i])
        }
      }

      # Create interrupt and progress files
      flag_file <- create_interrupt_flag(session$token)
      current_interrupt_flag(flag_file)
      prog_file <- create_progress_file(session$token)
      current_progress_file(prog_file)

      # Close input modal, show progress modal
      removeModal()
      showModal(modalDialog(
        title = tagList(icon_spinner(class = "fa-spin"), "Importing Papers"),
        tags$div(
          class = "progress",
          style = "height: 25px;",
          tags$div(
            id = ns("import_progress_bar"),
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
          id = ns("import_progress_message"),
          class = "text-muted mt-2",
          "Initializing import..."
        ),
        footer = actionButton(ns("cancel_import"), "Cancel",
                               class = "btn-warning", icon = icon_stop()),
        easyClose = FALSE
      ))

      # Invoke async import (API-only — DB writes happen in result handler)
      bib_meta <- bib_metadata_store()
      import_task$invoke(
        dois = dois_to_fetch,
        email = email,
        api_key = api_key,
        interrupt_flag = flag_file,
        progress_file = prog_file,
        app_dir = getwd(),
        bib_metadata = bib_meta
      )

      # Start polling observer
      poller <- observe({
        invalidateLater(1000)
        pf <- isolate(current_progress_file())
        prog <- read_import_progress(pf)
        session$sendCustomMessage("updateImportProgress", list(
          bar_id = ns("import_progress_bar"),
          msg_id = ns("import_progress_message"),
          percent = max(prog$pct, 5),
          message = prog$message
        ))
      })
      progress_poller(poller)
    })

    # --- Cancel Handler ---
    observeEvent(input$cancel_import, {
      flag_file <- current_interrupt_flag()
      if (!is.null(flag_file)) {
        signal_interrupt(flag_file)
      }

      # Stop progress poller
      poller <- progress_poller()
      if (!is.null(poller)) {
        poller$destroy()
        progress_poller(NULL)
      }

      # Update modal message
      session$sendCustomMessage("updateImportProgress", list(
        bar_id = ns("import_progress_bar"),
        msg_id = ns("import_progress_message"),
        percent = 100,
        message = "Stopping... keeping partial results"
      ))
    })

    # Guard: track the last processed result to prevent re-entry
    last_processed_result <- reactiveVal(NULL)

    # --- Result Handler ---
    observe({
      result <- import_task$result()
      req(result)

      # Prevent infinite re-fire: skip if we already processed this result
      if (identical(result, isolate(last_processed_result()))) return()
      last_processed_result(result)

      # Everything below uses isolate() to avoid creating reactive dependencies
      # that would re-trigger this observer
      isolate({
        # Destroy progress poller
        poller <- progress_poller()
        if (!is.null(poller)) {
          poller$destroy()
          progress_poller(NULL)
        }

        # Close progress modal
        removeModal()

        # Clean up files
        flag_file <- current_interrupt_flag()
        clear_interrupt_flag(flag_file)
        current_interrupt_flag(NULL)
        clear_progress_file(current_progress_file())
        current_progress_file(NULL)

        # Write fetched papers to DB in main process (avoids DuckDB cross-process file lock)
        nb_id <- notebook_id()
        run_id <- current_run_id()
        imported_count <- 0L
        failed_count <- 0L

        for (paper in result$papers) {
          tryCatch({
            create_abstract(
              con = con(),
              notebook_id = nb_id,
              paper_id = paper$paper_id,
              title = paper$title,
              authors = paper$authors,
              abstract = paper$abstract,
              year = paper$year,
              venue = paper$venue,
              pdf_url = paper$pdf_url,
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
            if (!is.null(run_id)) {
              create_import_run_item(con(), run_id, paper$doi %||% "unknown", "success")
            }
            imported_count <- imported_count + 1L
          }, error = function(e) {
            message("[bulk_import] Error storing paper: ", conditionMessage(e))
            if (!is.null(run_id)) {
              tryCatch(
                create_import_run_item(con(), run_id, paper$doi %||% "unknown", "api_error",
                                       paste("Storage error:", conditionMessage(e))),
                error = function(e2) NULL
              )
            }
            failed_count <<- failed_count + 1L
          })
        }

        for (err in result$errors) {
          tryCatch({
            if (!is.null(run_id)) {
              create_import_run_item(con(), run_id, err$doi, err$reason,
                                     err$details %||% NA_character_)
            }
            failed_count <- failed_count + 1L
          }, error = function(e) {
            message("[bulk_import] Error storing error item: ", conditionMessage(e))
          })
        }

        # Build final result for UI
        final_result <- list(
          run_id = run_id,
          imported_count = imported_count,
          failed_count = failed_count,
          cancelled = isTRUE(result$cancelled)
        )
        last_result(final_result)

        # Update run counts
        if (!is.null(run_id)) {
          skipped <- length(duplicate_dois()) + (if (!is.null(malformed_dois())) nrow(malformed_dois()) else 0L)
          tryCatch({
            update_import_run_counts(con(), run_id, imported_count, failed_count, skipped)
          }, error = function(e) {
            message("[bulk_import] Error updating final counts: ", conditionMessage(e))
          })
        }

        # Refresh paper list
        paper_refresh(paper_refresh() + 1)
        history_refresh(history_refresh() + 1)

        # Navigate to notebook after standalone import
        if (standalone && !is.null(navigate_to_notebook)) {
          nb_id_val <- notebook_id()
          if (!is.null(nb_id_val)) {
            navigate_to_notebook(nb_id_val)
          }
        }

        # Show results modal
        show_results_modal(final_result, run_id)
      })
    })

    # --- Results Modal ---
    show_results_modal <- function(result, run_id) {
      title <- if (isTRUE(result$cancelled)) {
        tagList(icon_circle_pause(class = "text-warning"), "Import Cancelled")
      } else {
        tagList(icon_check_circle(class = "text-success"), "Import Complete")
      }

      skipped <- length(duplicate_dois()) + (if (!is.null(malformed_dois())) nrow(malformed_dois()) else 0L)

      # Build error category details
      error_ui <- NULL
      if (!is.null(run_id)) {
        tryCatch({
          items <- get_import_run_items(con(), run_id)
          if (nrow(items) > 0) {
            # Group by status
            statuses <- split(items, items$status)
            error_sections <- list()

            for (status in c("not_found", "api_error", "malformed")) {
              if (!is.null(statuses[[status]]) && nrow(statuses[[status]]) > 0) {
                status_items <- statuses[[status]]
                label <- switch(status,
                  not_found = "Not found in OpenAlex",
                  api_error = "API error",
                  malformed = "Malformed DOI"
                )
                error_sections[[length(error_sections) + 1]] <- tags$details(
                  class = "mb-2",
                  tags$summary(
                    paste0(label, " (", nrow(status_items), ")")
                  ),
                  tags$div(
                    class = "small ms-3 mt-1",
                    style = "max-height: 150px; overflow-y: auto;",
                    tags$ul(lapply(seq_len(nrow(status_items)), function(i) {
                      tags$li(
                        tags$code(status_items$doi[i]),
                        if (!is.na(status_items$error_reason[i]))
                          tags$span(class = "text-muted", paste0(" — ", status_items$error_reason[i]))
                      )
                    }))
                  )
                )
              }
            }

            if (length(error_sections) > 0) {
              error_ui <- tags$div(
                class = "mt-3",
                tags$h6("Error Details"),
                do.call(tagList, error_sections)
              )
            }
          }
        }, error = function(e) {
          message("[bulk_import] Error loading result items: ", conditionMessage(e))
        })
      }

      # Footer buttons
      footer_buttons <- list(modalButton("Close"))
      if (result$failed_count > 0) {
        footer_buttons <- c(
          list(actionButton(ns("retry_failed"), "Retry Failed DOIs",
                            class = "btn-outline-warning", icon = icon_rotate_right())),
          footer_buttons
        )
      }

      # Seed Citation Network button for BibTeX imports (Phase 36)
      bib_meta <- bib_metadata_store()
      if (result$imported_count > 0 && !is.null(bib_meta)) {
        footer_buttons <- c(
          list(actionButton(ns("seed_network"), "Seed Citation Network",
                            class = "btn-outline-primary",
                            icon = icon_share_nodes())),
          footer_buttons
        )
      }

      # BibTeX-specific results breakdown (Phase 36)
      bib_detail_ui <- NULL
      diag <- bib_diagnostics()
      if (!is.null(diag)) {
        bib_detail_ui <- tags$div(
          class = "border rounded p-2 mb-3",
          tags$h6(class = "mb-2", icon_paper(), "BibTeX Details"),
          tags$div(
            class = "small",
            tags$div(sprintf("%d entries parsed from .bib file", diag$total_entries)),
            tags$div(sprintf("%d entries had DOI fields", diag$entries_with_doi)),
            tags$div(class = "text-muted",
                     sprintf("%d entries skipped (no DOI)", diag$entries_without_doi))
          )
        )
      }

      showModal(modalDialog(
        title = title,
        tags$div(
          class = "d-flex gap-4 mb-3",
          tags$div(
            class = "text-center",
            tags$h3(class = "text-success mb-0", result$imported_count),
            tags$small(class = "text-muted", "imported")
          ),
          tags$div(
            class = "text-center",
            tags$h3(class = if (result$failed_count > 0) "text-danger mb-0" else "text-muted mb-0",
                     result$failed_count),
            tags$small(class = "text-muted", "failed")
          ),
          tags$div(
            class = "text-center",
            tags$h3(class = "text-muted mb-0", skipped),
            tags$small(class = "text-muted", "skipped")
          )
        ),
        bib_detail_ui,
        error_ui,
        footer = do.call(tagList, footer_buttons),
        size = "m",
        easyClose = TRUE
      ))
    }

    # --- Retry Failed DOIs ---
    observeEvent(input$retry_failed, {
      run_id <- current_run_id()
      req(run_id)

      failed_items <- get_failed_import_items(con(), run_id)
      req(nrow(failed_items) > 0)

      # Reset and re-import
      retry_dois <- failed_items$doi
      new_dois(retry_dois)
      duplicate_dois(character())
      malformed_dois(NULL)

      removeModal()

      # Trigger import directly
      nb_id <- notebook_id()
      cfg <- config()
      email <- get_setting(cfg, "openalex", "email") %||% ""
      api_key <- get_setting(cfg, "openalex", "api_key")
      run_name <- paste0("Retry - ", Sys.Date())

      total_count <- length(retry_dois)
      new_run_id <- create_import_run(con(), nb_id, run_name, total_count, source = "doi_bulk")
      current_run_id(new_run_id)

      flag_file <- create_interrupt_flag(session$token)
      current_interrupt_flag(flag_file)
      prog_file <- create_progress_file(session$token)
      current_progress_file(prog_file)

      showModal(modalDialog(
        title = tagList(icon_spinner(class = "fa-spin"), "Retrying Failed DOIs"),
        tags$div(
          class = "progress", style = "height: 25px;",
          tags$div(id = ns("import_progress_bar"),
                   class = "progress-bar progress-bar-striped progress-bar-animated",
                   role = "progressbar", style = "width: 5%;", "5%")
        ),
        tags$div(id = ns("import_progress_message"), class = "text-muted mt-2",
                 paste("Retrying", length(retry_dois), "DOIs...")),
        footer = actionButton(ns("cancel_import"), "Cancel",
                               class = "btn-warning", icon = icon_stop()),
        easyClose = FALSE
      ))

      import_task$invoke(
        dois = retry_dois,
        email = email,
        api_key = api_key,
        interrupt_flag = flag_file,
        progress_file = prog_file,
        app_dir = getwd(),
        bib_metadata = NULL
      )

      poller <- observe({
        invalidateLater(1000)
        pf <- isolate(current_progress_file())
        prog <- read_import_progress(pf)
        session$sendCustomMessage("updateImportProgress", list(
          bar_id = ns("import_progress_bar"),
          msg_id = ns("import_progress_message"),
          percent = max(prog$pct, 5),
          message = prog$message
        ))
      })
      progress_poller(poller)
    })

    # --- Seed Citation Network Handler (Phase 36) ---
    observeEvent(input$seed_network, {
      run_id <- current_run_id()
      req(run_id)
      con_val <- con()
      run_meta <- dbGetQuery(con_val, "SELECT notebook_id FROM import_runs WHERE id = ?", list(run_id))
      imported <- dbGetQuery(con_val, "
  SELECT a.paper_id
  FROM import_run_items i
  JOIN abstracts a ON i.doi = a.doi
  WHERE i.run_id = ? AND i.status = 'success'
", list(run_id))
      if (nrow(imported) == 0) {
        showNotification("No papers imported yet", type = "warning")
        return()
      }
      network_seed_request(list(
        seed_ids = imported$paper_id,
        source_notebook_id = run_meta$notebook_id[1],
        timestamp = Sys.time()
      ))
      removeModal()
      # Note: No notification here - switching to network view is sufficient feedback
    })

    # --- Import History ---
    output$import_history <- renderUI({
      history_refresh()  # Trigger on refresh
      nb_id <- notebook_id()
      req(nb_id)

      runs <- tryCatch(get_import_runs(con(), nb_id), error = function(e) data.frame())
      if (nrow(runs) == 0) return(NULL)

      run_items <- lapply(seq_len(nrow(runs)), function(i) {
        run <- runs[i, ]
        run_date <- if (!is.null(run$created_at)) format(run$created_at, "%Y-%m-%d %H:%M") else ""
        tags$div(
          class = "border rounded p-2 mb-2",
          tags$div(
            class = "d-flex justify-content-between align-items-start",
            tags$div(
              tags$strong(class = "small", run$name),
              tags$div(class = "text-muted small", run_date)
            ),
            actionButton(
              ns(paste0("delete_run_", run$id)),
              NULL, class = "btn-sm btn-outline-danger",
              icon = icon_delete(), title = "Delete run"
            )
          ),
          tags$div(
            class = "d-flex gap-2 mt-1 small",
            tags$span(class = "text-success", paste(run$imported_count, "imported")),
            if (run$failed_count > 0) tags$span(class = "text-danger", paste(run$failed_count, "failed")),
            if (run$skipped_count > 0) tags$span(class = "text-muted", paste(run$skipped_count, "skipped"))
          )
        )
      })

      do.call(tagList, run_items)
    })

    # --- Delete Run Handlers ---
    # Use observe pattern for dynamic delete buttons
    observe({
      nb_id <- notebook_id()
      req(nb_id)

      runs <- tryCatch(get_import_runs(con(), nb_id), error = function(e) data.frame())
      if (nrow(runs) == 0) return()

      lapply(runs$id, function(rid) {
        btn_id <- paste0("delete_run_", rid)
        observeEvent(input[[btn_id]], {
          tryCatch({
            delete_import_run(con(), rid)
            history_refresh(history_refresh() + 1)
            showNotification("Import run deleted", type = "message")
          }, error = function(e) {
            showNotification(paste("Error deleting run:", conditionMessage(e)), type = "error")
          })
        }, ignoreInit = TRUE, once = TRUE)
      })
    })

    # Return API for parent module
    list(
      show_import_modal = show_import_modal,
      network_seed_request = network_seed_request
    )
  })
}
