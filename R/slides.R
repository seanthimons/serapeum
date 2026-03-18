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

  # System prompt — LLM generates slide CONTENT only, no YAML frontmatter
  system_prompt <- paste0(
    "You are an expert presentation designer. Generate Quarto RevealJS slide content.\n\n",
    "CRITICAL: Do NOT output YAML frontmatter (no --- block). Start directly with your first slide using ##.\n",
    "The app builds the YAML frontmatter separately.\n\n",
    "Quarto Syntax Reference:\n\n",
    "Footnotes (use inline syntax):\n",
    "  Correct: 'Machine learning improves accuracy.^[WHO AMR Report, 2024, p.12]'\n",
    "  WRONG - do NOT use these: '[^1]', '^1', '[1]'\n",
    "  The ^[text] syntax renders a numbered footnote at the bottom of the slide automatically.\n\n",
    "IMPORTANT: Always include the page number in footnotes when the source data includes page numbers.\n",
    "If no page number is available, use the chunk identifier from the source label.\n",
    "Every substantive claim on a slide MUST have a footnote citation.\n\n",
    "Speaker notes:\n",
    "  ::: {.notes}\n",
    "  Presenter notes go here.\n",
    "  :::\n\n",
    "Tables:\n",
    "  | Method | Accuracy |\n",
    "  |:-------|:--------:|\n",
    "  | CNN    | 95%      |\n\n",
    "Bullet lists (IMPORTANT — blank line required before first item):\n",
    "  Correct:\n",
    "    ## Slide Title\n\n",
    "    - First item\n",
    "    - Second item\n\n",
    "  WRONG (renders as inline text, not bullets):\n",
    "    ## Slide Title\n",
    "    - First item\n\n",
    "Content rules:\n",
    "- Use ## for individual slide titles (each ## starts a new slide)\n",
    "- Use # for section titles (creates section dividers)\n",
    "- Keep slides concise - max 5-7 bullet points per slide\n",
    "- Always leave a blank line between a heading and the first bullet point\n",
    "- Each bullet point must be on its own line starting with - (not inline)\n",
    if (include_notes) "- Include speaker notes using ::: {.notes} blocks\n" else "",
    "- Output ONLY valid Quarto markdown slide content, no explanations or code fences\n",
    "- Do NOT include any YAML frontmatter, --- delimiters, title:, format:, theme:, or css:"
  )

  # Citation instructions
  citation_instructions <- switch(citation_style,
    "footnotes" = "Use Quarto inline footnotes: add ^[source info] after ALL substantive claims (e.g., 'key finding.^[Author et al., 2023, p.5]'). Always include the page number from the source data. Do NOT use [^1] reference-style or bare ^1. Quarto renders these as numbered footnotes automatically.",
    "inline" = "Use inline parenthetical citations like (Author, Year, p.X) after ALL substantive claims. Always include the page number from the source data.",
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

#' Build complete QMD frontmatter programmatically
#' @param title Presentation title
#' @param theme RevealJS theme name (default "default")
#' @return YAML frontmatter string including --- delimiters
build_qmd_frontmatter <- function(title, theme = "default") {
  # CSS for footnote sizing — smaller, positioned at bottom
  css_block <- paste0(
    "    css:\n",
    "      - |\n",
    "        .reveal .slides section aside {\n",
    "          font-size: 0.4em !important;\n",
    "          line-height: 1.2;\n",
    "          color: rgba(255, 255, 255, 0.6);\n",
    "        }\n",
    "        .reveal .slides section .footnotes {\n",
    "          font-size: 0.4em !important;\n",
    "          line-height: 1.2;\n",
    "        }\n",
    "        .reveal .slides section .footnote-ref {\n",
    "          font-size: 0.65em;\n",
    "          vertical-align: super;\n",
    "        }\n",
    "        .reveal .slides section sup {\n",
    "          font-size: 0.55em;\n",
    "        }\n"
  )

  theme_val <- if (is.null(theme) || theme == "default") "default" else theme

  paste0(
    "---\n",
    "title: \"", gsub('"', '\\\\"', title), "\"\n",
    "format:\n",
    "  revealjs:\n",
		"    embed-resources: true\n",
    "    theme: ", theme_val, "\n",
    "    smaller: true\n",
    "    scrollable: true\n",
    "    reference-location: document\n",
    css_block,
    "---\n"
  )
}

#' Strip YAML frontmatter from QMD content if LLM included it despite instructions
#' @param qmd_content Raw QMD string from LLM
#' @return Slide content without YAML frontmatter, and extracted title if found
strip_llm_yaml <- function(qmd_content) {
  title <- NULL
  content <- qmd_content

  # Check if LLM included YAML despite instructions
  if (grepl("^---\\s*\\n", qmd_content)) {
    yaml_match <- regmatches(qmd_content, regexpr("(?s)^---\\n(.*?)\\n---", qmd_content, perl = TRUE))
    if (length(yaml_match) > 0 && nchar(yaml_match) > 0) {
      # Extract title if present
      title_match <- regmatches(yaml_match, regexpr('title:\\s*"?([^"\\n]+)"?', yaml_match, perl = TRUE))
      if (length(title_match) > 0 && nchar(title_match) > 0) {
        title <- sub('title:\\s*"?([^"\\n]+)"?', "\\1", title_match, perl = TRUE)
        title <- trimws(title)
      }
      # Remove the YAML block
      content <- sub("(?s)^---\\n.*?\\n---\\s*\\n?", "", qmd_content, perl = TRUE)
    }
  }

  list(content = trimws(content), title = title)
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
#' @param con Optional database connection for cost logging (default NULL)
#' @param session_id Optional Shiny session ID for cost logging (default NULL)
#' @return List with qmd (content string), qmd_path (temp file), or error
generate_slides <- function(api_key, model, chunks, options, notebook_name = "Presentation",
                             con = NULL, session_id = NULL) {
  # Build prompt
  prompt <- build_slides_prompt(chunks, options)

  # Call LLM
  messages <- format_chat_messages(prompt$system, prompt$user)

  qmd_content <- tryCatch({
    result <- chat_completion(api_key, model, messages)

    # Log cost if con and session_id provided
    if (!is.null(con) && !is.null(session_id) && !is.null(result$usage)) {
      cost <- estimate_cost(model,
                          result$usage$prompt_tokens %||% 0,
                          result$usage$completion_tokens %||% 0)
      log_cost(con, "slide_generation", model,
               result$usage$prompt_tokens %||% 0,
               result$usage$completion_tokens %||% 0,
               result$usage$total_tokens %||% 0,
               cost, session_id)
    }

    result$content
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

  # Strip any YAML the LLM included despite instructions, extract title if present
  stripped <- strip_llm_yaml(qmd_content)
  slide_content <- stripped$content
  llm_title <- stripped$title

  # Build YAML frontmatter programmatically (no regex injection)
  title <- llm_title %||% notebook_name
  theme <- options$theme %||% "default"
  frontmatter <- build_qmd_frontmatter(title, theme)

  # Combine: clean YAML + LLM slide content
  qmd_content <- paste0(frontmatter, "\n", slide_content)

  # Validate the assembled QMD
  validation <- validate_qmd_yaml(qmd_content)

  # Save to temp file
  qmd_path <- file.path(tempdir(), paste0(gsub("[^a-zA-Z0-9]", "-", notebook_name), "-slides.qmd"))
  writeLines(qmd_content, qmd_path)

  list(qmd = qmd_content, qmd_path = qmd_path, error = NULL, validation = validation)
}

#' Validate YAML frontmatter in QMD content
#' @param qmd_content Raw QMD string
#' @return List with valid (logical), errors (character vector), parsed (list or NULL)
validate_qmd_yaml <- function(qmd_content) {
  # Extract YAML frontmatter between --- delimiters
  # Use (?s) flag so . matches newlines for non-greedy match
  # Allow empty content between delimiters (---\n---) for empty detection
  yaml_match <- regmatches(qmd_content, regexpr("(?s)^---\n(.*?)(\n---|\n?---)", qmd_content, perl = TRUE))

  if (length(yaml_match) == 0 || nchar(yaml_match) == 0) {
    return(list(
      valid = FALSE,
      errors = "No YAML frontmatter found (missing --- delimiters)",
      parsed = NULL
    ))
  }

  # Extract just the YAML content between delimiters
  yaml_text <- sub("^---\n", "", yaml_match)
  yaml_text <- sub("\n?---$", "", yaml_text)

  # Check for empty frontmatter
  if (nchar(trimws(yaml_text)) == 0) {
    return(list(
      valid = FALSE,
      errors = "Empty YAML frontmatter",
      parsed = NULL
    ))
  }

  # Parse with yaml package
  tryCatch({
    parsed <- yaml::yaml.load(yaml_text)
    list(valid = TRUE, errors = character(0), parsed = parsed)
  }, error = function(e) {
    list(valid = FALSE, errors = e$message, parsed = NULL)
  })
}

#' Build prompt for targeted slide healing
#' @param previous_qmd Previous QMD content to fix
#' @param errors Character vector of validation/render errors
#' @param instructions User's healing instructions
#' @return List with system and user prompt strings
build_healing_prompt <- function(previous_qmd, errors, instructions) {
  system_prompt <- paste0(
    "You are an expert Quarto presentation fixer. You receive a broken or imperfect .qmd file ",
    "and specific instructions on what to fix. Make targeted changes while preserving the parts that work.\n\n",
    "CRITICAL rules for the YAML frontmatter:\n",
    "- Preserve the existing YAML frontmatter structure (title, format, theme, css) exactly as-is\n",
    "- Do NOT change theme, css, or format options unless specifically asked to\n",
    "- Do NOT remove or simplify the YAML — keep every field that exists\n\n",
    "Quarto Syntax Reference:\n\n",
    "Footnotes (use inline syntax):\n",
    "  Correct: 'Key finding.^[Author et al., 2023, p.5]'\n",
    "  WRONG - do NOT use these: '[^1]', '^1', '[1]'\n",
    "  The ^[text] syntax renders a numbered footnote at the bottom of the slide automatically.\n",
    "When fixing citations, ensure page numbers from the source data are preserved in footnotes.\n\n",
    "Speaker notes:\n",
    "  ::: {.notes}\n",
    "  Presenter notes go here.\n",
    "  :::\n\n",
    "Tables:\n",
    "  | Method | Accuracy |\n",
    "  |:-------|:--------:|\n",
    "  | CNN    | 95%      |\n\n",
    "Output ONLY the complete fixed .qmd content. No explanations, no code fences.\n",
    "Ensure YAML frontmatter is valid (proper --- delimiters, correct indentation with spaces)."
  )

  error_section <- if (length(errors) > 0 && nchar(paste(errors, collapse = "")) > 0) {
    paste0("\n\nValidation errors found:\n", paste(errors, collapse = "\n"))
  } else {
    ""
  }

  user_prompt <- sprintf(
    "Here is the current .qmd file:\n\n```\n%s\n```\n%s\n\nUser instructions: %s\n\nFix the issues and return the complete corrected .qmd file.",
    previous_qmd,
    error_section,
    instructions
  )

  list(system = system_prompt, user = user_prompt)
}

#' Heal slides using LLM with targeted instructions
#' @param api_key OpenRouter API key
#' @param model Model ID to use
#' @param previous_qmd Previous QMD content to fix
#' @param errors Character vector of validation/render errors
#' @param instructions User's healing instructions
#' @param con Optional database connection for cost logging
#' @param session_id Optional Shiny session ID for cost logging
#' @return List with qmd (content string), qmd_path (temp file), or error
heal_slides <- function(api_key, model, previous_qmd, errors, instructions,
                        con = NULL, session_id = NULL) {
  # Build healing prompt
  prompt <- build_healing_prompt(previous_qmd, errors, instructions)

  # Call LLM
  messages <- format_chat_messages(prompt$system, prompt$user)

  qmd_content <- tryCatch({
    result <- chat_completion(api_key, model, messages)

    # Log cost if con and session_id provided
    if (!is.null(con) && !is.null(session_id) && !is.null(result$usage)) {
      cost <- estimate_cost(model,
                            result$usage$prompt_tokens %||% 0,
                            result$usage$completion_tokens %||% 0)
      log_cost(con, "slide_healing", model,
               result$usage$prompt_tokens %||% 0,
               result$usage$completion_tokens %||% 0,
               result$usage$total_tokens %||% 0,
               cost, session_id)
    }

    result$content
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

  # Save to temp file
  qmd_path <- file.path(tempdir(), "healed-slides.qmd")
  writeLines(qmd_content, qmd_path)

  list(qmd = qmd_content, qmd_path = qmd_path, error = NULL)
}

#' Build fallback QMD template from source chunks
#' @param chunks Data frame with content, doc_name, page_number
#' @param notebook_name Name of notebook (for title)
#' @return QMD content string
build_fallback_qmd <- function(chunks, notebook_name = "Presentation") {
  # Extract unique document names for section headers
  sections <- unique(chunks$doc_name)

  # Build minimal valid QMD
  qmd <- paste0(
    "---\n",
    "title: \"", notebook_name, "\"\n",
    "format:\n",
    "  revealjs:\n",
    "    theme: default\n",
    "---\n\n",
    "## Overview\n\n",
    "- Presentation generated from ", length(sections), " source document(s)\n\n"
  )

  # Add section slides from document names
  for (doc in sections) {
    doc_chunks <- chunks[chunks$doc_name == doc, ]
    doc_label <- tools::file_path_sans_ext(doc)
    qmd <- paste0(qmd, "## ", doc_label, "\n\n")
    # Extract first line of first chunk as a summary point
    first_content <- trimws(strsplit(doc_chunks$content[1], "\n")[[1]][1])
    if (nchar(first_content) > 0) {
      qmd <- paste0(qmd, "- ", substr(first_content, 1, 100), "\n\n")
    }
  }

  qmd
}

#' Get context-aware healing chip labels
#' @param errors Character vector of validation/render errors
#' @param is_success Logical - TRUE if generation was successful
#' @return Character vector of chip labels
get_healing_chips <- function(errors, is_success) {
  if (is_success) {
    # Cosmetic chips for successful generation
    return(c("Fewer bullet points", "Make text bigger", "Add more detail",
             "Shorten content", "Simplify slides"))
  }

  # Start with error-specific chips
  chips <- character(0)

  errors_text <- paste(errors, collapse = " ")
  if (grepl("YAML|parse|syntax", errors_text, ignore.case = TRUE)) {
    chips <- c(chips, "Fix YAML syntax")
  }
  if (grepl("CSS|style|format", errors_text, ignore.case = TRUE)) {
    chips <- c(chips, "Fix CSS formatting")
  }
  if (grepl("render|quarto", errors_text, ignore.case = TRUE)) {
    chips <- c(chips, "Fix Quarto formatting")
  }

  # Append baseline chips
  chips <- c(chips, "Simplify slides", "Fewer bullet points")

  chips
}
