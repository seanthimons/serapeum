# R/mod_slides.R
#' Slides Generation Modal UI
#' @param id Module namespace ID
#' @param documents Data frame of documents (id, filename)
#' @param models Data frame of available models (id, name)
#' @param current_model Currently selected model ID
mod_slides_modal_ui <- function(id, documents, models, current_model) {
  ns <- NS(id)

  # RevealJS themes
  themes <- c("default", "beige", "blood", "dark", "league",
              "moon", "night", "serif", "simple", "sky", "solarized")

  modalDialog(
    title = tagList(icon("presentation-screen"), "Generate Slides"),
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
#' @param id Module namespace ID
#' @param preview_url URL to preview HTML (or NULL)
#' @param error Error message (or NULL)
mod_slides_results_ui <- function(id, preview_url = NULL, error = NULL) {
  ns <- NS(id)

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
    title = tagList(icon("presentation-screen"), "Generated Slides"),
    size = "xl",
    easyClose = FALSE,
    content,
    footer = tagList(
      actionButton(ns("regenerate"), "Regenerate", class = "btn-outline-secondary", icon = icon("rotate")),
      modalButton("Close")
    )
  )
}
