#' Citation Audit Module UI
#' @param id Module ID
mod_citation_audit_ui <- function(id) {
  ns <- NS(id)
  tagList(
    tags$script(src = "js/audit-progress.js"),
    div(
      class = "container-fluid p-3",
      # Header
      div(
        class = "d-flex align-items-center gap-2 mb-3",
        icon("magnifying-glass-chart", class = "fa-2x text-primary"),
        div(
          h3("Citation Audit", class = "mb-0"),
          p(class = "text-muted mb-0 small",
            "Find frequently-cited papers missing from your collection")
        )
      ),

      # Controls row
      div(
        class = "card mb-3",
        div(
          class = "card-body",
          layout_columns(
            col_widths = c(5, 4, 3),
            uiOutput(ns("notebook_selector")),
            div(
              class = "d-flex align-items-end gap-2 h-100",
              actionButton(ns("run_audit"), "Run Analysis",
                           icon = icon("play"), class = "btn-primary"),
              uiOutput(ns("last_analyzed_text"))
            ),
            div(
              class = "d-flex align-items-end justify-content-end",
              uiOutput(ns("paper_count_badge"))
            )
          )
        )
      ),

      # Warning banner for partial results
      uiOutput(ns("partial_warning")),

      # Summary cards
      uiOutput(ns("summary_cards")),

      # Results section
      uiOutput(ns("results_section"))
    )
  )
}

