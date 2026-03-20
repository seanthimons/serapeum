# Citation Audit Business Logic (Phase 37)
#
# Fetches backward references and forward citations from OpenAlex,
# aggregates them by frequency, and ranks missing papers.

#' Write audit progress to file
#' @param progress_file Path to progress file
#' @param step Current step number
#' @param total_steps Total number of steps
#' @param detail_message Human-readable detail message
write_audit_progress <- function(progress_file, step, total_steps, detail_message) {
  if (is.null(progress_file)) return(invisible(NULL))
  tryCatch({
    writeLines(paste(step, total_steps, detail_message, sep = "|"), progress_file)
  }, error = function(e) {
    # Silently handle errors (file may be deleted)
  })
  invisible(NULL)
}

#' Read audit progress from file
#' @param progress_file Path to progress file
#' @return List with step, total_steps, message
read_audit_progress <- function(progress_file) {
  if (is.null(progress_file) || !file.exists(progress_file)) {
    return(list(step = 0, total_steps = 3, message = "Waiting..."))
  }
  line <- tryCatch(readLines(progress_file, n = 1, warn = FALSE), error = function(e) "0|3|Waiting...")
  parts <- strsplit(line, "\\|", fixed = FALSE)[[1]]
  if (length(parts) < 3) {
    return(list(step = 0, total_steps = 3, message = "Waiting..."))
  }
  list(
    step = as.integer(parts[1]),
    total_steps = as.integer(parts[2]),
    message = paste(parts[3:length(parts)], collapse = "|")
  )
}

#' Aggregate backward references for papers in a notebook
#'
#' For each paper, fetches its referenced_works from OpenAlex API using batch
#' openalex_id filter. Counts frequency of each referenced work across all papers.
#' Filters out works already in the notebook.
#'
#' @param paper_ids Character vector of OpenAlex paper IDs (W-prefixed)
#' @param email Email for OpenAlex polite pool
#' @param api_key Optional OpenAlex API key
#' @param interrupt_flag Path to interrupt flag file (optional)
#' @param progress_file Path to progress file (optional)
#' @return Named integer vector: work_id -> count (only missing papers)
aggregate_backward_refs <- function(paper_ids, email, api_key = NULL,
                                     interrupt_flag = NULL, progress_file = NULL) {
  if (length(paper_ids) == 0) return(integer(0))

  all_refs <- character(0)
  paper_id_set <- paper_ids

  # Process in batches of 50 using openalex_id filter
  chunks <- split(paper_ids, ceiling(seq_along(paper_ids) / 50))

  for (i in seq_along(chunks)) {
    # Check interrupt between chunks
    if (!is.null(interrupt_flag) && check_interrupt(interrupt_flag)) {
      message("[citation_audit] Backward refs interrupted at chunk ", i, "/", length(chunks))
      break
    }

    chunk <- chunks[[i]]
    filter_str <- paste0("openalex_id:", paste(chunk, collapse = "|"))

    write_audit_progress(progress_file, 1, 3,
      paste0("Fetching backward references: batch ", i, "/", length(chunks), "..."))

    tryCatch({
      req <- build_openalex_request("works", email, api_key) |>
        httr2::req_url_query(
          filter = filter_str,
          select = "id,referenced_works",
          per_page = 200
        ) |>
        httr2::req_retry(
          max_tries = 3,
          is_transient = function(resp) httr2::resp_status(resp) == 429,
          backoff = function(tries) 2^(tries - 1)
        )

      resp <- httr2::req_perform(req)
      body <- httr2::resp_body_json(resp)

      if (!is.null(body$results)) {
        for (work in body$results) {
          if (!is.null(work$referenced_works) && length(work$referenced_works) > 0) {
            # Strip OpenAlex URL prefix to get work IDs
            ref_ids <- gsub("^https://openalex.org/", "", as.character(work$referenced_works))
            all_refs <- c(all_refs, ref_ids)
          }
        }
      }
    }, error = function(e) {
      message("[citation_audit] Error fetching backward refs batch ", i, ": ", e$message)
    })

    # Rate limiting
    if (i < length(chunks)) Sys.sleep(0.1)
  }

  if (length(all_refs) == 0) return(integer(0))

  # Count frequency using table()
  ref_counts <- table(all_refs)

  # Filter out papers already in the notebook
  ref_counts <- ref_counts[!names(ref_counts) %in% paper_id_set]

  # Convert to named integer vector (as.integer strips names)
  result <- as.integer(ref_counts)
  names(result) <- names(ref_counts)
  result
}

