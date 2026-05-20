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
  top_k <- length(candidate_paper_ids) * 2

  # Try VSS first (requires working embedding), fall back to BM25
  vss_results <- tryCatch(
    ragnar::ragnar_retrieve_vss(store, query_text, top_k = top_k),
    error = function(e) {
      message("[refiner] VSS retrieval failed (embedding issue): ", e$message)
      NULL
    }
  )

  bm25_results <- tryCatch(
    ragnar::ragnar_retrieve_bm25(store, text = query_text, top_k = top_k),
    error = function(e) {
      message("[refiner] BM25 retrieval failed: ", e$message)
      NULL
    }
  )

  # Combine results: prefer VSS cosine_distance, fall back to BM25 rank-based score
  if (!is.null(vss_results) && nrow(vss_results) > 0) {
    results <- vss_results
    if ("cosine_distance" %in% names(results)) {
      results$similarity <- 1 - results$cosine_distance
    } else if (all(c("metric_name", "metric_value") %in% names(results))) {
      is_cosine_distance <- grepl("^cosine_distance$", results$metric_name)
      is_similarity <- grepl("similarity$", results$metric_name)
      results$similarity <- ifelse(
        is_cosine_distance,
        1 - results$metric_value,
        ifelse(is_similarity, results$metric_value, NA_real_)
      )
    } else {
      results$similarity <- NA_real_
    }
  } else if (!is.null(bm25_results) && nrow(bm25_results) > 0) {
    results <- bm25_results
    if ("metric_value" %in% names(results)) {
      metric_range <- range(results$metric_value, na.rm = TRUE)
      if (isTRUE(all.equal(metric_range[1], metric_range[2]))) {
        results$similarity <- rep(0.5, nrow(results))
      } else {
        results$similarity <- (results$metric_value - metric_range[1]) /
          (metric_range[2] - metric_range[1])
      }
    } else {
      # BM25 doesn't produce cosine_distance; use rank-based score as proxy
      results$similarity <- seq(1, 0.1, length.out = nrow(results))
    }
  } else {
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

  # Map back to candidate IDs
  scores <- setNames(rep(NA_real_, length(candidate_paper_ids)), candidate_paper_ids)
  for (i in seq_len(nrow(results))) {
    pid <- results$paper_id[i]
    if (!is.na(pid) && pid %in% candidate_paper_ids && !is.na(results$similarity[i])) {
      existing <- scores[[pid]]
      if (is.na(existing) || results$similarity[i] > existing) {
        scores[[pid]] <- results$similarity[i]
      }
    }
  }
  scores
}

#' Keyword overlap scoring fallback when embedding is unavailable
#'
#' Scores each candidate abstract by the proportion of query terms found in it.
#' Normalizes to 0-1 range across the pool.
#'
#' @param candidates Data frame with paper_id and abstract columns
#' @param query_text Search query text
#' @return Named numeric vector: paper_id -> score [0, 1]
score_keyword_overlap <- function(candidates, query_text) {
  # Tokenize query into unique words (lowercase, strip punctuation)
  query_words <- unique(strsplit(
    gsub("[^a-z0-9 ]", " ", tolower(query_text)), "\\s+"
  )[[1]])
  query_words <- query_words[nchar(query_words) > 2]

  if (length(query_words) == 0) {
    return(setNames(rep(NA_real_, nrow(candidates)), candidates$paper_id))
  }

  # Score each abstract by proportion of query terms present
  raw_scores <- vapply(candidates$abstract, function(abs_text) {
    if (is.na(abs_text) || nchar(abs_text) == 0) return(0)
    abs_lower <- tolower(abs_text)
    sum(vapply(query_words, function(w) grepl(w, abs_lower, fixed = TRUE), logical(1))) /
      length(query_words)
  }, numeric(1))

  setNames(raw_scores, candidates$paper_id)
}

#' Split refiner embedding chunks into provider-safe batches
#'
#' OpenRouter embedding providers can reject oversized bulk requests. Keep each
#' batch under conservative item and character limits so temporary refiner store
#' creation works across models like Gemini Embedding 001.
#'
#' @param chunks Data frame with a content column
#' @param max_batch_items Maximum rows per batch
#' @param max_batch_chars Approximate maximum total characters per batch
#' @return List of chunk data frames
split_refiner_embedding_batches <- function(chunks,
                                             max_batch_items = 8L,
                                             max_batch_chars = 12000L) {
  if (nrow(chunks) == 0) {
    return(list(chunks))
  }

  batches <- list()
  current_rows <- integer(0)
  current_chars <- 0L

  for (i in seq_len(nrow(chunks))) {
    content_chars <- nchar(chunks$content[i] %||% "", type = "chars", allowNA = FALSE)
    would_exceed_items <- length(current_rows) >= max_batch_items
    would_exceed_chars <- length(current_rows) > 0 &&
      (current_chars + content_chars) > max_batch_chars

    if (would_exceed_items || would_exceed_chars) {
      batches[[length(batches) + 1]] <- chunks[current_rows, , drop = FALSE]
      current_rows <- integer(0)
      current_chars <- 0L
    }

    current_rows <- c(current_rows, i)
    current_chars <- current_chars + content_chars
  }

  if (length(current_rows) > 0) {
    batches[[length(batches) + 1]] <- chunks[current_rows, , drop = FALSE]
  }

  batches
}

