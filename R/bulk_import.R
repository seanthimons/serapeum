#' Extract DOIs from BibTeX file content
#'
#' Parses BibTeX-formatted text and extracts DOI field values.
#' Only extracts the DOI field — full metadata extraction is Phase 36.
#'
#' @param bib_text Character vector of lines from a .bib file (from readLines)
#' @return List with:
#'   \describe{
#'     \item{dois}{Character vector of extracted DOI strings}
#'     \item{entries_without_doi}{Integer count of BibTeX entries that had no DOI field}
#'   }
#' @examples
#' bib_lines <- c(
#'   "@article{smith2020,",
#'   "  title = {A paper},",
#'   "  doi = {10.1234/abc}",
#'   "}"
#' )
#' extract_dois_from_bib(bib_lines)
extract_dois_from_bib <- function(bib_text) {
  if (is.null(bib_text) || length(bib_text) == 0) {
    return(list(dois = character(0), entries_without_doi = 0L))
  }

  # Collapse to single string for multi-line field handling
  full_text <- paste(bib_text, collapse = "\n")

  # Count total BibTeX entries (lines starting with @type{)
  entry_pattern <- "@\\w+\\s*\\{"
  total_entries <- length(gregexpr(entry_pattern, full_text, perl = TRUE)[[1]])
  # gregexpr returns -1 if no match
  if (length(total_entries) == 1 && total_entries == -1) total_entries <- 0L

  # Extract DOI values
  # Match doi = {value}, doi = "value", or doi = value patterns
  doi_pattern <- "doi\\s*=\\s*[{\"']?\\s*(10\\.[^},\"'\\s]+)"
  matches <- gregexpr(doi_pattern, full_text, ignore.case = TRUE, perl = TRUE)
  raw_matches <- regmatches(full_text, matches)[[1]]

  if (length(raw_matches) == 0) {
    return(list(dois = character(0), entries_without_doi = as.integer(total_entries)))
  }

  # Extract just the DOI portion (the capture group equivalent)
  dois <- sub("doi\\s*=\\s*[{\"']?\\s*", "", raw_matches, ignore.case = TRUE, perl = TRUE)
  # Clean trailing delimiters
  dois <- gsub("[}\"',;\\s]+$", "", dois, perl = TRUE)
  dois <- trimws(dois)
  # Remove empty strings
  dois <- dois[nchar(dois) > 0]

  entries_without_doi <- max(0L, as.integer(total_entries) - length(dois))

  list(
    dois = dois,
    entries_without_doi = entries_without_doi
  )
}

