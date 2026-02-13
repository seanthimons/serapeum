library(pdftools)

# Note: ragnar_available() is defined in R/_ragnar.R (sourced first alphabetically)

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

#' Split text into chunks with overlap
#' @param text Text to chunk
#' @param chunk_size Approximate words per chunk
#' @param overlap Words of overlap between chunks
#' @return List of chunks
chunk_text <- function(text, chunk_size = 500, overlap = 50) {
  # Split into words
  words <- unlist(strsplit(text, "\\s+"))
  words <- words[nchar(words) > 0]

  if (length(words) == 0) {
    return(list())
  }

  if (length(words) <= chunk_size) {
    return(list(paste(words, collapse = " ")))
  }

  chunks <- list()
  start <- 1

  while (start <= length(words)) {
    end <- min(start + chunk_size - 1, length(words))
    chunk_words <- words[start:end]
    chunks <- c(chunks, list(paste(chunk_words, collapse = " ")))

    if (end >= length(words)) break

    start <- end - overlap + 1
    if (start <= 0) start <- 1
  }

  chunks
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
#' Uses ragnar's semantic chunking when available, falls back to word-based
#' chunking otherwise. Preserves page numbers for citation accuracy.
#'
#' @param path Path to PDF
#' @param chunk_size Words per chunk (legacy) or target characters (ragnar)
#' @param overlap Words of overlap (legacy) or fraction (ragnar)
#' @param use_ragnar Use ragnar semantic chunking if available (default TRUE)
#' @param origin Document origin identifier for ragnar (defaults to filename)
#' @return List with chunks data frame, full_text, and page_count
process_pdf <- function(path, chunk_size = 500, overlap = 50,
                        use_ragnar = TRUE, origin = NULL) {
  extracted <- extract_pdf_text(path)

  # Default origin to filename
  if (is.null(origin)) {
    origin <- basename(path)
  }

  # Try ragnar semantic chunking if available and requested
  if (use_ragnar && ragnar_available()) {
    all_chunks <- tryCatch({
      # Convert word-based params to ragnar's character-based params
      # Approximate: 500 words ~= 2500 characters, 50 words overlap ~= 10%
      target_size <- chunk_size * 5  # ~5 chars per word
      target_overlap <- min(overlap / chunk_size, 0.5)  # fraction, cap at 0.5

      chunk_with_ragnar(
        pages = extracted$text,
        origin = origin,
        target_size = target_size,
        target_overlap = target_overlap
      )
    }, error = function(e) {
      message("Ragnar chunking failed, falling back to word-based: ", e$message)
      NULL
    })

    if (!is.null(all_chunks) && nrow(all_chunks) > 0) {
      # Add section_hint column by analyzing each chunk
      all_chunks$section_hint <- vapply(seq_len(nrow(all_chunks)), function(i) {
        detect_section_hint(
          all_chunks$content[i],
          all_chunks$page_number[i],
          extracted$page_count
        )
      }, FUN.VALUE = character(1))

      return(list(
        chunks = all_chunks,
        full_text = paste(extracted$text, collapse = "\n\n"),
        page_count = extracted$page_count,
        chunking_method = "ragnar"
      ))
    }
  }

  # Fallback: original word-based chunking
  all_chunks <- data.frame(
    content = character(),
    page_number = integer(),
    chunk_index = integer(),
    section_hint = character(),
    stringsAsFactors = FALSE
  )

  global_index <- 0

  for (page_num in seq_along(extracted$text)) {
    page_text <- extracted$text[page_num]

    # Skip empty pages
    if (nchar(trimws(page_text)) == 0) next

    page_chunks <- chunk_text(page_text, chunk_size, overlap)

    for (chunk in page_chunks) {
      if (nchar(trimws(chunk)) == 0) next

      all_chunks <- rbind(all_chunks, data.frame(
        content = chunk,
        page_number = page_num,
        chunk_index = global_index,
        section_hint = detect_section_hint(chunk, page_num, extracted$page_count),
        stringsAsFactors = FALSE
      ))
      global_index <- global_index + 1
    }
  }

  list(
    chunks = all_chunks,
    full_text = paste(extracted$text, collapse = "\n\n"),
    page_count = extracted$page_count,
    chunking_method = "word_based"
  )
}
