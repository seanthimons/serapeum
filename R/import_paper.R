#' Import a single paper into a document notebook
#'
#' Attempts PDF download + chunking first, falls back to abstract-only.
#' When an OpenAlex API key is provided, uses the content proxy API first
#' (bypasses publisher restrictions, ~100 free downloads/day).
#' No embedding — that's deferred to "Rebuild Search Index".
#'
#' @param con DuckDB connection
#' @param notebook_id Target document notebook ID
#' @param abstract_row Single-row data frame from abstracts table
#' @param download_pdfs Whether to attempt PDF download (default TRUE)
#' @param openalex_api_key OpenAlex API key for content proxy (NULL to skip)
#' @param storage_dir Directory to store downloaded PDFs (default .temp/pdfs/{notebook_id})
#' @param chunk_size Target characters per chunk (default 2500)
#' @param chunk_overlap Overlap fraction between chunks (default 0.1)
#' @return List with success, doc_id, method ("pdf" or "abstract"), and optionally reason
import_single_paper <- function(con, notebook_id, abstract_row,
                                 download_pdfs = TRUE, openalex_api_key = NULL,
                                 storage_dir = NULL,
                                 chunk_size = 2500, chunk_overlap = 0.1) {
  abs <- abstract_row

  # No content at all
  has_abstract <- !is.na(abs$abstract) && nchar(abs$abstract) > 0
  has_pdf_url <- !is.null(abs$pdf_url) && is_safe_url(abs$pdf_url)
  has_work_id <- !is.null(abs$paper_id) && !is.na(abs$paper_id) && nchar(abs$paper_id) > 0
  has_api_key <- !is.null(openalex_api_key) && nchar(openalex_api_key) > 0 &&
    !grepl("^your-", openalex_api_key)

  if (!has_abstract && !has_pdf_url && !has_work_id) {
    return(list(success = FALSE, reason = "No content available"))
  }

  # Extract metadata
  doc_doi <- if (!is.null(abs$doi) && !is.na(abs$doi)) abs$doi else NA_character_
  doc_authors <- if (!is.null(abs$authors) && !is.na(abs$authors)) abs$authors else NA_character_
  doc_year <- if (!is.null(abs$year) && !is.na(abs$year)) as.integer(abs$year) else NA_integer_

  # Setup storage
  if (is.null(storage_dir)) {
    storage_dir <- file.path(".temp", "pdfs", notebook_id)
  }
  safe_name <- sanitize_filename(abs$title)

  # --- PDF download attempts ---
  if (download_pdfs) {
    dir.create(storage_dir, recursive = TRUE, showWarnings = FALSE)
    dest_path <- file.path(storage_dir, paste0(safe_name, ".pdf"))

    # Attempt 1: OpenAlex Content API (most reliable, bypasses publisher restrictions)
    if (has_api_key && has_work_id) {
      message("[import] Trying OpenAlex content API for: ", substr(abs$title, 1, 60))
      message("[import] Work ID: ", abs$paper_id)
      dl <- tryCatch(
        download_pdf_from_openalex(abs$paper_id, openalex_api_key, dest_path),
        error = function(e) list(success = FALSE, reason = e$message, usage = NULL)
      )

      # Log content API usage for cost tracking
      if (!is.null(dl$usage)) {
        tryCatch(
          log_oa_usage(con, "content_download",
                       paste0("content/works/", abs$paper_id, ".pdf"),
                       dl$usage, cost_usd = 0.01),
          error = function(e) message("[import] Failed to log OA usage: ", e$message)
        )
      }

      if (isTRUE(dl$success)) {
        pdf_result <- process_and_store_pdf(con, notebook_id, abs, dl$path, safe_name,
                                             doc_authors, doc_year, doc_doi,
                                             chunk_size, chunk_overlap)
        if (isTRUE(pdf_result$success)) {
          message("[import] PDF import succeeded via OpenAlex content API")
          return(pdf_result)
        }
      } else {
        message("[import] OpenAlex content API failed: ", dl$reason)
      }
    }

    # Attempt 2: Direct URL download (works for repos like arXiv, PMC, OSTI)
    if (has_pdf_url) {
      message("[import] Trying direct PDF URL: ", abs$pdf_url)
      dl <- tryCatch(
        download_pdf_from_url(abs$pdf_url, dest_path),
        error = function(e) list(success = FALSE, reason = e$message)
      )
      if (isTRUE(dl$success)) {
        pdf_result <- process_and_store_pdf(con, notebook_id, abs, dl$path, safe_name,
                                             doc_authors, doc_year, doc_doi,
                                             chunk_size, chunk_overlap)
        if (isTRUE(pdf_result$success)) {
          message("[import] PDF import succeeded via direct URL")
          return(pdf_result)
        }
      } else {
        message("[import] Direct PDF download failed: ", dl$reason)
      }
    }

    message("[import] All PDF methods failed, falling back to abstract")
  }

  # Abstract-only fallback
  if (has_abstract) {
    doc_id <- create_document(
      con, notebook_id,
      paste0(abs$title, ".txt"),
      "",
      abs$abstract,
      1,
      title = abs$title,
      authors = doc_authors,
      year = doc_year,
      doi = doc_doi,
      abstract_id = abs$id
    )
    create_chunk(con, doc_id, "document", 0, abs$abstract, page_number = 1)
    return(list(success = TRUE, doc_id = doc_id, method = "abstract"))
  }

  list(success = FALSE, reason = "No content available")
}


#' Process a downloaded PDF and store as document with chunks
#'
#' Internal helper — extracts text, chunks, creates DB records.
#'
#' @return List with success, doc_id, method
process_and_store_pdf <- function(con, notebook_id, abs, pdf_path, safe_name,
                                   doc_authors, doc_year, doc_doi,
                                   chunk_size, chunk_overlap) {
  tryCatch({
    processed <- process_pdf(pdf_path, chunk_size = chunk_size, overlap = chunk_overlap)

    if (nrow(processed$chunks) == 0) {
      return(list(success = FALSE, reason = "PDF produced no chunks"))
    }

    doc_id <- create_document(
      con, notebook_id,
      paste0(safe_name, ".pdf"),
      pdf_path,
      processed$full_text,
      processed$page_count,
      title = abs$title,
      authors = doc_authors,
      year = doc_year,
      doi = doc_doi,
      abstract_id = abs$id
    )

    for (ci in seq_len(nrow(processed$chunks))) {
      chunk <- processed$chunks[ci, ]
      create_chunk(
        con, doc_id, "document", ci - 1,
        chunk$content,
        page_number = chunk$page_number,
        section_hint = if ("section_hint" %in% names(chunk)) chunk$section_hint else "general"
      )
    }

    list(success = TRUE, doc_id = doc_id, method = "pdf")
  }, error = function(e) {
    message("[import] PDF processing error: ", e$message)
    list(success = FALSE, reason = e$message)
  })
}
