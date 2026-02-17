library(pdftools)

#' Extract text from PDF file
#' @param path Path to PDF file
#' @return List with text (character vector per page) and page_count
extract_pdf_text <- function(path) {
  if (!file.exists(path)) {
    stop("PDF file not found: ", path)
  }

  text <- tryCatch({
    pdf_text(path)
  }, error = function(e) {
    stop("Failed to extract text from PDF: ", e$message)
  })

  list(
    text = text,
    page_count = length(text)
  )
}

#' Detect section hint for a chunk based on content and position
#'
#' Uses keyword heuristics and page position to classify chunks by paper section.
#' This enables section-targeted retrieval for conclusion synthesis and similar tasks.
#'
#' @param text Chunk text content to analyze
#' @param page_number Page number of this chunk
#' @param total_pages Total pages in document
#' @return Section hint string: "conclusion", "limitations", "future_work", "discussion",
#'   "introduction", "methods", "results", "late_section", or "general"
detect_section_hint <- function(text, page_number, total_pages) {
  # Normalize text for matching (case-insensitive)
  text_lower <- tolower(text)

  # Check section keywords in priority order (return first match)
  # Note: These patterns match on chunk CONTENT, not just headings

  if (grepl("\\bconclu[ds]|\\bsummary and conclusion", text_lower)) {
    return("conclusion")
  }

  if (grepl("\\b(limitation|constraint|caveat)\\b", text_lower)) {
    return("limitations")
  }

  if (grepl("\\b(future work|future research|future direction|further research|open question|open problem)\\b", text_lower)) {
    return("future_work")
  }

  if (grepl("\\b(discussion|interpretation|implication)\\b", text_lower)) {
    return("discussion")
  }

  if (grepl("\\b(introduction|background)\\b", text_lower)) {
    return("introduction")
  }

  if (grepl("\\b(method|methodology|approach|experimental setup)\\b", text_lower)) {
    return("methods")
  }

  if (grepl("\\b(result|finding|experiment)\\b", text_lower)) {
    return("results")
  }

  # Page position fallback: if in last 20% of document, mark as late_section
  if (page_number / total_pages > 0.8) {
    return("late_section")
  }

  # Default: general content
  return("general")
}

#' Process PDF into chunks with page numbers
#'
#' Uses ragnar's semantic chunking to produce chunks. Preserves page numbers
#' for citation accuracy.
#'
#' @param path Path to PDF
#' @param chunk_size Target characters per chunk (approximate)
#' @param overlap Overlap fraction between chunks (0-0.5)
#' @param origin Document origin identifier for ragnar (defaults to filename)
#' @return List with chunks data frame, full_text, and page_count
process_pdf <- function(path, chunk_size = 2500, overlap = 0.1, origin = NULL) {
  extracted <- extract_pdf_text(path)

  # Default origin to filename
  if (is.null(origin)) {
    origin <- basename(path)
  }

  all_chunks <- tryCatch({
    chunk_with_ragnar(
      pages = extracted$text,
      origin = origin,
      target_size = chunk_size,
      target_overlap = min(overlap, 0.5)
    )
  }, error = function(e) {
    message("Ragnar chunking failed: ", e$message)
    NULL
  })

  if (is.null(all_chunks) || nrow(all_chunks) == 0) {
    all_chunks <- data.frame(
      content = character(),
      page_number = integer(),
      chunk_index = integer(),
      context = character(),
      origin = character(),
      stringsAsFactors = FALSE
    )
  }

  # Add section_hint column by analyzing each chunk
  all_chunks$section_hint <- vapply(seq_len(nrow(all_chunks)), function(i) {
    detect_section_hint(
      all_chunks$content[i],
      all_chunks$page_number[i],
      extracted$page_count
    )
  }, FUN.VALUE = character(1))

  list(
    chunks = all_chunks,
    full_text = paste(extracted$text, collapse = "\n\n"),
    page_count = extracted$page_count,
    chunking_method = "ragnar"
  )
}
