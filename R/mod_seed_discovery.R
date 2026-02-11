#' Seed Paper Discovery Module UI
#' @param id Module ID
mod_seed_discovery_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header("Discover from a Paper"),
    card_body(
      # DOI input
      textInput(
        ns("doi_input"),
        "Enter DOI or DOI URL",
        placeholder = "10.1234/abcd or https://doi.org/10.1234/abcd"
      ),

      # Lookup button
      actionButton(
        ns("lookup_btn"),
        "Look Up",
        class = "btn-primary"
      ),

      # Paper preview area
      hr(),
      uiOutput(ns("paper_preview")),

      # Citation controls area
      uiOutput(ns("citation_controls"))
    )
  )
}

#' Seed Paper Discovery Module Server
#' @param id Module ID
#' @param con Reactive database connection
#' @param config Reactive config
#' @return Reactive discovery_request for app.R to consume
mod_seed_discovery_server <- function(id, con, config) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Internal state
    seed_paper <- reactiveVal(NULL)
    discovery_request <- reactiveVal(NULL)

    # Lookup button click
    observeEvent(input$lookup_btn, {
      req(input$doi_input)

      # Normalize DOI
      doi <- normalize_doi(input$doi_input)

      if (is.null(doi)) {
        showNotification(
          "Invalid DOI format. Please enter a valid DOI.",
          type = "error",
          duration = 5
        )
        return()
      }

      # Get config values — prefer DB settings, fall back to config file
      cfg <- config()
      email <- get_db_setting(con(), "openalex_email") %||%
               get_setting(cfg, "openalex", "email")
      api_key <- get_setting(cfg, "openalex", "api_key")

      if (is.null(email) || nchar(email) == 0) {
        showNotification(
          "OpenAlex email not configured. Please go to Settings.",
          type = "warning",
          duration = 5
        )
        return()
      }

      # Fetch paper
      withProgress(message = "Looking up paper...", {
        paper <- tryCatch({
          get_paper(doi, email, api_key)
        }, error = function(e) {
          showNotification(
            paste("Error fetching paper:", e$message),
            type = "error",
            duration = 5
          )
          NULL
        })

        if (is.null(paper)) {
          showNotification(
            "Paper not found. Please check the DOI.",
            type = "error",
            duration = 5
          )
          return()
        }

        seed_paper(paper)
        showNotification(
          "Paper found!",
          type = "message",
          duration = 3
        )
      })
    })

    # Paper preview
    output$paper_preview <- renderUI({
      paper <- seed_paper()
      if (is.null(paper)) return(NULL)

      # Format authors (first 3 + "et al.")
      authors_display <- if (length(paper$authors) > 0) {
        author_names <- unlist(paper$authors)
        if (length(author_names) > 3) {
          paste(paste(author_names[1:3], collapse = ", "), "et al.")
        } else {
          paste(author_names, collapse = ", ")
        }
      } else {
        "Unknown authors"
      }

      # Abstract snippet (first 200 chars)
      abstract_snippet <- if (!is.na(paper$abstract) && nchar(paper$abstract) > 0) {
        snippet <- substr(paper$abstract, 1, 200)
        if (nchar(paper$abstract) > 200) {
          paste0(snippet, "...")
        } else {
          snippet
        }
      } else {
        "(No abstract available)"
      }

      div(
        class = "border rounded p-3 bg-light",
        h5(class = "mb-2", paper$title),
        p(class = "text-muted small mb-1", authors_display),
        p(class = "text-muted small mb-2",
          paste0(
            if (!is.na(paper$year)) paste0(paper$year, " • ") else "",
            if (!is.na(paper$venue)) paper$venue else "No venue"
          )
        ),
        p(class = "small mb-0", abstract_snippet)
      )
    })

    # Citation controls
    output$citation_controls <- renderUI({
      paper <- seed_paper()
      if (is.null(paper)) return(NULL)

      div(
        hr(),
        h6("Citation Relationships"),
        p(
          class = "text-muted small",
          sprintf(
            "Cited by: %d papers | References: %d papers",
            paper$cited_by_count %||% 0,
            paper$referenced_works_count %||% 0
          )
        ),
        radioButtons(
          ns("citation_type"),
          "Select citation direction:",
          choices = c(
            "Papers citing this work" = "cites",
            "Papers cited by this work" = "cited_by",
            "Related papers" = "related_to"
          ),
          selected = "cites"
        ),
        actionButton(
          ns("fetch_btn"),
          "Create Notebook with Results",
          class = "btn-success w-100",
          icon = icon("book")
        )
      )
    })

    # Fetch button click
    observeEvent(input$fetch_btn, {
      paper <- seed_paper()
      req(paper, input$citation_type)

      # Create label based on citation type
      label <- switch(
        input$citation_type,
        cites = "Citing:",
        cited_by = "Cited by:",
        related_to = "Related to:"
      )

      notebook_name <- paste(label, paper$title)

      # Set discovery request for app.R to consume
      discovery_request(list(
        seed_paper = paper,
        citation_type = input$citation_type,
        notebook_name = notebook_name
      ))
    })

    # Return discovery request reactive
    return(discovery_request)
  })
}
