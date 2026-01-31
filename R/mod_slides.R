# R/mod_slides.R
#' Slides Generation Modal UI
#' @param ns Namespace function from session$ns
#' @param documents Data frame of documents (id, filename)
#' @param models Data frame of available models (id, name)
#' @param current_model Currently selected model ID
mod_slides_modal_ui <- function(ns, documents, models, current_model) {
  # RevealJS themes
  themes <- c("default", "beige", "blood", "dark", "league",
              "moon", "night", "serif", "simple", "sky", "solarized")

  modalDialog(
    title = tagList(icon("file-powerpoint"), "Generate Slides"),
    size = "l",
    easyClose = FALSE,

    # Document selection
    div(
      class = "mb-4",
      h6("Select Documents", class = "fw-semibold"),
      div(
        class = "border rounded p-3",
        style = "max-height: 200px; overflow-y: auto;",
        checkboxInput(ns("select_all_docs"), "Select All", value = TRUE),
        hr(class = "my-2"),
        checkboxGroupInput(
          ns("selected_docs"),
          NULL,
          choices = setNames(documents$id, documents$filename),
          selected = documents$id
        )
      )
    ),

    # Configuration options
    div(
      class = "mb-3",
      h6("Options", class = "fw-semibold"),

      layout_columns(
        col_widths = c(6, 6),

        # Model selection
        selectInput(
          ns("model"),
          "Model",
          choices = setNames(models$id, models$name),
          selected = current_model
        ),

        # Length
        radioButtons(
          ns("length"),
          "Presentation Length",
          choices = c("Short (5-8 slides)" = "short",
                      "Medium (10-15 slides)" = "medium",
                      "Long (20+ slides)" = "long"),
          selected = "medium",
          inline = TRUE
        )
      ),

      layout_columns(
        col_widths = c(4, 4, 4),

        # Audience
        selectInput(
          ns("audience"),
          "Audience",
          choices = c("Technical" = "technical",
                      "Executive" = "executive",
                      "General / Educational" = "general"),
          selected = "general"
        ),

        # Citation style
        selectInput(
          ns("citation_style"),
          "Citation Style",
          choices = c("Footnotes" = "footnotes",
                      "Inline (Author, p.X)" = "inline",
                      "Speaker Notes Only" = "notes_only",
                      "None" = "none"),
          selected = "footnotes"
        ),

        # Theme
        selectInput(
          ns("theme"),
          "Theme",
          choices = themes,
          selected = "default"
        )
      ),

      # Speaker notes checkbox
      checkboxInput(ns("include_notes"), "Include speaker notes", value = TRUE),

      # Custom instructions
      textAreaInput(
        ns("custom_instructions"),
        "Custom Instructions (optional)",
        placeholder = "e.g., Focus on methodology, include comparison table...",
        rows = 2
      )
    ),

    footer = tagList(
      modalButton("Cancel"),
      actionButton(ns("generate"), "Generate", class = "btn-primary", icon = icon("wand-magic-sparkles"))
    )
  )
}

#' Slides Results Modal UI
#' @param ns Namespace function from session$ns
#' @param preview_url URL to preview HTML (or NULL)
#' @param error Error message (or NULL)
mod_slides_results_ui <- function(ns, preview_url = NULL, error = NULL) {

  content <- if (!is.null(error)) {
    div(
      class = "alert alert-danger",
      icon("triangle-exclamation", class = "me-2"),
      strong("Generation failed: "), error
    )
  } else if (!is.null(preview_url)) {
    tagList(
      div(
        class = "mb-3",
        style = "height: 400px; border: 1px solid var(--bs-border-color); border-radius: 0.5rem; overflow: hidden;",
        tags$iframe(
          src = preview_url,
          style = "width: 100%; height: 100%; border: none;"
        )
      ),
      div(
        class = "d-flex gap-2 justify-content-center",
        downloadButton(ns("download_qmd"), "Download .qmd", class = "btn-outline-primary"),
        downloadButton(ns("download_html"), "Download HTML", class = "btn-outline-primary"),
        downloadButton(ns("download_pdf"), "Download PDF", class = "btn-outline-secondary")
      )
    )
  } else {
    div(
      class = "text-center py-5",
      div(class = "spinner-border text-primary", role = "status"),
      p(class = "mt-3 text-muted", "Generating slides...")
    )
  }

  modalDialog(
    title = tagList(icon("file-powerpoint"), "Generated Slides"),
    size = "xl",
    easyClose = FALSE,
    content,
    footer = tagList(
      actionButton(ns("regenerate"), "Regenerate", class = "btn-outline-secondary", icon = icon("rotate")),
      modalButton("Close")
    )
  )
}

