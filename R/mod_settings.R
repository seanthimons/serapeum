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
          textInput(ns("openrouter_key"), "OpenRouter API Key",
                    placeholder = "sk-or-..."),
          p(class = "text-muted small",
            "Get your key at ", tags$a(href = "https://openrouter.ai/keys",
                                       target = "_blank", "openrouter.ai/keys")),
          hr(),
          textInput(ns("openalex_email"), "OpenAlex Email",
                    placeholder = "your@email.com"),
          p(class = "text-muted small",
            "Used for polite pool access. Get an API key at ",
            tags$a(href = "https://openalex.org/settings/api",
                   target = "_blank", "openalex.org"))
        ),

        # Right column
        div(
          h5(icon("robot"), " Models"),
          selectInput(ns("chat_model"), "Chat Model",
                      choices = c(
                        # Budget options
                        "DeepSeek V3 (budget)" = "deepseek/deepseek-chat",
                        "Gemini 2.0 Flash (budget)" = "google/gemini-2.0-flash-001",
                        "GPT-4o Mini (budget)" = "openai/gpt-4o-mini",
                        # Mid-tier
                        "Kimi K2 0905 (recommended)" = "moonshotai/kimi-k2-0905",
                        "Claude 3.5 Haiku" = "anthropic/claude-3-5-haiku",
                        "Llama 3.3 70B" = "meta-llama/llama-3.3-70b-instruct",
                        # Premium
                        "Claude Sonnet 4" = "anthropic/claude-sonnet-4",
                        "GPT-4o" = "openai/gpt-4o",
                        "Gemini 2.5 Pro" = "google/gemini-2.5-pro-preview"
                      ),
                      selected = "moonshotai/kimi-k2-0905"),
          p(class = "text-muted small mb-3",
            "Budget < $0.50/M tokens | Mid-tier $0.50-$2/M | Premium > $2/M"),
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
            "Number of paper abstracts to fetch from OpenAlex per search (max 100).")
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

    # Reactive value to trigger model refresh
    refresh_embed_trigger <- reactiveVal(0)

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

      # Models
      chat_model <- get_db_setting(con(), "chat_model") %||%
                    get_setting(cfg, "defaults", "chat_model") %||%
                    "moonshotai/kimi-k2-0905"
      updateSelectInput(session, "chat_model", selected = chat_model)

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
                       "moonshotai/kimi-k2-0905",
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