#' Insert refiner candidate chunks into a temporary store in safe batches
#'
#' @param store RagnarStore connection
#' @param chunks Data frame of abstract chunks
#' @param progress_callback Optional function(detail_text) for progress updates
#' @param max_batch_items Maximum rows per batch
#' @param max_batch_chars Approximate maximum total characters per batch
#' @return Invisibly TRUE
insert_refiner_chunks_batched <- function(store, chunks,
                                           progress_callback = NULL,
                                           max_batch_items = 8L,
                                           max_batch_chars = 12000L) {
  batches <- split_refiner_embedding_batches(
    chunks,
    max_batch_items = max_batch_items,
    max_batch_chars = max_batch_chars
  )

  total_batches <- length(batches)
  processed_rows <- 0L
  total_rows <- nrow(chunks)
  for (i in seq_along(batches)) {
    batch_rows <- nrow(batches[[i]])
    processed_rows <- processed_rows + batch_rows
    if (!is.null(progress_callback)) {
      progress_callback(sprintf(
        "Embedding abstract batch %d/%d (%d/%d abstracts)...",
        i, total_batches, processed_rows, total_rows
      ))
    }
    insert_chunks_to_ragnar(store, batches[[i]], "batch", "abstract")
  }

  invisible(TRUE)
}

#' Embed refiner candidate abstracts in provider-safe batches
#'
#' @param provider Provider config object
#' @param embed_model Embedding model ID
#' @param candidate_rows Data frame with paper_id, abstract, abstract_hash columns
#' @param progress_callback Optional progress callback
#' @param max_batch_items Maximum rows per provider batch
#' @param max_batch_chars Approximate maximum total characters per batch
#' @return Named list paper_id -> embedding vector
embed_refiner_candidates <- function(provider, embed_model, candidate_rows,
                                      progress_callback = NULL,
                                      max_batch_items = 8L,
                                      max_batch_chars = 12000L) {
  chunks <- data.frame(
    content = candidate_rows$abstract,
    page_number = NA_integer_,
    chunk_index = 0L,
    context = "",
    origin = paste0("abstract:", candidate_rows$paper_id),
    stringsAsFactors = FALSE
  )
  batches <- split_refiner_embedding_batches(
    chunks,
    max_batch_items = max_batch_items,
    max_batch_chars = max_batch_chars
  )

  embeddings <- vector("list", nrow(candidate_rows))
  names(embeddings) <- candidate_rows$paper_id
  total_rows <- nrow(candidate_rows)
  processed_rows <- 0L

  for (i in seq_along(batches)) {
    batch <- batches[[i]]
    batch_ids <- sub("^abstract:", "", batch$origin)
    batch_idx <- match(batch_ids, candidate_rows$paper_id)
    processed_rows <- processed_rows + nrow(batch)

    if (!is.null(progress_callback)) {
      progress_callback(sprintf(
        "Embedding abstract batch %d/%d (%d/%d abstracts)...",
        i, length(batches), processed_rows, total_rows
      ))
    }

    result <- provider_get_embeddings(provider, embed_model, batch$content)
    for (j in seq_along(batch_ids)) {
      embeddings[[batch_ids[j]]] <- result$embeddings[[j]]
    }
  }

  embeddings
}

#' Compute cosine similarity between query embedding and candidate embeddings
#'
#' @param query_embedding Numeric vector
#' @param candidate_embeddings Named list paper_id -> numeric vector
#' @return Named numeric vector
compute_cached_embedding_similarity <- function(query_embedding, candidate_embeddings) {
  query_norm <- sqrt(sum(query_embedding * query_embedding))
  if (is.na(query_norm) || query_norm == 0) {
    return(setNames(rep(NA_real_, length(candidate_embeddings)), names(candidate_embeddings)))
  }

  vapply(candidate_embeddings, function(candidate_embedding) {
    if (is.null(candidate_embedding)) return(NA_real_)
    candidate_norm <- sqrt(sum(candidate_embedding * candidate_embedding))
    if (is.na(candidate_norm) || candidate_norm == 0) return(NA_real_)
    sum(query_embedding * candidate_embedding) / (query_norm * candidate_norm)
  }, numeric(1))
}