#' Slides Module Server
#' @param id Module ID
#' @param con Database connection (reactive)
#' @param notebook_id Reactive notebook ID
#' @param config App config (reactive)
#' @param trigger Reactive trigger to open modal
mod_slides_server <- function(id, con, notebook_id, config, trigger) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Store generation state
    generation_state <- reactiveValues(
      qmd_content = NULL,
      qmd_path = NULL,
      html_path = NULL,
      pdf_path = NULL,
      error = NULL,
      last_options = NULL
    )

    # Handle select all checkbox
    observeEvent(input$select_all_docs, {
      nb_id <- notebook_id()
      req(nb_id)
      docs <- list_documents(con(), nb_id)

      if (input$select_all_docs) {
        updateCheckboxGroupInput(session, "selected_docs", selected = docs$id)
      } else {
        updateCheckboxGroupInput(session, "selected_docs", selected = character(0))
      }
    }, ignoreInit = TRUE)

    # Open modal when triggered
    observeEvent(trigger(), {
      nb_id <- notebook_id()
      req(nb_id)

      # Check Quarto installation
      if (!check_quarto_installed()) {
        showNotification(
          "Quarto is not installed. Please install Quarto to use slide generation: https://quarto.org/docs/get-started/",
          type = "error",
          duration = 10
        )
        return()
      }

      # Get documents
      docs <- list_documents(con(), nb_id)
      if (nrow(docs) == 0) {
        showNotification("No documents in this notebook", type = "warning")
        return()
      }

      # Get models
      cfg <- config()
      api_key <- get_setting(cfg, "openrouter", "api_key")
      models <- tryCatch({
        list_models(api_key)
      }, error = function(e) {
        data.frame(id = "anthropic/claude-sonnet-4", name = "Claude Sonnet 4", stringsAsFactors = FALSE)
      })

      current_model <- get_setting(cfg, "defaults", "chat_model") %||% "anthropic/claude-sonnet-4"

      # Reset state
      generation_state$qmd_content <- NULL
      generation_state$qmd_path <- NULL
      generation_state$html_path <- NULL
      generation_state$error <- NULL

      showModal(mod_slides_modal_ui(ns, docs, models, current_model))
    }, ignoreInit = TRUE)

    # Handle generation
    observeEvent(input$generate, {
      req(input$selected_docs)
      nb_id <- notebook_id()
      cfg <- config()

      # Get selected document IDs
      doc_ids <- input$selected_docs

      if (length(doc_ids) == 0) {
        showNotification("Please select at least one document", type = "warning")
        return()
      }

      # Store options for regeneration
      generation_state$last_options <- list(
        model = input$model,
        length = input$length,
        audience = input$audience,
        citation_style = input$citation_style,
        include_notes = input$include_notes,
        theme = input$theme,
        custom_instructions = input$custom_instructions
      )

      # Show loading modal
      showModal(mod_slides_results_ui(ns))

      # Get chunks for selected documents
      chunks <- get_chunks_for_documents(con(), doc_ids)

      if (nrow(chunks) == 0) {
        generation_state$error <- "No content found in selected documents"
        showModal(mod_slides_results_ui(ns, error = generation_state$error))
        return()
      }

      # Get notebook name for title
      nb <- get_notebook(con(), nb_id)
      notebook_name <- nb$name %||% "Presentation"

      # Generate slides
      api_key <- get_setting(cfg, "openrouter", "api_key")

      result <- generate_slides(
        api_key = api_key,
        model = input$model,
        chunks = chunks,
        options = generation_state$last_options,
        notebook_name = notebook_name
      )

      if (!is.null(result$error)) {
        generation_state$error <- result$error
        showModal(mod_slides_results_ui(ns, error = result$error))
        return()
      }

      generation_state$qmd_content <- result$qmd
      generation_state$qmd_path <- result$qmd_path

      # Render to HTML for preview
      html_result <- render_qmd_to_html(result$qmd_path)

      if (!is.null(html_result$error)) {
        # Still show modal but with error, offer qmd download
        generation_state$error <- html_result$error
        showModal(mod_slides_results_ui(ns, error = paste("Preview failed:", html_result$error, "- You can still download the .qmd file")))
        return()
      }

      generation_state$html_path <- html_result$path

      # Create resource path for preview
      preview_name <- basename(html_result$path)
      addResourcePath("slides_preview", dirname(html_result$path))
      preview_url <- paste0("slides_preview/", preview_name)

      showModal(mod_slides_results_ui(ns, preview_url = preview_url))
    })

    # Handle regeneration
    observeEvent(input$regenerate, {
      nb_id <- notebook_id()
      req(nb_id)

      docs <- list_documents(con(), nb_id)
      cfg <- config()
      api_key <- get_setting(cfg, "openrouter", "api_key")

      models <- tryCatch({
        list_models(api_key)
      }, error = function(e) {
        data.frame(id = "anthropic/claude-sonnet-4", name = "Claude Sonnet 4", stringsAsFactors = FALSE)
      })

      current_model <- generation_state$last_options$model %||%
                       get_setting(cfg, "defaults", "chat_model") %||%
                       "anthropic/claude-sonnet-4"

      showModal(mod_slides_modal_ui(ns, docs, models, current_model))
    })

    # Download handlers
    output$download_qmd <- downloadHandler(
      filename = function() {
        nb_id <- notebook_id()
        nb <- get_notebook(con(), nb_id)
        paste0(gsub("[^a-zA-Z0-9]", "-", nb$name %||% "slides"), ".qmd")
      },
      content = function(file) {
        req(generation_state$qmd_content)
        writeLines(generation_state$qmd_content, file)
      }
    )

    output$download_html <- downloadHandler(
      filename = function() {
        nb_id <- notebook_id()
        nb <- get_notebook(con(), nb_id)
        paste0(gsub("[^a-zA-Z0-9]", "-", nb$name %||% "slides"), ".html")
      },
      content = function(file) {
        req(generation_state$html_path)
        file.copy(generation_state$html_path, file)
      }
    )

    output$download_pdf <- downloadHandler(
      filename = function() {
        nb_id <- notebook_id()
        nb <- get_notebook(con(), nb_id)
        paste0(gsub("[^a-zA-Z0-9]", "-", nb$name %||% "slides"), ".pdf")
      },
      content = function(file) {
        req(generation_state$qmd_path)

        # Render PDF on demand
        withProgress(message = "Rendering PDF...", {
          pdf_result <- render_qmd_to_pdf(generation_state$qmd_path)

          if (!is.null(pdf_result$error)) {
            showNotification(paste("PDF export failed:", pdf_result$error), type = "error")
            return()
          }

          file.copy(pdf_result$path, file)
        })
      }
    )
  })
}