#' Fetch forward citations for papers in a notebook
#'
#' For each notebook paper, fetches papers that cite it from OpenAlex.
#' Counts how many times each citing paper appears across all notebook papers.
#' Filters out works already in the notebook.
#'
#' @param paper_ids Character vector of OpenAlex paper IDs (W-prefixed)
#' @param email Email for OpenAlex polite pool
#' @param api_key Optional OpenAlex API key
#' @param interrupt_flag Path to interrupt flag file (optional)
#' @param progress_file Path to progress file (optional)
#' @return Named integer vector: work_id -> count (only missing papers)
fetch_forward_citations <- function(paper_ids, email, api_key = NULL,
                                     interrupt_flag = NULL, progress_file = NULL) {
  if (length(paper_ids) == 0) return(integer(0))

  all_citing <- character(0)
  paper_id_set <- paper_ids

  # Process in chunks of 10 with interrupt checks
  chunks <- split(paper_ids, ceiling(seq_along(paper_ids) / 10))

  for (i in seq_along(chunks)) {
    if (!is.null(interrupt_flag) && check_interrupt(interrupt_flag)) {
      message("[citation_audit] Forward citations interrupted at chunk ", i, "/", length(chunks))
      break
    }

    chunk <- chunks[[i]]

    for (j in seq_along(chunk)) {
      pid <- chunk[j]
      overall_idx <- (i - 1) * 10 + j

      write_audit_progress(progress_file, 2, 3,
        paste0("Fetching forward citations: paper ", overall_idx, "/", length(paper_ids), "..."))

      tryCatch({
        citing <- get_citing_papers(pid, email, api_key, per_page = 200)
        if (length(citing) > 0) {
          citing_ids <- vapply(citing, function(w) w$paper_id, character(1))
          all_citing <- c(all_citing, citing_ids)
        }
      }, error = function(e) {
        message("[citation_audit] Error fetching citations for ", pid, ": ", e$message)
      })

      # Rate limiting between individual calls
      Sys.sleep(0.1)
    }
  }

  if (length(all_citing) == 0) return(integer(0))

  # Count frequency
  cite_counts <- table(all_citing)

  # Filter out papers already in the notebook
  cite_counts <- cite_counts[!names(cite_counts) %in% paper_id_set]

  # Convert to named integer vector (as.integer strips names)
  result <- as.integer(cite_counts)
  names(result) <- names(cite_counts)
  result
}