#' Compute semantic similarity using cached embeddings
#'
#' For candidates not in any notebook ragnar store (e.g., fetched from
#' OpenAlex), persist abstract embeddings in DuckDB and reuse them across
#' refiner runs. Missing abstracts are embedded in batches; semantic relevance
#' is cosine similarity between the query embedding and cached candidate vectors.
#'
#' @param candidates Data frame with paper_id and abstract columns
#' @param query_text Search query for semantic scoring
#' @param provider Provider config object (from provider_from_config)
#' @param con Optional DuckDB connection for embedding cache reuse
#' @param embed_model Embedding model ID
#' @param progress_callback Optional function(detail_text) for progress updates
#' @return Named numeric vector: paper_id -> similarity score [0, 1]
score_with_temp_ragnar <- function(candidates, query_text, provider, con = NULL,
                                    embed_model = "openai/text-embedding-3-small",
                                    progress_callback = NULL) {
  # Filter to candidates with abstracts
  has_abstract <- !is.na(candidates$abstract) & nchar(candidates$abstract) > 0
  scoreable <- candidates[has_abstract, , drop = FALSE]

  if (nrow(scoreable) == 0) {
    return(setNames(rep(NA_real_, nrow(candidates)), candidates$paper_id))
  }

  scoreable$abstract_hash <- vapply(scoreable$abstract, hash_refiner_abstract, character(1))
  rownames(scoreable) <- scoreable$paper_id

  cached_rows <- if (!is.null(con)) {
    get_refiner_embedding_cache(con, scoreable$paper_id, embed_model,
                                abstract_hashes = setNames(scoreable$abstract_hash, scoreable$paper_id))
  } else {
    data.frame(
      paper_id = character(0),
      embed_model = character(0),
      abstract_hash = character(0),
      embedding = character(0),
      stringsAsFactors = FALSE
    )
  }

  candidate_embeddings <- setNames(vector("list", nrow(scoreable)), scoreable$paper_id)
  if (nrow(cached_rows) > 0) {
    for (i in seq_len(nrow(cached_rows))) {
      candidate_embeddings[[cached_rows$paper_id[i]]] <- deserialize_embedding(cached_rows$embedding[i])
    }
  }

  cached_count <- sum(vapply(candidate_embeddings, Negate(is.null), logical(1)))
  if (!is.null(progress_callback) && cached_count > 0) {
    progress_callback(sprintf(
      "Reusing %d cached embeddings; embedding %d/%d candidate abstracts...",
      cached_count, nrow(scoreable) - cached_count, nrow(scoreable)
    ))
  }

  missing_ids <- names(candidate_embeddings)[vapply(candidate_embeddings, is.null, logical(1))]

  if (length(missing_ids) > 0) {
    missing_rows <- scoreable[missing_ids, , drop = FALSE]
    embedded_missing <- tryCatch(
      embed_refiner_candidates(
        provider, embed_model, missing_rows,
        progress_callback = progress_callback
      ),
      error = function(e) {
        message("[refiner] Candidate embedding failed: ", e$message)
        NULL
      }
    )

    if (is.null(embedded_missing)) {
      message("[refiner] Falling back to keyword overlap scoring")
      if (!is.null(progress_callback)) progress_callback("Using keyword matching fallback...")
      scores <- score_keyword_overlap(scoreable, query_text)
      all_scores <- setNames(rep(NA_real_, nrow(candidates)), candidates$paper_id)
      all_scores[names(scores)] <- scores
      return(all_scores)
    }

    for (paper_id in names(embedded_missing)) {
      candidate_embeddings[[paper_id]] <- embedded_missing[[paper_id]]
    }

    if (!is.null(con)) {
      cache_df <- data.frame(
        paper_id = names(embedded_missing),
        embed_model = embed_model,
        abstract_hash = unname(scoreable[names(embedded_missing), "abstract_hash"]),
        embedding = vapply(embedded_missing, serialize_embedding, character(1)),
        stringsAsFactors = FALSE
      )
      save_refiner_embedding_cache(con, cache_df)
    }
  }

  query_embedding <- tryCatch(
    provider_get_embeddings(provider, embed_model, query_text)$embeddings[[1]],
    error = function(e) {
      message("[refiner] Query embedding failed: ", e$message)
      NULL
    }
  )

  if (is.null(query_embedding)) {
    if (!is.null(progress_callback)) progress_callback("Using keyword matching fallback...")
    scores <- score_keyword_overlap(scoreable, query_text)
    all_scores <- setNames(rep(NA_real_, nrow(candidates)), candidates$paper_id)
    all_scores[names(scores)] <- scores
    return(all_scores)
  }

  scores <- compute_cached_embedding_similarity(query_embedding, candidate_embeddings)
  all_scores <- setNames(rep(NA_real_, nrow(candidates)), candidates$paper_id)
  all_scores[names(scores)] <- scores
  all_scores
}
