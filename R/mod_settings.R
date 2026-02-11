#' Settings Module UI
#' @param id Module ID
mod_settings_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header(
      class = "d-flex justify-content-between align-items-center",
      span(icon("gear"), "Settings"),
      actionButton(ns("save"), "Save Settings", class = "btn-primary")
    ),
    card_body(
      layout_columns(
        col_widths = c(6, 6),

        # Left column
        div(
          h5(icon("key"), " API Keys"),
          div(
            class = "d-flex align-items-end gap-2",
            div(
              style = "flex-grow: 1;",
              textInput(ns("openrouter_key"), "OpenRouter API Key",
                        placeholder = "sk-or-...")
            ),
            uiOutput(ns("openrouter_status"))
          ),
          p(class = "text-muted small",
            "Get your key at ", tags$a(href = "https://openrouter.ai/keys",
                                       target = "_blank", "openrouter.ai/keys")),
          hr(),
          div(
            class = "d-flex align-items-end gap-2",
            div(
              style = "flex-grow: 1;",
              textInput(ns("openalex_email"), "OpenAlex Email",
                        placeholder = "your@email.com")
            ),
            uiOutput(ns("openalex_status"))
          ),
          p(class = "text-muted small",
            "Used for polite pool access. Get an API key at ",
            tags$a(href = "https://openalex.org/settings/api",
                   target = "_blank", "openalex.org"))
        ),

        # Right column
        div(
          h5(icon("robot"), " Models"),
          div(
            class = "d-flex align-items-end gap-2",
            div(
              style = "flex-grow: 1;",
              selectizeInput(ns("chat_model"), "Chat Model",
                             choices = format_chat_model_choices(get_default_chat_models()),
                             selected = "moonshotai/kimi-k2.5")
            ),
            actionButton(ns("refresh_chat_models"), NULL,
                         icon = icon("refresh"),
                         class = "btn-outline-secondary btn-sm",
                         title = "Refresh model list",
                         style = "margin-bottom: 15px;")
          ),
          uiOutput(ns("model_info")),
          div(
            class = "d-flex align-items-end gap-2",
            div(
              style = "flex-grow: 1;",
              selectizeInput(ns("embed_model"), "Embedding Model",
                             choices = c(
                               "OpenAI text-embedding-3-small ($0.02/M)" = "openai/text-embedding-3-small",
                               "OpenAI text-embedding-3-large ($0.13/M)" = "openai/text-embedding-3-large",
                               "Google Gemini Embedding ($0.15/M) - MTEB #1" = "google/gemini-embedding-001",
                               "Qwen3 Embedding 8B ($0.01/M) - Budget" = "qwen/qwen3-embedding-8b",
                               "Mistral Embed ($0.10/M)" = "mistralai/mistral-embed-2312"
                             ))
            ),
            actionButton(ns("refresh_embed_models"), NULL,
                         icon = icon("refresh"),
                         class = "btn-outline-secondary btn-sm",
                         title = "Refresh model list",
                         style = "margin-bottom: 15px;")
          ),
          hr(),
          h5(icon("sliders"), " Advanced"),
          layout_columns(
            col_widths = c(6, 6),
            numericInput(ns("chunk_size"), "Chunk Size (words)",
                         value = 500, min = 100, max = 2000, step = 50),
            numericInput(ns("chunk_overlap"), "Chunk Overlap (words)",
                         value = 50, min = 0, max = 200, step = 10)
          ),
          p(class = "text-muted small",
            "Chunk settings affect how documents are split for processing. ",
            "Changes only apply to newly uploaded documents."),
          hr(),
          h5(icon("magnifying-glass"), " Search"),
          numericInput(ns("abstracts_per_search"), "Abstracts per Search",
                       value = 25, min = 5, max = 100, step = 5),
          p(class = "text-muted small",
            "Number of paper abstracts to fetch from OpenAlex per search (max 100)."),
          hr(),
          h5(icon("shield-halved"), " Quality Data"),
          p(class = "text-muted small",
            "Download lists of predatory journals/publishers and retracted papers ",
            "to flag questionable sources in search results."),
          uiOutput(ns("quality_data_status")),
          actionButton(ns("download_quality_data"), "Download Quality Data",
                       class = "btn-outline-secondary btn-sm mt-2",
                       icon = icon("download"))
        )
      )
    )
  )
}

