# Research Refiner Business Logic
#
# Candidate fetching, anchor reference resolution, and scoring pipeline.
# Designed for use inside mirai workers — no DuckDB or Shiny dependencies.

#' Fetch anchor paper's reference lists from OpenAlex
#'
#' For each seed paper, retrieves the paper's metadata and its referenced_works
#' list. Returns structures needed to compute seed_connectivity.
#'
#' @param seed_ids Character vector of OpenAlex work IDs (W-prefixed)
#' @param email Email for OpenAlex polite pool
#' @param api_key Optional OpenAlex API key
#' @return List with:
#'   - anchor_refs: list of character vectors (referenced_works per seed)
#'   - anchor_ids: character vector of seed paper IDs
#'   - anchor_papers: list of parsed work objects
#'   - errors: character vector of error messages (empty if no failures)
fetch_anchor_refs <- function(seed_ids, email, api_key = NULL) {
  anchor_refs <- list()
  anchor_papers <- list()
  errors <- character(0)

  for (sid in seed_ids) {
    # Fetch the seed paper to get its referenced_works
    req <- build_openalex_request("works", email, api_key) |>
      req_url_query(filter = paste0("openalex_id:", sid))

    resp <- tryCatch(req_perform(req), error = function(e) {
      errors[length(errors) + 1] <<- paste0("Anchor ", sid, ": ", e$message)
      NULL
    })
    if (is.null(resp)) next

    body <- resp_body_json(resp)
    if (is.null(body$results) || length(body$results) == 0) next

    parsed <- parse_openalex_work(body$results[[1]])
    anchor_papers <- c(anchor_papers, list(parsed))
    anchor_refs <- c(anchor_refs, list(parsed$referenced_works))
  }

  list(
    anchor_refs = anchor_refs,
    anchor_ids = seed_ids,
    anchor_papers = anchor_papers,
    errors = errors
  )
}

