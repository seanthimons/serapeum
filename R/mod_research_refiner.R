#' Research Refiner Module UI
#' @param id Module ID
mod_research_refiner_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(
      class = "container-fluid p-3",
      # Header
      div(
        class = "d-flex align-items-center gap-2 mb-3",
        icon_funnel(class = "fa-2x text-primary"),
        div(
          h3("Research Refiner", class = "mb-0"),
          p(class = "text-muted mb-0 small",
            "Score and rank papers against your research anchor")
        )
      ),

      # Step 1: Define Anchor
      div(
        class = "card mb-3",
        div(
          class = "card-header",
          strong("Step 1: Define Anchor")
        ),
        div(
          class = "card-body",
          radioButtons(ns("anchor_type"), "Anchor Type",
                       choices = c("Seed Papers" = "seeds",
                                   "Research Intent" = "intent",
                                   "Both" = "both"),
                       selected = "seeds", inline = TRUE),
          conditionalPanel(
            condition = sprintf("input['%s'] === 'seeds' || input['%s'] === 'both'",
                                ns("anchor_type"), ns("anchor_type")),
            div(
              class = "mb-3",
              textInput(ns("seed_doi"), "Seed Paper DOI or OpenAlex ID",
                        placeholder = "e.g., 10.1234/example or W2741809807"),
              div(
                class = "d-flex gap-2",
                actionButton(ns("add_seed"), "Add Seed",
                             icon = icon("plus"), class = "btn-sm btn-outline-primary"),
                actionButton(ns("clear_seeds"), "Clear All",
                             icon = icon("times"), class = "btn-sm btn-outline-secondary")
              ),
              uiOutput(ns("seed_list"))
            )
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] === 'intent' || input['%s'] === 'both'",
                                ns("anchor_type"), ns("anchor_type")),
            textAreaInput(ns("anchor_intent"),
                          "Research Intent",
                          placeholder = "Describe what you're looking for, e.g., 'How do transformers improve clinical NLP outcomes compared to traditional methods?'",
                          rows = 3)
          )
        )
      ),

      # Step 2: Select Candidates
      div(
        class = "card mb-3",
        div(
          class = "card-header",
          strong("Step 2: Select Candidates")
        ),
        div(
          class = "card-body",
          radioButtons(ns("source_type"), "Candidate Source",
                       choices = c("From Notebook" = "notebook",
                                   "Fetch from Seeds" = "fetch"),
                       selected = "notebook", inline = TRUE),
          conditionalPanel(
            condition = sprintf("input['%s'] === 'notebook'", ns("source_type")),
            uiOutput(ns("notebook_selector"))
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] === 'fetch'", ns("source_type")),
            p(class = "text-muted small",
              "Will fetch citing, cited, and related papers for each seed from OpenAlex.")
          ),
          uiOutput(ns("candidate_count_badge"))
        )
      ),

      # Step 3: Scoring Mode
      div(
        class = "card mb-3",
        div(
          class = "card-header",
          strong("Step 3: Scoring Mode")
        ),
        div(
          class = "card-body",
          layout_columns(
            col_widths = c(6, 6),
            selectInput(ns("scoring_mode"), "Mode",
                        choices = c("Discovery" = "discovery",
                                    "Comprehensive" = "comprehensive",
                                    "Emerging" = "emerging"),
                        selected = "discovery"),
            div(
              class = "d-flex align-items-end h-100",
              checkboxInput(ns("show_advanced"), "Show Advanced Weights",
                            value = FALSE)
            )
          ),
          # Mode description
          uiOutput(ns("mode_description")),
          # Advanced weight sliders
          conditionalPanel(
            condition = sprintf("input['%s'] === true", ns("show_advanced")),
            div(
              class = "border rounded p-3 mt-2 bg-body-secondary",
              layout_columns(
                col_widths = c(4, 4, 4),
                sliderInput(ns("w1"), "Seed Connectivity",
                            min = 0, max = 1, value = 0.25, step = 0.05),
                sliderInput(ns("w2"), "Bridge Score",
                            min = 0, max = 1, value = 0.30, step = 0.05),
                sliderInput(ns("w3"), "Citation Velocity",
                            min = 0, max = 1, value = 0.20, step = 0.05)
              ),
              layout_columns(
                col_widths = c(6, 6),
                sliderInput(ns("w4"), "FWCI",
                            min = 0, max = 1, value = 0.15, step = 0.05),
                sliderInput(ns("w5"), "Ubiquity Penalty",
                            min = 0, max = 1, value = 0.30, step = 0.05)
              )
            )
          )
        )
      ),

      # Score button
      div(
        class = "d-grid mb-3",
        actionButton(ns("run_scoring"), "Score Papers",
                     icon = icon_funnel(), class = "btn-primary btn-lg")
      ),

      # Results section
      uiOutput(ns("results_section")),

      # Curation actions
      uiOutput(ns("curation_section"))
    )
  )
}

