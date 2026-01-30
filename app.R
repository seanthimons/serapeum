library(shiny)
library(bslib)
library(DBI)
library(duckdb)

# Source all R files
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

# Load config from file (if exists)
config_file <- load_config()

# Initialize database
db_path <- get_setting(config_file, "app", "db_path") %||% "data/notebooks.duckdb"

# UI
ui <- page_sidebar(
  title = div(
    class = "d-flex align-items-center gap-2",
    icon("book-open"),
    "Notebook"
  ),
  theme = bs_theme(
    preset = "shiny",
    primary = "#6366f1",
    "border-radius" = "0.5rem"
  ),
  sidebar = sidebar(
    title = "Notebooks",
    width = 280,
    # New notebook button
    div(
      class = "d-grid gap-2 mb-3",
      actionButton("new_document_nb", "New Document Notebook",
                   class = "btn-primary",
                   icon = icon("file-pdf")),
      actionButton("new_search_nb", "New Search Notebook",
                   class = "btn-outline-primary",
                   icon = icon("magnifying-glass"))
    ),
    hr(),
    # Notebook list
    div(
      style = "max-height: calc(100vh - 350px); overflow-y: auto;",
      uiOutput("notebook_list")
    ),
    hr(),
    # Settings link
    actionLink("settings_link", label = tagList(icon("gear"), "Settings"),
               class = "text-muted")
  ),
  # Main content
  uiOutput("main_content")
)

# Server
server <- function(input, output, session) {

  # Database connection - create fresh for this session
  con <- get_db_connection(db_path)
  init_schema(con)

  # Clean up on session end
  session$onSessionEnded(function() {
    tryCatch({
      DBI::dbDisconnect(con, shutdown = TRUE)
    }, error = function(e) {})
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

  # Reactive: current selected notebook
  current_notebook <- reactiveVal(NULL)

  # Reactive: current view ("notebook" or "settings")
  current_view <- reactiveVal("welcome")

  # Reactive: trigger notebook list refresh
  notebook_refresh <- reactiveVal(0)

  # Settings module - returns effective config
  effective_config <- mod_settings_server("settings", con_r, config_file_r)

  # Render notebook list
  output$notebook_list <- renderUI({
    notebook_refresh()

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
      }
    )
  })

  # Observe notebook selection clicks
  observe({
    notebooks <- list_notebooks(con)
    lapply(notebooks$id, function(nb_id) {
      observeEvent(input[[paste0("select_nb_", nb_id)]], {
        current_notebook(nb_id)
        current_view("notebook")
      }, ignoreInit = TRUE)
    })
  })

  # Settings link
  observeEvent(input$settings_link, {
    current_view("settings")
    current_notebook(NULL)
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
      layout_columns(
        col_widths = c(6, 6),
        numericInput("search_from_year", "From Year", value = 2020,
                     min = 1900, max = 2030),
        numericInput("search_to_year", "To Year", value = 2025,
                     min = 1900, max = 2030)
      ),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("create_search_nb", "Create & Search", class = "btn-primary")
      )
    ))
  })

  # Create search notebook
  observeEvent(input$create_search_nb, {
    req(input$new_search_nb_name, input$new_search_query)
    name <- trimws(input$new_search_nb_name)
    query <- trimws(input$new_search_query)
    if (nchar(name) == 0 || nchar(query) == 0) return()

    filters <- list(
      from_year = input$search_from_year,
      to_year = input$search_to_year
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
    view <- current_view()
    nb_id <- current_notebook()

    if (view == "settings") {
      return(mod_settings_ui("settings"))
    }

    if (view == "welcome" || is.null(nb_id)) {
      return(
        card(
          class = "border-0",
          card_body(
            class = "text-center py-5",
            icon("book-open", class = "fa-4x text-primary mb-4"),
            h2("Welcome to Notebook"),
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
  mod_search_notebook_server("search_notebook", con_r, current_notebook, effective_config, notebook_refresh)

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
    storage_dir <- file.path("storage", nb_id)
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