#' Prepare candidates from a notebook's abstracts
#'
#' Reads papers from the abstracts table and returns a data frame ready for
#' scoring. Called from the main Shiny process (has DB access).
#'
#' @param con DuckDB connection
#' @param notebook_id Notebook ID
#' @param exclude_ids Optional character vector of paper IDs to exclude (e.g., seed papers)
#' @return Data frame with columns needed by score_candidate_pool
prepare_candidates_from_notebook <- function(con, notebook_id, exclude_ids = character(0)) {
  # Note: authors column from abstracts table is already JSON-encoded.
  # It flows as a string through refiner_results.authors, then is decoded
  # by fromJSON() during import (mod_research_refiner.R), and create_abstract()
  # detects pre-encoded JSON to avoid double-encoding.
  papers <- dbGetQuery(con, "
    SELECT paper_id, title, authors, abstract, year, venue, doi,
           cited_by_count, fwci, referenced_works_count
    FROM abstracts
    WHERE notebook_id = ?
  ", list(notebook_id))

  if (nrow(papers) == 0) return(papers)

  # Exclude seed papers from candidates

  if (length(exclude_ids) > 0) {
    papers <- papers[!papers$paper_id %in% exclude_ids, , drop = FALSE]
  }

  # Ensure numeric types (replace both NULL columns and NA values)
  papers$cited_by_count <- as.integer(papers$cited_by_count %||% 0L)
  papers$cited_by_count[is.na(papers$cited_by_count)] <- 0L
  papers$year <- as.integer(papers$year)
  papers$fwci <- as.numeric(papers$fwci)

  # Initialize optional scoring columns as NA (will be computed if data available)
  papers$seed_connectivity <- NA_real_
  papers$bridge_score <- NA_real_

  papers
}

#' Compute seed connectivity for all candidates
#'
#' For each candidate, counts how many seed papers have a direct citation
#' link. Requires anchor_refs (what seeds cite) and candidate referenced_works
#' (what candidates cite).
#'
#' @param candidates Data frame of candidates (must have paper_id column)
#' @param anchor_data List from fetch_anchor_refs()
#' @param candidate_refs Named list: paper_id -> character vector of referenced_works
#'   (optional; if NULL, only forward connectivity is computed)
#' @return Numeric vector of connectivity scores (same length as candidates)
compute_pool_connectivity <- function(candidates, anchor_data,
                                       candidate_refs = NULL) {
  vapply(seq_len(nrow(candidates)), function(i) {
    pid <- candidates$paper_id[i]
    crefs <- if (!is.null(candidate_refs)) {
      candidate_refs[[pid]] %||% character(0)
    } else {
      character(0)
    }
    compute_seed_connectivity(
      pid,
      anchor_data$anchor_refs,
      anchor_data$anchor_ids,
      crefs
    )
  }, numeric(1))
}

#' Fetch candidates from seed papers via OpenAlex
#'
#' For each seed, fetches citing papers, cited papers, and related papers.
#' De-duplicates across seeds. Returns a data frame ready for scoring.
#'
#' @param seed_ids Character vector of seed paper IDs
#' @param email Email for OpenAlex
#' @param api_key Optional API key
#' @param per_page Results per page per query (default 50)
#' @param progress_callback Optional function(message) for progress updates
#' @return List with:
#'   - candidates: data frame of unique candidate papers
#'   - errors: character vector of error messages (empty if no failures)
fetch_candidates_from_seeds <- function(seed_ids, email, api_key = NULL,
                                         per_page = 50,
                                         progress_callback = NULL) {
  all_papers <- list()
  seen_ids <- new.env(hash = TRUE, parent = emptyenv())
  errors <- character(0)

  for (i in seq_along(seed_ids)) {
    sid <- seed_ids[i]
    if (!is.null(progress_callback)) {
      progress_callback(paste0("Fetching papers for seed ", i, "/", length(seed_ids)))
    }

    # Fetch citing, cited, and related
    citing <- tryCatch(
      get_citing_papers(sid, email, api_key, per_page = per_page),
      error = function(e) {
        errors[length(errors) + 1] <<- paste0("Seed ", sid, " citing: ", e$message)
        list()
      }
    )
    cited <- tryCatch(
      get_cited_papers(sid, email, api_key, per_page = per_page),
      error = function(e) {
        errors[length(errors) + 1] <<- paste0("Seed ", sid, " cited: ", e$message)
        list()
      }
    )
    related <- tryCatch(
      get_related_papers(sid, email, api_key, per_page = per_page),
      error = function(e) {
        errors[length(errors) + 1] <<- paste0("Seed ", sid, " related: ", e$message)
        list()
      }
    )

    for (paper in c(citing, cited, related)) {
      if (exists(paper$paper_id, envir = seen_ids, inherits = FALSE)) next
      if (paper$paper_id %in% seed_ids) next  # Exclude seeds from candidates
      assign(paper$paper_id, TRUE, envir = seen_ids)
      all_papers <- c(all_papers, list(paper))
    }
  }

  if (length(all_papers) == 0) {
    return(list(
      candidates = data.frame(
        paper_id = character(0), title = character(0), authors = character(0),
        abstract = character(0), year = integer(0), venue = character(0),
        doi = character(0), cited_by_count = integer(0), fwci = double(0),
        referenced_works_count = integer(0), seed_connectivity = double(0),
        bridge_score = double(0),
        stringsAsFactors = FALSE
      ),
      errors = errors
    ))
  }

  # Convert list of papers to data frame
  candidates_df <- data.frame(
    paper_id = vapply(all_papers, function(p) p$paper_id, character(1)),
    title = vapply(all_papers, function(p) p$title %||% "Untitled", character(1)),
    authors = vapply(all_papers, function(p) {
      if (length(p$authors) > 0) jsonlite::toJSON(p$authors, auto_unbox = TRUE) else "[]"
    }, character(1)),
    abstract = vapply(all_papers, function(p) p$abstract %||% NA_character_, character(1)),
    year = vapply(all_papers, function(p) as.integer(p$year %||% NA_integer_), integer(1)),
    venue = vapply(all_papers, function(p) p$venue %||% NA_character_, character(1)),
    doi = vapply(all_papers, function(p) p$doi %||% NA_character_, character(1)),
    cited_by_count = vapply(all_papers, function(p) {
      v <- p$cited_by_count %||% 0L
      if (is.na(v)) 0L else as.integer(v)
    }, integer(1)),
    fwci = vapply(all_papers, function(p) as.numeric(p$fwci %||% NA_real_), numeric(1)),
    referenced_works_count = vapply(all_papers, function(p) {
      v <- p$referenced_works_count %||% 0L
      if (is.na(v)) 0L else as.integer(v)
    }, integer(1)),
    seed_connectivity = NA_real_,
    bridge_score = NA_real_,
    stringsAsFactors = FALSE
  )

  list(candidates = candidates_df, errors = errors)
}

# ---- Semantic Scoring (Tier 2) ----

#' Build a query string for semantic scoring
#'
#' Constructs a search query from intent text and/or seed paper abstracts.
#'
#' @param intent Optional intent text
#' @param seed_abstracts Optional character vector of seed paper abstracts
#' @return Character string query
build_semantic_query <- function(intent = NULL, seed_abstracts = NULL) {
  parts <- character(0)
  if (!is.null(intent) && nchar(trimws(intent)) > 0) {
    parts <- c(parts, intent)
  }
  if (!is.null(seed_abstracts)) {
    # Use first 3 seed abstracts (truncated) to keep query manageable
    abstracts <- seed_abstracts[!is.na(seed_abstracts)]
    abstracts <- head(abstracts, 3)
    abstracts <- vapply(abstracts, function(a) substr(a, 1, 500), character(1))
    parts <- c(parts, abstracts)
  }
  if (length(parts) == 0) return(NULL)
  paste(parts, collapse = "\n\n")
}

#' Compute semantic similarity scores using an existing ragnar store
#'
#' Retrieves BM25+VSS scores for candidates that are already embedded in a
#' ragnar store (e.g., from a search notebook). Maps scores back to paper_ids
#' via the origin field (format: "abstract:{paper_id}|...").
#'
#' @param store RagnarStore object (must have embed function attached)
#' @param query_text Search query for semantic scoring
#' @param candidate_paper_ids Character vector of paper IDs to score
#' @param uuid_to_paper_id Named character vector mapping abstract UUIDs to
#'   OpenAlex paper IDs. Required because ragnar origins use internal UUIDs
#'   while candidates use OpenAlex IDs. If NULL, assumes origin IDs match
#'   candidate IDs directly.
#' @return Named numeric vector: paper_id -> similarity score [0, 1]
score_from_ragnar_store <- function(store, query_text, candidate_paper_ids,
                                     uuid_to_paper_id = NULL) {
  # Retrieve all candidates (generous top_k to get full coverage)
  results <- tryCatch(
    ragnar::ragnar_retrieve(store, query_text, top_k = length(candidate_paper_ids) * 2),
    error = function(e) {
      message("Ragnar retrieval failed: ", e$message)
      return(NULL)
    }
  )

  if (is.null(results) || nrow(results) == 0) {
    return(setNames(rep(NA_real_, length(candidate_paper_ids)), candidate_paper_ids))
  }


  # Extract UUID from origin field (format: "abstract:{uuid}|...")
  results$origin_uuid <- vapply(results$origin, function(o) {
    id <- sub("^abstract:", "", o)
    id <- sub("\\|.*$", "", id)
    id
  }, character(1))

  # Map UUIDs to OpenAlex paper IDs if mapping provided
  if (!is.null(uuid_to_paper_id)) {
    results$paper_id <- uuid_to_paper_id[results$origin_uuid]
  } else {
    results$paper_id <- results$origin_uuid
  }

  # Convert cosine_distance to similarity (lower distance = higher similarity)
  if ("cosine_distance" %in% names(results)) {
    results$similarity <- 1 - results$cosine_distance
  } else {
    results$similarity <- NA_real_
  }

  # Map back to candidate IDs
  scores <- setNames(rep(NA_real_, length(candidate_paper_ids)), candidate_paper_ids)
  for (i in seq_len(nrow(results))) {
    pid <- results$paper_id[i]
    if (pid %in% candidate_paper_ids && !is.na(results$similarity[i])) {
      # Take best (highest) similarity if paper appears multiple times
      existing <- scores[[pid]]
      if (is.na(existing) || results$similarity[i] > existing) {
        scores[[pid]] <- results$similarity[i]
      }
    }
  }
  scores
}

#' Compute semantic similarity using a temporary ragnar store
#'
#' For candidates not in any ragnar store (e.g., fetched from OpenAlex),
#' creates a temp store, ingests candidate abstracts, embeds them, then
#' retrieves with hybrid BM25+VSS.
#'
#' @param candidates Data frame with paper_id and abstract columns
#' @param query_text Search query for semantic scoring
#' @param openrouter_api_key API key for embedding
#' @param embed_model Embedding model ID
#' @param progress_callback Optional function(detail_text) for progress updates
#' @return Named numeric vector: paper_id -> similarity score [0, 1]
score_with_temp_ragnar <- function(candidates, query_text, openrouter_api_key,
                                    embed_model = "openai/text-embedding-3-small",
                                    progress_callback = NULL) {
  # Filter to candidates with abstracts
  has_abstract <- !is.na(candidates$abstract) & nchar(candidates$abstract) > 0
  scoreable <- candidates[has_abstract, , drop = FALSE]

  if (nrow(scoreable) == 0) {
    return(setNames(rep(NA_real_, nrow(candidates)), candidates$paper_id))
  }

  # Create temporary ragnar store
  temp_path <- tempfile(pattern = "refiner_", fileext = ".duckdb")
  on.exit({
    tryCatch({
      DBI::dbDisconnect(store@con, shutdown = TRUE)
      unlink(temp_path, force = TRUE)
      unlink(paste0(temp_path, ".wal"), force = TRUE)
    }, error = function(e) NULL)
  }, add = TRUE)

  if (!is.null(progress_callback)) progress_callback("Creating temporary store...")

  store <- get_ragnar_store(temp_path, openrouter_api_key, embed_model)

  # Ingest candidate abstracts (batched for efficiency)
  if (!is.null(progress_callback)) {
    progress_callback(paste0("Embedding ", nrow(scoreable), " abstracts..."))
  }
  chunks <- data.frame(
    content = scoreable$abstract,
    page_number = NA_integer_,
    chunk_index = 0L,
    context = "",
    origin = paste0("abstract:", scoreable$paper_id),
    stringsAsFactors = FALSE
  )
  insert_chunks_to_ragnar(store, chunks, "batch", "abstract")

  # Build index for BM25
  build_ragnar_index(store)

  # Retrieve with hybrid scoring
  scores <- score_from_ragnar_store(store, query_text, candidates$paper_id)
  scores
}
