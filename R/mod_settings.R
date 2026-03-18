#' Settings Module UI
#' @param id Module ID
mod_settings_ui <- function(id) {
  ns <- NS(id)

  card(
    fill = FALSE,
    card_header(
      class = "d-flex justify-content-between align-items-center",
      span(icon_settings(), "Settings"),
      actionButton(ns("save"), "Save Settings", class = "btn-primary")
    ),
    card_body(
      layout_columns(
        col_widths = c(6, 6),

        # Left column: API Keys + Advanced + Search + Citation Networks
        div(
          h5(icon_key(), " API Keys"),
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
            "Used for polite pool access (optional if API key is set)."),
          hr(),
          div(
            class = "d-flex align-items-end gap-2",
            div(
              style = "flex-grow: 1;",
              textInput(ns("openalex_api_key"), "OpenAlex API Key",
                        placeholder = "openalex_api_key_...")
            ),
            uiOutput(ns("openalex_key_status"))
          ),
          uiOutput(ns("oa_migration_nudge")),
          p(class = "text-muted small",
            "Free tier: $1/day. Get your key at ",
            tags$a(href = "https://openalex.org/settings/api",
                   target = "_blank", "openalex.org/settings/api")),
          hr(),
          h5(icon_sliders(), " Advanced"),
          checkboxInput(ns("query_reformulation"), "Query Reformulation (RAG-Fusion)",
                        value = TRUE),
          p(class = "text-muted small",
            "When enabled, generates multiple query variants before retrieval ",
            "to improve recall. Adds one small LLM call per chat query."),
          numericInput(ns("chunk_size"), "Chunk Size (words)",
                       value = 500, min = 100, max = 2000, step = 50),
          numericInput(ns("chunk_overlap"), "Chunk Overlap (words)",
                       value = 50, min = 0, max = 200, step = 10),
          p(class = "text-muted small",
            "Chunk settings affect how documents are split for processing. ",
            "Changes only apply to newly uploaded documents."),
          hr(),
          h5(icon_search(), " Search"),
          numericInput(ns("abstracts_per_search"), "Abstracts per Search",
                       value = 25, min = 5, max = 100, step = 5),
          p(class = "text-muted small",
            "Number of paper abstracts to fetch from OpenAlex per search (max 100)."),
          hr(),
          h5(icon_diagram(), " Citation Networks"),
          selectInput(ns("network_palette"), "Color Palette",
                      choices = c(
                        "Viridis (Default)" = "viridis",
                        "Magma" = "magma",
                        "Plasma" = "plasma",
                        "Inferno" = "inferno",
                        "Cividis (Colorblind-safe)" = "cividis"
                      ),
                      selected = "viridis"),
          p(class = "text-muted small",
            "Choose a colorblind-friendly palette for network node colors. Applied to new and loaded networks.")
        ),

        # Right column: Models + Quality Data + DOI Management
        div(
          h5(icon_robot(), " Models"),
          div(
            class = "d-flex align-items-end gap-2",
            div(
              style = "flex-grow: 1;",
              selectizeInput(ns("quality_model"), "Quality Model",
                             choices = format_chat_model_choices(get_default_chat_models()),
                             selected = "google/gemini-3.1-flash-lite-preview")
            ),
            actionButton(ns("refresh_chat_models"), NULL,
                         icon = icon_refresh(),
                         class = "btn-outline-secondary btn-sm mb-3",
                         title = "Refresh model list")
          ),
          p(class = "text-muted small mt-0 mb-2",
            "For: chat, synthesis, analysis, slides, overviews"),
          uiOutput(ns("model_info")),
          div(
            class = "d-flex align-items-end gap-2",
            div(
              style = "flex-grow: 1;",
              selectizeInput(ns("fast_model"), "Fast Model (optional)",
                             choices = c("(Use Quality model)" = "", format_chat_model_choices(get_default_chat_models())),
                             selected = "")
            )
          ),
          uiOutput(ns("fast_model_fallback_hint")),
          p(class = "text-muted small mt-0 mb-2",
            "For: query building, reformulation. Use a cheap/fast model to save costs."),
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
                         icon = icon_refresh(),
                         class = "btn-outline-secondary btn-sm mb-3",
                         title = "Refresh model list")
          ),
          p(class = "text-muted small mt-0 mb-2",
            "For: document indexing and retrieval"),
          uiOutput(ns("embed_dimension_warning")),
          hr(),
          h5(icon_server(), " Providers"),
          p(class = "text-muted small",
            "Add OpenAI-compatible endpoints (Ollama, LM Studio, vLLM) ",
            "to use local models alongside cloud providers."),
          uiOutput(ns("providers_list")),
          actionButton(ns("add_provider"), "Add Provider",
                       class = "btn-outline-secondary btn-sm mt-2",
                       icon = icon_plus()),
          hr(),
          h5(icon_shield(), " Quality Data"),
          p(class = "text-muted small",
            "Download lists of predatory journals/publishers and retracted papers ",
            "to flag questionable sources in search results."),
          uiOutput(ns("quality_data_status")),
          actionButton(ns("download_quality_data"), "Download Quality Data",
                       class = "btn-outline-secondary btn-sm mt-2",
                       icon = icon_download()),
          hr(),
          h5(icon_fingerprint(), " DOI Management"),
          p(class = "text-muted small",
            "Backfill missing DOIs for legacy papers by fetching from OpenAlex."),
          uiOutput(ns("doi_status")),
          actionButton(ns("backfill_dois"), "Backfill Missing DOIs",
                       class = "btn-outline-primary btn-sm mt-2",
                       icon = icon_rotate()),
          hr(),
          h5(icon_broom(), " Maintenance"),
          p(class = "text-muted small",
            "Remove orphaned search index files left over from failed notebook deletions."),
          actionButton(ns("cleanup_orphans"), "Clean Up Orphaned Indexes",
                       class = "btn-outline-secondary btn-sm",
                       icon = icon_trash_can()),
          textOutput(ns("cleanup_status"))
        )
      )
    )
  )
}

