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
    title = tagList(icon_file_powerpoint(), "Generate Slides"),
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
      actionButton(ns("generate"), "Generate", class = "btn-primary", icon = icon_wand())
    )
  )
}

#' Slides Healing Modal UI
#' @param ns Namespace function from session$ns
#' @param errors Character vector of validation/render errors (or NULL)
#' @param is_success Logical - TRUE if generation was successful
mod_slides_heal_modal_ui <- function(ns, errors = NULL, is_success = FALSE) {
  # Error/info summary at top
  summary_panel <- if (is_success) {
    div(
      class = "alert alert-info mb-3",
      icon_circle_info(class = "me-2"),
      "Slides generated successfully. Use healing to make cosmetic adjustments."
    )
  } else if (!is.null(errors) && length(errors) > 0) {
    div(
      class = "alert alert-warning mb-3",
      icon_warning(class = "me-2"),
      strong("Issues found:"),
      tags$ul(
        class = "mb-0 mt-2",
        lapply(errors, function(err) tags$li(err))
      )
    )
  } else {
    NULL
  }

  # Quick-pick chips
  chip_labels <- get_healing_chips(errors %||% character(0), is_success)
  chip_buttons <- lapply(seq_along(chip_labels), function(i) {
    actionButton(
      ns(paste0("chip_", i)),
      chip_labels[i],
      class = "btn btn-outline-secondary btn-sm me-2 mb-2"
    )
  })

  modalDialog(
    title = tagList(icon_wrench(), "Heal Slides"),
    size = "m",
    easyClose = FALSE,

    summary_panel,

    # Quick-pick chips
    div(
      class = "mb-3",
      h6("Quick Fixes", class = "fw-semibold"),
      do.call(tagList, chip_buttons)
    ),

    # Free text input
    textAreaInput(
      ns("heal_instructions"),
      "Custom Instructions",
      placeholder = "Describe what to fix...",
      rows = 3
    ),

    footer = tagList(
      modalButton("Cancel"),
      actionButton(ns("do_heal"), "Heal", class = "btn-primary", icon = icon_wrench())
    )
  )
}

