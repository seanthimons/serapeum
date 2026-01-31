# R/slides.R
library(processx)

#' Check if Quarto CLI is installed
#' @return TRUE if quarto command exists, FALSE otherwise
check_quarto_installed <- function() {
  result <- tryCatch({
    run("quarto", "--version", error_on_status = FALSE)
    TRUE
  }, error = function(e) {
    FALSE
  })
  result
}

#' Get Quarto version string
#' @return Version string like "1.4.550" or NULL if not installed
get_quarto_version <- function() {
  tryCatch({
    result <- run("quarto", "--version", error_on_status = FALSE)
    if (result$status == 0) {
      trimws(result$stdout)
    } else {
      NULL
    }
  }, error = function(e) {
    NULL
  })
}

# Null coalescing operator (if not already defined)
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Build prompt for slide generation
#' @param chunks Data frame with content, doc_name, page_number
#' @param options List with length, audience, citation_style, include_notes, custom_instructions
#' @return List with system and user prompt strings
build_slides_prompt <- function(chunks, options) {
  # Default options
  length_val <- options$length %||% "medium"
  audience <- options$audience %||% "general"
  citation_style <- options$citation_style %||% "footnotes"
  include_notes <- options$include_notes %||% TRUE
  custom_instructions <- options$custom_instructions %||% ""

  # Map length to slide count
  slide_counts <- list(
    short = "5-8 slides",
    medium = "10-15 slides",
    long = "20+ slides"
  )
  slide_count <- slide_counts[[length_val]] %||% "10-15 slides"

  # Build context from chunks
  context_parts <- vapply(seq_len(nrow(chunks)), function(i) {
    sprintf("[%s, p.%d]:\n%s",
            chunks$doc_name[i],
            chunks$page_number[i],
            chunks$content[i])
  }, character(1))
  context <- paste(context_parts, collapse = "\n\n---\n\n")

  # System prompt
  system_prompt <- paste0(
    "You are an expert presentation designer. Generate a Quarto RevealJS presentation in valid .qmd format.\n\n",
    "Output format requirements:\n",
    "- Start with YAML frontmatter (title, format: revealjs)\n",
    "- Use # for section titles (creates horizontal slide breaks)\n",
    "- Use ## for individual slide titles\n",
    "- Keep slides concise - max 5-7 bullet points per slide\n",
    if (include_notes) "- Include speaker notes using ::: {.notes} blocks\n" else "",
    "- Output ONLY valid Quarto markdown, no explanations or code fences around the output"
  )

  # Citation instructions
  citation_instructions <- switch(citation_style,
    "footnotes" = "Use footnote-style citations: add superscript numbers after key points and list references at the end.",
    "inline" = "Use inline parenthetical citations like (Author, p.X) after relevant content.",
    "notes_only" = "Put all citations in speaker notes only, keeping slides clean.",
    "none" = "Do not include citations.",
    "Use footnote-style citations."
  )

  # User prompt
  user_prompt <- sprintf(
    "Create a presentation with %s for a %s audience.\n\n%s\n\n%sSource content:\n\n%s",
    slide_count,
    audience,
    citation_instructions,
    if (nchar(custom_instructions) > 0) paste0("Additional instructions: ", custom_instructions, "\n\n") else "",
    context
  )

  list(system = system_prompt, user = user_prompt)
}

#' Inject theme into QMD frontmatter
#' @param qmd_content Raw QMD string
#' @param theme RevealJS theme name
#' @return Modified QMD string with theme
inject_theme_to_qmd <- function(qmd_content, theme) {
  if (is.null(theme) || theme == "default") {
    return(qmd_content)
  }

  # Check if format section exists
  if (grepl("format:\\s*\\n\\s*revealjs:", qmd_content)) {
    # Add theme under revealjs section
    qmd_content <- sub(
      "(format:\\s*\\n\\s*revealjs:)",
      paste0("\\1\n    theme: ", theme),
      qmd_content
    )
  } else if (grepl("format:\\s*revealjs", qmd_content)) {
    # Convert simple format to expanded with theme
    qmd_content <- sub(
      "format:\\s*revealjs",
      paste0("format:\n  revealjs:\n    theme: ", theme),
      qmd_content
    )
  } else if (grepl("^---", qmd_content)) {
    # No format section, add one before closing ---
    qmd_content <- sub(
      "\n---\n",
      paste0("\nformat:\n  revealjs:\n    theme: ", theme, "\n---\n"),
      qmd_content
    )
  }

  qmd_content
}

