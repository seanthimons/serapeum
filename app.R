library(shiny)
library(bslib)
library(DBI)
library(duckdb)

# Set up persistent mirai daemons for async tasks (bulk import, embedding, etc.)
mirai::daemons(2)
onStop(function() mirai::daemons(0))

# Source all R files
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

# Load config from file (if exists)
config_file <- load_config()

# Initialize database
db_path <- get_setting(config_file, "app", "db_path") %||% "data/notebooks.duckdb"

# Create ragnar store directory for per-notebook stores (v3.0)
ragnar_dir <- file.path("data", "ragnar")
if (!dir.create(ragnar_dir, showWarnings = FALSE, recursive = TRUE)) {
  if (!dir.exists(ragnar_dir)) {
    stop("Failed to create ", ragnar_dir, " directory. Check permissions and disk space.")
  }
}

# Phase 22: Delete legacy shared store (replaced by per-notebook stores)
# Phase 24: Track deletion for deferred toast notification in server
legacy_store_deleted <- FALSE
legacy_store <- file.path("data", "serapeum.ragnar.duckdb")
if (file.exists(legacy_store)) {
  message("[ragnar] Removing legacy shared store: ", legacy_store)
  file.remove(legacy_store)
  # Also remove WAL and tmp files
  for (ext in c(".wal", ".tmp")) {
    f <- paste0(legacy_store, ext)
    if (file.exists(f)) file.remove(f)
  }
  legacy_store_deleted <- TRUE
}