#' Slides Results Modal UI
#' @param ns Namespace function from session$ns
#' @param preview_url URL to preview HTML (or NULL)
#' @param error Error message (or NULL)
#' @param qmd_content Raw QMD content for "Show raw output" toggle (or NULL)
#' @param validation_errors Character vector of validation errors (or NULL)
#' @param heal_attempts Number of healing attempts so far
#' @param is_fallback TRUE if showing fallback template
mod_slides_results_ui <- function(ns, preview_url = NULL, error = NULL,
                                   qmd_content = NULL, validation_errors = NULL,
                                   heal_attempts = 0, is_fallback = FALSE) {

  # Raw output collapsible (used in multiple content branches)
  raw_output_toggle <- if (!is.null(qmd_content)) {
    tags$details(
      class = "mt-3",
      tags$summary(class = "text-muted small", style = "cursor: pointer;", "Show raw output"),
      div(
        class = "bg-dark text-light p-3 rounded mt-2",
        style = "max-height: 300px; overflow-y: auto; font-family: monospace; font-size: 0.8em; white-space: pre-wrap;",
        qmd_content
      )
    )
  } else {
    NULL
  }

  # Retry counter
  retry_counter <- if (heal_attempts > 0 && !is_fallback) {
    div(class = "text-muted small mb-2", sprintf("Healing attempt %d of 2", heal_attempts))
  } else {
    NULL
  }

  # Fallback warning banner
  fallback_banner <- if (is_fallback) {
    div(
      class = "alert alert-warning mb-3",
      icon_warning(class = "me-2"),
      "Generation failed after 2 attempts. Showing template outline ",
      tags$span(class = "fw-semibold", "-- download the .qmd and edit manually.")
    )
  } else {
    NULL
  }

  content <- if (!is.null(error)) {
    # Error panel replaces preview area
    div(
      class = "py-4 px-3",
      retry_counter,
      div(
        class = "alert alert-danger",
        icon_warning(class = "me-2"),
        strong("Generation failed: "), error
      ),
      raw_output_toggle
    )
  } else if (!is.null(preview_url)) {
    tagList(
      fallback_banner,
      retry_counter,
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
        downloadButton(ns("download_pdf"), "Download PDF", class = "btn-outline-primary")
      ),
      raw_output_toggle
    )
  } else {
    div(
      class = "text-center py-5",
      div(class = "spinner-border text-primary", role = "status"),
      p(class = "mt-3 text-muted", "Generating slides...")
    )
  }

  modalDialog(
    title = tagList(icon_file_powerpoint(), "Generated Slides"),
    size = "xl",
    easyClose = FALSE,
    content,
    footer = tagList(
      actionButton(ns("open_heal"), "Heal", class = "btn-outline-warning", icon = icon_wrench()),
      actionButton(ns("regenerate"), "Regenerate", class = "btn-outline-secondary", icon = icon_rotate()),
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
      last_options = NULL,
      heal_attempts = 0,
      validation_errors = NULL,
      is_fallback = FALSE,
      last_chunks = NULL
    )

    # Store current chip labels for chip click handling
    current_chips <- reactiveVal(character(0))

    # Helper to show results modal with current state
    show_results <- function(preview_url = NULL, error = NULL) {
      showModal(mod_slides_results_ui(
        ns,
        preview_url = preview_url,
        error = error,
        qmd_content = generation_state$qmd_content,
        validation_errors = generation_state$validation_errors,
        heal_attempts = generation_state$heal_attempts,
        is_fallback = generation_state$is_fallback
      ))
    }

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
      provider <- provider_from_config(cfg, con())
      models <- tryCatch({
        provider_list_models(provider)
      }, error = function(e) {
        data.frame(id = "google/gemini-3.1-flash-lite-preview", name = "Gemini 3.1 Flash Lite", stringsAsFactors = FALSE)
      })

      current_model <- resolve_model_for_operation(cfg, "slide_generation")

      # Reset state
      generation_state$qmd_content <- NULL
      generation_state$qmd_path <- NULL
      generation_state$html_path <- NULL
      generation_state$error <- NULL
      generation_state$heal_attempts <- 0
      generation_state$validation_errors <- NULL
      generation_state$is_fallback <- FALSE
      generation_state$last_chunks <- NULL

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
      show_results()

      # Get chunks for selected documents
      showNotification("Preparing content...", id = "slides_progress", duration = NULL, type = "message")
      chunks <- get_chunks_for_documents(con(), doc_ids)

      if (nrow(chunks) == 0) {
        removeNotification("slides_progress")
        generation_state$error <- "No content found in selected documents"
        show_results(error = generation_state$error)
        return()
      }

      # Store chunks for fallback
      generation_state$last_chunks <- chunks

      # Reset heal state for fresh generation
      generation_state$heal_attempts <- 0
      generation_state$is_fallback <- FALSE
      generation_state$validation_errors <- NULL

      # Get notebook name for title
      nb <- get_notebook(con(), nb_id)
      notebook_name <- nb$name %||% "Presentation"

      # Generate slides
      showNotification(
        paste0("Generating slides with ", input$model, "..."),
        id = "slides_progress", duration = NULL, type = "message"
      )
      provider <- provider_from_config(cfg, con())

      result <- generate_slides(
        provider = provider,
        model = input$model,
        chunks = chunks,
        options = generation_state$last_options,
        notebook_name = notebook_name,
        con = con(),
        session_id = session$token
      )

      if (!is.null(result$error)) {
        removeNotification("slides_progress")
        generation_state$error <- result$error
        show_results(error = result$error)
        return()
      }

      generation_state$qmd_content <- result$qmd
      generation_state$qmd_path <- result$qmd_path

      # Store validation errors if any
      if (!is.null(result$validation) && !result$validation$valid) {
        generation_state$validation_errors <- result$validation$errors
      }

      # Render to HTML for preview
      showNotification("Rendering preview with Quarto...", id = "slides_progress", duration = NULL, type = "message")
      html_result <- render_qmd_to_html(result$qmd_path)

      if (!is.null(html_result$error)) {
        removeNotification("slides_progress")
        generation_state$error <- paste("Preview failed:", html_result$error, "- You can still download the .qmd file")
        show_results(error = generation_state$error)
        return()
      }

      generation_state$html_path <- html_result$path
      generation_state$error <- NULL

      # Create resource path for preview
      preview_name <- basename(html_result$path)
      addResourcePath("slides_preview", dirname(html_result$path))
      preview_url <- paste0("slides_preview/", preview_name)

      removeNotification("slides_progress")
      show_results(preview_url = preview_url)
    })

    # Handle opening healing modal
    observeEvent(input$open_heal, {
      # Determine current errors
      errors <- generation_state$validation_errors %||% character(0)
      if (length(errors) == 0 && !is.null(generation_state$error)) {
        errors <- generation_state$error
      }

      # Determine if generation was successful
      is_success <- is.null(generation_state$error) && length(generation_state$validation_errors %||% character(0)) == 0

      # Store chips for click handlers
      current_chips(get_healing_chips(errors, is_success))

      showModal(mod_slides_heal_modal_ui(ns, errors, is_success))
    }, ignoreInit = TRUE)

    # Chip click handlers (up to 10 chips)
    lapply(seq_len(10), function(i) {
      observeEvent(input[[paste0("chip_", i)]], {
        chips <- current_chips()
        if (i <= length(chips)) {
          updateTextAreaInput(session, "heal_instructions", value = chips[i])
        }
      }, ignoreInit = TRUE)
    })

    # Handle healing execution
    observeEvent(input$do_heal, {
      generation_state$heal_attempts <- generation_state$heal_attempts + 1
      attempt <- generation_state$heal_attempts

      cfg <- config()
      provider <- provider_from_config(cfg, con())

      # Check if we've exceeded the retry limit
      if (attempt > 2) {
        # FALLBACK PATH
        chunks <- generation_state$last_chunks
        if (is.null(chunks) || nrow(chunks) == 0) {
          show_results(error = "Cannot generate fallback: no source content available")
          return()
        }

        nb_id <- notebook_id()
        nb <- get_notebook(con(), nb_id)
        notebook_name <- nb$name %||% "Presentation"

        # Generate fallback template
        fallback_qmd <- build_fallback_qmd(chunks, notebook_name)
        generation_state$qmd_content <- fallback_qmd
        generation_state$is_fallback <- TRUE
        generation_state$error <- NULL
        generation_state$validation_errors <- NULL

        # Save to temp file
        qmd_path <- file.path(tempdir(), paste0(gsub("[^a-zA-Z0-9]", "-", notebook_name), "-fallback-slides.qmd"))
        writeLines(fallback_qmd, qmd_path)
        generation_state$qmd_path <- qmd_path

        # Render fallback
        showNotification("Generating fallback template...", id = "slides_progress", duration = NULL, type = "message")
        html_result <- render_qmd_to_html(qmd_path)
        removeNotification("slides_progress")

        if (!is.null(html_result$error)) {
          generation_state$error <- paste("Fallback render failed:", html_result$error)
          show_results(error = generation_state$error)
          return()
        }

        generation_state$html_path <- html_result$path
        preview_name <- basename(html_result$path)
        addResourcePath("slides_preview", dirname(html_result$path))
        preview_url <- paste0("slides_preview/", preview_name)

        show_results(preview_url = preview_url)
        return()
      }

      # HEALING PATH (attempt <= 2)
      # Show loading results modal
      show_results()

      previous_qmd <- generation_state$qmd_content
      errors <- generation_state$validation_errors %||% character(0)
      if (length(errors) == 0 && !is.null(generation_state$error)) {
        errors <- generation_state$error
      }
      instructions <- input$heal_instructions %||% ""

      model <- generation_state$last_options$model %||%
        resolve_model_for_operation(cfg, "slide_healing")

      showNotification(
        sprintf("Healing slides (attempt %d of 2)...", attempt),
        id = "slides_progress", duration = NULL, type = "message"
      )

      heal_result <- heal_slides(
        provider = provider,
        model = model,
        previous_qmd = previous_qmd,
        errors = errors,
        instructions = instructions,
        con = con(),
        session_id = session$token
      )

      if (!is.null(heal_result$error)) {
        removeNotification("slides_progress")
        generation_state$error <- heal_result$error
        show_results(error = heal_result$error)
        return()
      }

      # Validate healed output
      validation <- validate_qmd_yaml(heal_result$qmd)
      generation_state$qmd_content <- heal_result$qmd
      generation_state$qmd_path <- heal_result$qmd_path

      if (!validation$valid) {
        removeNotification("slides_progress")
        generation_state$validation_errors <- validation$errors
        generation_state$error <- paste("Validation failed:", paste(validation$errors, collapse = "; "))
        show_results(error = generation_state$error)
        return()
      }

      # Validation passed - rebuild with clean frontmatter, then render
      generation_state$validation_errors <- NULL
      generation_state$error <- NULL

      # Strip whatever YAML the LLM produced and rebuild with known-good frontmatter
      stripped <- strip_llm_yaml(heal_result$qmd)
      title <- stripped$title %||% generation_state$title %||% "Presentation"
      theme <- generation_state$last_options$theme %||% "default"
      frontmatter <- build_qmd_frontmatter(title, theme)
      qmd_content <- paste0(frontmatter, "\n", stripped$content)
      generation_state$qmd_content <- qmd_content

      # Re-save with clean frontmatter
      writeLines(qmd_content, heal_result$qmd_path)

      showNotification("Rendering healed preview...", id = "slides_progress", duration = NULL, type = "message")
      html_result <- render_qmd_to_html(heal_result$qmd_path)
      removeNotification("slides_progress")

      if (!is.null(html_result$error)) {
        generation_state$error <- paste("Render failed:", html_result$error)
        show_results(error = generation_state$error)
        return()
      }

      generation_state$html_path <- html_result$path
      preview_name <- basename(html_result$path)
      addResourcePath("slides_preview", dirname(html_result$path))
      preview_url <- paste0("slides_preview/", preview_name)

      show_results(preview_url = preview_url)
    }, ignoreInit = TRUE)

    # Handle regeneration - reopens full config modal
    observeEvent(input$regenerate, {
      nb_id <- notebook_id()
      req(nb_id)

      # Reset healing state
      generation_state$heal_attempts <- 0
      generation_state$is_fallback <- FALSE
      generation_state$validation_errors <- NULL

      docs <- list_documents(con(), nb_id)
      cfg <- config()
      provider <- provider_from_config(cfg, con())

      models <- tryCatch({
        provider_list_models(provider)
      }, error = function(e) {
        data.frame(id = "google/gemini-3.1-flash-lite-preview", name = "Gemini 3.1 Flash Lite", stringsAsFactors = FALSE)
      })

      current_model <- generation_state$last_options$model %||%
                       resolve_model_for_operation(cfg, "slide_generation")

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
            showNotification(
              tagList(
                "PDF export failed: ", pdf_result$error,
                tags$br(),
                "Tip: Run ", tags$code("quarto install tinytex"), " in your terminal to enable PDF export."
              ),
              type = "error",
              duration = 10
            )
            return()
          }

          file.copy(pdf_result$path, file)
        })
      }
    )
  })
}
