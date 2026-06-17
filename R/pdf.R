library(pdftools)

#' Sanitize a filename by removing characters unsafe for filesystems
#'
#' Replaces characters not allowed in Windows/Unix filenames with underscores.
#' Truncates to max_length to avoid path-length issues.
#'
#' @param name The filename to sanitize
#' @param max_length Maximum length before truncation (default 100)
#' @return Sanitized filename string
sanitize_filename <- function(name, max_length = 100) {
  safe <- gsub('[/:*?"<>|\\\\]', "_", name)
  if (nchar(safe) > max_length) {
    safe <- substr(safe, 1, max_length)
  }
  safe
}

#' Validate URL is safe for use (HTTP/HTTPS only)
#' @param url URL to validate
#' @return TRUE if URL is safe, FALSE otherwise
is_safe_url <- function(url) {
  if (is.na(url) || is.null(url) || nchar(url) == 0) return(FALSE)
  grepl("^https?://", url, ignore.case = TRUE)
}

#' Download a PDF from a URL
#'
#' Downloads a PDF and validates it has the correct magic bytes.
#' Catches HTML landing pages, CAPTCHAs, etc.
#'
#' @param url URL to download from
#' @param dest_path Destination file path
#' @param timeout_seconds Download timeout (default 30)
#' @return List with success (logical), path or reason
download_pdf_from_url <- function(url, dest_path, timeout_seconds = 30) {
  tryCatch({
    resp <- httr2::request(url) |>
      httr2::req_headers(
        `User-Agent` = "Serapeum/1.0 (Research Assistant; mailto:serapeum@localhost)",
        `Accept` = "application/pdf"
      ) |>
      httr2::req_timeout(timeout_seconds) |>
      httr2::req_error(is_error = ~ FALSE) |>
      httr2::req_perform()

    if (httr2::resp_status(resp) >= 400) {
      return(list(success = FALSE, reason = paste("HTTP", httr2::resp_status(resp), httr2::resp_status_desc(resp))))
    }

    writeBin(httr2::resp_body_raw(resp), dest_path)

    # Verify PDF magic bytes
    raw_bytes <- readBin(dest_path, "raw", n = 5)
    magic <- rawToChar(raw_bytes)
    if (magic != "%PDF-") {
      unlink(dest_path)
      return(list(success = FALSE, reason = "Not a valid PDF (wrong magic bytes)"))
    }

    list(success = TRUE, path = dest_path)
  }, error = function(e) {
    if (file.exists(dest_path)) unlink(dest_path)
    list(success = FALSE, reason = e$message)
  })
}

#' Download a PDF via the OpenAlex Content API
#'
#' Uses content.openalex.org to proxy PDF downloads, bypassing publisher restrictions.
#' Requires an OpenAlex API key (free tier: ~100 downloads/day).
#'
#' @param work_id OpenAlex work ID (e.g., "W3038568908")
#' @param api_key OpenAlex API key
#' @param dest_path Destination file path
#' @param timeout_seconds Download timeout (default 60, content proxy can be slower)
#' @return List with success (logical), path or reason
download_pdf_from_openalex <- function(work_id, api_key, dest_path, timeout_seconds = 60) {
  url <- paste0("https://content.openalex.org/works/", work_id, ".pdf")

  tryCatch({
    resp <- httr2::request(url) |>
      httr2::req_url_query(api_key = api_key) |>
      httr2::req_timeout(timeout_seconds) |>
      httr2::req_error(is_error = ~ FALSE) |>
      httr2::req_perform()

    # Parse rate-limit headers for cost tracking
    usage <- list(
      daily_limit = as.numeric(httr2::resp_header(resp, "X-RateLimit-Limit-Day") %||% NA),
      remaining = as.numeric(httr2::resp_header(resp, "X-RateLimit-Remaining-Day") %||% NA),
      credits_used = as.numeric(httr2::resp_header(resp, "X-Cost") %||% 0.01),
      reset_seconds = as.numeric(httr2::resp_header(resp, "X-RateLimit-Reset") %||% NA)
    )

    if (httr2::resp_status(resp) >= 400) {
      return(list(success = FALSE,
                  reason = paste("OpenAlex content API:", httr2::resp_status(resp), httr2::resp_status_desc(resp)),
                  usage = usage))
    }

    writeBin(httr2::resp_body_raw(resp), dest_path)

    # Verify PDF magic bytes
    raw_bytes <- readBin(dest_path, "raw", n = 5)
    magic <- rawToChar(raw_bytes)
    if (magic != "%PDF-") {
      unlink(dest_path)
      return(list(success = FALSE, reason = "OpenAlex content API returned non-PDF response",
                  usage = usage))
    }

    list(success = TRUE, path = dest_path, usage = usage)
  }, error = function(e) {
    if (file.exists(dest_path)) unlink(dest_path)
    list(success = FALSE, reason = e$message, usage = NULL)
  })
}

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