# UI
ui <- page_sidebar(
  window_title = paste("Serapeum", paste0("v", SERAPEUM_VERSION)),
  title = div(
    class = "d-flex align-items-center justify-content-between w-100",
    div(
      class = "d-flex align-items-center gap-2",
      icon_book_open(),
      "Serapeum",
      span(class = "badge bg-secondary small", paste0("v", SERAPEUM_VERSION))
    ),
    bslib::input_dark_mode(id = "dark_mode")
  ),
  theme = {
    serapeum_theme <- bs_theme(
      version = 5,
      preset = "shiny",
      bg = LATTE$base,
      fg = LATTE$text,
      primary = LATTE$lavender,
      secondary = LATTE$surface1,
      success = LATTE$green,
      danger = LATTE$red,
      warning = LATTE$yellow,
      info = LATTE$sapphire,
      "border-radius" = "0.5rem",
      "link-color" = LATTE$sapphire,
      "link-hover-color" = LATTE$sky
    )
    bs_add_rules(serapeum_theme, catppuccin_dark_css())
  },
  tags$head(
    tags$link(rel = "stylesheet", href = "custom.css"),
    tags$link(rel = "shortcut icon", href = "favicon.ico"),
    tags$link(rel = "icon", type = "image/png", sizes = "32x32", href = "favicon-32x32.png"),
    tags$link(rel = "icon", type = "image/png", sizes = "16x16", href = "favicon-16x16.png"),
    tags$style(HTML("
    .chat-markdown > *:first-child { margin-top: 0; }
    .chat-markdown > *:last-child { margin-bottom: 0; }
    .chat-markdown h1, .chat-markdown h2, .chat-markdown h3 {
      font-size: 1.1em; font-weight: 600; margin: 0.6em 0 0.3em;
    }
    .chat-markdown h1 { font-size: 1.25em; }
    .chat-markdown table {
      border-collapse: collapse; width: 100%; margin: 0.5em 0; font-size: 0.88em;
    }
    .chat-markdown th, .chat-markdown td {
      border: 1px solid #dee2e6; padding: 0.3em 0.5em; text-align: left;
    }
    .chat-markdown th { background: #f1f3f5; font-weight: 600; }
    .chat-markdown pre {
      background: #f8f9fa; padding: 0.5em; border-radius: 4px;
      overflow-x: auto; font-size: 0.88em;
    }
    .chat-markdown code { font-size: 0.9em; }
    .chat-markdown p { margin: 0.4em 0; }
    .chat-markdown ul, .chat-markdown ol { margin: 0.3em 0; padding-left: 1.5em; }

    /* Literature review table: horizontal scroll + frozen first column */
    .lit-review-scroll {
      overflow-x: auto;
      max-width: 100%;
      border: 1px solid #dee2e6;
      border-radius: 0.25rem;
      margin: 0.5em 0;
    }
    .lit-review-scroll table {
      min-width: 900px;
      border-collapse: separate;
      border-spacing: 0;
      margin: 0;
    }
    .lit-review-scroll th:first-child,
    .lit-review-scroll td:first-child {
      position: sticky;
      left: 0;
      z-index: 1;
      background-color: #f1f3f5;
      border-right: 2px solid #adb5bd;
      min-width: 140px;
      max-width: 200px;
    }
    .lit-review-scroll th:first-child {
      z-index: 2;
      background-color: #e9ecef;
    }
    .lit-review-scroll th {
      white-space: nowrap;
    }
    .lit-review-scroll td {
      min-width: 120px;
      max-width: 250px;
    }
    /* Dark theme support for frozen column — handled by catppuccin_dark_css() */

    /* Welcome wizard modal — position near top of viewport */
    .modal:has(#wizard-modal-marker) .modal-dialog {
      margin-top: 5vh;
    }
    ")),
    tags$script(HTML("
    // Startup wizard localStorage support
    $(document).on('shiny:connected', function() {
      const hasSeenWizard = localStorage.getItem('serapeum_skip_wizard') === 'true';
      Shiny.setInputValue('has_seen_wizard', hasSeenWizard, {priority: 'event'});
    });

    Shiny.addCustomMessageHandler('setWizardPreference', function(value) {
      localStorage.setItem('serapeum_skip_wizard', 'true');
    });

    Shiny.addCustomMessageHandler('set-theme-storage', function(message) {
      localStorage.setItem('theme', message.theme);
    });

    // Verbose API logging to browser console
    Shiny.addCustomMessageHandler('consoleLog', function(data) {
      console.log('[' + data.label + ']', data.url);
    });

    // Restore theme on page load
    document.addEventListener('DOMContentLoaded', function() {
      const savedTheme = localStorage.getItem('theme');
      if (savedTheme === 'dark') {
        document.documentElement.setAttribute('data-bs-theme', 'dark');
      }
    });
  "))),
  sidebar = sidebar(
    width = 280,
    # Notebook creation and discovery buttons
    div(
      class = "d-grid gap-2 mb-2",
      # Notebook creation (solid primary lavender)
      actionButton("new_search_nb", "New Search Notebook",
                   class = "btn-primary",
                   icon = icon_search()),
      actionButton("new_document_nb", "New Document Notebook",
                   class = "btn-primary",
                   icon = icon_file_pdf()),
      # Divider between creation and discovery
      div(class = "border-top my-2"),
      # Discovery and utility actions (rainbow outline colors)
      bslib::tooltip(
        actionButton("import_papers", "Import Papers",
                     class = "btn-outline-peach",
                     icon = icon_file_import()),
        "Add papers by pasting DOIs or uploading a BibTeX file",
        placement = "bottom",
        options = list(delay = list(show = 300, hide = 100))
      ),
      bslib::tooltip(
        actionButton("discover_paper", "Discover from Paper",
                     class = "btn-outline-success",
                     icon = icon_seedling()),
        "Find related work by using a known paper as a seed",
        placement = "bottom",
        options = list(delay = list(show = 300, hide = 100))
      ),
      bslib::tooltip(
        actionButton("explore_topics", "Explore Topics",
                     class = "btn-outline-warning",
                     icon = icon_compass()),
        "Browse OpenAlex topic hierarchies to find research areas",
        placement = "bottom",
        options = list(delay = list(show = 300, hide = 100))
      ),
      bslib::tooltip(
        actionButton("build_query", "Build a Query",
                     class = "btn-outline-info",
                     icon = icon_wand()),
        "Use AI to help construct an effective search query",
        placement = "bottom",
        options = list(delay = list(show = 300, hide = 100))
      ),
      bslib::tooltip(
        actionButton("new_network", "Citation Network",
                     class = "btn-outline-primary",
                     icon = icon_diagram()),
        "Visualize citation relationships between papers",
        placement = "bottom",
        options = list(delay = list(show = 300, hide = 100))
      ),
      bslib::tooltip(
        actionButton("citation_audit", "Citation Audit",
                     class = "btn-outline-sky",
                     icon = icon_audit()),
        "Check your collection for missing references and gaps",
        placement = "bottom",
        options = list(delay = list(show = 300, hide = 100))
      )
    ),
    # Divider between sidebar buttons and saved notebooks
    div(class = "border-top my-2"),
    # Notebook list
    div(
      class = "mt-2",
      style = "max-height: calc(100vh - 320px); overflow-y: auto;",
      uiOutput("notebook_list")
    ),
    # Compact footer
    div(
      class = "d-flex flex-column gap-1 mt-2",
      # Row 1: Session cost + Costs link
      div(
        class = "d-flex justify-content-between align-items-center",
        span(class = "text-muted small", icon_coins(), " Session:"),
        div(
          class = "d-flex align-items-center gap-2",
          textOutput("session_cost_inline", inline = TRUE) |>
            tagAppendAttributes(class = "text-muted small fw-semibold"),
          actionLink("cost_link", label = tagList(icon_dollar(), "Details"),
                     class = "text-muted small")
        )
      ),
      # Row 2: Settings + About
      div(
        class = "d-flex justify-content-between align-items-center",
        actionLink("settings_link", label = tagList(icon_settings(), "Settings"),
                   class = "text-muted small"),
        actionLink("about_link", label = tagList(icon_circle_info(), "About"),
                   class = "text-muted small")
      )
    ),
  ),
  # Hidden module UIs
  mod_bulk_import_ui("sidebar_import"),
  # Main content
  uiOutput("main_content")
)

# Server
server <- function(input, output, session) {
  # Enable thematic auto-theming for all renderPlot outputs (Phase 31-03)
  thematic::thematic_shiny()

  # Persist theme preference to localStorage
  observeEvent(input$dark_mode, {
    session$sendCustomMessage(
      type = "set-theme-storage",
      message = list(theme = if (input$dark_mode == "dark") "dark" else "light")
    )
  }, ignoreNULL = FALSE, ignoreInit = TRUE)

  # Database connection - create fresh for this session
  con <- get_db_connection(db_path)
  seed_quality_data(con)

  # Clean up on session end
  session$onSessionEnded(function() {
    close_db_connection(con)
  })

  # Startup notification for config file
  observe({
    if (!is.null(config_file)) {
      has_openrouter <- !is.null(get_setting(config_file, "openrouter", "api_key")) &&
                        nchar(get_setting(config_file, "openrouter", "api_key") %||% "") > 0
      has_openalex <- !is.null(get_setting(config_file, "openalex", "email")) &&
                      nchar(get_setting(config_file, "openalex", "email") %||% "") > 0

      if (has_openrouter || has_openalex) {
        msg <- "Config file detected. Loaded:"
        if (has_openrouter) msg <- paste(msg, "OpenRouter API key")
        if (has_openrouter && has_openalex) msg <- paste(msg, "+")
        if (has_openalex) msg <- paste(msg, "OpenAlex email")
        showNotification(msg, type = "message", duration = 5)
      }
    }
  }) |> bindEvent(TRUE, once = TRUE)

  # Deferred toast notification for legacy shared store deletion (Phase 24)
  observe({
    if (legacy_store_deleted) {
      showNotification(
        "Legacy search index removed",
        type = "message",
        duration = 5
      )
    }
  }) |> bindEvent(TRUE, once = TRUE)

  # Reactive: wrap connection for modules
  con_r <- reactive(con)

  # Reactive: config from file
  config_file_r <- reactive(config_file)

  # Session ID for cost tracking
  session_id <- session$token

  # Reactive: current selected notebook
  current_notebook <- reactiveVal(NULL)

  # Reactive: current view ("notebook" or "settings")
  current_view <- reactiveVal("welcome")

  # Reactive: trigger notebook list refresh
  notebook_refresh <- reactiveVal(0)

  # Reactive: pre-filled DOI for seed discovery
  pre_fill_doi <- reactiveVal(NULL)

  # Reactive: current network ID
  current_network <- reactiveVal(NULL)

  # Reactive: notebook ID for sidebar bulk import
  sidebar_import_nb_id <- reactiveVal(NULL)

  # Reactive: trigger network list refresh
  network_refresh <- reactiveVal(0)

  # Track which network IDs already have delete observers to prevent duplicates
  delete_network_observers <- reactiveValues()

  # Settings module - returns effective config
  effective_config <- mod_settings_server("settings", con_r, config_file_r)

  # Cost tracker module
  mod_cost_tracker_server(
    "cost_tracker",
    con_r,
    reactive(session_id),
    effective_config,
    reactive(input$dark_mode)
  )

  # BUGF-03: Fetch live model pricing at startup so non-default models show accurate costs
  observeEvent(effective_config(), {
    cfg <- effective_config()
    api_key <- get_setting(cfg, "openrouter", "api_key")
    if (is.null(api_key) || nchar(api_key) < 10) return()

    tryCatch({
      # Fetch chat model pricing
      chat_models_df <- list_chat_models(api_key)
      if (!is.null(chat_models_df) && nrow(chat_models_df) > 0) {
        update_model_pricing(chat_models_df[, c("id", "prompt_price", "completion_price")])
      }

      # Fetch embedding model pricing (convert column names to match update_model_pricing)
      embed_models_df <- list_embedding_models(api_key)
      if (!is.null(embed_models_df) && nrow(embed_models_df) > 0 &&
          "price_per_million" %in% names(embed_models_df)) {
        embed_pricing <- data.frame(
          id = embed_models_df$id,
          prompt_price = embed_models_df$price_per_million,
          completion_price = 0,
          stringsAsFactors = FALSE
        )
        update_model_pricing(embed_pricing)
      }
    }, error = function(e) {
      message("[cost] Pricing fetch failed (non-fatal): ", e$message)
    })
  }, once = TRUE)

  # Render inline session cost
  output$session_cost_inline <- renderText({
    invalidateLater(10000)  # Poll every 10 seconds
    costs <- get_session_costs(con, session_id)
    total <- attr(costs, "total_cost") %||% 0
    sprintf("$%.4f", total)
  })

  # Render notebook list
  output$notebook_list <- renderUI({
    notebook_refresh()
    network_refresh()

    notebooks <- list_notebooks(con)

    if (nrow(notebooks) == 0) {
      return(
        div(
          class = "text-center text-muted py-3",
          p("No notebooks yet"),
          p(class = "small", "Create one to get started")
        )
      )
    }

    # Separate by type
    doc_notebooks <- notebooks[notebooks$type == "document", ]
    search_notebooks <- notebooks[notebooks$type == "search", ]

    tagList(
      if (nrow(doc_notebooks) > 0) {
        tagList(
          div(class = "text-muted small fw-semibold mb-2", "DOCUMENTS"),
          lapply(seq_len(nrow(doc_notebooks)), function(i) {
            nb <- doc_notebooks[i, ]
            actionLink(
              inputId = paste0("select_nb_", nb$id),
              label = tagList(
                icon_file_pdf(class = "text-danger me-2"),
                span(class = "text-truncate", nb$name)
              ),
              class = "d-flex align-items-center py-2 px-2 rounded hover-bg-light w-100"
            )
          })
        )
      },
      if (nrow(search_notebooks) > 0) {
        tagList(
          div(class = "text-muted small fw-semibold mb-2 mt-3", "SEARCHES"),
          lapply(seq_len(nrow(search_notebooks)), function(i) {
            nb <- search_notebooks[i, ]
            actionLink(
              inputId = paste0("select_nb_", nb$id),
              label = tagList(
                icon_search(class = "text-primary me-2"),
                span(class = "text-truncate", nb$name)
              ),
              class = "d-flex align-items-center py-2 px-2 rounded hover-bg-light w-100"
            )
          })
        )
      },
      # NETWORKS section
      {
        networks <- list_networks(con)
        if (nrow(networks) > 0) {
          tagList(
            div(class = "text-muted small fw-semibold mb-2 mt-3", "NETWORKS"),
            lapply(seq_len(nrow(networks)), function(i) {
              net <- networks[i, ]
              div(
                class = "d-flex justify-content-between align-items-center py-2 px-2 rounded hover-bg-light",
                actionLink(
                  inputId = paste0("select_network_", net$id),
                  label = tagList(
                    icon_diagram(class = "text-primary me-2"),
                    span(class = "text-truncate", net$name)
                  ),
                  class = "flex-grow-1 text-decoration-none"
                ),
                actionButton(
                  paste0("delete_network_", net$id),
                  icon_times(),
                  class = "btn-sm btn-link text-muted p-0",
                  style = "border: none;",
                  title = "Delete network"
                )
              )
            })
          )
        }
      }
    )
  })

  # Observe notebook selection clicks
  # Re-run when notebook_refresh changes (e.g., after creating/importing notebooks)
  observe({
    notebook_refresh()
    notebooks <- list_notebooks(con)
    lapply(notebooks$id, function(nb_id) {
      observeEvent(input[[paste0("select_nb_", nb_id)]], {
        current_notebook(nb_id)
        current_view("notebook")
      }, ignoreInit = TRUE)
    })
  })

  # Observe network selection clicks
  observe({
    network_refresh()
    networks <- list_networks(con)
    lapply(networks$id, function(net_id) {
      observeEvent(input[[paste0("select_network_", net_id)]], {
        current_network(net_id)
        current_notebook(NULL)
        current_view("network")
      }, ignoreInit = TRUE)
    })
  })

  # Observe network deletion clicks
  observe({
    network_refresh()
    networks <- list_networks(con)
    lapply(networks$id, function(net_id) {
      net_id_str <- as.character(net_id)

      # Only create observer if one doesn't exist for this network ID
      if (is.null(delete_network_observers[[net_id_str]])) {
        delete_network_observers[[net_id_str]] <- observeEvent(input[[paste0("delete_network_", net_id)]], {
          # Delete immediately without confirmation (per plan requirement)
          delete_network(con, net_id)
          network_refresh(network_refresh() + 1)

          # If deleted network is currently viewed, go back to welcome
          if (!is.null(current_network()) && current_network() == net_id) {
            current_network(NULL)
            current_view("welcome")
          }

          showNotification("Network deleted", type = "message")

          # Clean up this observer after it fires
          delete_network_observers[[net_id_str]] <- NULL
        }, ignoreInit = TRUE)
      }
    })
  })

  # Settings link
  observeEvent(input$settings_link, {
    current_view("settings")
    current_notebook(NULL)
  })

  # About link
  observeEvent(input$about_link, {
    current_view("about")
    current_notebook(NULL)
  })

  # Cost link
  observeEvent(input$cost_link, {
    current_view("costs")
    current_notebook(NULL)
  })

  # Welcome landing page button handlers
  observeEvent(input$welcome_settings, {
    current_view("settings")
    current_notebook(NULL)
  })
  observeEvent(input$welcome_search, {
    current_notebook(NULL)
    current_view("discover")
  })
  observeEvent(input$welcome_discover, {
    current_notebook(NULL)
    current_view("discover")
  })
  observeEvent(input$welcome_topics, {
    current_notebook(NULL)
    current_view("topic_explorer")
  })
  observeEvent(input$welcome_query, {
    current_notebook(NULL)
    current_view("query_builder")
  })
  observeEvent(input$welcome_import, {
    current_notebook(NULL)
    current_view("welcome")
    shiny::onFlushed(function() {
      sidebar_import_nb_id(NULL)
      sidebar_import_api$show_import_modal()
    }, once = TRUE)
  })
  observeEvent(input$welcome_doc_nb, {
    # Create a new document notebook
    con <- con_r()
    req(con)
    nb_id <- create_notebook(con, "New Document Notebook", "document")
    notebook_refresh(notebook_refresh() + 1)
    current_notebook(nb_id)
    current_view("notebook")
  })
  observeEvent(input$welcome_network, {
    current_notebook(NULL)
    current_view("network")
  })
  observeEvent(input$welcome_audit, {
    current_notebook(NULL)
    current_view("citation_audit")
  })

  # Wizard modal helper function — 5-step workflow
  wizard_modal <- function() {
    wizard_step <- function(number, icon_fn, title, description, btn_id, btn_label, btn_class) {
      div(
        class = "d-flex align-items-start gap-3 mb-3",
        span(class = "badge bg-primary rounded-pill fs-6 mt-1",
             style = "min-width: 28px; text-align: center;", number),
        div(
          class = "flex-grow-1",
          div(class = "d-flex align-items-center gap-2 mb-1",
              icon_fn(class = "text-primary"),
              strong(title)),
          p(class = "text-muted small mb-2", description),
          actionButton(btn_id, btn_label,
                       class = paste("btn-sm", btn_class))
        )
      )
    }

    modalDialog(
      title = tagList(icon_book_open(), " Welcome to Serapeum"),
      div(
        id = "wizard-modal-marker",
        class = "mb-3",
        p(class = "lead text-center", "Your research workflow in 5 steps")
      ),
      wizard_step("1", icon_settings, "Set Up",
                  "Configure your API keys, choose AI models, and download journal metadata.",
                  "wizard_settings", "Go to Settings", "btn-outline-secondary"),
      wizard_step("2", icon_search, "Find Papers",
                  "Search OpenAlex, discover from a seed paper, explore topics, or build a query with AI.",
                  "wizard_search", "New Search Notebook", "btn-outline-primary"),
      wizard_step("3", icon_file_import, "Collect & Import",
                  "Import papers by DOI or BibTeX, upload PDFs into document notebooks.",
                  "wizard_import", "Import Papers", "btn-outline-peach"),
      wizard_step("4", icon_brain, "Analyze",
                  "Chat with your papers, generate synthesis presets, and visualize citation networks.",
                  "wizard_analyze", "New Document Notebook", "btn-outline-success"),
      wizard_step("5", icon_audit, "Audit",
                  "Run citation audits to find missing seminal papers and gaps in your collection.",
                  "wizard_audit", "Citation Audit", "btn-outline-sky"),
      footer = tagList(
        actionLink("skip_wizard", "Don't show this again", class = "text-muted"),
        modalButton("Close")
      ),
      size = "l",
      easyClose = TRUE
    )
  }

  # Show wizard on first load — only if no notebooks exist and not previously dismissed
  observe({
    con <- con_r()
    req(con)
    notebooks <- list_notebooks(con)
    has_seen <- isTRUE(input$has_seen_wizard)
    if (nrow(notebooks) == 0 && !has_seen) {
      shiny::onFlushed(function() {
        showModal(wizard_modal())
      }, once = TRUE)
    }
  }) |> bindEvent(con_r(), once = TRUE)

  # Wizard routing handlers
  observeEvent(input$wizard_settings, {
    removeModal()
    current_notebook(NULL)
    current_view("settings")
  })

  observeEvent(input$wizard_search, {
    removeModal()
    current_notebook(NULL)
    current_view("discover")
  })

  observeEvent(input$wizard_import, {
    removeModal()
    current_notebook(NULL)
    current_view("welcome")
    # Defer import modal to next flush so sidebar_import_api is guaranteed available
    shiny::onFlushed(function() {
      sidebar_import_nb_id(NULL)
      sidebar_import_api$show_import_modal()
    }, once = TRUE)
  })

  observeEvent(input$wizard_analyze, {
    removeModal()
    current_notebook(NULL)
    current_view("query_builder")
  })

  observeEvent(input$wizard_audit, {
    removeModal()
    current_notebook(NULL)
    current_view("citation_audit")
  })

  # Skip wizard handler
  observeEvent(input$skip_wizard, {
    session$sendCustomMessage('setWizardPreference', TRUE)
    removeModal()
  })

  # Discover from paper button
  observeEvent(input$discover_paper, {
    current_view("discover")
    current_notebook(NULL)
  })

  # Build a query button
  observeEvent(input$build_query, {
    current_notebook(NULL)
    current_view("query_builder")
  })

  # Explore topics button
  observeEvent(input$explore_topics, {
    current_notebook(NULL)
    current_view("topic_explorer")
  })

  # Citation audit button
  observeEvent(input$citation_audit, {
    current_notebook(NULL)
    current_view("citation_audit")
  })

  # Import papers button (sidebar)
  observeEvent(input$import_papers, {
    sidebar_import_api$show_import_modal()
  })

  # New citation network button - show seed paper search modal
  observeEvent(input$new_network, {
    showModal(modalDialog(
      title = tagList(icon_diagram(), "New Citation Network"),
      p("Search for a seed paper to build a citation network around."),
      textInput("network_seed_search", "Search for Paper",
                placeholder = "e.g., attention is all you need"),
      uiOutput("network_seed_results"),
      footer = tagList(
        modalButton("Cancel")
      ),
      size = "l"
    ))
  })

  # Network seed search
  network_seed_papers <- reactiveVal(NULL)

  observeEvent(input$network_seed_search, {
    query <- trimws(input$network_seed_search)
    if (nchar(query) == 0) {
      network_seed_papers(NULL)
      return()
    }

    config <- config_file_r()
    email <- get_setting(config, "openalex", "email")

    # Debounce search
    invalidateLater(500, session)

    # Search OpenAlex
    tryCatch({
      req_obj <- build_openalex_request("works", email, api_key = NULL) |>
        req_url_query(search = query, per_page = 10)

      resp <- req_perform(req_obj)
      body <- resp_body_json(resp)

      if (!is.null(body$results) && length(body$results) > 0) {
        papers <- lapply(body$results, parse_openalex_work)
        network_seed_papers(papers)
      } else {
        network_seed_papers(list())
      }
    }, error = function(e) {
      network_seed_papers(list())
    })
  })

  output$network_seed_results <- renderUI({
    papers <- network_seed_papers()
    if (is.null(papers)) return(NULL)

    if (length(papers) == 0) {
      return(div(class = "text-muted small", "No papers found"))
    }

    div(
      class = "mt-3",
      style = "max-height: 400px; overflow-y: auto;",
      h6("Select a seed paper:"),
      lapply(seq_along(papers), function(i) {
        paper <- papers[[i]]
        actionLink(
          paste0("select_network_seed_", i),
          label = div(
            class = "border rounded p-2 mb-2",
            strong(paper$title),
            div(
              class = "small text-muted",
              paste(
                paste(if (length(paper$authors) > 3) c(paper$authors[1:3], "et al.") else paper$authors, collapse = ", "),
                "|", paper$year, "|", paper$cited_by_count, "citations"
              )
            )
          ),
          class = "text-decoration-none d-block"
        )
      })
    )
  })

  # Handle seed paper selection
  observe({
    papers <- network_seed_papers()
    if (is.null(papers) || length(papers) == 0) return()

    lapply(seq_along(papers), function(i) {
      observeEvent(input[[paste0("select_network_seed_", i)]], {
        paper <- papers[[i]]
        removeModal()

        # Set current network to NULL and view to network
        # This will trigger network module to show with the seed paper
        current_network(paper$paper_id)
        current_view("network")

        showNotification(paste("Building network for:", paper$title), type = "message")
      }, ignoreInit = TRUE)
    })
  })

  # New document notebook modal
  observeEvent(input$new_document_nb, {
    showModal(modalDialog(
      title = tagList(icon_file_pdf(), "New Document Notebook"),
      textInput("new_doc_nb_name", "Notebook Name",
                placeholder = "e.g., Research Papers"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("create_doc_nb", "Create", class = "btn-primary")
      )
    ))
  })

  # Create document notebook
  observeEvent(input$create_doc_nb, {
    req(input$new_doc_nb_name)
    name <- trimws(input$new_doc_nb_name)
    if (nchar(name) == 0) return()

    id <- create_notebook(con, name, "document")
    removeModal()
    notebook_refresh(notebook_refresh() + 1)
    current_notebook(id)
    current_view("notebook")
  })

  # New search notebook modal
  observeEvent(input$new_search_nb, {
    showModal(modalDialog(
      title = tagList(icon_search(), "New Search Notebook"),
      textInput("new_search_nb_name", "Notebook Name",
                placeholder = "e.g., Machine Learning Papers"),
      textInput("new_search_query", "Search Query",
                placeholder = "e.g., deep learning medical imaging"),

      # Search field selector
      selectInput("search_field", "Search In",
                  choices = c(
                    "All Fields" = "default",
                    "Title Only" = "title",
                    "Abstract Only" = "abstract",
                    "Title & Abstract" = "title_and_abstract"
                  ),
                  selected = "default"),

      layout_columns(
        col_widths = c(6, 6),
        numericInput("search_from_year", "From Year", value = 2020,
                     min = 1900, max = 2030),
        numericInput("search_to_year", "To Year", value = 2025,
                     min = 1900, max = 2030)
      ),

      # Open access filter
      checkboxInput("search_is_oa", "Open Access Only", value = FALSE),
      checkboxInput("search_has_abstract", "Only papers with abstracts", value = TRUE),

      hr(),

      # Quality filters
      div(
        class = "mb-3",
        h6(class = "text-muted", icon_shield(), " Quality Filters"),
        checkboxInput("search_exclude_retracted", "Exclude retracted papers", value = TRUE),
        checkboxInput("search_flag_predatory", "Flag predatory journals/publishers", value = TRUE),
        numericInput("search_min_citations", "Minimum citations (optional)",
                     value = NA, min = 0, max = 10000, step = 1),
        uiOutput("quality_cache_status_create")
      ),

      # Query preview
      tags$details(
        class = "mt-3",
        tags$summary(class = "text-muted small", "Show API Query"),
        div(
          class = "mt-2 p-2 bg-light rounded small font-monospace",
          style = "word-break: break-all;",
          uiOutput("create_query_preview")
        )
      ),

      footer = tagList(
        modalButton("Cancel"),
        actionButton("create_search_nb", "Create & Search", class = "btn-primary")
      )
    ))
  })

  # Query preview for create modal
  output$create_query_preview <- renderUI({
    query <- input$new_search_query %||% ""
    from_year <- input$search_from_year
    to_year <- input$search_to_year
    search_field <- input$search_field %||% "default"
    is_oa <- input$search_is_oa %||% FALSE
    has_abstract <- input$search_has_abstract %||% TRUE
    min_citations <- input$search_min_citations
    exclude_retracted <- input$search_exclude_retracted %||% TRUE

    preview <- build_query_preview(
      query,
      from_year,
      to_year,
      search_field,
      is_oa,
      min_citations = min_citations,
      has_abstract = has_abstract,
      exclude_retracted = exclude_retracted
    )

    tagList(
      if (!is.null(preview$search)) {
        div(tags$strong("search="), preview$search)
      },
      div(tags$strong("filter="), preview$filter)
    )
  })

  # Quality cache status for create modal
  output$quality_cache_status_create <- renderUI({
    status <- tryCatch({
      check_quality_cache_status(con)
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
      if (status$is_empty || status$is_stale) {
        actionLink("refresh_quality_cache_create", "Download quality data", class = "small")
      }
    )
  })

  # Handle quality cache refresh from create modal
  observeEvent(input$refresh_quality_cache_create, {
    showNotification("Downloading quality data...", type = "message", id = "quality_refresh", duration = NULL)

    result <- tryCatch({
      refresh_quality_cache(con)
    }, error = function(e) {
      list(success = FALSE, error = e$message)
    })

    removeNotification("quality_refresh")

    if (result$success) {
      showNotification(
        sprintf("Quality data ready: %d publishers, %d journals, %d retractions",
                result$predatory_publishers$count,
                result$predatory_journals$count,
                result$retraction_watch$count),
        type = "message", duration = 5
      )
    } else {
      # Show which sources failed
      failed <- character()
      if (!result$predatory_publishers$success) failed <- c(failed, "publishers")
      if (!result$predatory_journals$success) failed <- c(failed, "journals")
      if (!result$retraction_watch$success) failed <- c(failed, "retractions")
      showNotification(
        paste("Failed to download:", paste(failed, collapse = ", ")),
        type = "error", duration = 10
      )
    }
  })

  # Create search notebook
  observeEvent(input$create_search_nb, {
    req(input$new_search_nb_name, input$new_search_query)
    name <- trimws(input$new_search_nb_name)
    query <- trimws(input$new_search_query)
    if (nchar(name) == 0 || nchar(query) == 0) return()

    filters <- list(
      from_year = input$search_from_year,
      to_year = input$search_to_year,
      search_field = input$search_field %||% "default",
      is_oa = input$search_is_oa %||% FALSE,
      has_abstract = input$search_has_abstract %||% TRUE,
      # Quality filters
      exclude_retracted = input$search_exclude_retracted %||% TRUE,
      flag_predatory = input$search_flag_predatory %||% TRUE,
      min_citations = input$search_min_citations
    )

    id <- create_notebook(con, name, "search",
                          search_query = query,
                          search_filters = filters)
    removeModal()
    notebook_refresh(notebook_refresh() + 1)
    current_notebook(id)
    current_view("notebook")
  })

  # Main content switching
  output$main_content <- renderUI({
    # Re-render when notebook is updated (e.g., search query changed)
    notebook_refresh()

    view <- current_view()
    nb_id <- current_notebook()

    if (view == "settings") {
      return(mod_settings_ui("settings"))
    }

    if (view == "about") {
      return(mod_about_ui("about"))
    }

    if (view == "costs") {
      return(mod_cost_tracker_ui("cost_tracker"))
    }

    if (view == "discover") {
      return(mod_seed_discovery_ui("seed_discovery"))
    }

    if (view == "query_builder") {
      return(mod_query_builder_ui("query_builder"))
    }

    if (view == "topic_explorer") {
      return(mod_topic_explorer_ui("topic_explorer"))
    }

    if (view == "network") {
      return(mod_citation_network_ui("citation_network"))
    }

    if (view == "citation_audit") {
      return(mod_citation_audit_ui("citation_audit"))
    }

    if (view == "welcome" || is.null(nb_id)) {
      # Check setup status for live indicators
      cfg <- effective_config()
      has_or_key <- !is.null(get_setting(cfg, "openrouter", "api_key"))
      has_chat_model <- !is.null(get_db_setting(con, "chat_model")) ||
                        !is.null(get_setting(cfg, "defaults", "chat_model"))
      has_quality_data <- !is.null(get_db_setting(con, "quality_data_version"))

      status_badge <- function(ok, label_yes, label_no) {
        if (ok) {
          span(class = "badge bg-success me-1", icon_check(), label_yes)
        } else {
          span(class = "badge bg-warning text-dark me-1", icon_warning(), label_no)
        }
      }

      landing_step <- function(number, icon_fn, title, description, action_ui,
                               icon_class = "text-primary") {
        div(
          class = "d-flex align-items-start gap-3 p-3 border rounded mb-3",
          div(
            class = "text-center",
            style = "min-width: 48px;",
            span(class = "badge bg-primary rounded-pill fs-5", number),
            div(icon_fn(class = paste("fa-lg mt-2", icon_class)))
          ),
          div(
            class = "flex-grow-1",
            h5(class = "mb-1", title),
            p(class = "text-muted small mb-2", description),
            action_ui
          )
        )
      }

      return(
        card(
          class = "border-0 bg-transparent",
          card_body(
            class = "py-4",
            style = "max-width: 750px; margin: 0 auto;",
            div(
              class = "text-center mb-4",
              icon_book_open(class = "fa-3x text-primary mb-3"),
              h2("Welcome to Serapeum"),
              p(class = "lead text-muted",
                "Your AI-powered research assistant"),
              p(class = "text-muted small",
                "Follow these steps to get started with your research workflow.")
            ),

            # Step 1: Set Up
            landing_step("1", icon_settings, "Set Up",
              "Configure API keys, choose AI models, and download journal quality metadata.",
              div(
                div(
                  class = "d-flex flex-wrap gap-1 mb-2",
                  status_badge(has_or_key, "API key", "No API key"),
                  status_badge(has_chat_model, "Model set", "No model"),
                  status_badge(has_quality_data, "Metadata", "No metadata")
                ),
                actionButton("welcome_settings", "Go to Settings",
                             class = "btn-sm btn-outline-secondary",
                             icon = icon_settings())
              ),
              icon_class = "text-secondary"
            ),

            # Step 2: Find Papers
            landing_step("2", icon_search, "Find Papers",
              "Search OpenAlex, discover from a seed paper, explore research topics, or build a query with AI assistance.",
              div(
                class = "d-flex flex-wrap gap-2",
                actionButton("welcome_search", "New Search Notebook",
                             class = "btn-sm btn-outline-primary", icon = icon_search()),
                actionButton("welcome_discover", "Discover from Paper",
                             class = "btn-sm btn-outline-success", icon = icon_seedling()),
                actionButton("welcome_topics", "Explore Topics",
                             class = "btn-sm btn-outline-warning", icon = icon_compass()),
                actionButton("welcome_query", "Build a Query",
                             class = "btn-sm btn-outline-info", icon = icon_wand())
              )
            ),

            # Step 3: Collect & Import
            landing_step("3", icon_file_import, "Collect & Import",
              "Import papers by pasting DOIs or uploading BibTeX files. Upload PDFs into document notebooks.",
              div(
                class = "d-flex flex-wrap gap-2",
                actionButton("welcome_import", "Import Papers",
                             class = "btn-sm btn-outline-peach", icon = icon_file_import()),
                actionButton("welcome_doc_nb", "New Document Notebook",
                             class = "btn-sm btn-outline-primary", icon = icon_file_pdf())
              ),
              icon_class = "text-success"
            ),

            # Step 4: Analyze
            landing_step("4", icon_brain, "Analyze",
              "Chat with your papers using AI, generate literature reviews and synthesis presets, and visualize citation networks.",
              div(
                class = "d-flex flex-wrap gap-2",
                actionButton("welcome_network", "Citation Network",
                             class = "btn-sm btn-outline-primary", icon = icon_diagram())
              ),
              icon_class = "text-info"
            ),

            # Step 5: Audit
            landing_step("5", icon_audit, "Audit",
              "Run citation audits to find missing seminal papers and identify gaps in your collection.",
              actionButton("welcome_audit", "Citation Audit",
                           class = "btn-sm btn-outline-sky", icon = icon_audit()),
              icon_class = "text-warning"
            )
          )
        )
      )
    }

    # Get notebook info
    nb <- get_notebook(con, nb_id)
    if (is.null(nb)) {
      current_notebook(NULL)
      current_view("welcome")
      return(NULL)
    }

    # Show appropriate module based on type
    if (nb$type == "document") {
      tagList(
        div(
          class = "d-flex align-items-center gap-2 mb-3",
          h4(class = "mb-0", tagList(icon_file_pdf(class = "text-danger me-2"), nb$name)),
          actionButton("delete_nb", NULL, class = "btn-outline-danger btn-sm",
                       icon = icon_delete(), title = "Delete notebook")
        ),
        mod_document_notebook_ui("doc_notebook")
      )
    } else {
      tagList(
        div(
          class = "mb-3",
          div(
            class = "d-flex align-items-center gap-2",
            h4(class = "mb-0", tagList(icon_search(class = "text-primary me-2"), nb$name)),
            actionButton("delete_nb", NULL, class = "btn-outline-danger btn-sm",
                         icon = icon_delete(), title = "Delete notebook")
          ),
          p(class = "text-muted small mb-0 mt-1", paste("Query:", nb$search_query))
        ),
        mod_search_notebook_ui("search_notebook")
      )
    }
  })

  # Document notebook module
  mod_document_notebook_server("doc_notebook", con_r, current_notebook, effective_config)

  # Search notebook module
  search_nb_result <- mod_search_notebook_server("search_notebook", con_r, current_notebook, effective_config, notebook_refresh, db_path = db_path)

  # Seed discovery module
  discovery_request <- mod_seed_discovery_server("seed_discovery", reactive(con), config_file_r, pre_fill_doi)

  # Query builder module
  query_request <- mod_query_builder_server("query_builder", reactive(con), config_file_r)

  # Topic explorer module
  topic_request <- mod_topic_explorer_server("topic_explorer", reactive(con), config_file_r)

  # Citation network module
  network_api <- mod_citation_network_server("citation_network", con_r, effective_config, current_network, network_refresh)

  # Citation audit module
  mod_citation_audit_server("citation_audit", con, config_r = effective_config,
    db_path = db_path,
    navigate_to_notebook = function(notebook_id) {
      current_notebook(notebook_id)
      current_view("notebook")
      notebook_refresh(notebook_refresh() + 1)
    },
    notebook_refresh = notebook_refresh
  )

  # Sidebar bulk import module
  sidebar_import_api <- mod_bulk_import_server(
    "sidebar_import", con_r,
    notebook_id = sidebar_import_nb_id,
    config = effective_config,
    paper_refresh = reactiveVal(0),
    db_path_r = reactive(db_path),
    standalone = TRUE,
    navigate_to_notebook = function(nb_id) {
      current_notebook(nb_id)
      current_view("notebook")
      notebook_refresh(notebook_refresh() + 1)
    }
  )

  # Wire "Use as Seed" from search notebook to seed discovery
  observeEvent(search_nb_result$seed_request(), {
    req <- search_nb_result$seed_request()
    if (is.null(req)) return()

    # Navigate to seed discovery view
    current_view("discover")
    current_notebook(NULL)

    # Pre-fill DOI in seed discovery module
    pre_fill_doi(req$doi)
  }, ignoreInit = TRUE)

  # Wire "Seed Citation Network" from search notebook to citation network
  observeEvent(search_nb_result$network_seed_request(), {
    req_data <- search_nb_result$network_seed_request()
    req(req_data)
    network_api$set_seeds(req_data$seed_ids, req_data$source_notebook_id)
    current_view("network")
  }, ignoreInit = TRUE)

  # Wire "Seed Citation Network" from bulk import to citation network
  observeEvent(sidebar_import_api$network_seed_request(), {
    req_data <- sidebar_import_api$network_seed_request()
    req(req_data)
    network_api$set_seeds(req_data$seed_ids, req_data$source_notebook_id)
    current_view("network")
  }, ignoreInit = TRUE)

  # Consume discovery request to create search notebook
  observeEvent(discovery_request(), {
    req <- discovery_request()
    if (is.null(req)) return()

    # Build filter for the citation query
    citation_filter <- paste0(req$citation_type, ":", req$seed_paper$paper_id)

    # Create notebook with citation filter
    filters <- list(
      citation_filter = citation_filter,
      citation_type = req$citation_type,
      seed_paper_id = req$seed_paper$paper_id
    )

    nb_id <- create_notebook(con, req$notebook_name, "search",
                             search_query = NULL,
                             search_filters = filters)

    # Fetch citation results and populate notebook
    email <- get_setting(config_file, "openalex", "email")
    api_key <- get_setting(config_file, "openalex", "api_key")

    withProgress(message = "Fetching related papers...", {
      papers <- tryCatch({
        switch(req$citation_type,
          cites = get_citing_papers(req$seed_paper$paper_id, email, api_key),
          cited_by = get_cited_papers(req$seed_paper$paper_id, email, api_key),
          related_to = get_related_papers(req$seed_paper$paper_id, email, api_key)
        )
      }, error = function(e) {
        if (inherits(e, "api_error")) {
          show_error_toast(e$message, e$details, e$severity)
        } else {
          err <- classify_api_error(e, "OpenAlex")
          show_error_toast(err$message, err$details, err$severity)
        }
        list()
      })

      # BUGF-01 Part A: Insert seed paper first so it always appears in the notebook
      seed <- req$seed_paper
      seed_existing <- dbGetQuery(con, "SELECT id FROM abstracts WHERE notebook_id = ? AND paper_id = ?",
                                  list(nb_id, seed$paper_id))
      if (nrow(seed_existing) == 0) {
        seed_abstract_id <- create_abstract(
          con, nb_id, seed$paper_id, seed$title,
          seed$authors, seed$abstract,
          seed$year, seed$venue, seed$pdf_url,
          keywords = seed$keywords,
          work_type = seed$work_type,
          work_type_crossref = seed$work_type_crossref,
          oa_status = seed$oa_status,
          is_oa = seed$is_oa,
          cited_by_count = seed$cited_by_count,
          referenced_works_count = seed$referenced_works_count,
          fwci = seed$fwci,
          doi = seed$doi
        )
        if (!is.null(seed$abstract) && !is.na(seed$abstract) && nchar(seed$abstract) > 0) {
          create_chunk(con, seed_abstract_id, "abstract", 0, seed$abstract)
        }
      }

      if (length(papers) > 0) {
        for (paper in papers) {
          # Check for duplicate
          existing <- dbGetQuery(con, "SELECT id FROM abstracts WHERE notebook_id = ? AND paper_id = ?",
                                 list(nb_id, paper$paper_id))
          if (nrow(existing) > 0) next

          abstract_id <- create_abstract(
            con, nb_id, paper$paper_id, paper$title,
            paper$authors, paper$abstract,
            paper$year, paper$venue, paper$pdf_url,
            keywords = paper$keywords,
            work_type = paper$work_type,
            work_type_crossref = paper$work_type_crossref,
            oa_status = paper$oa_status,
            is_oa = paper$is_oa,
            cited_by_count = paper$cited_by_count,
            referenced_works_count = paper$referenced_works_count,
            fwci = paper$fwci
          )

          if (!is.na(paper$abstract) && nchar(paper$abstract) > 0) {
            create_chunk(con, abstract_id, "abstract", 0, paper$abstract)
          }
        }
      }

      incProgress(1.0)
    })

    # Navigate to the new notebook
    notebook_refresh(notebook_refresh() + 1)
    current_notebook(nb_id)
    current_view("notebook")

    showNotification(
      paste("Created notebook with", length(papers), "papers"),
      type = "message"
    )
  })

  # Consume query builder request to create search notebook
  observeEvent(query_request(), {
    req <- query_request()
    if (is.null(req)) return()

    # Create notebook with LLM-generated query
    nb_id <- create_notebook(con, req$notebook_name, "search",
                             search_query = req$query,
                             search_filters = req$filters)

    # Execute the search using existing OpenAlex search
    email <- get_setting(config_file, "openalex", "email")
    api_key <- get_setting(config_file, "openalex", "api_key")

    withProgress(message = "Searching OpenAlex...", {
      # Use search_papers function from api_openalex.R
      # The filter string needs to be parsed to extract individual parameters
      filter_str <- req$filters$filter

      # For now, pass the full filter string to search_papers
      # We'll need to parse it to extract specific parameters
      results <- tryCatch({
        # Build a minimal query using search_papers
        # Extract search term from filters if present, or use req$query
        search_term <- req$query %||% ""

        # Call search_papers with filter string
        # Note: search_papers doesn't accept a raw filter string parameter
        # We need to parse the filter to extract year ranges, etc.
        # For simplicity, we'll use the filter as-is and rely on OpenAlex API

        # Actually, looking at api_openalex.R, there's no direct way to pass raw filters
        # We need to use the lower-level build_openalex_request
        req_obj <- build_openalex_request("works", email, api_key)

        if (!is.null(search_term) && nchar(search_term) > 0) {
          req_obj <- req_obj |> req_url_query(search = search_term)
        }

        if (!is.null(filter_str) && nchar(filter_str) > 0) {
          req_obj <- req_obj |> req_url_query(filter = filter_str, per_page = 50)
        } else {
          req_obj <- req_obj |> req_url_query(per_page = 50)
        }

        resp <- req_perform(req_obj)
        body <- resp_body_json(resp)

        if (is.null(body$results)) {
          list()
        } else {
          lapply(body$results, parse_openalex_work)
        }
      }, error = function(e) {
        if (inherits(e, "api_error")) {
          show_error_toast(e$message, e$details, e$severity)
        } else {
          err <- classify_api_error(e, "OpenAlex")
          show_error_toast(err$message, err$details, err$severity)
        }
        list()
      })

      if (length(results) > 0) {
        for (paper in results) {
          existing <- dbGetQuery(con, "SELECT id FROM abstracts WHERE notebook_id = ? AND paper_id = ?",
                                 list(nb_id, paper$paper_id))
          if (nrow(existing) > 0) next

          abstract_id <- create_abstract(
            con, nb_id, paper$paper_id, paper$title,
            paper$authors, paper$abstract,
            paper$year, paper$venue, paper$pdf_url,
            keywords = paper$keywords,
            work_type = paper$work_type,
            work_type_crossref = paper$work_type_crossref,
            oa_status = paper$oa_status,
            is_oa = paper$is_oa,
            cited_by_count = paper$cited_by_count,
            referenced_works_count = paper$referenced_works_count,
            fwci = paper$fwci
          )

          if (!is.na(paper$abstract) && nchar(paper$abstract) > 0) {
            create_chunk(con, abstract_id, "abstract", 0, paper$abstract)
          }
        }
      }

      incProgress(1.0)
    })

    # Navigate to new notebook
    current_notebook(nb_id)
    current_view("notebook")
    if (!is.null(notebook_refresh)) notebook_refresh(notebook_refresh() + 1)
    showNotification(paste("Created notebook with", length(results), "papers"), type = "message")
  })

  # Consume topic request to create search notebook
  observeEvent(topic_request(), {
    req <- topic_request()
    if (is.null(req)) return()

    # Create notebook with topic filter
    filter_str <- paste0("primary_topic.id:", req$topic_id)

    filters <- list(
      filter = filter_str,
      topic_id = req$topic_id,
      topic_name = req$topic_name
    )

    nb_id <- create_notebook(con, req$notebook_name, "search",
                             search_query = "",
                             search_filters = filters)

    # Fetch papers filtered by topic
    email <- get_setting(config_file, "openalex", "email")
    api_key <- get_setting(config_file, "openalex", "api_key")

    results <- tryCatch({
      req_obj <- build_openalex_request("works", email, api_key) |>
        req_url_query(filter = filter_str, per_page = 50)

      resp <- req_perform(req_obj)
      body <- resp_body_json(resp)

      if (is.null(body$results)) list()
      else lapply(body$results, parse_openalex_work)
    }, error = function(e) {
      if (inherits(e, "api_error")) {
        show_error_toast(e$message, e$details, e$severity)
      } else {
        err <- classify_api_error(e, "OpenAlex")
        show_error_toast(err$message, err$details, err$severity)
      }
      list()
    })

    if (length(results) > 0) {
      withProgress(message = paste("Adding", length(results), "papers..."), {
        for (paper in results) {
          existing <- dbGetQuery(con, "SELECT id FROM abstracts WHERE notebook_id = ? AND paper_id = ?",
                                 list(nb_id, paper$paper_id))
          if (nrow(existing) > 0) next

          abstract_id <- create_abstract(
            con, nb_id, paper$paper_id, paper$title,
            paper$authors, paper$abstract,
            paper$year, paper$venue, paper$pdf_url,
            keywords = paper$keywords,
            work_type = paper$work_type,
            work_type_crossref = paper$work_type_crossref,
            oa_status = paper$oa_status,
            is_oa = paper$is_oa,
            cited_by_count = paper$cited_by_count,
            referenced_works_count = paper$referenced_works_count,
            fwci = paper$fwci
          )

          if (!is.na(paper$abstract) && nchar(paper$abstract) > 0) {
            create_chunk(con, abstract_id, "abstract", 0, paper$abstract)
          }
        }
      })
    }

    # Navigate to new notebook
    notebook_refresh(notebook_refresh() + 1)
    current_notebook(nb_id)
    current_view("notebook")
    showNotification(paste("Created notebook with", length(results), "papers for topic:", req$topic_name), type = "message")
  })

  # Delete notebook
  observeEvent(input$delete_nb, {
    nb_id <- current_notebook()
    req(nb_id)

    nb <- get_notebook(con, nb_id)

    showModal(modalDialog(
      title = "Delete Notebook",
      p("Are you sure you want to delete", strong(nb$name), "?"),
      p(class = "text-danger", "This will permanently delete all documents and data in this notebook."),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_delete", "Delete", class = "btn-danger")
      )
    ))
  })

  observeEvent(input$confirm_delete, {
    nb_id <- current_notebook()
    req(nb_id)

    # Delete files
    storage_dir <- file.path(".temp", "pdfs", nb_id)
    if (dir.exists(storage_dir)) {
      unlink(storage_dir, recursive = TRUE)
    }

    delete_notebook(con, nb_id)
    removeModal()
    notebook_refresh(notebook_refresh() + 1)
    current_notebook(NULL)
    current_view("welcome")
    showNotification("Notebook deleted", type = "message")
  })
}

# Run app
port <- get_setting(config_file, "app", "port") %||% 8080
shinyApp(ui, server, options = list(port = port, launch.browser = TRUE))