#' Migrate 2-slot model settings to 3-slot
#'
#' If quality_model is not set but chat_model exists, copies chat_model → quality_model.
#' This is a one-time runtime migration for existing users.
#'
#' @param con DuckDB connection
migrate_model_slots <- function(con) {
  quality <- tryCatch(get_db_setting(con, "quality_model"), error = function(e) NULL)
  if (!is.null(quality)) return(invisible(NULL))

  chat <- tryCatch(get_db_setting(con, "chat_model"), error = function(e) NULL)
  if (!is.null(chat)) {
    save_db_setting(con, "quality_model", chat)
    message("[migrate_model_slots] Copied chat_model → quality_model: ", chat)
  }

  invisible(NULL)
}

#' Settings Module Server
#' @param id Module ID
#' @param con Database connection (reactive)
#' @param config_rv Reactive value holding current config
mod_settings_server <- function(id, con, config_rv) {
  moduleServer(id, function(input, output, session) {

    # One-time migration: chat_model → quality_model
    observe({
      req(con())
      migrate_model_slots(con())
    }) |> bindEvent(con(), once = TRUE)

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

    # Helper function to update quality model choices
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

      updateSelectizeInput(session, "quality_model",
                           choices = choices,
                           selected = selected)
    }

    # Helper function to update fast model choices
    update_fast_model_choices <- function(api_key, current_selection = NULL) {
      models <- tryCatch({
        list_chat_models(api_key)
      }, error = function(e) {
        get_default_chat_models()
      })

      if (is.null(models) || nrow(models) == 0) {
        models <- get_default_chat_models()
      }

      choices <- c("(Use Quality model)" = "", format_chat_model_choices(models))

      selected <- if (!is.null(current_selection) && current_selection %in% choices) {
        current_selection
      } else {
        ""  # default to empty = use quality model
      }

      updateSelectizeInput(session, "fast_model",
                           choices = choices,
                           selected = selected)
    }

    # Load current settings on init
    # Track whether we've populated the UI (prevent re-populating after user edits)
    settings_populated <- reactiveVal(FALSE)

    observe({
      # Wait until settings UI is rendered (input is NULL until then)
      req(!is.null(input$save))
      req(!settings_populated())

      cfg <- config_rv()

      # API Keys - prefer DB settings, fall back to config file
      or_key <- get_db_setting(con(), "openrouter_api_key") %||%
                get_setting(cfg, "openrouter", "api_key") %||% ""
      updateTextInput(session, "openrouter_key", value = or_key)

      oa_email <- get_db_setting(con(), "openalex_email") %||%
                  get_setting(cfg, "openalex", "email") %||% ""
      updateTextInput(session, "openalex_email", value = oa_email)

      oa_key <- get_db_setting(con(), "openalex_api_key") %||%
                get_setting(cfg, "openalex", "api_key") %||% ""
      updateTextInput(session, "openalex_api_key", value = oa_key)

      # Quality model (with chat_model fallback for existing users)
      quality_model <- get_db_setting(con(), "quality_model") %||%
                       get_db_setting(con(), "chat_model") %||%
                       get_setting(cfg, "defaults", "quality_model") %||%
                       get_setting(cfg, "defaults", "chat_model") %||%
                       "google/gemini-3.1-flash-lite-preview"
      update_chat_model_choices(or_key, quality_model)

      # Fast model (optional — empty string means use quality model)
      fast_model <- get_db_setting(con(), "fast_model") %||%
                    get_setting(cfg, "defaults", "fast_model") %||% ""
      update_fast_model_choices(or_key, fast_model)

      # Embedding model - get saved selection then populate dropdown
      embed_model <- get_db_setting(con(), "embedding_model") %||%
                     get_setting(cfg, "defaults", "embedding_model") %||%
                     "openai/text-embedding-3-small"
      update_embed_model_choices(or_key, embed_model)

      # Advanced
      reformulation <- get_db_setting(con(), "rag_query_reformulation")
      if (!is.null(reformulation)) {
        updateCheckboxInput(session, "query_reformulation", value = isTRUE(reformulation))
      }

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

      # Network settings
      network_palette <- get_db_setting(con(), "network_palette") %||% "viridis"
      updateSelectInput(session, "network_palette", selected = network_palette)

      # Validate initial API key values using helper functions
      validate_and_update_openrouter_status(or_key)
      validate_and_update_openalex_status(oa_email)

      settings_populated(TRUE)
    })

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

    # Refresh chat/fast models when API key changes or refresh button clicked
    observe({
      api_key <- input$openrouter_key
      refresh_chat_trigger()  # Also trigger on manual refresh
      current_quality <- input$quality_model
      update_chat_model_choices(api_key, current_quality)
      current_fast <- input$fast_model
      update_fast_model_choices(api_key, current_fast)
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
        class = paste(icon_info$class, "mb-3"),
        style = "font-size: 1.2em; cursor: help;",
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

    # OA API key status - simple presence check
    output$openalex_key_status <- renderUI({
      key <- trimws(input$openalex_api_key %||% "")
      if (nchar(key) > 0) {
        render_status_icon("success", "API key configured")
      } else {
        render_status_icon("neutral", "Optional - enables usage tracking")
      }
    })

    # Migration nudge: shown when email set but no API key
    output$oa_migration_nudge <- renderUI({
      email <- trimws(input$openalex_email %||% "")
      key <- trimws(input$openalex_api_key %||% "")
      if (should_show_oa_migration_nudge(email, key, con())) {
        div(
          class = "alert alert-info alert-dismissible py-2 px-3 small mt-2",
          role = "alert",
          tags$button(
            type = "button", class = "btn-close btn-close-sm",
            `data-bs-dismiss` = "alert", `aria-label` = "Close",
            onclick = paste0(
              "Shiny.setInputValue('", ns("dismiss_oa_nudge"), "', true, {priority: 'event'})"
            )
          ),
          icon_circle_info(), " ",
          "OpenAlex now offers free API keys with $1/day credit and usage tracking. ",
          tags$a(href = "https://openalex.org/settings/api", target = "_blank", "Get your free key"),
          " to enable budget monitoring."
        )
      }
    })

    # Handle nudge dismissal
    observeEvent(input$dismiss_oa_nudge, {
      save_db_setting(con(), "oa_migration_nudge_dismissed", TRUE)
    })

    # Fast model fallback hint
    output$fast_model_fallback_hint <- renderUI({
      fast <- input$fast_model
      if (is.null(fast) || fast == "") {
        tags$p(class = "small text-info mt-0 mb-1", "Using Quality model as fallback")
      } else {
        NULL
      }
    })

    # Model info panel showing details for currently selected quality model
    output$model_info <- renderUI({
      req(input$quality_model)
      models <- chat_models_data()
      req(models)

      selected <- models[models$id == input$quality_model, ]
      if (nrow(selected) == 0) return(NULL)

      row <- selected[1, ]
      tier_badge <- switch(row$tier,
        "budget" = span(class = "badge bg-success", "Budget"),
        "mid" = span(class = "badge bg-primary", "Mid-tier"),
        "premium" = span(class = "badge bg-warning text-body", "Premium"),
        span(class = "badge bg-secondary", row$tier)
      )

      ctx_display <- if (row$context_length >= 1000000) {
        sprintf("%.1fM tokens", row$context_length / 1000000)
      } else {
        sprintf("%sk tokens", format(round(row$context_length / 1000), big.mark = ","))
      }

      div(
        class = "card card-body bg-body-secondary py-2 px-3 mt-2 small",
        div(class = "d-flex justify-content-between align-items-center mb-1",
          span(class = "fw-semibold", row$name),
          tier_badge
        ),
        div(class = "text-muted",
          icon_window_maximize(class = "me-1"), "Context: ", ctx_display,
          span(class = "mx-2", "|"),
          icon_arrow_right_bracket(class = "me-1"),
          sprintf("$%.2f/M in", row$prompt_price),
          span(class = "mx-1", "/"),
          sprintf("$%.2f/M out", row$completion_price)
        )
      )
    })

    # --- Provider Management ---

    provider_refresh <- reactiveVal(0)

    output$providers_list <- renderUI({
      provider_refresh()
      req(con())

      providers <- get_providers(con())

      if (nrow(providers) == 0) {
        return(tags$p(class = "text-muted small", "No providers configured."))
      }

      # For OpenRouter, use the API key from settings
      or_key <- trimws(input$openrouter_key %||% "")

      tagList(lapply(seq_len(nrow(providers)), function(i) {
        p <- providers[i, ]
        is_openrouter <- isTRUE(p$is_default)

        # Status indicator
        status_icon <- if (is_openrouter && nchar(or_key) > 0) {
          span(class = "text-success me-1", icon("circle-check"))
        } else if (is_openrouter) {
          span(class = "text-warning me-1", icon("circle-exclamation"))
        } else {
          # For non-default providers, test health synchronously (quick 3s timeout)
          cfg <- provider_row_to_config(p)
          health <- tryCatch(provider_check_health(cfg, timeout = 3), error = function(e) list(alive = FALSE))
          if (isTRUE(health$alive)) {
            span(class = "text-success me-1", icon("circle-check"),
                 title = sprintf("%d models", health$model_count %||% 0))
          } else {
            span(class = "text-danger me-1", icon("circle-xmark"), title = "Offline")
          }
        }

        # API key display
        key_display <- if (is_openrouter) {
          if (nchar(or_key) > 0) "(API key in credentials)" else "(no API key)"
        } else if (!is.null(p$api_key) && nchar(p$api_key %||% "") > 0) {
          paste0("key: ", substr(p$api_key, 1, 8), "...")
        } else {
          "(no key)"
        }

        div(
          class = "d-flex align-items-center gap-2 py-1",
          status_icon,
          div(
            class = "flex-grow-1",
            span(class = "fw-semibold", p$name),
            if (is_openrouter) span(class = "badge bg-secondary ms-1", "built-in"),
            tags$br(),
            span(class = "text-muted small", p$base_url, " ", key_display)
          ),
          if (!is_openrouter) {
            div(
              class = "d-flex gap-1",
              actionButton(
                ns(paste0("test_provider_", p$id)), NULL,
                icon = icon("plug"), class = "btn-outline-secondary btn-sm",
                title = "Test connection"
              ),
              actionButton(
                ns(paste0("edit_provider_", p$id)), NULL,
                icon = icon("pen"), class = "btn-outline-secondary btn-sm",
                title = "Edit"
              ),
              actionButton(
                ns(paste0("delete_provider_", p$id)), NULL,
                icon = icon("trash"), class = "btn-outline-danger btn-sm",
                title = "Delete"
              )
            )
          }
        )
      }))
    })

    # Add provider modal
    observeEvent(input$add_provider, {
      ns <- session$ns
      showModal(modalDialog(
        title = "Add Provider",
        textInput(ns("new_provider_name"), "Name", placeholder = "My Ollama"),
        textInput(ns("new_provider_url"), "Base URL",
                  placeholder = "http://localhost:11434/v1"),
        passwordInput(ns("new_provider_key"), "API Key (optional)"),
        uiOutput(ns("new_provider_test_result")),
        footer = tagList(
          actionButton(ns("test_new_provider"), "Test Connection",
                       class = "btn-outline-secondary"),
          actionButton(ns("save_new_provider"), "Save",
                       class = "btn-primary"),
          modalButton("Cancel")
        )
      ))
    })

    # Test new provider connection
    observeEvent(input$test_new_provider, {
      url <- trimws(input$new_provider_url %||% "")
      key <- trimws(input$new_provider_key %||% "")

      if (nchar(url) == 0) {
        output$new_provider_test_result <- renderUI(
          div(class = "alert alert-warning py-1 small mt-2", "Please enter a base URL.")
        )
        return()
      }

      cfg <- create_provider_config(
        name = "test", base_url = url,
        api_key = if (nchar(key) > 0) key else NULL
      )
      health <- provider_check_health(cfg, timeout = 5)

      output$new_provider_test_result <- renderUI({
        if (isTRUE(health$alive)) {
          div(class = "alert alert-success py-1 small mt-2",
              icon("circle-check"), sprintf(" Connected! Found %d models. Server type: %s",
                                            health$model_count, health$server_type))
        } else {
          div(class = "alert alert-danger py-1 small mt-2",
              icon("circle-xmark"), " Could not connect. Check the URL and try again.")
        }
      })
    })

    # Save new provider
    observeEvent(input$save_new_provider, {
      name <- trimws(input$new_provider_name %||% "")
      url <- trimws(input$new_provider_url %||% "")
      key <- trimws(input$new_provider_key %||% "")

      if (nchar(name) == 0 || nchar(url) == 0) {
        showNotification("Name and Base URL are required.", type = "error")
        return()
      }

      # Generate a URL-safe ID from the name
      id <- tolower(gsub("[^a-z0-9]+", "-", name))
      id <- sub("-+$", "", sub("^-+", "", id))

      save_provider(con(), id, name, url,
                    api_key = if (nchar(key) > 0) key else NULL)

      removeModal()
      provider_refresh(provider_refresh() + 1)
      showNotification(paste("Provider", name, "added!"), type = "message")
    })

    # Dynamic observers for provider test/edit/delete buttons
    observe({
      provider_refresh()
      req(con())

      providers <- get_providers(con())
      non_default <- providers[!providers$is_default, , drop = FALSE]

      lapply(seq_len(nrow(non_default)), function(i) {
        p <- non_default[i, ]
        pid <- p$id

        # Test button
        local({
          local_pid <- pid
          local_name <- p$name
          btn_id <- paste0("test_provider_", local_pid)
          observeEvent(input[[btn_id]], {
            cfg <- provider_row_to_config(get_provider(con(), local_pid))
            health <- provider_check_health(cfg, timeout = 5)
            if (isTRUE(health$alive)) {
              showNotification(
                sprintf("%s: connected (%d models, %s)", local_name, health$model_count, health$server_type),
                type = "message")
            } else {
              showNotification(sprintf("%s: connection failed", local_name), type = "error")
            }
          }, ignoreInit = TRUE)
        })

        # Delete button
        local({
          local_pid <- pid
          local_name <- p$name
          btn_id <- paste0("delete_provider_", local_pid)
          observeEvent(input[[btn_id]], {
            tryCatch({
              delete_provider(con(), local_pid)
              provider_refresh(provider_refresh() + 1)
              showNotification(paste("Deleted provider:", local_name), type = "message")
            }, error = function(e) {
              showNotification(e$message, type = "error")
            })
          }, ignoreInit = TRUE)
        })

        # Edit button
        local({
          local_pid <- pid
          btn_id <- paste0("edit_provider_", local_pid)
          observeEvent(input[[btn_id]], {
            p_data <- get_provider(con(), local_pid)
            ns <- session$ns
            showModal(modalDialog(
              title = paste("Edit Provider:", p_data$name),
              textInput(ns("edit_provider_name"), "Name", value = p_data$name),
              textInput(ns("edit_provider_url"), "Base URL", value = p_data$base_url),
              passwordInput(ns("edit_provider_key"), "API Key",
                            placeholder = if (!is.null(p_data$api_key) && nchar(p_data$api_key %||% "") > 0) "******** (leave blank to keep)" else ""),
              tags$input(type = "hidden", id = ns("edit_provider_id"), value = local_pid),
              footer = tagList(
                actionButton(ns("save_edit_provider"), "Save", class = "btn-primary"),
                modalButton("Cancel")
              )
            ))
          }, ignoreInit = TRUE)
        })
      })
    })

    # Save edited provider
    observeEvent(input$save_edit_provider, {
      pid <- input$edit_provider_id
      name <- trimws(input$edit_provider_name %||% "")
      url <- trimws(input$edit_provider_url %||% "")
      key <- trimws(input$edit_provider_key %||% "")

      if (nchar(name) == 0 || nchar(url) == 0) {
        showNotification("Name and Base URL are required.", type = "error")
        return()
      }

      # If key is blank, keep the existing one
      existing <- get_provider(con(), pid)
      api_key <- if (nchar(key) > 0) key else existing$api_key

      save_provider(con(), pid, name, url, api_key = api_key)

      removeModal()
      provider_refresh(provider_refresh() + 1)
      showNotification(paste("Provider", name, "updated!"), type = "message")
    })

    # Embedding dimension warning
    output$embed_dimension_warning <- renderUI({
      embed_model <- input$embed_model
      req(embed_model)
      req(con())

      # Get dimension of selected model
      new_dim <- detect_embedding_dimension(embed_model)
      if (is.null(new_dim)) return(NULL)

      # Check stored dimension
      stored_dim <- tryCatch(get_db_setting(con(), "embedding_dimension"), error = function(e) NULL)
      if (is.null(stored_dim)) return(NULL)
      stored_dim <- as.integer(stored_dim)

      if (new_dim != stored_dim) {
        div(
          class = "alert alert-warning py-2 small mt-2",
          icon("triangle-exclamation"),
          sprintf(" Dimension mismatch: indexes were built with %d dims, but %s produces %d dims. ",
                  stored_dim, embed_model, new_dim),
          "Re-index your notebooks for retrieval to work."
        )
      }
    })

    # DOI backfill status
    doi_refresh <- reactiveVal(0)

    output$doi_status <- renderUI({
      doi_refresh()  # Dependency for refresh

      status <- tryCatch({
        get_doi_backfill_status(con())
      }, error = function(e) {
        list(total_papers = 0, has_doi = 0, missing_doi = 0)
      })

      div(
        class = "small",
        span(class = "badge bg-success me-2", paste(status$has_doi, "with DOI")),
        span(class = "badge bg-warning text-body", paste(status$missing_doi, "missing DOI"))
      )
    })

    # Backfill DOIs button handler
    observeEvent(input$backfill_dois, {
      # Get email from settings
      email <- get_db_setting(con(), "openalex_email")

      if (is.null(email) || nchar(email) == 0) {
        showNotification("OpenAlex email not configured. Please set it in Settings.",
                         type = "error", duration = 5)
        return()
      }

      withProgress(message = "Backfilling DOIs...", {
        total_updated <- 0
        repeat {
          updated <- backfill_dois(con(), email = email, batch_size = 50)
          total_updated <- total_updated + updated
          incProgress(0.1, detail = paste(total_updated, "papers updated"))
          if (updated < 50) break  # No more papers to backfill
          Sys.sleep(0.5)  # Be polite to OpenAlex API
        }
      })

      showNotification(paste("Backfill complete:", total_updated, "DOIs updated"),
                       type = "message", duration = 5)

      # Refresh status display
      doi_refresh(doi_refresh() + 1)
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
          icon_warning(), " No quality data downloaded yet."
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

    # Orphan store cleanup (Phase 21)
    observeEvent(input$cleanup_orphans, {
      orphans <- find_orphaned_stores(con())

      if (length(orphans) == 0) {
        output$cleanup_status <- renderText(
          paste("No orphaned indexes found.", format(Sys.time(), "(%H:%M:%S)"))
        )
        return()
      }

      # Delete orphans
      removed <- vapply(orphans, function(f) {
        tryCatch({
          result <- file.remove(f)
          # Also clean up WAL/tmp sidecar files
          suppressWarnings({
            file.remove(paste0(f, ".wal"))
            file.remove(paste0(f, ".tmp"))
          })
          result
        }, error = function(e) FALSE)
      }, logical(1))

      output$cleanup_status <- renderText(
        paste("Cleaned up", sum(removed), "of", length(orphans), "orphaned indexes.",
              format(Sys.time(), "(%H:%M:%S)"))
      )

      showNotification(
        paste("Removed", sum(removed), "orphaned search indexes."),
        type = "message"
      )
    })

    # Save settings
    observeEvent(input$save, {
      tryCatch({
        # Only save credentials to DB if non-empty (empty = defer to config.yml)
        or_key <- trimws(input$openrouter_key %||% "")
        if (nchar(or_key) > 0) {
          save_db_setting(con(), "openrouter_api_key", or_key)
        }

        oa_email <- trimws(input$openalex_email %||% "")
        if (nchar(oa_email) > 0) {
          save_db_setting(con(), "openalex_email", oa_email)
        }

        oa_key <- trimws(input$openalex_api_key %||% "")
        if (nchar(oa_key) > 0) {
          save_db_setting(con(), "openalex_api_key", oa_key)
        }

        save_db_setting(con(), "quality_model", input$quality_model)
        # Save fast_model: empty string means "use quality model"
        fast_val <- input$fast_model %||% ""
        if (nchar(fast_val) > 0) {
          save_db_setting(con(), "fast_model", fast_val)
        } else {
          # Remove fast_model setting so fallback to quality works
          tryCatch(
            DBI::dbExecute(con(), "DELETE FROM settings WHERE key = 'fast_model'"),
            error = function(e) NULL
          )
        }
        save_db_setting(con(), "embedding_model", input$embed_model)
        save_db_setting(con(), "rag_query_reformulation", input$query_reformulation)
        save_db_setting(con(), "chunk_size", input$chunk_size)
        save_db_setting(con(), "chunk_overlap", input$chunk_overlap)
        save_db_setting(con(), "abstracts_per_search", input$abstracts_per_search)
        save_db_setting(con(), "network_palette", input$network_palette)

        showNotification("Settings saved!", type = "message")
      }, error = function(e) {
        showNotification(paste("Error saving settings:", e$message),
                         type = "error")
      })
    })

    # Return reactive that gets current effective settings
    # This merges config file with DB overrides
    # Helper: treat empty strings as NULL so %||% fallback works
    non_empty <- function(x) {
      if (is.null(x) || (is.character(x) && nchar(trimws(x)) == 0)) NULL else x
    }

    reactive({
      cfg <- config_rv() %||% list()

      list(
        openrouter = list(
          api_key = non_empty(get_db_setting(con(), "openrouter_api_key")) %||%
                    non_empty(get_setting(cfg, "openrouter", "api_key")) %||% ""
        ),
        openalex = list(
          email = non_empty(get_db_setting(con(), "openalex_email")) %||%
                  non_empty(get_setting(cfg, "openalex", "email")) %||% "",
          api_key = non_empty(get_db_setting(con(), "openalex_api_key")) %||%
                    non_empty(get_setting(cfg, "openalex", "api_key")) %||% ""
        ),
        defaults = list(
          fast_model = get_db_setting(con(), "fast_model") %||%
                       get_setting(cfg, "defaults", "fast_model"),
          quality_model = get_db_setting(con(), "quality_model") %||%
                          get_db_setting(con(), "chat_model") %||%
                          get_setting(cfg, "defaults", "quality_model") %||%
                          get_setting(cfg, "defaults", "chat_model") %||%
                          "google/gemini-3.1-flash-lite-preview",
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
