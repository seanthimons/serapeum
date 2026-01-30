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