#' Get existing DOIs in a notebook for duplicate detection
#'
#' Queries the abstracts table for DOIs already present in the specified notebook.
#' Used during the preview step to identify duplicates before making API calls.
#'
#' @param con DuckDB connection
#' @param notebook_id Notebook ID
#' @return Character vector of bare DOIs (lowercase) already in the notebook
get_notebook_dois <- function(con, notebook_id) {
  result <- DBI::dbGetQuery(con, "
    SELECT DISTINCT doi FROM abstracts
    WHERE notebook_id = ? AND doi IS NOT NULL AND doi != ''
  ", list(notebook_id))
  if (nrow(result) == 0) return(character(0))
  tolower(result$doi)
}

#' Estimate import time based on DOI count
#'
#' Calculates a rough time estimate for user display in the preview step.
#' Based on batch size, inter-batch delay, and estimated API response time.
#'
#' @param doi_count Number of DOIs to fetch (after deduplication)
#' @param batch_size DOIs per batch (default 50)
#' @param delay_per_batch Seconds between batches (default 0.1)
#' @param api_time_per_batch Estimated API response time per batch (default 1.5 seconds)
#' @return Formatted time string (e.g., "~15 seconds" or "~3 minutes")
estimate_import_time <- function(doi_count, batch_size = 50, delay_per_batch = 0.1,
                                  api_time_per_batch = 1.5) {
  if (doi_count <= 0) return("~0 seconds")
  n_batches <- ceiling(doi_count / batch_size)
  total_seconds <- n_batches * (api_time_per_batch + delay_per_batch)

  if (total_seconds < 60) {
    paste0("~", ceiling(total_seconds), " seconds")
  } else {
    paste0("~", ceiling(total_seconds / 60), " minutes")
  }
}

#' Write import progress to progress file
#'
#' @param progress_file Path to progress file
#' @param batch Current batch number
#' @param total_batches Total number of batches
#' @param found Papers found so far
#' @param failed Papers failed so far
#' @param message Human-readable status message
write_import_progress <- function(progress_file, batch, total_batches, found, failed, message) {
  if (is.null(progress_file)) return(invisible(NULL))
  tryCatch({
    writeLines(paste(batch, total_batches, found, failed, message, sep = "|"), progress_file)
  }, error = function(e) {
    # Silently handle errors (file may be deleted)
  })
  invisible(NULL)
}

#' Read import progress from progress file
#'
#' @param progress_file Path to progress file
#' @return List with batch, total_batches, found, failed, message, and pct (0-100)
read_import_progress <- function(progress_file) {
  default <- list(batch = 0, total_batches = 1, found = 0, failed = 0,
                  message = "Waiting...", pct = 0)
  if (is.null(progress_file) || !file.exists(progress_file)) return(default)

  line <- tryCatch(readLines(progress_file, n = 1, warn = FALSE),
                   error = function(e) "0|1|0|0|Waiting...")

  # Guard against empty file (race condition with mirai worker)
  if (length(line) == 0 || nchar(line[1]) == 0) {
    return(default)
  }

  parts <- strsplit(line, "\\|", fixed = FALSE)[[1]]
  if (length(parts) < 5) return(default)

  batch <- as.integer(parts[1])
  total_batches <- max(as.integer(parts[2]), 1L)
  found <- as.integer(parts[3])
  failed <- as.integer(parts[4])
  message <- paste(parts[5:length(parts)], collapse = "|")
  pct <- round(min(batch / total_batches * 100, 99))

  list(batch = batch, total_batches = total_batches, found = found,
       failed = failed, message = message, pct = pct)
}

#' Fetch papers from OpenAlex without DB access (for mirai workers)
#'
#' API-only function that fetches papers and merges BibTeX metadata.
#' Returns results for the main process to write to DB, avoiding
#' DuckDB cross-process file locking issues on Windows.
#'
#' @param dois Character vector of bare DOIs to fetch
#' @param email OpenAlex polite pool email
#' @param api_key Optional API key
#' @param interrupt_flag Optional path to interrupt flag file
#' @param progress_file Optional path to progress file
#' @param bib_metadata Optional BibTeX metadata data frame for merging
#' @return List with papers, errors, and cancelled flag
fetch_bulk_papers <- function(dois, email, api_key,
                              interrupt_flag = NULL, progress_file = NULL,
                              bib_metadata = NULL) {
  cancelled <- FALSE

  progress_cb <- function(batch_current, batch_total, found_so_far, not_found_so_far) {
    if (!is.null(interrupt_flag) && check_interrupt(interrupt_flag)) {
      cancelled <<- TRUE
    }
    msg <- sprintf("Batch %d/%d: %d found, %d not found",
                   batch_current, batch_total, found_so_far, not_found_so_far)
    write_import_progress(progress_file, batch_current, batch_total,
                          found_so_far, not_found_so_far, msg)
  }

  result <- tryCatch({
    batch_fetch_papers(
      dois = dois,
      email = email,
      api_key = api_key,
      progress_callback = progress_cb
    )
  }, error = function(e) {
    message("[bulk_import] Fatal error in batch_fetch_papers: ", conditionMessage(e))
    list(papers = list(), errors = lapply(dois, function(d) {
      list(doi = d, reason = "api_error", details = conditionMessage(e))
    }))
  })

  # Merge BibTeX metadata if available
  if (!is.null(bib_metadata) && is.data.frame(bib_metadata) && nrow(bib_metadata) > 0) {
    for (i in seq_along(result$papers)) {
      paper_doi <- tolower(result$papers[[i]]$doi %||% "")
      if (nchar(paper_doi) > 0 && "DOI" %in% names(bib_metadata)) {
        bib_match <- bib_metadata[tolower(bib_metadata$DOI) == paper_doi, , drop = FALSE]
        if (nrow(bib_match) > 0) {
          result$papers[[i]] <- merge_bibtex_openalex(result$papers[[i]], bib_match[1, , drop = FALSE])
        }
      }
    }
  }

  total <- length(result$papers) + length(result$errors)
  write_import_progress(progress_file, total, total,
                        length(result$papers), length(result$errors),
                        if (cancelled) "Import cancelled" else "Fetching complete")

  list(
    papers = result$papers,
    errors = result$errors,
    cancelled = cancelled
  )
}

#' Run bulk DOI import (designed for mirai worker execution)
#'
#' Main orchestration function for bulk imports. Opens its own DB connection
#' (mirai workers cannot share connections with the main Shiny session).
#' NOTE: On Windows, this may fail due to DuckDB file locking. Use
#' fetch_bulk_papers() instead for the mirai worker, and write to DB
#' in the main process.
#'
#' @param dois Character vector of bare DOIs to fetch from OpenAlex
#' @param notebook_id Notebook ID to import papers into
#' @param email OpenAlex polite pool email
#' @param api_key Optional API key
#' @param db_path Path to DuckDB database file
#' @param run_id Import run ID (pre-created by main session)
#' @param interrupt_flag Optional path to interrupt flag file
#' @param progress_file Optional path to progress file
#' @return List with run_id, imported_count, failed_count, cancelled flag
run_bulk_import <- function(dois, notebook_id, email, api_key, db_path,
                            run_id, interrupt_flag = NULL, progress_file = NULL,
                            bib_metadata = NULL, source = "doi_bulk") {
  # Open worker's own DB connection
  con <- get_db_connection(path = db_path)
  on.exit(close_db_connection(con), add = TRUE)

  imported_count <- 0L
  failed_count <- 0L
  cancelled <- FALSE

  # Progress callback for batch_fetch_papers
  progress_cb <- function(batch_current, batch_total, found_so_far, not_found_so_far) {
    # Check for cancellation
    if (!is.null(interrupt_flag) && check_interrupt(interrupt_flag)) {
      cancelled <<- TRUE
    }

    # Write progress
    msg <- sprintf("Batch %d/%d: %d found, %d not found",
                   batch_current, batch_total, found_so_far, not_found_so_far)
    write_import_progress(progress_file, batch_current, batch_total,
                          found_so_far, not_found_so_far, msg)
  }

  # Fetch papers from OpenAlex
  result <- tryCatch({
    batch_fetch_papers(
      dois = dois,
      email = email,
      api_key = api_key,
      progress_callback = progress_cb
    )
  }, error = function(e) {
    message("[bulk_import] Fatal error in batch_fetch_papers: ", conditionMessage(e))
    list(papers = list(), errors = lapply(dois, function(d) {
      list(doi = d, reason = "api_error", details = conditionMessage(e))
    }))
  })

  # Merge BibTeX metadata if available (Phase 36)
  if (!is.null(bib_metadata) && is.data.frame(bib_metadata) && nrow(bib_metadata) > 0) {
    for (i in seq_along(result$papers)) {
      paper_doi <- tolower(result$papers[[i]]$doi %||% "")
      if (nchar(paper_doi) > 0 && "DOI" %in% names(bib_metadata)) {
        bib_match <- bib_metadata[tolower(bib_metadata$DOI) == paper_doi, , drop = FALSE]
        if (nrow(bib_match) > 0) {
          result$papers[[i]] <- merge_bibtex_openalex(result$papers[[i]], bib_match[1, , drop = FALSE])
        }
      }
    }
  }

  # Store successful papers
  for (paper in result$papers) {
    tryCatch({
      abstract_id <- create_abstract(
        con = con,
        notebook_id = notebook_id,
        paper_id = paper$paper_id,
        title = paper$title,
        authors = paper$authors,
        abstract = paper$abstract,
        year = paper$year,
        venue = paper$venue,
        pdf_url = paper$pdf_url,
        keywords = paper$keywords,
        work_type = paper$work_type,
        work_type_crossref = paper$work_type_crossref,
        oa_status = paper$oa_status,
        is_oa = paper$is_oa,
        cited_by_count = paper$cited_by_count,
        referenced_works_count = paper$referenced_works_count,
        fwci = paper$fwci,
        doi = paper$doi
      )

      if (!is.null(paper$abstract) && !is.na(paper$abstract) && nchar(paper$abstract) > 0) {
        create_chunk(con, abstract_id, "abstract", 0, paper$abstract)
      }

      create_import_run_item(con, run_id, paper$doi %||% "unknown", "success")
      imported_count <- imported_count + 1L
    }, error = function(e) {
      message("[bulk_import] Error storing paper: ", conditionMessage(e))
      create_import_run_item(con, run_id, paper$doi %||% "unknown", "api_error",
                             paste("Storage error:", conditionMessage(e)))
      failed_count <<- failed_count + 1L
    })
  }

  # Store error entries
  for (err in result$errors) {
    tryCatch({
      create_import_run_item(con, run_id, err$doi, err$reason,
                             err$details %||% NA_character_)
      failed_count <- failed_count + 1L
    }, error = function(e) {
      message("[bulk_import] Error storing error item: ", conditionMessage(e))
    })
  }

  # Update run counts
  tryCatch({
    update_import_run_counts(con, run_id, imported_count, failed_count, 0L)
  }, error = function(e) {
    message("[bulk_import] Error updating run counts: ", conditionMessage(e))
  })

  # Final progress
  write_import_progress(progress_file, length(result$papers) + length(result$errors),
                        length(result$papers) + length(result$errors),
                        imported_count, failed_count,
                        if (cancelled) "Import cancelled" else "Import complete")

  list(
    run_id = run_id,
    imported_count = imported_count,
    failed_count = failed_count,
    cancelled = cancelled
  )
}

#' Parse BibTeX file into structured metadata using bib2df
#'
#' Reads a .bib file and extracts entry metadata including DOI, title, abstract,
#' author, and year. Uses bib2df for robust parsing with graceful error handling
#' for malformed files.
#'
#' @param bib_file_path Path to a .bib file
#' @return List with:
#'   \describe{
#'     \item{data}{Tibble with UPPERCASE columns (DOI, TITLE, ABSTRACT, AUTHOR, YEAR, etc.)}
#'     \item{diagnostics}{List with total_entries, entries_with_doi, entries_without_doi}
#'   }
parse_bibtex_metadata <- function(bib_file_path) {
  empty_result <- list(
    data = data.frame(
      DOI = character(0), TITLE = character(0), ABSTRACT = character(0),
      AUTHOR = character(0), YEAR = character(0),
      stringsAsFactors = FALSE
    ),
    diagnostics = list(
      total_entries = 0L,
      entries_with_doi = 0L,
      entries_without_doi = 0L
    )
  )

  # Handle nonexistent files gracefully

  if (!file.exists(bib_file_path)) {
    return(empty_result)
  }

  # Parse with bib2df, catching malformed files
  parsed <- tryCatch({
    bib2df::bib2df(bib_file_path, separate_names = FALSE)
  }, error = function(e) {
    message("[bibtex] Error parsing .bib file: ", conditionMessage(e))
    NULL
  }, warning = function(w) {
    # bib2df may warn about malformed entries but still return partial results
    suppressWarnings(bib2df::bib2df(bib_file_path, separate_names = FALSE))
  })

  if (is.null(parsed) || !is.data.frame(parsed) || nrow(parsed) == 0) {
    return(empty_result)
  }

  # Ensure expected columns exist (bib2df uses UPPERCASE)
  for (col in c("DOI", "TITLE", "ABSTRACT", "AUTHOR", "YEAR")) {
    if (!col %in% names(parsed)) {
      parsed[[col]] <- NA_character_
    }
  }

  total <- nrow(parsed)
  with_doi <- sum(!is.na(parsed$DOI) & nchar(trimws(as.character(parsed$DOI))) > 0)
  without_doi <- total - with_doi

  list(
    data = parsed,
    diagnostics = list(
      total_entries = as.integer(total),
      entries_with_doi = as.integer(with_doi),
      entries_without_doi = as.integer(without_doi)
    )
  )
}

#' Merge BibTeX metadata into OpenAlex paper record
#'
#' Fills abstract from BibTeX when OpenAlex enrichment lacks one.
#' OpenAlex data takes priority for all fields; BibTeX only fills gaps.
#'
#' @param openalex_paper List with paper fields (from batch_fetch_papers)
#' @param bibtex_row Single-row data.frame from bib2df (UPPERCASE columns)
#' @return Modified openalex_paper with abstract filled from BibTeX if needed
merge_bibtex_openalex <- function(openalex_paper, bibtex_row) {
  # Check if OpenAlex abstract is missing
  oa_abstract <- openalex_paper$abstract
  has_oa_abstract <- !is.null(oa_abstract) && !is.na(oa_abstract) && nchar(trimws(oa_abstract)) > 0

  if (!has_oa_abstract) {
    # Try to fill from BibTeX
    bib_abstract <- bibtex_row$ABSTRACT
    if (length(bib_abstract) > 0 && !is.na(bib_abstract[1]) && nchar(trimws(bib_abstract[1])) > 0) {
      openalex_paper$abstract <- bib_abstract[1]
    }
  }

  openalex_paper
}