#' Rank missing papers by combined backward + forward frequency
#'
#' @param backward_refs Named integer vector (work_id -> backward count)
#' @param forward_refs Named integer vector (work_id -> forward count)
#' @param threshold Minimum collection frequency to include (default 2)
#' @return Data frame with columns: work_id, backward_count, forward_count, collection_frequency
rank_missing_papers <- function(backward_refs, forward_refs, threshold = 2) {
  # Handle empty inputs
  if (length(backward_refs) == 0 && length(forward_refs) == 0) {
    return(data.frame(
      work_id = character(0),
      backward_count = integer(0),
      forward_count = integer(0),
      collection_frequency = integer(0),
      stringsAsFactors = FALSE
    ))
  }

  # Convert to data frames
  backward_df <- if (length(backward_refs) > 0) {
    data.frame(
      work_id = names(backward_refs),
      backward_count = as.integer(backward_refs),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(work_id = character(0), backward_count = integer(0), stringsAsFactors = FALSE)
  }

  forward_df <- if (length(forward_refs) > 0) {
    data.frame(
      work_id = names(forward_refs),
      forward_count = as.integer(forward_refs),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(work_id = character(0), forward_count = integer(0), stringsAsFactors = FALSE)
  }

  # Full outer join
  merged <- merge(backward_df, forward_df, by = "work_id", all = TRUE)

  # Replace NAs with 0
  merged$backward_count[is.na(merged$backward_count)] <- 0L
  merged$forward_count[is.na(merged$forward_count)] <- 0L

  # Calculate combined frequency
  merged$collection_frequency <- merged$backward_count + merged$forward_count

  # Filter by threshold
  merged <- merged[merged$collection_frequency >= threshold, , drop = FALSE]

  # Sort by collection_frequency descending
  merged <- merged[order(-merged$collection_frequency), , drop = FALSE]
  rownames(merged) <- NULL

  merged
}

#' Fetch metadata for missing papers from OpenAlex
#'
#' @param work_ids Character vector of OpenAlex work IDs (W-prefixed)
#' @param email Email for OpenAlex polite pool
#' @param api_key Optional OpenAlex API key
#' @param interrupt_flag Path to interrupt flag file (optional)
#' @param progress_file Path to progress file (optional)
#' @return List of parsed work objects
fetch_missing_paper_metadata <- function(work_ids, email, api_key = NULL,
                                          interrupt_flag = NULL, progress_file = NULL) {
  if (length(work_ids) == 0) return(list())

  all_papers <- list()
  chunks <- split(work_ids, ceiling(seq_along(work_ids) / 50))

  for (i in seq_along(chunks)) {
    if (!is.null(interrupt_flag) && check_interrupt(interrupt_flag)) {
      message("[citation_audit] Metadata fetch interrupted at chunk ", i, "/", length(chunks))
      break
    }

    chunk <- chunks[[i]]
    filter_str <- paste0("openalex_id:", paste(chunk, collapse = "|"))

    write_audit_progress(progress_file, 3, 3,
      paste0("Fetching metadata: batch ", i, "/", length(chunks), "..."))

    tryCatch({
      req <- build_openalex_request("works", email, api_key) |>
        httr2::req_url_query(
          filter = filter_str,
          per_page = 200
        ) |>
        httr2::req_retry(
          max_tries = 3,
          is_transient = function(resp) httr2::resp_status(resp) == 429,
          backoff = function(tries) 2^(tries - 1)
        )

      resp <- httr2::req_perform(req)
      body <- httr2::resp_body_json(resp)

      if (!is.null(body$results)) {
        parsed <- lapply(body$results, parse_openalex_work)
        all_papers <- c(all_papers, parsed)
      }
    }, error = function(e) {
      message("[citation_audit] Error fetching metadata batch ", i, ": ", e$message)
    })

    if (i < length(chunks)) Sys.sleep(0.1)
  }

  all_papers
}

#' Fetch citation audit data from OpenAlex (API-only, no DB access)
#'
#' Designed for mirai worker execution. Does all OpenAlex API calls,
#' ranking, and metadata enrichment, then returns results for the main
#' process to write to DB. Avoids DuckDB cross-process file locking on Windows.
#'
#' @param paper_ids Character vector of OpenAlex paper IDs (W-prefixed)
#' @param email Email for OpenAlex polite pool
#' @param api_key Optional OpenAlex API key
#' @param interrupt_flag Path to interrupt flag file (optional)
#' @param progress_file Path to progress file (optional)
#' @return List with ranked (data frame), backward_count, forward_count,
#'   missing_found, status, cancelled
fetch_citation_audit <- function(paper_ids, email, api_key,
                                  interrupt_flag = NULL, progress_file = NULL) {
  tryCatch({
    # Step 1: Backward references
    write_audit_progress(progress_file, 1, 3, "Fetching backward references...")
    backward_refs <- aggregate_backward_refs(paper_ids, email, api_key,
                                              interrupt_flag, progress_file)

    # Check interrupt
    if (!is.null(interrupt_flag) && check_interrupt(interrupt_flag)) {
      return(list(
        ranked = data.frame(),
        backward_count = length(backward_refs),
        forward_count = 0, missing_found = 0,
        status = "cancelled", cancelled = TRUE
      ))
    }

    # Step 2: Forward citations
    write_audit_progress(progress_file, 2, 3, "Fetching forward citations...")
    forward_refs <- fetch_forward_citations(paper_ids, email, api_key,
                                             interrupt_flag, progress_file)

    # Check interrupt — still rank partial results
    cancelled <- !is.null(interrupt_flag) && check_interrupt(interrupt_flag)

    # Step 3: Rank
    write_audit_progress(progress_file, 3, 3, "Ranking results...")
    ranked <- rank_missing_papers(backward_refs, forward_refs, threshold = 2)

    if (nrow(ranked) > 0) {
      top_ids <- head(ranked$work_id, 200)
      metadata <- fetch_missing_paper_metadata(top_ids, email, api_key,
                                                interrupt_flag, progress_file)
      ranked <- enrich_ranked_with_metadata(ranked, metadata)
    }

    write_audit_progress(progress_file, 3, 3,
                         if (cancelled) "Cancelled — partial results" else "Complete!")

    list(
      ranked = ranked,
      backward_count = length(backward_refs),
      forward_count = length(forward_refs),
      missing_found = nrow(ranked),
      status = if (cancelled) "cancelled" else "completed",
      cancelled = cancelled
    )
  }, error = function(e) {
    message("[citation_audit] Error: ", e$message)
    list(
      ranked = data.frame(),
      backward_count = 0, forward_count = 0,
      missing_found = 0, status = "failed",
      cancelled = FALSE,
      error = e$message
    )
  })
}

#' Run a complete citation audit for a notebook
#'
#' Legacy orchestrator that opens its own DB connection.
#' NOTE: On Windows, this will fail in mirai workers due to DuckDB file locking.
#' Use fetch_citation_audit() for workers and handle DB writes in the main process.
#'
#' @param notebook_id Notebook ID
#' @param email Email for OpenAlex polite pool
#' @param api_key Optional OpenAlex API key
#' @param db_path Path to DuckDB database file
#' @param interrupt_flag Path to interrupt flag file (optional)
#' @param progress_file Path to progress file (optional)
#' @return List with run_id, backward_count, forward_count, missing_found, status
run_citation_audit <- function(notebook_id, email, api_key, db_path,
                                interrupt_flag = NULL, progress_file = NULL) {
  con <- NULL
  run_id <- NULL

  tryCatch({
    # Open DB connection
    con <- get_db_connection(db_path)

    # Get all paper_ids from abstracts table for this notebook
    papers <- dbGetQuery(con, "
      SELECT paper_id FROM abstracts WHERE notebook_id = ? AND paper_id IS NOT NULL
    ", list(notebook_id))

    paper_ids <- papers$paper_id
    if (length(paper_ids) == 0) {
      close_db_connection(con)
      return(list(
        run_id = NULL,
        backward_count = 0, forward_count = 0,
        missing_found = 0, status = "completed",
        cancelled = FALSE,
        message = "No papers in notebook"
      ))
    }

    # Create audit run
    run_id <- create_audit_run(con, notebook_id)
    update_audit_run(con, run_id, total_papers = length(paper_ids))

    # Delegate to API-only function
    result <- fetch_citation_audit(paper_ids, email, api_key,
                                    interrupt_flag, progress_file)

    # Write results to DB
    if (nrow(result$ranked) > 0) {
      save_audit_results(con, run_id, notebook_id, result$ranked)
    }

    update_audit_run(con, run_id,
                     status = result$status,
                     backward_count = result$backward_count,
                     forward_count = result$forward_count,
                     missing_found = result$missing_found)

    close_db_connection(con)

    list(
      run_id = run_id,
      backward_count = result$backward_count,
      forward_count = result$forward_count,
      missing_found = result$missing_found,
      status = result$status,
      cancelled = result$cancelled
    )
  }, error = function(e) {
    message("[citation_audit] Error: ", e$message)
    if (!is.null(con) && !is.null(run_id)) {
      tryCatch(update_audit_run(con, run_id, status = "failed"), error = function(e2) NULL)
    }
    if (!is.null(con)) {
      tryCatch(close_db_connection(con), error = function(e2) NULL)
    }
    list(
      run_id = run_id,
      backward_count = 0, forward_count = 0,
      missing_found = 0, status = "failed",
      cancelled = FALSE,
      error = e$message
    )
  })
}

#' Enrich ranked data frame with metadata from OpenAlex
#'
#' @param ranked Data frame from rank_missing_papers
#' @param metadata List of parsed work objects from fetch_missing_paper_metadata
#' @return Enriched data frame with title, authors, year, doi, cited_by_count
enrich_ranked_with_metadata <- function(ranked, metadata) {
  if (length(metadata) == 0 || nrow(ranked) == 0) {
    # Add empty metadata columns if not present
    if (!"title" %in% names(ranked)) ranked$title <- NA_character_
    if (!"authors" %in% names(ranked)) ranked$authors <- NA_character_
    if (!"year" %in% names(ranked)) ranked$year <- NA_integer_
    if (!"doi" %in% names(ranked)) ranked$doi <- NA_character_
    if (!"cited_by_count" %in% names(ranked)) ranked$cited_by_count <- 0L
    if (!"fwci" %in% names(ranked)) ranked$fwci <- NA_real_
    return(ranked)
  }

  # Build lookup from metadata
  meta_lookup <- list()
  for (paper in metadata) {
    pid <- paper$paper_id
    authors_str <- if (length(paper$authors) > 0) {
      paste(unlist(paper$authors), collapse = ", ")
    } else {
      NA_character_
    }
    meta_lookup[[pid]] <- list(
      title = paper$title %||% NA_character_,
      authors = authors_str,
      year = paper$year %||% NA_integer_,
      doi = paper$doi %||% NA_character_,
      cited_by_count = paper$cited_by_count %||% 0L,
      fwci = paper$fwci %||% NA_real_
    )
  }

  # Enrich ranked data frame
  ranked$title <- vapply(ranked$work_id, function(wid) {
    if (!is.null(meta_lookup[[wid]])) meta_lookup[[wid]]$title else NA_character_
  }, character(1))

  ranked$authors <- vapply(ranked$work_id, function(wid) {
    if (!is.null(meta_lookup[[wid]])) meta_lookup[[wid]]$authors else NA_character_
  }, character(1))

  ranked$year <- vapply(ranked$work_id, function(wid) {
    if (!is.null(meta_lookup[[wid]])) as.integer(meta_lookup[[wid]]$year) else NA_integer_
  }, integer(1))

  ranked$doi <- vapply(ranked$work_id, function(wid) {
    if (!is.null(meta_lookup[[wid]])) as.character(meta_lookup[[wid]]$doi) else NA_character_
  }, character(1))

  ranked$cited_by_count <- vapply(ranked$work_id, function(wid) {
    if (!is.null(meta_lookup[[wid]])) as.integer(meta_lookup[[wid]]$cited_by_count) else 0L
  }, integer(1))

  ranked$fwci <- vapply(ranked$work_id, function(wid) {
    if (!is.null(meta_lookup[[wid]])) as.numeric(meta_lookup[[wid]]$fwci) else NA_real_
  }, numeric(1))

  ranked
}

#' Import papers from audit results into notebook
#'
#' @param work_ids Character vector of work IDs to import
#' @param notebook_id Notebook ID
#' @param email Email for OpenAlex polite pool
#' @param api_key Optional OpenAlex API key
#' @param con DuckDB connection (uses existing connection from main process)
#' @param interrupt_flag Path to interrupt flag file (optional)
#' @param progress_file Path to progress file (optional)
#' @param progress_callback Optional function(current, total) called after each paper
#' @return List with imported_count, failed_count, skipped_count
import_audit_papers <- function(work_ids, notebook_id, email, api_key, con,
                                 interrupt_flag = NULL, progress_file = NULL,
                                 progress_callback = NULL) {
  if (length(work_ids) == 0) {
    return(list(imported_count = 0L, failed_count = 0L, skipped_count = 0L))
  }

  tryCatch({
    # Get existing paper_ids to avoid duplicates
    existing <- DBI::dbGetQuery(con, "
      SELECT paper_id FROM abstracts WHERE notebook_id = ?
    ", list(notebook_id))$paper_id

    # Filter out already-imported and track skipped count
    new_ids <- setdiff(work_ids, existing)
    skipped <- length(work_ids) - length(new_ids)

    if (length(new_ids) == 0) {
      return(list(imported_count = 0L, failed_count = 0L, skipped_count = skipped))
    }

    # Fetch full metadata from OpenAlex
    metadata <- fetch_missing_paper_metadata(new_ids, email, api_key,
                                              interrupt_flag, progress_file)

    imported <- 0L
    failed <- 0L

    for (i in seq_along(metadata)) {
      paper <- metadata[[i]]
      tryCatch({
        create_abstract(
          con = con,
          notebook_id = notebook_id,
          paper_id = paper$paper_id,
          title = paper$title,
          authors = paper$authors,
          abstract = paper$abstract,
          year = paper$year,
          venue = paper$venue,
          pdf_url = paper$pdf_url,
          keywords = unlist(paper$keywords),
          work_type = paper$work_type,
          work_type_crossref = paper$work_type_crossref,
          oa_status = paper$oa_status,
          is_oa = paper$is_oa,
          cited_by_count = paper$cited_by_count,
          referenced_works_count = paper$referenced_works_count,
          fwci = paper$fwci,
          doi = paper$doi
        )
        imported <- imported + 1L
      }, error = function(e) {
        message("[citation_audit] Failed to import ", paper$paper_id, ": ", e$message)
        failed <<- failed + 1L
      })

      # Call progress callback after processing each paper
      if (!is.null(progress_callback)) {
        progress_callback(i, length(metadata))
      }
    }

    # Mark imported results in audit table
    latest_run <- get_latest_audit_run(con, notebook_id)
    if (!is.null(latest_run)) {
      check_audit_imports(con, latest_run$id, notebook_id)
    }

    list(imported_count = imported, failed_count = failed, skipped_count = skipped)
  }, error = function(e) {
    message("[citation_audit] Import error: ", e$message)
    list(imported_count = 0L, failed_count = 0L, skipped_count = 0L, error = e$message)
  })
}