#' Research Refiner Module Server
#'
#' @param id Module ID
#' @param con_r Reactive DuckDB connection
#' @param config_r Reactive config
#' @param notebook_refresh ReactiveVal for triggering notebook list refresh
#' @param navigate_to_notebook Callback function(notebook_id)
mod_research_refiner_server <- function(id, con_r, config_r,
                                         notebook_refresh = NULL,
                                         navigate_to_notebook = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # --- Reactive state ---
    seed_papers <- reactiveVal(list())  # List of parsed seed paper objects
    scored_results <- reactiveVal(NULL)  # Data frame of scored candidates
    current_run_id <- reactiveVal(NULL)

    # --- Notebook selector ---
    output$notebook_selector <- renderUI({
      con <- con_r()
      req(con)
      if (!is.null(notebook_refresh)) notebook_refresh()
      nbs <- list_notebooks(con)
      search_nbs <- nbs[nbs$type == "search", , drop = FALSE]
      choices <- if (nrow(search_nbs) > 0) {
        setNames(search_nbs$id, search_nbs$name)
      } else {
        c("No search notebooks" = "")
      }
      selectInput(ns("source_notebook_id"), "Search Notebook",
                  choices = choices, width = "100%")
    })

    # --- Add seed paper ---
    observeEvent(input$add_seed, {
      seed_input <- trimws(input$seed_doi)
      if (nchar(seed_input) == 0) return()

      cfg <- config_r()
      email <- get_setting(cfg, "openalex", "email")
      api_key <- get_setting(cfg, "openalex", "api_key")

      if (is.null(email) || nchar(email) == 0) {
        showNotification("Please set your OpenAlex email in Settings first.",
                         type = "error")
        return()
      }

      # Determine if input is DOI or OpenAlex ID
      if (grepl("^W\\d+$", seed_input) || grepl("^w\\d+$", seed_input)) {
        # OpenAlex ID
        filter_val <- paste0("openalex_id:", toupper(seed_input))
      } else {
        # Treat as DOI
        doi <- normalize_doi_bare(seed_input)
        filter_val <- paste0("doi:", doi)
      }

      # Look up paper in OpenAlex
      withProgress(message = "Looking up seed paper...", {
        tryCatch({
          req_obj <- build_openalex_request("works", email, api_key) |>
            req_url_query(filter = filter_val)
          resp <- req_perform(req_obj)
          body <- resp_body_json(resp)

          if (is.null(body$results) || length(body$results) == 0) {
            showNotification("Paper not found in OpenAlex.", type = "warning")
            return()
          }

          parsed <- parse_openalex_work(body$results[[1]])

          # Check for duplicates
          existing <- seed_papers()
          if (parsed$paper_id %in% vapply(existing, function(p) p$paper_id, character(1))) {
            showNotification("This paper is already added as a seed.", type = "warning")
            return()
          }

          seed_papers(c(existing, list(parsed)))
          updateTextInput(session, "seed_doi", value = "")
          showNotification(paste("Added seed:", parsed$title), type = "message")
        }, error = function(e) {
          err <- classify_api_error(e, "OpenAlex")
          showNotification(err$message, type = "error")
        })
      })
    })

    # --- Clear seeds ---
    observeEvent(input$clear_seeds, {
      seed_papers(list())
    })

    # --- Render seed list ---
    output$seed_list <- renderUI({
      seeds <- seed_papers()
      if (length(seeds) == 0) return(NULL)
      div(
        class = "mt-2",
        lapply(seq_along(seeds), function(i) {
          p <- seeds[[i]]
          div(
            class = "d-flex align-items-center justify-content-between border rounded p-2 mb-1",
            div(
              class = "text-truncate me-2",
              strong(class = "small", p$title),
              span(class = "text-muted small ms-1",
                   paste0("(", p$year, ", ", p$cited_by_count, " citations)"))
            ),
            actionButton(ns(paste0("remove_seed_", i)), NULL,
                         icon = icon("times"),
                         class = "btn-sm btn-link text-muted p-0")
          )
        })
      )
    })

    # --- Remove individual seeds ---
    observe({
      seeds <- seed_papers()
      lapply(seq_along(seeds), function(i) {
        observeEvent(input[[paste0("remove_seed_", i)]], {
          current <- seed_papers()
          if (i <= length(current)) {
            seed_papers(current[-i])
          }
        }, ignoreInit = TRUE, once = TRUE)
      })
    })

    # --- Mode description ---
    output$mode_description <- renderUI({
      mode <- input$scoring_mode
      desc <- switch(mode,
        discovery = "Find what you're missing — favors bridge papers, novel connections, and emerging work.",
        comprehensive = "Build the full picture — broad coverage with high-impact papers.",
        emerging = "What's new and rising — recent papers with high citation velocity."
      )
      p(class = "text-muted small fst-italic", desc)
    })

    # --- Update sliders when mode changes ---
    observeEvent(input$scoring_mode, {
      if (!isTRUE(input$show_advanced)) return()
      weights <- get_preset_weights(input$scoring_mode)
      updateSliderInput(session, "w1", value = weights$w1)
      updateSliderInput(session, "w2", value = weights$w2)
      updateSliderInput(session, "w3", value = weights$w3)
      updateSliderInput(session, "w4", value = weights$w4)
      updateSliderInput(session, "w5", value = weights$w5)
    })

    # --- Candidate count badge ---
    output$candidate_count_badge <- renderUI({
      if (input$source_type == "notebook") {
        nb_id <- input$source_notebook_id
        if (is.null(nb_id) || nchar(nb_id) == 0) return(NULL)
        con <- con_r()
        count <- dbGetQuery(con, "SELECT COUNT(*) as n FROM abstracts WHERE notebook_id = ?",
                            list(nb_id))
        span(class = "badge bg-secondary mt-2", paste0(count$n, " papers available"))
      } else {
        seeds <- seed_papers()
        if (length(seeds) == 0) return(NULL)
        span(class = "badge bg-info mt-2",
             paste0(length(seeds), " seed(s) — papers will be fetched from OpenAlex"))
      }
    })

    # --- Get current weights ---
    get_current_weights <- reactive({
      if (isTRUE(input$show_advanced)) {
        list(
          w1 = input$w1 %||% 0.25,
          w2 = input$w2 %||% 0.30,
          w3 = input$w3 %||% 0.20,
          w4 = input$w4 %||% 0.15,
          w5 = input$w5 %||% 0.30
        )
      } else {
        get_preset_weights(input$scoring_mode %||% "discovery")
      }
    })

    # --- Run scoring ---
    observeEvent(input$run_scoring, {
      con <- con_r()
      cfg <- config_r()
      email <- get_setting(cfg, "openalex", "email")
      api_key <- get_setting(cfg, "openalex", "api_key")

      if (is.null(email) || nchar(email) == 0) {
        showNotification("Please set your OpenAlex email in Settings first.",
                         type = "error")
        return()
      }

      seeds <- seed_papers()
      anchor_type <- input$anchor_type

      # Validate anchor
      if (anchor_type %in% c("seeds", "both") && length(seeds) == 0) {
        showNotification("Please add at least one seed paper.", type = "warning")
        return()
      }
      if (anchor_type %in% c("intent", "both") &&
          (is.null(input$anchor_intent) || nchar(trimws(input$anchor_intent)) == 0)) {
        showNotification("Please enter a research intent.", type = "warning")
        return()
      }

      weights <- get_current_weights()
      seed_ids <- vapply(seeds, function(p) p$paper_id, character(1))

      withProgress(message = "Scoring papers...", {
        # Step 1: Get candidates
        incProgress(0.1, detail = "Loading candidates...")

        if (input$source_type == "notebook") {
          nb_id <- input$source_notebook_id
          if (is.null(nb_id) || nchar(nb_id) == 0) {
            showNotification("Please select a source notebook.", type = "warning")
            return()
          }
          candidates <- prepare_candidates_from_notebook(con, nb_id, exclude_ids = seed_ids)
        } else {
          candidates <- fetch_candidates_from_seeds(seed_ids, email, api_key,
                                                     per_page = 50)
        }

        if (nrow(candidates) == 0) {
          showNotification("No candidates found to score.", type = "warning")
          return()
        }

        # Step 2: Compute seed connectivity (if we have seeds)
        incProgress(0.3, detail = "Computing connectivity...")
        if (length(seed_ids) > 0) {
          anchor_data <- tryCatch(
            fetch_anchor_refs(seed_ids, email, api_key),
            error = function(e) {
              list(anchor_refs = list(), anchor_ids = seed_ids, anchor_papers = list())
            }
          )
          candidates$seed_connectivity <- compute_pool_connectivity(candidates, anchor_data)
        }

        # Step 3: Score candidates
        incProgress(0.5, detail = "Scoring candidates...")
        scored <- score_candidate_pool(candidates, weights)

        # Step 4: Save to DB
        incProgress(0.8, detail = "Saving results...")
        run_id <- create_refiner_run(
          con,
          anchor_type = anchor_type,
          source_type = input$source_type,
          anchor_intent = if (anchor_type %in% c("intent", "both")) input$anchor_intent else NULL,
          anchor_seed_ids = if (length(seed_ids) > 0) jsonlite::toJSON(seed_ids) else NULL,
          source_notebook_id = if (input$source_type == "notebook") input$source_notebook_id else NULL,
          mode = input$scoring_mode,
          weights = jsonlite::toJSON(weights, auto_unbox = TRUE)
        )

        save_refiner_results(con, run_id, scored)
        update_refiner_run(con, run_id,
                           status = "completed",
                           total_candidates = nrow(scored),
                           scored_count = nrow(scored))

        current_run_id(run_id)
        scored_results(scored)

        incProgress(1.0, detail = "Done!")
      })

      # Check for missing data and warn
      has_connectivity <- any(!is.na(scored_results()$seed_connectivity))
      has_fwci <- any(!is.na(scored_results()$fwci))

      warnings <- character(0)
      if (!has_connectivity) {
        warnings <- c(warnings, "Seed connectivity data unavailable — scoring based on citation metrics only.")
      }
      if (!has_fwci) {
        warnings <- c(warnings, "FWCI data unavailable for all papers — excluded from scoring.")
      }
      if (length(warnings) > 0) {
        showNotification(
          paste(warnings, collapse = " "),
          type = "warning", duration = 8
        )
      }

      showNotification(
        paste("Scored", nrow(scored_results()), "candidates"),
        type = "message"
      )
    })

    # --- Results section ---
    output$results_section <- renderUI({
      results <- scored_results()
      if (is.null(results) || nrow(results) == 0) return(NULL)

      div(
        class = "card mb-3",
        div(
          class = "card-header d-flex justify-content-between align-items-center",
          strong(paste("Results:", nrow(results), "papers scored")),
          div(
            class = "d-flex gap-2",
            actionButton(ns("accept_top_n"), "Accept Top 25",
                         icon = icon("check"), class = "btn-sm btn-outline-success"),
            actionButton(ns("reject_below_median"), "Reject Bottom Half",
                         icon = icon("times"), class = "btn-sm btn-outline-danger")
          )
        ),
        div(
          class = "card-body p-0",
          style = "max-height: 600px; overflow-y: auto;",
          div(
            class = "list-group list-group-flush",
            lapply(seq_len(min(nrow(results), 100)), function(i) {
              r <- results[i, ]
              action <- if (!is.null(r$user_action)) r$user_action else "pending"
              bg_class <- switch(action,
                accepted = "list-group-item-success",
                rejected = "list-group-item-danger",
                ""
              )

              # Parse authors for display
              authors_display <- tryCatch({
                au <- jsonlite::fromJSON(r$authors)
                if (length(au) > 3) paste(c(au[1:3], "et al."), collapse = ", ")
                else paste(au, collapse = ", ")
              }, error = function(e) r$authors %||% "")

              div(
                class = paste("list-group-item", bg_class),
                div(
                  class = "d-flex justify-content-between align-items-start",
                  div(
                    class = "flex-grow-1 me-3",
                    div(
                      class = "d-flex align-items-center gap-2",
                      span(class = "badge bg-primary", paste0("#", r$rank)),
                      strong(r$title)
                    ),
                    div(
                      class = "small text-muted mt-1",
                      paste0(
                        authors_display,
                        if (!is.na(r$year)) paste0(" | ", r$year) else "",
                        if (!is.na(r$venue) && nchar(r$venue) > 0) paste0(" | ", r$venue) else ""
                      )
                    ),
                    div(
                      class = "small mt-1",
                      span(class = "badge bg-secondary me-1",
                           paste0(r$cited_by_count, " cit")),
                      if (!is.na(r$citation_velocity)) {
                        span(class = "badge bg-info me-1",
                             paste0(round(r$citation_velocity, 1), " cit/yr"))
                      },
                      if (!is.na(r$fwci)) {
                        span(class = "badge bg-warning me-1",
                             paste0("FWCI ", round(r$fwci, 2)))
                      },
                      if (!is.na(r$seed_connectivity) && r$seed_connectivity > 0) {
                        span(class = "badge bg-success me-1",
                             paste0(r$seed_connectivity, " seed links"))
                      }
                    )
                  ),
                  div(
                    class = "d-flex flex-column gap-1 align-items-end",
                    span(class = "badge bg-primary fs-6",
                         paste0("Score: ", round(r$utility_score, 3))),
                    div(
                      class = "btn-group btn-group-sm",
                      actionButton(ns(paste0("accept_", i)), NULL,
                                   icon = icon("check"),
                                   class = if (action == "accepted") "btn-success" else "btn-outline-success"),
                      actionButton(ns(paste0("reject_", i)), NULL,
                                   icon = icon("times"),
                                   class = if (action == "rejected") "btn-danger" else "btn-outline-danger")
                    )
                  )
                )
              )
            })
          )
        )
      )
    })

    # --- Accept/reject individual papers ---
    observe({
      results <- scored_results()
      if (is.null(results) || nrow(results) == 0) return()

      n <- min(nrow(results), 100)
      lapply(seq_len(n), function(i) {
        observeEvent(input[[paste0("accept_", i)]], {
          con <- con_r()
          run_id <- current_run_id()
          results <- scored_results()
          r <- results[i, ]

          # Toggle: if already accepted, revert to pending
          new_action <- if (!is.null(r$user_action) && r$user_action == "accepted") "pending" else "accepted"

          # Update in DB using paper_id match
          dbExecute(con, "
            UPDATE refiner_results SET user_action = ?
            WHERE run_id = ? AND paper_id = ?
          ", list(new_action, run_id, r$paper_id))

          # Update local state
          results$user_action[i] <- new_action
          scored_results(results)
        }, ignoreInit = TRUE)

        observeEvent(input[[paste0("reject_", i)]], {
          con <- con_r()
          run_id <- current_run_id()
          results <- scored_results()
          r <- results[i, ]

          new_action <- if (!is.null(r$user_action) && r$user_action == "rejected") "pending" else "rejected"

          dbExecute(con, "
            UPDATE refiner_results SET user_action = ?
            WHERE run_id = ? AND paper_id = ?
          ", list(new_action, run_id, r$paper_id))

          results$user_action[i] <- new_action
          scored_results(results)
        }, ignoreInit = TRUE)
      })
    })

    # --- Batch accept top N ---
    observeEvent(input$accept_top_n, {
      con <- con_r()
      run_id <- current_run_id()
      results <- scored_results()
      req(results, run_id)

      n <- min(25, nrow(results))
      top_ids <- results$paper_id[1:n]

      # Update DB
      for (pid in top_ids) {
        dbExecute(con, "
          UPDATE refiner_results SET user_action = 'accepted'
          WHERE run_id = ? AND paper_id = ?
        ", list(run_id, pid))
      }

      # Update local state
      results$user_action[1:n] <- "accepted"
      scored_results(results)

      showNotification(paste("Accepted top", n, "papers"), type = "message")
    })

    # --- Reject bottom half ---
    observeEvent(input$reject_below_median, {
      con <- con_r()
      run_id <- current_run_id()
      results <- scored_results()
      req(results, run_id)

      mid <- ceiling(nrow(results) / 2)
      if (mid >= nrow(results)) return()

      bottom_ids <- results$paper_id[(mid + 1):nrow(results)]

      for (pid in bottom_ids) {
        dbExecute(con, "
          UPDATE refiner_results SET user_action = 'rejected'
          WHERE run_id = ? AND paper_id = ?
        ", list(run_id, pid))
      }

      results$user_action[(mid + 1):nrow(results)] <- "rejected"
      scored_results(results)

      showNotification(paste("Rejected", length(bottom_ids), "papers"), type = "message")
    })

    # --- Curation section ---
    output$curation_section <- renderUI({
      results <- scored_results()
      if (is.null(results)) return(NULL)

      accepted_count <- sum(results$user_action == "accepted", na.rm = TRUE)
      if (accepted_count == 0) return(NULL)

      con <- con_r()
      nbs <- list_notebooks(con)

      div(
        class = "card mb-3",
        div(
          class = "card-header",
          strong(paste("Export:", accepted_count, "accepted papers"))
        ),
        div(
          class = "card-body",
          layout_columns(
            col_widths = c(6, 3, 3),
            selectInput(ns("target_notebook"), "Import into Notebook",
                        choices = c("Create New Notebook" = "__new__",
                                    setNames(nbs$id, nbs$name))),
            conditionalPanel(
              condition = sprintf("input['%s'] === '__new__'", ns("target_notebook")),
              textInput(ns("new_nb_name"), "New Notebook Name",
                        placeholder = "e.g., Refined Results")
            ),
            div(
              class = "d-flex align-items-end h-100",
              actionButton(ns("import_accepted"), "Import Papers",
                           icon = icon_file_import(),
                           class = "btn-success")
            )
          )
        )
      )
    })

    # --- Import accepted papers ---
    observeEvent(input$import_accepted, {
      con <- con_r()
      results <- scored_results()
      req(results)

      accepted <- results[results$user_action == "accepted", , drop = FALSE]
      if (nrow(accepted) == 0) {
        showNotification("No accepted papers to import.", type = "warning")
        return()
      }

      # Determine target notebook
      target <- input$target_notebook
      if (target == "__new__") {
        nb_name <- trimws(input$new_nb_name %||% "")
        if (nchar(nb_name) == 0) {
          showNotification("Please enter a name for the new notebook.", type = "warning")
          return()
        }
        target <- create_notebook(con, nb_name, "search")
      }

      # Import papers
      imported <- 0
      withProgress(message = "Importing papers...", {
        for (j in seq_len(nrow(accepted))) {
          p <- accepted[j, ]

          # Check for duplicate
          existing <- dbGetQuery(con, "
            SELECT id FROM abstracts WHERE notebook_id = ? AND paper_id = ?
          ", list(target, p$paper_id))
          if (nrow(existing) > 0) next

          abstract_id <- create_abstract(
            con, target, p$paper_id, p$title,
            p$authors, p$abstract,
            p$year, p$venue, NULL,
            cited_by_count = p$cited_by_count,
            fwci = p$fwci,
            doi = p$doi
          )

          # Create chunk for abstract text
          if (!is.na(p$abstract) && nchar(p$abstract) > 0) {
            create_chunk(con, abstract_id, "abstract", 0, p$abstract)
          }

          imported <- imported + 1
          incProgress(j / nrow(accepted))
        }
      })

      if (!is.null(notebook_refresh)) {
        notebook_refresh(notebook_refresh() + 1)
      }

      showNotification(
        paste("Imported", imported, "papers into notebook"),
        type = "message"
      )

      # Navigate to the target notebook
      if (!is.null(navigate_to_notebook)) {
        navigate_to_notebook(target)
      }
    })
  })
}