#' Render QMD file to HTML
#' @param qmd_path Path to .qmd file
#' @param timeout Timeout in seconds
#' @return List with path (on success) or error (on failure)
render_qmd_to_html <- function(qmd_path, timeout = 120) {
  if (!check_quarto_installed()) {
    return(list(path = NULL, error = "Quarto is not installed"))
  }

  output_path <- sub("\\.qmd$", ".html", qmd_path)

  result <- tryCatch({
    processx::run(
      "quarto",
      c("render", qmd_path, "--to", "html"),
      timeout = timeout,
      error_on_status = FALSE
    )
  }, error = function(e) {
    return(list(status = -1, stderr = e$message))
  })

  if (result$status != 0) {
    return(list(path = NULL, error = paste("Render failed:", result$stderr)))
  }

  if (!file.exists(output_path)) {
    return(list(path = NULL, error = "Output file not created"))
  }

  list(path = output_path, error = NULL)
}

#' Render QMD file to PDF
#' @param qmd_path Path to .qmd file
#' @param timeout Timeout in seconds
#' @return List with path (on success) or error (on failure)
render_qmd_to_pdf <- function(qmd_path, timeout = 180) {
  if (!check_quarto_installed()) {
    return(list(path = NULL, error = "Quarto is not installed"))
  }

  output_path <- sub("\\.qmd$", ".pdf", qmd_path)

  result <- tryCatch({
    processx::run(
      "quarto",
      c("render", qmd_path, "--to", "pdf"),
      timeout = timeout,
      error_on_status = FALSE
    )
  }, error = function(e) {
    return(list(status = -1, stderr = e$message))
  })

  if (result$status != 0) {
    return(list(path = NULL, error = paste("PDF render failed:", result$stderr)))
  }

  if (!file.exists(output_path)) {
    return(list(path = NULL, error = "PDF file not created"))
  }

  list(path = output_path, error = NULL)
}

#' Generate slides from document chunks
#' @param api_key OpenRouter API key
#' @param model Model ID to use
#' @param chunks Data frame with content, doc_name, page_number
#' @param options List with length, audience, citation_style, include_notes, theme, custom_instructions
#' @param notebook_name Name of notebook (for title)
#' @return List with qmd (content string), qmd_path (temp file), or error
generate_slides <- function(api_key, model, chunks, options, notebook_name = "Presentation") {
  # Build prompt
  prompt <- build_slides_prompt(chunks, options)

  # Call LLM
  messages <- format_chat_messages(prompt$system, prompt$user)

  qmd_content <- tryCatch({
    chat_completion(api_key, model, messages)
  }, error = function(e) {
    return(list(qmd = NULL, error = paste("LLM error:", e$message)))
  })

  if (is.list(qmd_content) && !is.null(qmd_content$error)) {
    return(qmd_content)
  }

  # Clean up response - remove markdown code fences if present
  qmd_content <- gsub("^```(qmd|markdown|yaml)?\\n?", "", qmd_content)
  qmd_content <- gsub("\\n?```$", "", qmd_content)
  qmd_content <- trimws(qmd_content)

  # Inject theme if specified
  theme <- options$theme %||% "default"
  if (theme != "default") {
    qmd_content <- inject_theme_to_qmd(qmd_content, theme)
  }

  # Save to temp file
  qmd_path <- file.path(tempdir(), paste0(gsub("[^a-zA-Z0-9]", "-", notebook_name), "-slides.qmd"))
  writeLines(qmd_content, qmd_path)

  list(qmd = qmd_content, qmd_path = qmd_path, error = NULL)
}