#' Citation Audit Module Server
#'
#' @param id Module ID
#' @param con DuckDB connection
#' @param config_r Reactive config (for email/API key)
#' @param db_path DB file path string
#' @param navigate_to_notebook Callback function(notebook_id) to navigate to notebook
mod_citation_audit_server <- function(id, con, config_r, db_path,
                                       navigate_to_notebook = NULL,
                                       notebook_refresh = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # --- Reactive state ---
    audit_results <- reactiveVal(NULL)
    audit_run <- reactiveVal(NULL)
    selected_ids <- reactiveVal(character(0))
    current_interrupt_flag <- reactiveVal(NULL)
    current_progress_file <- reactiveVal(NULL)

    # --- Notebook list ---
    notebooks <- reactive({
      # Re-query when notebooks change (e.g., new notebook created via bulk import)
      if (!is.null(notebook_refresh)) notebook_refresh()
      nbs <- list_notebooks(con)
      if (nrow(nbs) == 0) return(nbs)
      nbs[nbs$type == "search", , drop = FALSE]
    })

    output$notebook_selector <- renderUI({
      nbs <- notebooks()
      choices <- if (nrow(nbs) > 0) {
        setNames(nbs$id, nbs$name)
      } else {
        c("No search notebooks" = "")
      }
      selectInput(ns("notebook_id"), "Search Notebook",
                  choices = choices, width = "100%")
    })

    # --- Paper count badge ---
    output$paper_count_badge <- renderUI({
      req(input$notebook_id, nchar(input$notebook_id) > 0)
      papers <- dbGetQuery(con, "
        SELECT COUNT(*) as n FROM abstracts WHERE notebook_id = ?
      ", list(input$notebook_id))
      span(class = "badge bg-secondary", paste0(papers$n, " papers"))
    })

    # --- Load cached results when notebook changes ---
    observeEvent(input$notebook_id, {
      req(nchar(input$notebook_id) > 0)
      nb_id <- input$notebook_id

      latest <- get_latest_audit_run(con, nb_id)
      if (!is.null(latest) && latest$status %in% c("completed", "cancelled")) {
        # Refresh imported flags
        check_audit_imports(con, latest$id, nb_id)
        results <- get_audit_results(con, latest$id)
        audit_run(latest)
        audit_results(results)
      } else {
        audit_run(NULL)
        audit_results(NULL)
      }
      selected_ids(character(0))
    })

    # --- Last analyzed text ---
    output$last_analyzed_text <- renderUI({
      run <- audit_run()
      if (is.null(run)) return(NULL)
      ts <- if (!is.null(run$completed_at) && !is.na(run$completed_at)) {
        format(as.POSIXct(run$completed_at), "%Y-%m-%d %H:%M")
      } else {
        format(as.POSIXct(run$created_at), "%Y-%m-%d %H:%M")
      }
      span(class = "text-muted small", paste("Last analyzed:", ts))
    })

    # --- Partial results warning ---
    output$partial_warning <- renderUI({
      run <- audit_run()
      if (is.null(run) || run$status != "cancelled") return(NULL)
      div(
        class = "alert alert-warning d-flex align-items-center mb-3",
        icon("triangle-exclamation", class = "me-2"),
        "Results may be incomplete -- analysis was cancelled or encountered errors."
      )
    })

    # --- Summary cards ---
    output$summary_cards <- renderUI({
      run <- audit_run()
      if (is.null(run)) return(NULL)

      layout_columns(
        col_widths = c(3, 3, 3, 3),
        value_box(
          title = "Papers Analyzed",
          value = format(run$total_papers, big.mark = ","),
          showcase = bsicons::bs_icon("file-text"),
          theme = "primary"
        ),
        value_box(
          title = "Backward Refs",
          value = format(run$backward_count, big.mark = ","),
          showcase = bsicons::bs_icon("arrow-left"),
          theme = "info"
        ),
        value_box(
          title = "Forward Citations",
          value = format(run$forward_count, big.mark = ","),
          showcase = bsicons::bs_icon("arrow-right"),
          theme = "info"
        ),
        value_box(
          title = "Missing Papers Found",
          value = format(run$missing_found, big.mark = ","),
          showcase = bsicons::bs_icon("search"),
          theme = "success"
        )
      )
    })

    # --- ExtendedTask for async audit ---
    audit_task <- ExtendedTask$new(function(notebook_id, email, api_key,
                                             interrupt_flag, progress_file,
                                             db_path_val, app_dir) {
      mirai::mirai({
        setwd(app_dir)
        source("R/config.R")
        source("R/utils_doi.R")
        source("R/db_migrations.R")
        source("R/db.R")
        source("R/api_openalex.R")
        source("R/interrupt.R")
        source("R/citation_audit.R")
        run_citation_audit(notebook_id, email, api_key, db_path_val,
                           interrupt_flag, progress_file)
      }, notebook_id = notebook_id, email = email, api_key = api_key,
         interrupt_flag = interrupt_flag, progress_file = progress_file,
         db_path_val = db_path_val, app_dir = app_dir)
    })

    # --- Run audit handler ---
    observeEvent(input$run_audit, {
      req(input$notebook_id, nchar(input$notebook_id) > 0)

      # Get config
      cfg <- config_r()
      email <- get_setting(cfg, "openalex", "email")
      api_key <- get_setting(cfg, "openalex", "api_key")

      if (is.null(email) || nchar(email) == 0) {
        showNotification("Please set your OpenAlex email in Settings first.",
                         type = "error")
        return()
      }

      # Create interrupt flag and progress file
      flag <- create_interrupt_flag(session$token)
      pf <- tempfile(pattern = "serapeum_audit_progress_", fileext = ".progress")
      write_audit_progress(pf, 0, 3, "Initializing...")
      current_interrupt_flag(flag)
      current_progress_file(pf)

      # Show progress modal
      showModal(modalDialog(
        title = tagList(icon("spinner", class = "fa-spin"), "Analyzing Citations"),
        div(
          class = "mb-3",
          div(
            class = "progress",
            div(id = ns("audit_bar"),
                class = "progress-bar progress-bar-striped progress-bar-animated",
                role = "progressbar",
                style = "width: 0%",
                `aria-valuenow` = "0",
                `aria-valuemin` = "0",
                `aria-valuemax` = "100",
                "0%")
          )
        ),
        p(id = ns("audit_msg"), class = "text-muted", "Initializing..."),
        footer = actionButton(ns("cancel_audit"), "Cancel",
                              class = "btn-warning", icon = icon("stop")),
        size = "m",
        easyClose = FALSE
      ))

      # Invoke task
      audit_task$invoke(
        notebook_id = input$notebook_id,
        email = email,
        api_key = api_key,
        interrupt_flag = flag,
        progress_file = pf,
        db_path_val = db_path,
        app_dir = getwd()
      )
    })

    # --- Progress polling ---
    observe({
      pf <- current_progress_file()
      req(pf)

      invalidateLater(500)

      progress <- read_audit_progress(pf)

      # Map steps to percentages
      pct <- if (progress$step <= 0) {
        0
      } else if (progress$step == 1) {
        # Extract sub-progress from message if available
        base_pct <- 5
        if (grepl("batch (\\d+)/(\\d+)", progress$message)) {
          m <- regmatches(progress$message, regexpr("(\\d+)/(\\d+)", progress$message))
          parts <- strsplit(m, "/")[[1]]
          if (length(parts) == 2) {
            sub_pct <- as.numeric(parts[1]) / as.numeric(parts[2])
            base_pct <- round(5 + sub_pct * 28)
          }
        }
        base_pct
      } else if (progress$step == 2) {
        base_pct <- 34
        if (grepl("paper (\\d+)/(\\d+)", progress$message)) {
          m <- regmatches(progress$message, regexpr("(\\d+)/(\\d+)", progress$message))
          parts <- strsplit(m, "/")[[1]]
          if (length(parts) == 2) {
            sub_pct <- as.numeric(parts[1]) / as.numeric(parts[2])
            base_pct <- round(34 + sub_pct * 32)
          }
        }
        base_pct
      } else if (progress$step == 3) {
        if (grepl("Complete", progress$message)) 100 else 70
      } else {
        100
      }

      session$sendCustomMessage("updateAuditProgress", list(
        bar_id = ns("audit_bar"),
        msg_id = ns("audit_msg"),
        percent = pct,
        message = progress$message
      ))
    })

    # --- Task completion handler ---
    observe({
      result <- audit_task$result()
      req(result)

      removeModal()
      current_progress_file(NULL)
      current_interrupt_flag(NULL)

      if (!is.null(result$error)) {
        showNotification(paste("Audit failed:", result$error), type = "error", duration = 10)
      } else if (result$status == "cancelled") {
        showNotification("Analysis cancelled. Partial results shown.", type = "warning")
      } else {
        showNotification(
          paste0("Found ", result$missing_found, " missing papers"),
          type = "message"
        )
      }

      # Reload results from DB
      if (!is.null(result$run_id)) {
        latest <- get_latest_audit_run(con, input$notebook_id)
        if (!is.null(latest)) {
          check_audit_imports(con, latest$id, input$notebook_id)
          results <- get_audit_results(con, latest$id)
          audit_run(latest)
          audit_results(results)
        }
      }
      selected_ids(character(0))
    })

    # --- Cancel handler ---
    observeEvent(input$cancel_audit, {
      flag <- current_interrupt_flag()
      if (!is.null(flag)) {
        signal_interrupt(flag)
      }
    })

    # --- Results table ---
    output$results_section <- renderUI({
      results <- audit_results()
      if (is.null(results) || nrow(results) == 0) return(NULL)

      # Sort control
      sort_by <- input$sort_by %||% "collection_frequency"
      results <- switch(sort_by,
        "collection_frequency" = results[order(-results$collection_frequency), ],
        "cited_by_count" = results[order(-results$cited_by_count), ],
        "year" = results[order(-results$year, na.last = TRUE), ],
        results
      )

      sel <- selected_ids()

      tagList(
        # Controls bar
        div(
          class = "d-flex justify-content-between align-items-center mb-2",
          div(
            class = "d-flex align-items-center gap-3",
            radioButtons(ns("sort_by"), NULL,
              choices = c("Collection Frequency" = "collection_frequency",
                          "Global Citations" = "cited_by_count",
                          "Year" = "year"),
              selected = sort_by, inline = TRUE
            )
          ),
          div(
            class = "d-flex align-items-center gap-2",
            if (length(sel) > 0) {
              tagList(
                span(class = "badge bg-primary", paste(length(sel), "selected")),
                actionButton(ns("batch_import"), "Import Selected",
                             class = "btn-sm btn-success", icon = icon("download"))
              )
            },
            checkboxInput(ns("select_all"), "Select All", value = FALSE, width = "auto")
          )
        ),

        # Table
        div(
          class = "table-responsive",
          tags$table(
            class = "table table-hover table-sm",
            tags$thead(
              tags$tr(
                tags$th(width = "30px"),  # checkbox
                tags$th("Title"),
                tags$th("Authors", width = "150px"),
                tags$th("Year", width = "60px"),
                tags$th("Backward", width = "80px", class = "text-center"),
                tags$th("Forward", width = "80px", class = "text-center"),
                tags$th("Frequency", width = "90px", class = "text-center"),
                tags$th("Citations", width = "90px", class = "text-center"),
                tags$th(width = "90px")  # action
              )
            ),
            tags$tbody(
              lapply(seq_len(nrow(results)), function(i) {
                row <- results[i, ]
                wid <- row$work_id
                is_imported <- isTRUE(row$imported)
                is_selected <- wid %in% sel

                # Format title
                title_text <- if (!is.na(row$title)) {
                  if (nchar(row$title) > 80) paste0(substr(row$title, 1, 77), "...") else row$title
                } else {
                  wid
                }

                # Title with optional DOI link
                title_el <- if (!is.na(row$doi) && nchar(row$doi) > 0) {
                  tags$a(href = paste0("https://doi.org/", row$doi),
                         target = "_blank", title = row$title %||% "",
                         title_text)
                } else {
                  span(title = row$title %||% "", title_text)
                }

                # Authors (first author + et al.)
                authors_text <- if (!is.na(row$authors) && nchar(row$authors) > 0) {
                  parts <- strsplit(row$authors, ", ")[[1]]
                  if (length(parts) > 1) paste0(parts[1], " et al.") else parts[1]
                } else {
                  ""
                }

                tags$tr(
                  class = if (is_imported) "table-success" else NULL,
                  tags$td(
                    if (!is_imported) {
                      checkboxInput(ns(paste0("sel_", wid)), label = NULL,
                                    value = is_selected, width = "20px")
                    }
                  ),
                  tags$td(title_el),
                  tags$td(class = "text-muted small", authors_text),
                  tags$td(class = "text-center", row$year %||% ""),
                  tags$td(class = "text-center", row$backward_count),
                  tags$td(class = "text-center", row$forward_count),
                  tags$td(class = "text-center fw-bold", row$collection_frequency),
                  tags$td(class = "text-center text-muted",
                          format(row$cited_by_count, big.mark = ",")),
                  tags$td(
                    if (is_imported) {
                      span(class = "badge bg-success", "Imported")
                    } else {
                      actionButton(ns(paste0("imp_", wid)), "Import",
                                   class = "btn-sm btn-outline-success",
                                   icon = icon("plus"))
                    }
                  )
                )
              })
            )
          )
        )
      )
    })

    # --- Select all handler ---
    observeEvent(input$select_all, {
      results <- audit_results()
      if (is.null(results) || nrow(results) == 0) return()

      if (isTRUE(input$select_all)) {
        # Select all non-imported
        non_imported <- results$work_id[!results$imported]
        selected_ids(non_imported)
      } else {
        selected_ids(character(0))
      }
    })

    # --- Individual checkbox tracking ---
    observe({
      results <- audit_results()
      if (is.null(results) || nrow(results) == 0) return()

      sel <- character(0)
      for (wid in results$work_id) {
        cb_id <- paste0("sel_", wid)
        if (isTRUE(input[[cb_id]])) {
          sel <- c(sel, wid)
        }
      }
      selected_ids(sel)
    })

    # --- Single import handler ---
    observe({
      results <- audit_results()
      if (is.null(results) || nrow(results) == 0) return()

      for (wid in results$work_id) {
        local({
          my_wid <- wid
          btn_id <- paste0("imp_", my_wid)
          observeEvent(input[[btn_id]], {
            cfg <- config_r()
            email <- get_setting(cfg, "openalex", "email")
            api_key <- get_setting(cfg, "openalex", "api_key")

            result <- import_audit_papers(
              work_ids = my_wid,
              notebook_id = input$notebook_id,
              email = email,
              api_key = api_key,
              db_path = db_path
            )

            if (result$imported_count > 0) {
              showNotification("Paper imported successfully", type = "message")
              # Refresh results
              latest <- get_latest_audit_run(con, input$notebook_id)
              if (!is.null(latest)) {
                check_audit_imports(con, latest$id, input$notebook_id)
                audit_results(get_audit_results(con, latest$id))
              }
            } else {
              showNotification("Import failed", type = "error")
            }
          }, ignoreInit = TRUE, once = TRUE)
        })
      }
    })

    # --- Batch import handler ---
    observeEvent(input$batch_import, {
      sel <- selected_ids()
      req(length(sel) > 0)

      showModal(modalDialog(
        title = "Confirm Batch Import",
        p(paste0("Import ", length(sel), " papers into the selected notebook?")),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("confirm_batch"), "Import",
                       class = "btn-success", icon = icon("download"))
        )
      ))
    })

    observeEvent(input$confirm_batch, {
      removeModal()
      sel <- selected_ids()
      req(length(sel) > 0)

      cfg <- config_r()
      email <- get_setting(cfg, "openalex", "email")
      api_key <- get_setting(cfg, "openalex", "api_key")

      # For small batches, run synchronously
      withProgress(message = paste("Importing", length(sel), "papers..."), {
        result <- import_audit_papers(
          work_ids = sel,
          notebook_id = input$notebook_id,
          email = email,
          api_key = api_key,
          db_path = db_path
        )
      })

      showNotification(
        paste0("Imported ", result$imported_count, " papers",
               if (result$failed_count > 0) paste0(" (", result$failed_count, " failed)") else ""),
        type = if (result$imported_count > 0) "message" else "warning"
      )

      # Refresh results
      latest <- get_latest_audit_run(con, input$notebook_id)
      if (!is.null(latest)) {
        check_audit_imports(con, latest$id, input$notebook_id)
        audit_results(get_audit_results(con, latest$id))
      }
      selected_ids(character(0))

      # Navigate to notebook if callback provided
      if (!is.null(navigate_to_notebook) && result$imported_count > 0) {
        navigate_to_notebook(input$notebook_id)
      }
    })
  })
}
