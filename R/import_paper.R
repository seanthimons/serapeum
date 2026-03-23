#' Import a single paper into a document notebook
#'
#' Attempts PDF download + chunking first, falls back to abstract-only.
#' No embedding — that's deferred to "Rebuild Search Index".
#'
#' @param con DuckDB connection
#' @param notebook_id Target document notebook ID
#' @param abstract_row Single-row data frame from abstracts table
#' @param download_pdfs Whether to attempt PDF download (default TRUE)
#' @param storage_dir Directory to store downloaded PDFs (default .temp/pdfs/{notebook_id})
#' @param chunk_size Target characters per chunk (default 2500)
#' @param chunk_overlap Overlap fraction between chunks (default 0.1)
#' @return List with success, doc_id, method ("pdf" or "abstract"), and optionally reason
import_single_paper <- function(con, notebook_id, abstract_row,
                                 download_pdfs = TRUE, storage_dir = NULL,
                                 chunk_size = 2500, chunk_overlap = 0.1) {
  abs <- abstract_row

  # No content at all
  has_abstract <- !is.na(abs$abstract) && nchar(abs$abstract) > 0
  has_pdf_url <- !is.null(abs$pdf_url) && is_safe_url(abs$pdf_url)

  if (!has_abstract && !has_pdf_url) {
    return(list(success = FALSE, reason = "No content available"))
  }

  # Extract metadata
  doc_doi <- if (!is.null(abs$doi) && !is.na(abs$doi)) abs$doi else NA_character_
  doc_authors <- if (!is.null(abs$authors) && !is.na(abs$authors)) abs$authors else NA_character_
  doc_year <- if (!is.null(abs$year) && !is.na(abs$year)) as.integer(abs$year) else NA_integer_

  # Attempt PDF download + processing
  if (download_pdfs && has_pdf_url) {
    pdf_result <- tryCatch({
      if (is.null(storage_dir)) {
        storage_dir <- file.path(".temp", "pdfs", notebook_id)
      }
      dir.create(storage_dir, recursive = TRUE, showWarnings = FALSE)

      safe_name <- sanitize_filename(abs$title)
      dest_path <- file.path(storage_dir, paste0(safe_name, ".pdf"))

      dl <- download_pdf_from_url(abs$pdf_url, dest_path)
      if (!dl$success) {
        list(success = FALSE, reason = dl$reason)
      } else {
        # Process the PDF into chunks
        processed <- process_pdf(dl$path, chunk_size = chunk_size, overlap = chunk_overlap)

        if (nrow(processed$chunks) == 0) {
          list(success = FALSE, reason = "PDF produced no chunks")
        } else {
          # Create document with PDF content
          doc_id <- create_document(
            con, notebook_id,
            paste0(safe_name, ".pdf"),
            dest_path,
            processed$full_text,
            processed$page_count,
            title = abs$title,
            authors = doc_authors,
            year = doc_year,
            doi = doc_doi,
            abstract_id = abs$id
          )

          # Create chunks
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
        }
      }
    }, error = function(e) {
      list(success = FALSE, reason = e$message)
    })

    if (isTRUE(pdf_result$success)) {
      return(pdf_result)
    }
    # PDF failed — fall through to abstract fallback
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
