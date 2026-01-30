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

#' Process PDF into chunks with page numbers
#' @param path Path to PDF
#' @param chunk_size Words per chunk
#' @param overlap Words of overlap
#' @return List with chunks data frame, full_text, and page_count
process_pdf <- function(path, chunk_size = 500, overlap = 50) {
  extracted <- extract_pdf_text(path)

  all_chunks <- data.frame(
    content = character(),
    page_number = integer(),
    chunk_index = integer(),
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
        stringsAsFactors = FALSE
      ))
      global_index <- global_index + 1
    }
  }

  list(
    chunks = all_chunks,
    full_text = paste(extracted$text, collapse = "\n\n"),
    page_count = extracted$page_count
  )
}
