library(shiny)
library(bslib)
library(DBI)
library(duckdb)
library(connections)

# Options
options("duckdb.enable_rstudio_connection_pane" = TRUE)

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

# UI
ui <- page_sidebar(
  title = div(
    class = "d-flex align-items-center justify-content-between w-100",
    div(
      class = "d-flex align-items-center gap-2",
      icon("book-open"),
      "Serapeum"
    ),
    tags$button(
      id = "dark_mode_toggle",
      class = "btn btn-sm btn-outline-secondary border-0",
      onclick = "
        const html = document.documentElement;
        const current = html.getAttribute('data-bs-theme');
        const next = current === 'dark' ? 'light' : 'dark';
        html.setAttribute('data-bs-theme', next);
        localStorage.setItem('theme', next);
        this.innerHTML = next === 'dark' ? '<i class=\"fa fa-sun\"></i>' : '<i class=\"fa fa-moon\"></i>';
      ",
      icon("moon")
    )
  ),
  theme = bs_theme(
    preset = "shiny",
    primary = "#6366f1",
    "border-radius" = "0.5rem"
  ),
  tags$head(
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
  "))),
  sidebar = sidebar(
    title = "Notebooks",
    width = 280,
    # New notebook button
    div(
      class = "d-grid gap-2 mb-2",
      actionButton("new_document_nb", "New Document Notebook",
                   class = "btn-primary",
                   icon = icon("file-pdf")),
      actionButton("new_search_nb", "New Search Notebook",
                   class = "btn-outline-primary",
                   icon = icon("magnifying-glass")),
      actionButton("discover_paper", "Discover from Paper",
                   class = "btn-outline-success",
                   icon = icon("seedling")),
      actionButton("build_query", "Build a Query",
                   class = "btn-outline-info",
                   icon = icon("wand-magic-sparkles")),
      actionButton("explore_topics", "Explore Topics",
                   class = "btn-outline-warning",
                   icon = icon("compass")),
      actionButton("new_network", "Citation Network",
                   class = "btn-outline-danger",
                   icon = icon("diagram-project"))
    ),
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
        span(class = "text-muted small", icon("coins"), " Session:"),
        div(
          class = "d-flex align-items-center gap-2",
          textOutput("session_cost_inline", inline = TRUE) |>
            tagAppendAttributes(class = "text-muted small fw-semibold"),
          actionLink("cost_link", label = tagList(icon("dollar-sign"), "Details"),
                     class = "text-muted small")
        )
      ),
      # Row 2: Settings + About
      div(
        class = "d-flex justify-content-between align-items-center",
        actionLink("settings_link", label = tagList(icon("gear"), "Settings"),
                   class = "text-muted small"),
        actionLink("about_link", label = tagList(icon("info-circle"), "About"),
                   class = "text-muted small")
      )
    ),
    # Script to restore theme preference on load
    tags$script(HTML("
      document.addEventListener('DOMContentLoaded', function() {
        const saved = localStorage.getItem('theme');
        if (saved) {
          document.documentElement.setAttribute('data-bs-theme', saved);
          const btn = document.getElementById('dark_mode_toggle');
          if (btn) btn.innerHTML = saved === 'dark' ? '<i class=\"fa fa-sun\"></i>' : '<i class=\"fa fa-moon\"></i>';
        }
      });
    "))
  ),
  # Main content
  uiOutput("main_content")
)

# Server
server <- function(input, output, session) {

  # Database connection - create fresh for this session
  con <- get_db_connection(db_path)
  init_schema(con)
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

  # Reactive: trigger network list refresh
  network_refresh <- reactiveVal(0)

  # Settings module - returns effective config
  effective_config <- mod_settings_server("settings", con_r, config_file_r)

  # Cost tracker module
  mod_cost_tracker_server("cost_tracker", con_r, reactive(session_id), effective_config)

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
                icon("file-pdf", class = "text-danger me-2"),
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
                icon("magnifying-glass", class = "text-primary me-2"),
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
                    icon("diagram-project", class = "text-danger me-2"),
                    span(class = "text-truncate", net$name)
                  ),
                  class = "flex-grow-1 text-decoration-none"
                ),
                actionButton(
                  paste0("delete_network_", net$id),
                  icon("times"),
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
      observeEvent(input[[paste0("delete_network_", net_id)]], {
        # Delete immediately without confirmation (per plan requirement)
        delete_network(con, net_id)
        network_refresh(network_refresh() + 1)

        # If deleted network is currently viewed, go back to welcome
        if (!is.null(current_network()) && current_network() == net_id) {
          current_network(NULL)
          current_view("welcome")
        }

        showNotification("Network deleted", type = "message")
      }, ignoreInit = TRUE)
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

  # Wizard modal helper function
  wizard_modal <- function() {
    modalDialog(
      title = tagList(icon("compass"), "Welcome to Serapeum"),
      div(
        class = "text-center mb-4",
        p(class = "lead", "How would you like to start exploring research?")
      ),
      layout_columns(
        col_widths = c(4, 4, 4),
        actionButton("wizard_seed_paper",
                     label = tagList(
                       div(icon("seedling", class = "fa-2x mb-2")),
                       div(strong("Start with a Paper")),
                       div(class = "small text-muted", "Have a paper in mind? Find related work.")
                     ),
                     class = "btn-outline-success w-100 h-100 py-4"),
        actionButton("wizard_query_builder",
                     label = tagList(
                       div(icon("wand-magic-sparkles", class = "fa-2x mb-2")),
                       div(strong("Build a Query")),
                       div(class = "small text-muted", "Describe your research interest.")
                     ),
                     class = "btn-outline-info w-100 h-100 py-4"),
        actionButton("wizard_topic_explorer",
                     label = tagList(
                       div(icon("compass", class = "fa-2x mb-2")),
                       div(strong("Browse Topics")),
                       div(class = "small text-muted", "Explore research areas.")
                     ),
                     class = "btn-outline-warning w-100 h-100 py-4")
      ),
      footer = tagList(
        actionLink("skip_wizard", "Don't show this again", class = "text-muted"),
        modalButton("Close")
      ),
      size = "l",
      easyClose = TRUE
    )
  }

  # Show wizard on first load — only if no notebooks exist yet
  observe({
    con <- con_r()
    req(con)
    notebooks <- list_notebooks(con)
    if (nrow(notebooks) == 0) {
      shiny::onFlushed(function() {
        showModal(wizard_modal())
      }, once = TRUE)
    }
  }) |> bindEvent(con_r(), once = TRUE)

  # Wizard routing handlers
  observeEvent(input$wizard_seed_paper, {
    removeModal()
    current_notebook(NULL)
    current_view("discover")
  })

  observeEvent(input$wizard_query_builder, {
    removeModal()
    current_notebook(NULL)
    current_view("query_builder")
  })

  observeEvent(input$wizard_topic_explorer, {
    removeModal()
    current_notebook(NULL)
    current_view("topic_explorer")
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

  # New citation network button - show seed paper search modal
  observeEvent(input$new_network, {
    showModal(modalDialog(
      title = tagList(icon("diagram-project"), "New Citation Network"),
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
      title = tagList(icon("file-pdf"), "New Document Notebook"),
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
      title = tagList(icon("magnifying-glass"), "New Search Notebook"),
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

      hr(),

      # Quality filters
      div(
        class = "mb-3",
        h6(class = "text-muted", icon("shield-halved"), " Quality Filters"),
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
    min_citations <- input$search_min_citations
    exclude_retracted <- input$search_exclude_retracted %||% TRUE

    preview <- build_query_preview(query, from_year, to_year, search_field, is_oa,
                                    min_citations, exclude_retracted)

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

    if (view == "welcome" || is.null(nb_id)) {
      return(
        card(
          class = "border-0",
          card_body(
            class = "text-center py-5",
            icon("book-open", class = "fa-4x text-primary mb-4"),
            h2("Welcome to Serapeum"),
            p(class = "lead text-muted",
              "Your AI-powered research assistant"),
            hr(class = "my-4"),
            layout_columns(
              col_widths = c(4, 4, 4),
              div(
                icon("file-pdf", class = "fa-2x text-danger mb-2"),
                h5("Document Notebooks"),
                p(class = "text-muted small",
                  "Upload PDFs and chat with your documents. Get summaries, key points, and answers with citations.")
              ),
              div(
                icon("magnifying-glass", class = "fa-2x text-primary mb-2"),
                h5("Search Notebooks"),
                p(class = "text-muted small",
                  "Search OpenAlex for academic papers. Query abstracts and import interesting finds.")
              ),
              div(
                icon("gear", class = "fa-2x text-secondary mb-2"),
                h5("Configurable"),
                p(class = "text-muted small",
                  "Choose your preferred AI models via OpenRouter. Your data stays local.")
              )
            ),
            hr(class = "my-4"),
            p(class = "text-muted",
              "Get started by creating a notebook from the sidebar.")
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
          class = "d-flex justify-content-between align-items-center mb-3",
          h4(class = "mb-0", tagList(icon("file-pdf", class = "text-danger me-2"), nb$name)),
          actionButton("delete_nb", "Delete", class = "btn-outline-danger btn-sm",
                       icon = icon("trash"))
        ),
        mod_document_notebook_ui("doc_notebook")
      )
    } else {
      tagList(
        div(
          class = "d-flex justify-content-between align-items-center mb-3",
          div(
            h4(class = "mb-0", tagList(icon("magnifying-glass", class = "text-primary me-2"), nb$name)),
            p(class = "text-muted small mb-0", paste("Query:", nb$search_query))
          ),
          actionButton("delete_nb", "Delete", class = "btn-outline-danger btn-sm",
                       icon = icon("trash"))
        ),
        mod_search_notebook_ui("search_notebook")
      )
    }
  })

  # Document notebook module
  mod_document_notebook_server("doc_notebook", con_r, current_notebook, effective_config)

  # Search notebook module
  search_seed_request <- mod_search_notebook_server("search_notebook", con_r, current_notebook, effective_config, notebook_refresh)

  # Seed discovery module
  discovery_request <- mod_seed_discovery_server("seed_discovery", reactive(con), config_file_r, pre_fill_doi)

  # Query builder module
  query_request <- mod_query_builder_server("query_builder", reactive(con), config_file_r)

  # Topic explorer module
  topic_request <- mod_topic_explorer_server("topic_explorer", reactive(con), config_file_r)

  # Citation network module
  mod_citation_network_server("citation_network", con_r, effective_config, current_network, network_refresh)

  # Wire "Use as Seed" from search notebook to seed discovery
  observeEvent(search_seed_request(), {
    req <- search_seed_request()
    if (is.null(req)) return()

    # Navigate to seed discovery view
    current_view("discover")
    current_notebook(NULL)

    # Pre-fill DOI in seed discovery module
    pre_fill_doi(req$doi)
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