#' Settings Module Server
#' @param id Module ID
#' @param con Database connection (reactive)
#' @param config_rv Reactive value holding current config
mod_settings_server <- function(id, con, config_rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values to trigger model refresh
    refresh_embed_trigger <- reactiveVal(0)
    refresh_chat_trigger <- reactiveVal(0)

    # Store chat models data for info panel
    chat_models_data <- reactiveVal(NULL)

    # Reactive values for API key validation status
    api_status <- reactiveValues(
      openrouter = list(status = "unknown", message = NULL),
      openalex = list(status = "unknown", message = NULL)
    )

    # Minimum key length constant (prevents trivial/accidental values)
    MIN_API_KEY_LENGTH <- 10

    # Helper function to validate OpenRouter key and update status
    validate_and_update_openrouter_status <- function(key) {
      if (is.null(key) || nchar(key) == 0) {
        api_status$openrouter <- list(status = "empty", message = "No API key entered")
      } else if (nchar(key) < MIN_API_KEY_LENGTH) {
        api_status$openrouter <- list(status = "invalid", message = "Key too short")
      } else {
        api_status$openrouter <- list(status = "validating", message = "Checking...")
        
        result <- tryCatch({
          validate_openrouter_key(key)
        }, error = function(e) {
          list(valid = FALSE, error = e$message)
        })
        
        api_status$openrouter <- if (isTRUE(result$valid)) {
          list(status = "valid", message = "API key validated")
        } else {
          list(status = "invalid", message = result$error %||% "Validation failed")
        }
      }
    }

    # Helper function to validate OpenAlex email and update status
    validate_and_update_openalex_status <- function(email) {
      if (is.null(email) || nchar(email) == 0) {
        api_status$openalex <- list(status = "empty", message = "No email entered")
      } else if (!grepl("@", email)) {
        api_status$openalex <- list(status = "invalid", message = "Invalid email format")
      } else {
        api_status$openalex <- list(status = "validating", message = "Checking...")
        
        result <- tryCatch({
          validate_openalex_email(email)
        }, error = function(e) {
          list(valid = FALSE, error = e$message)
        })
        
        api_status$openalex <- if (isTRUE(result$valid)) {
          list(status = "valid", message = "Polite pool access confirmed")
        } else {
          list(status = "invalid", message = result$error %||% "Validation failed")
        }
      }
    }

    # Helper function to update embedding model choices
    update_embed_model_choices <- function(api_key, current_selection = NULL) {
      # Always get models - list_embedding_models returns defaults if API key invalid
      models <- tryCatch({
        list_embedding_models(api_key)
      }, error = function(e) {
        get_default_embedding_models()
      })

      # Ensure we have valid data
      if (is.null(models) || nrow(models) == 0) {
        models <- get_default_embedding_models()
      }

      choices <- setNames(models$id, models$name)

      # Preserve current selection if it exists in new choices
      selected <- if (!is.null(current_selection) && current_selection %in% choices) {
        current_selection
      } else if (length(choices) > 0) {
        choices[[1]]
      } else {
        NULL
      }

      updateSelectizeInput(session, "embed_model",
                           choices = choices,
                           selected = selected)
    }

    # Helper function to update chat model choices
    update_chat_model_choices <- function(api_key, current_selection = NULL) {
      # Always get models - list_chat_models returns defaults if API key invalid
      models <- tryCatch({
        list_chat_models(api_key)
      }, error = function(e) {
        get_default_chat_models()
      })

      # Ensure we have valid data
      if (is.null(models) || nrow(models) == 0) {
        models <- get_default_chat_models()
      }

      # Store models data for info panel
      chat_models_data(models)

      # Update pricing for cost tracking
      tryCatch({
        update_model_pricing(models)
      }, error = function(e) {
        # Silently fail pricing update - not critical
      })

      # Format choices for display
      choices <- format_chat_model_choices(models)

      # Preserve current selection if it exists in new choices
      selected <- if (!is.null(current_selection) && current_selection %in% choices) {
        current_selection
      } else if (length(choices) > 0) {
        choices[[1]]
      } else {
        NULL
      }

      updateSelectizeInput(session, "chat_model",
                           choices = choices,
                           selected = selected)
    }

    # Load current settings on init
    observe({
      cfg <- config_rv()

      # API Keys - prefer DB settings, fall back to config file
      or_key <- get_db_setting(con(), "openrouter_api_key") %||%
                get_setting(cfg, "openrouter", "api_key") %||% ""
      updateTextInput(session, "openrouter_key", value = or_key)

      oa_email <- get_db_setting(con(), "openalex_email") %||%
                  get_setting(cfg, "openalex", "email") %||% ""
      updateTextInput(session, "openalex_email", value = oa_email)

      # Chat model - use dynamic approach
      chat_model <- get_db_setting(con(), "chat_model") %||%
                    get_setting(cfg, "defaults", "chat_model") %||%
                    "moonshotai/kimi-k2.5"
      update_chat_model_choices(or_key, chat_model)

      # Embedding model - get saved selection then populate dropdown
      embed_model <- get_db_setting(con(), "embedding_model") %||%
                     get_setting(cfg, "defaults", "embedding_model") %||%
                     "openai/text-embedding-3-small"
      update_embed_model_choices(or_key, embed_model)

      # Advanced
      chunk_size <- get_db_setting(con(), "chunk_size") %||%
                    get_setting(cfg, "app", "chunk_size") %||% 500
      updateNumericInput(session, "chunk_size", value = chunk_size)

      chunk_overlap <- get_db_setting(con(), "chunk_overlap") %||%
                       get_setting(cfg, "app", "chunk_overlap") %||% 50
      updateNumericInput(session, "chunk_overlap", value = chunk_overlap)

      # Search settings
      abstracts_per_search <- get_db_setting(con(), "abstracts_per_search") %||%
                              get_setting(cfg, "app", "abstracts_per_search") %||% 25
      updateNumericInput(session, "abstracts_per_search", value = abstracts_per_search)

      # Validate initial API key values using helper functions
      validate_and_update_openrouter_status(or_key)
      validate_and_update_openalex_status(oa_email)
    }) |> bindEvent(config_rv(), once = TRUE)

    # Refresh embedding models when API key changes or refresh button clicked
    observe({
      api_key <- input$openrouter_key
      refresh_embed_trigger()  # Also trigger on manual refresh

      # Always update - will use defaults if API key is invalid
      current <- input$embed_model
      update_embed_model_choices(api_key, current)
    }) |> bindEvent(input$openrouter_key, refresh_embed_trigger(), ignoreInit = TRUE)

    # Handle refresh button click
    observeEvent(input$refresh_embed_models, {
      refresh_embed_trigger(refresh_embed_trigger() + 1)
      showNotification("Refreshing embedding models...", type = "message", duration = 2)
    })

    # Refresh chat models when API key changes or refresh button clicked
    observe({
      api_key <- input$openrouter_key
      refresh_chat_trigger()  # Also trigger on manual refresh
      current <- input$chat_model
      update_chat_model_choices(api_key, current)
    }) |> bindEvent(input$openrouter_key, refresh_chat_trigger(), ignoreInit = TRUE)

    # Handle chat model refresh button click
    observeEvent(input$refresh_chat_models, {
      refresh_chat_trigger(refresh_chat_trigger() + 1)
      showNotification("Refreshing chat models...", type = "message", duration = 2)
    })

    # --- API Key Validation ---

    # Helper to render status icon
    render_status_icon <- function(status, message) {
      icon_info <- switch(status,
        "empty" = list(icon = "circle-xmark", class = "text-danger", title = "No value entered"),
        "validating" = list(icon = "spinner", class = "text-primary", title = "Checking..."),
        "valid" = list(icon = "circle-check", class = "text-success", title = message %||% "Validated"),
        "invalid" = list(icon = "circle-exclamation", class = "text-danger", title = message %||% "Invalid"),
        list(icon = "circle-question", class = "text-muted", title = "Unknown status")
      )

      div(
        class = icon_info$class,
        style = "margin-bottom: 15px; font-size: 1.2em; cursor: help;",
        title = icon_info$title,
        icon(icon_info$icon, class = if (status == "validating") "fa-spin" else NULL)
      )
    }

    # Debounced OpenRouter key validation (wait 1 second after typing stops)
    openrouter_key_debounced <- reactive({
      input$openrouter_key
    }) |> debounce(1000)

    observe({
      key <- openrouter_key_debounced()
      validate_and_update_openrouter_status(key)
    })

    output$openrouter_status <- renderUI({
      status <- api_status$openrouter
      render_status_icon(status$status, status$message)
    })

    # Debounced OpenAlex email validation
    openalex_email_debounced <- reactive({
      input$openalex_email
    }) |> debounce(1000)

    observe({
      email <- openalex_email_debounced()
      validate_and_update_openalex_status(email)
    })

    output$openalex_status <- renderUI({
      status <- api_status$openalex
      render_status_icon(status$status, status$message)
    })

    # Model info panel showing details for currently selected chat model
    output$model_info <- renderUI({
      req(input$chat_model)
      models <- chat_models_data()
      req(models)

      selected <- models[models$id == input$chat_model, ]
      if (nrow(selected) == 0) return(NULL)

      row <- selected[1, ]
      tier_badge <- switch(row$tier,
        "budget" = span(class = "badge bg-success", "Budget"),
        "mid" = span(class = "badge bg-primary", "Mid-tier"),
        "premium" = span(class = "badge bg-warning text-dark", "Premium"),
        span(class = "badge bg-secondary", row$tier)
      )

      ctx_display <- if (row$context_length >= 1000000) {
        sprintf("%.1fM tokens", row$context_length / 1000000)
      } else {
        sprintf("%sk tokens", format(round(row$context_length / 1000), big.mark = ","))
      }

      div(
        class = "card card-body bg-light py-2 px-3 mt-2 small",
        div(class = "d-flex justify-content-between align-items-center mb-1",
          span(class = "fw-semibold", row$name),
          tier_badge
        ),
        div(class = "text-muted",
          icon("window-maximize", class = "me-1"), "Context: ", ctx_display,
          span(class = "mx-2", "|"),
          icon("arrow-right-to-bracket", class = "me-1"),
          sprintf("$%.2f/M in", row$prompt_price),
          span(class = "mx-1", "/"),
          sprintf("$%.2f/M out", row$completion_price)
        )
      )
    })

    # Quality data status
    quality_refresh <- reactiveVal(0)

    output$quality_data_status <- renderUI({
      quality_refresh()  # Dependency for refresh

      status <- tryCatch({
        check_quality_cache_status(con())
      }, error = function(e) {
        list(is_empty = TRUE, is_stale = TRUE, last_updated = NULL, sources = list())
      })

      if (status$is_empty) {
        return(div(
          class = "alert alert-warning py-2 small",
          icon("triangle-exclamation"), " No quality data downloaded yet."
        ))
      }

      # Build status for each source
      source_items <- lapply(names(status$sources), function(src) {
        s <- status$sources[[src]]
        icon_class <- if (s$is_stale) "text-warning" else "text-success"
        icon_name <- if (s$is_stale) "clock" else "circle-check"
        tags$li(
          icon(icon_name, class = icon_class),
          " ", gsub("_", " ", src), ": ",
          format(s$record_count, big.mark = ","), " records",
          if (s$is_stale) span(class = "text-warning", " (stale)")
        )
      })

      div(
        class = "small",
        tags$ul(class = "list-unstyled mb-1", source_items),
        div(class = "text-muted",
            "Last updated: ", format(status$last_updated, "%Y-%m-%d %H:%M"))
      )
    })

    # Download quality data
    observeEvent(input$download_quality_data, {
      showNotification("Downloading quality data...", type = "message",
                       id = "quality_download", duration = NULL)

      result <- tryCatch({
        refresh_quality_cache(con())
      }, error = function(e) {
        list(success = FALSE, error = e$message,
             predatory_publishers = list(success = FALSE, error = e$message),
             predatory_journals = list(success = FALSE, error = e$message),
             retraction_watch = list(success = FALSE, error = e$message))
      })

      removeNotification("quality_download")

      if (result$success) {
        showNotification(
          sprintf("Downloaded: %s publishers, %s journals, %s retractions",
                  format(result$predatory_publishers$count, big.mark = ","),
                  format(result$predatory_journals$count, big.mark = ","),
                  format(result$retraction_watch$count, big.mark = ",")),
          type = "message", duration = 5
        )
        quality_refresh(quality_refresh() + 1)
      } else {
        # Show detailed error
        errors <- character()
        if (!result$predatory_publishers$success) {
          errors <- c(errors, paste("Publishers:", result$predatory_publishers$error))
        }
        if (!result$predatory_journals$success) {
          errors <- c(errors, paste("Journals:", result$predatory_journals$error))
        }
        if (!result$retraction_watch$success) {
          errors <- c(errors, paste("Retractions:", result$retraction_watch$error))
        }
        showNotification(
          paste("Download failed:", paste(errors, collapse = "; ")),
          type = "error", duration = 10
        )
      }
    })

    # Save settings
    observeEvent(input$save, {
      tryCatch({
        save_db_setting(con(), "openrouter_api_key", input$openrouter_key)
        save_db_setting(con(), "openalex_email", input$openalex_email)
        save_db_setting(con(), "chat_model", input$chat_model)
        save_db_setting(con(), "embedding_model", input$embed_model)
        save_db_setting(con(), "chunk_size", input$chunk_size)
        save_db_setting(con(), "chunk_overlap", input$chunk_overlap)
        save_db_setting(con(), "abstracts_per_search", input$abstracts_per_search)

        showNotification("Settings saved!", type = "message")
      }, error = function(e) {
        showNotification(paste("Error saving settings:", e$message),
                         type = "error")
      })
    })

    # Return reactive that gets current effective settings
    # This merges config file with DB overrides
    reactive({
      cfg <- config_rv() %||% list()

      list(
        openrouter = list(
          api_key = get_db_setting(con(), "openrouter_api_key") %||%
                    get_setting(cfg, "openrouter", "api_key") %||% ""
        ),
        openalex = list(
          email = get_db_setting(con(), "openalex_email") %||%
                  get_setting(cfg, "openalex", "email") %||% ""
        ),
        defaults = list(
          chat_model = get_db_setting(con(), "chat_model") %||%
                       get_setting(cfg, "defaults", "chat_model") %||%
                       "moonshotai/kimi-k2.5",
          embedding_model = get_db_setting(con(), "embedding_model") %||%
                            get_setting(cfg, "defaults", "embedding_model") %||%
                            "openai/text-embedding-3-small"
        ),
        app = list(
          chunk_size = get_db_setting(con(), "chunk_size") %||%
                       get_setting(cfg, "app", "chunk_size") %||% 500,
          chunk_overlap = get_db_setting(con(), "chunk_overlap") %||%
                          get_setting(cfg, "app", "chunk_overlap") %||% 50,
          abstracts_per_search = get_db_setting(con(), "abstracts_per_search") %||%
                                 get_setting(cfg, "app", "abstracts_per_search") %||% 25
        )
      )
    })
  })
}
