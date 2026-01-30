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
                        "Claude Sonnet 4" = "anthropic/claude-sonnet-4",
                        "Claude Haiku 3.5" = "anthropic/claude-3-5-haiku",
                        "GPT-4o" = "openai/gpt-4o",
                        "GPT-4o Mini" = "openai/gpt-4o-mini",
                        "Llama 3.1 70B" = "meta-llama/llama-3.1-70b-instruct"
                      )),
          selectInput(ns("embed_model"), "Embedding Model",
                      choices = c(
                        "OpenAI text-embedding-3-small" = "openai/text-embedding-3-small",
                        "OpenAI text-embedding-3-large" = "openai/text-embedding-3-large"
                      )),
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
            "Changes only apply to newly uploaded documents.")
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
                    "anthropic/claude-sonnet-4"
      updateSelectInput(session, "chat_model", selected = chat_model)

      embed_model <- get_db_setting(con(), "embedding_model") %||%
                     get_setting(cfg, "defaults", "embedding_model") %||%
                     "openai/text-embedding-3-small"
      updateSelectInput(session, "embed_model", selected = embed_model)

      # Advanced
      chunk_size <- get_db_setting(con(), "chunk_size") %||%
                    get_setting(cfg, "app", "chunk_size") %||% 500
      updateNumericInput(session, "chunk_size", value = chunk_size)

      chunk_overlap <- get_db_setting(con(), "chunk_overlap") %||%
                       get_setting(cfg, "app", "chunk_overlap") %||% 50
      updateNumericInput(session, "chunk_overlap", value = chunk_overlap)
    }) |> bindEvent(config_rv(), once = TRUE)

    # Save settings
    observeEvent(input$save, {
      tryCatch({
        save_db_setting(con(), "openrouter_api_key", input$openrouter_key)
        save_db_setting(con(), "openalex_email", input$openalex_email)
        save_db_setting(con(), "chat_model", input$chat_model)
        save_db_setting(con(), "embedding_model", input$embed_model)
        save_db_setting(con(), "chunk_size", input$chunk_size)
        save_db_setting(con(), "chunk_overlap", input$chunk_overlap)

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
                       "anthropic/claude-sonnet-4",
          embedding_model = get_db_setting(con(), "embedding_model") %||%
                            get_setting(cfg, "defaults", "embedding_model") %||%
                            "openai/text-embedding-3-small"
        ),
        app = list(
          chunk_size = get_db_setting(con(), "chunk_size") %||%
                       get_setting(cfg, "app", "chunk_size") %||% 500,
          chunk_overlap = get_db_setting(con(), "chunk_overlap") %||%
                          get_setting(cfg, "app", "chunk_overlap") %||% 50
        )
      )
    })
  })
}
