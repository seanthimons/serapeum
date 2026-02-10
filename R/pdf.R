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
    page_count = extracted$page_count,
    chunking_method = "word_based"
  )
}

#' Extract images from PDF file
#'
#' Extracts embedded images from a PDF using the pdfimager package (which
#' interfaces with Poppler's pdfimages tool). Returns only the images embedded
#' in the document, not full-page renders.
#'
#' @param path Path to PDF file
#' @param output_dir Directory to save extracted images (default: temp dir)
#' @return Data frame with image metadata (path, page, width, height, type, name)
#'         or empty data frame if no images found
#' @examples
#' \dontrun{
#' images <- extract_pdf_images("paper.pdf")
#' if (nrow(images) > 0) {
#'   print(paste("Found", nrow(images), "images"))
#' }
#' }
extract_pdf_images <- function(path, output_dir = NULL) {
  # Check for pdfimager package
  if (!requireNamespace("pdfimager", quietly = TRUE)) {
    stop(
      "Package 'pdfimager' is required for image extraction.\n",
      "Install with: pak::pak('sckott/pdfimager')\n",
      "Note: Requires Poppler system utilities to be installed."
    )
  }

  # Validate file exists
  if (!file.exists(path)) {
    stop("PDF file not found: ", path)
  }

  # Use temp dir if not specified
  if (is.null(output_dir)) {
    output_dir <- tempfile("pdf_images_")
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  } else {
    # Ensure output dir exists
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    }
  }

  # Extract images using pdfimager
  result <- tryCatch({
    pdfimager::pdimg_images(path, format = "all", pages = NULL)
  }, error = function(e) {
    # Check if error is due to missing Poppler
    if (grepl("pdfimages", e$message, ignore.case = TRUE)) {
      stop(
        "Failed to extract images: Poppler utilities not found.\n",
        "Install Poppler:\n",
        "  - Ubuntu/Debian: apt-get install poppler-utils\n",
        "  - macOS: brew install poppler\n",
        "  - Windows: https://github.com/oschwartz10612/poppler-windows/releases/\n",
        "Original error: ", e$message
      )
    }
    stop("Failed to extract images from PDF: ", e$message)
  })

  # Return empty data frame if no images found
  if (is.null(result) || length(result) == 0) {
    return(data.frame(
      path = character(0),
      page = integer(0),
      width = integer(0),
      height = integer(0),
      type = character(0),
      name = character(0),
      stringsAsFactors = FALSE
    ))
  }

  # Return the result (pdfimager returns a data frame or list)
  result
}

#' Check if PDF contains extractable images
#'
#' Utility function to quickly check if a PDF has embedded images without
#' extracting them.
#'
#' @param path Path to PDF file
#' @return Logical indicating if images were found
#' @examples
#' \dontrun{
#' if (has_pdf_images("paper.pdf")) {
#'   images <- extract_pdf_images("paper.pdf")
#' }
#' }
has_pdf_images <- function(path) {
  tryCatch({
    images <- extract_pdf_images(path)
    return(!is.null(images) && nrow(images) > 0)
  }, error = function(e) {
    # Return FALSE on any error (file not found, no pdfimager, etc.)
    FALSE
  })
}
