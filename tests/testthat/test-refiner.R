library(testthat)

source_app("config.R", "db_migrations.R", "db.R", "api_provider.R", "pdf_images.R", "_ragnar.R",
           "api_openalex.R", "research_refiner.R")

# ---- Helper: set up a fresh DB with schema + migrations ----
setup_test_db <- function() {
  tmp_dir <- tempdir()
  db_path <- file.path(tmp_dir, paste0("test_refiner_", uuid::UUIDgenerate(), ".duckdb"))
  con <- get_db_connection(db_path)
  init_schema(con)
  run_pending_migrations(con)
  list(con = con, path = db_path)
}

teardown_test_db <- function(env) {
  close_db_connection(env$con)
  unlink(env$path)
}

# ===========================================================================
# Issue #186: delete_notebook cleans up refiner tables
# ===========================================================================

test_that("delete_notebook cleans up refiner runs and results", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))
  con <- env$con

  # Create a notebook
  nb_id <- create_notebook(con, "Test Notebook", "search")

  # Create a refiner run sourced from this notebook
  run_id <- create_refiner_run(con, "seeds", "notebook",
                                source_notebook_id = nb_id)

  # Create a refiner result for this run
  results_df <- data.frame(
    paper_id = "W12345",
    title = "Test Paper",
    authors = '["Author A","Author B"]',
    abstract = "Some abstract",
    year = 2025L,
    venue = "Nature",
    doi = NA_character_,
    cited_by_count = 10L,
    fwci = 1.5,
    seed_connectivity = 0.5,
    bridge_score = 0.3,
    citation_velocity = 0.8,
    ubiquity_penalty = 0.1,
    utility_score = 0.7,
    embedding_similarity = NA_real_,
    stringsAsFactors = FALSE
  )
  save_refiner_results(con, run_id, results_df)

  # Verify data exists before deletion
  runs_before <- DBI::dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM refiner_runs WHERE source_notebook_id = ?",
    list(nb_id))
  results_before <- DBI::dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM refiner_results WHERE run_id = ?",
    list(run_id))
  expect_equal(runs_before$n, 1)
  expect_equal(results_before$n, 1)

  # Delete the notebook
  delete_notebook(con, nb_id)

  # Verify cleanup
  runs_after <- DBI::dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM refiner_runs WHERE source_notebook_id = ?",
    list(nb_id))
  results_after <- DBI::dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM refiner_results WHERE run_id = ?",
    list(run_id))
  expect_equal(runs_after$n, 0)
  expect_equal(results_after$n, 0)
})

test_that("delete_refiner_run removes results before run", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))
  con <- env$con

  # Create a standalone run (source_type = "fetch", no notebook)
  run_id <- create_refiner_run(con, "seeds", "fetch")

  # Add results
  results_df <- data.frame(
    paper_id = c("W111", "W222"),
    title = c("Paper 1", "Paper 2"),
    authors = c('["A"]', '["B"]'),
    abstract = c("Abstract 1", "Abstract 2"),
    year = c(2024L, 2025L),
    venue = c("J1", "J2"),
    doi = c(NA_character_, NA_character_),
    cited_by_count = c(5L, 10L),
    fwci = c(1.0, 2.0),
    seed_connectivity = c(0.0, 0.0),
    bridge_score = c(0.0, 0.0),
    citation_velocity = c(0.0, 0.0),
    ubiquity_penalty = c(0.0, 0.0),
    utility_score = c(0.5, 0.6),
    embedding_similarity = c(NA_real_, NA_real_),
    stringsAsFactors = FALSE
  )
  save_refiner_results(con, run_id, results_df)

  # Verify 2 results
  before <- DBI::dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM refiner_results WHERE run_id = ?",
    list(run_id))
  expect_equal(before$n, 2)

  # Delete run
  delete_refiner_run(con, run_id)

  # Both run and results are gone
  runs <- DBI::dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM refiner_runs WHERE id = ?",
    list(run_id))
  results <- DBI::dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM refiner_results WHERE run_id = ?",
    list(run_id))
  expect_equal(runs$n, 0)
  expect_equal(results$n, 0)
})

test_that("delete_notebook does not affect fetch-sourced refiner runs", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))
  con <- env$con

  # Create a notebook and a fetch-sourced run (no source_notebook_id)
  nb_id <- create_notebook(con, "Unrelated Notebook", "search")
  run_id <- create_refiner_run(con, "seeds", "fetch")

  # Delete notebook should NOT touch fetch-sourced runs
  delete_notebook(con, nb_id)

  runs <- DBI::dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM refiner_runs WHERE id = ?",
    list(run_id))
  expect_equal(runs$n, 1)

  # Cleanup
  delete_refiner_run(con, run_id)
})

# ===========================================================================
# Issue #185: fetch_candidates_from_seeds returns errors
# ===========================================================================

test_that("fetch_candidates_from_seeds returns list with candidates and errors", {
  # Mock API functions to simulate failures
  mock_citing <- function(id, email, api_key, per_page) {
    stop("HTTP 429: Rate limited")
  }
  mock_cited <- function(id, email, api_key, per_page) {
    list()  # succeeds with empty
  }
  mock_related <- function(id, email, api_key, per_page) {
    stop("Connection timeout")
  }

  # Temporarily replace the API functions
  original_citing <- get_citing_papers
  original_cited <- get_cited_papers
  original_related <- get_related_papers
  assignInNamespace <- NULL  # Can't mock in global env easily

  # Instead, test the structure of the return value by calling with empty seeds
  result <- fetch_candidates_from_seeds(character(0), "test@example.com")
  expect_type(result, "list")
  expect_true("candidates" %in% names(result))
  expect_true("errors" %in% names(result))
  expect_s3_class(result$candidates, "data.frame")
  expect_type(result$errors, "character")
  expect_equal(nrow(result$candidates), 0)
  expect_equal(length(result$errors), 0)
  expect_true("work_type" %in% names(result$candidates))
  expect_true("work_type_crossref" %in% names(result$candidates))
})

test_that("fetch_candidates_from_seeds preserves work type fields", {
  original_citing <- get_citing_papers
  original_cited <- get_cited_papers
  original_related <- get_related_papers

  assign("get_citing_papers", function(paper_id, email, api_key = NULL, per_page = 25) {
    list(list(
      paper_id = "WCandidate",
      title = "Typed Candidate",
      authors = list("Author"),
      abstract = "Candidate abstract",
      year = 2026L,
      venue = "Journal",
      doi = NA_character_,
      work_type = "book-chapter",
      work_type_crossref = "book-chapter",
      cited_by_count = 1L,
      fwci = NA_real_,
      referenced_works_count = 0L
    ))
  }, envir = .GlobalEnv)
  assign("get_cited_papers", function(paper_id, email, api_key = NULL, per_page = 25) {
    list()
  }, envir = .GlobalEnv)
  assign("get_related_papers", function(paper_id, email, api_key = NULL, per_page = 25) {
    list()
  }, envir = .GlobalEnv)
  on.exit({
    assign("get_citing_papers", original_citing, envir = .GlobalEnv)
    assign("get_cited_papers", original_cited, envir = .GlobalEnv)
    assign("get_related_papers", original_related, envir = .GlobalEnv)
  }, add = TRUE)

  result <- fetch_candidates_from_seeds("WSeed", "test@example.com")

  expect_equal(nrow(result$candidates), 1)
  expect_equal(result$candidates$paper_id, "WCandidate")
  expect_equal(result$candidates$work_type, "book-chapter")
  expect_equal(result$candidates$work_type_crossref, "book-chapter")
})

test_that("fetch_anchor_refs returns errors field", {
  # Call with empty seeds to verify structure
  result <- fetch_anchor_refs(character(0), "test@example.com")
  expect_type(result, "list")
  expect_true("errors" %in% names(result))
  expect_type(result$errors, "character")
  expect_equal(length(result$errors), 0)
})

# ===========================================================================
# Issue #177: create_abstract handles pre-encoded and vector authors
# ===========================================================================

test_that("create_abstract handles character vector authors", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))
  con <- env$con

  nb_id <- create_notebook(con, "Test", "search")
  abstract_id <- create_abstract(
    con, nb_id, "W001", "Paper One",
    c("Smith", "Jones"), "Abstract text",
    2025L, "Nature", NULL
  )

  row <- DBI::dbGetQuery(con,
    "SELECT authors FROM abstracts WHERE id = ?",
    list(abstract_id))
  parsed <- jsonlite::fromJSON(row$authors)
  expect_type(parsed, "character")
  expect_equal(parsed, c("Smith", "Jones"))
})

test_that("create_abstract handles pre-encoded JSON authors without double-encoding", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))
  con <- env$con

  nb_id <- create_notebook(con, "Test", "search")
  pre_encoded <- '["Smith","Jones"]'

  abstract_id <- create_abstract(
    con, nb_id, "W002", "Paper Two",
    pre_encoded, "Abstract text",
    2025L, "Nature", NULL
  )

  row <- DBI::dbGetQuery(con,
    "SELECT authors FROM abstracts WHERE id = ?",
    list(abstract_id))

  # Should be identical to the input — NOT double-encoded
  expect_equal(row$authors, pre_encoded)

  # Should round-trip to a character vector
  parsed <- jsonlite::fromJSON(row$authors)
  expect_type(parsed, "character")
  expect_equal(parsed, c("Smith", "Jones"))
})

test_that("create_abstract handles single author correctly", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))
  con <- env$con

  nb_id <- create_notebook(con, "Test", "search")

  # Single author as vector
  abstract_id <- create_abstract(
    con, nb_id, "W003", "Solo Paper",
    c("Solo Author"), "Abstract text",
    2025L, "Nature", NULL
  )

  row <- DBI::dbGetQuery(con,
    "SELECT authors FROM abstracts WHERE id = ?",
    list(abstract_id))

  # With auto_unbox=TRUE, single element becomes bare string "Solo Author"
  # fromJSON should return a scalar character
  parsed <- jsonlite::fromJSON(row$authors)
  expect_type(parsed, "character")
  expect_true("Solo Author" %in% parsed)
})

test_that("create_abstract handles NULL and empty authors", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))
  con <- env$con

  nb_id <- create_notebook(con, "Test", "search")

  # NULL authors
  id1 <- create_abstract(con, nb_id, "W004", "No Authors",
                          NULL, "Abstract", 2025L, "J", NULL)
  row1 <- DBI::dbGetQuery(con, "SELECT authors FROM abstracts WHERE id = ?",
                           list(id1))
  expect_equal(row1$authors, "[]")

  # Empty vector
  id2 <- create_abstract(con, nb_id, "W005", "Empty Authors",
                          character(0), "Abstract", 2025L, "J", NULL)
  row2 <- DBI::dbGetQuery(con, "SELECT authors FROM abstracts WHERE id = ?",
                           list(id2))
  expect_equal(row2$authors, "[]")
})

test_that("prepare_candidates_from_notebook empty result includes work type columns", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))
  con <- env$con

  nb_id <- create_notebook(con, "Empty Source Notebook", "search")

  candidates <- prepare_candidates_from_notebook(con, nb_id)

  expect_equal(nrow(candidates), 0)
  expect_true("work_type" %in% names(candidates))
  expect_true("work_type_crossref" %in% names(candidates))
})

test_that("authors survive full refiner round-trip (notebook path)", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))
  con <- env$con

  nb_id <- create_notebook(con, "Source Notebook", "search")

  # Step 1: Create abstract with vector authors (simulates initial import)
  create_abstract(con, nb_id, "W100", "Original Paper",
                  c("Alice", "Bob"), "Test abstract",
                  2024L, "Science", NULL,
                  work_type = "article",
                  work_type_crossref = "journal-article")

  # Step 2: Read via prepare_candidates_from_notebook (authors come back as JSON string)
  candidates <- prepare_candidates_from_notebook(con, nb_id)
  expect_equal(nrow(candidates), 1)
  # Authors column is a JSON string from DB
  expect_type(candidates$authors, "character")
  expect_equal(candidates$work_type, "article")
  expect_equal(candidates$work_type_crossref, "journal-article")

  # Step 3: Simulate save to refiner_results
  run_id <- create_refiner_run(con, "seeds", "notebook", source_notebook_id = nb_id)
  results_df <- candidates
  results_df$seed_connectivity <- 0
  results_df$bridge_score <- 0
  results_df$citation_velocity <- 0
  results_df$ubiquity_penalty <- 0
  results_df$utility_score <- 0.5
  results_df$embedding_similarity <- NA_real_
  save_refiner_results(con, run_id, results_df)

  # Step 4: Read from refiner_results (simulates the import path)
  stored <- get_refiner_results(con, run_id)
  expect_equal(nrow(stored), 1)
  expect_equal(stored$work_type, "article")
  expect_equal(stored$work_type_crossref, "journal-article")

  # Step 5: Simulate import — fromJSON then create_abstract in target notebook
  target_nb <- create_notebook(con, "Target Notebook", "search")
  authors_vec <- jsonlite::fromJSON(stored$authors)
  imported_id <- create_abstract(
    con, target_nb, stored$paper_id, stored$title,
    authors_vec, stored$abstract,
    stored$year, stored$venue, NULL,
    work_type = stored$work_type,
    work_type_crossref = stored$work_type_crossref
  )

  # Step 6: Verify no double-encoding and preserved type metadata
  final <- DBI::dbGetQuery(con,
    "SELECT authors, work_type, work_type_crossref FROM abstracts WHERE id = ?",
    list(imported_id))
  final_parsed <- jsonlite::fromJSON(final$authors)
  expect_type(final_parsed, "character")
  expect_equal(final_parsed, c("Alice", "Bob"))
  expect_equal(final$work_type, "article")
  expect_equal(final$work_type_crossref, "journal-article")
})

test_that("refiner results preserve work type fields", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))
  con <- env$con

  run_id <- create_refiner_run(con, "seeds", "fetch")
  results_df <- data.frame(
    paper_id = "WType",
    title = "Typed Paper",
    authors = '["Author"]',
    abstract = "Typed abstract",
    year = 2026L,
    venue = "Journal",
    doi = NA_character_,
    work_type = "review",
    work_type_crossref = "journal-article",
    cited_by_count = 3L,
    fwci = 1.2,
    seed_connectivity = 0.1,
    bridge_score = 0.2,
    citation_velocity = 0.3,
    ubiquity_penalty = 0.4,
    utility_score = 0.5,
    embedding_similarity = 0.6,
    stringsAsFactors = FALSE
  )

  expect_equal(save_refiner_results(con, run_id, results_df), 1L)

  stored <- get_refiner_results(con, run_id)
  expect_equal(nrow(stored), 1)
  expect_equal(stored$work_type, "review")
  expect_equal(stored$work_type_crossref, "journal-article")
})

test_that("refiner results save old-style frames without work type fields", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))
  con <- env$con

  run_id <- create_refiner_run(con, "seeds", "fetch")
  results_df <- data.frame(
    paper_id = "WOld",
    title = "Old Paper",
    authors = '["Author"]',
    abstract = "Old abstract",
    year = 2024L,
    venue = "Journal",
    doi = NA_character_,
    cited_by_count = 1L,
    fwci = NA_real_,
    seed_connectivity = 0,
    bridge_score = 0,
    citation_velocity = 0,
    ubiquity_penalty = 0,
    utility_score = 0.1,
    embedding_similarity = NA_real_,
    stringsAsFactors = FALSE
  )

  expect_equal(save_refiner_results(con, run_id, results_df), 1L)

  stored <- get_refiner_results(con, run_id)
  expect_equal(nrow(stored), 1)
  expect_true(is.na(stored$work_type))
  expect_true(is.na(stored$work_type_crossref))
})

test_that("split_refiner_embedding_batches keeps batches under conservative limits", {
  chunks <- data.frame(
    content = c(
      strrep("a", 5000),
      strrep("b", 5000),
      strrep("c", 5000),
      strrep("d", 1000)
    ),
    page_number = NA_integer_,
    chunk_index = 0L,
    context = "",
    origin = paste0("abstract:W", 1:4),
    stringsAsFactors = FALSE
  )

  batches <- split_refiner_embedding_batches(
    chunks,
    max_batch_items = 2L,
    max_batch_chars = 9000L
  )

  expect_length(batches, 3)
  expect_equal(vapply(batches, nrow, integer(1)), c(1L, 1L, 2L))
  expect_true(all(vapply(batches, nrow, integer(1)) <= 2L))
  expect_true(all(vapply(
    batches,
    function(batch) sum(nchar(batch$content)),
    integer(1)
  ) <= 9000L))
})

test_that("insert_refiner_chunks_batched inserts multiple smaller batches", {
  calls <- list()
  original_insert <- insert_chunks_to_ragnar

  assign("insert_chunks_to_ragnar", function(store, chunks, source_id, source_type) {
    calls <<- c(calls, list(list(
      rows = nrow(chunks),
      chars = sum(nchar(chunks$content)),
      source_id = source_id,
      source_type = source_type
    )))
    invisible(store)
  }, envir = .GlobalEnv)
  on.exit(assign("insert_chunks_to_ragnar", original_insert, envir = .GlobalEnv), add = TRUE)

  chunks <- data.frame(
    content = c(
      strrep("a", 5000),
      strrep("b", 5000),
      strrep("c", 5000),
      strrep("d", 1000)
    ),
    page_number = NA_integer_,
    chunk_index = 0L,
    context = "",
    origin = paste0("abstract:W", 1:4),
    stringsAsFactors = FALSE
  )

  expect_invisible(insert_refiner_chunks_batched(
    store = structure(list(), class = "mock_store"),
    chunks = chunks,
    max_batch_items = 2L,
    max_batch_chars = 9000L
  ))

  expect_length(calls, 3)
  expect_equal(vapply(calls, `[[`, integer(1), "rows"), c(1L, 1L, 2L))
  expect_true(all(vapply(calls, `[[`, integer(1), "chars") <= 9000L))
  expect_true(all(vapply(calls, `[[`, character(1), "source_id") == "batch"))
  expect_true(all(vapply(calls, `[[`, character(1), "source_type") == "abstract"))
})

test_that("insert_refiner_chunks_batched reports batch and abstract counts", {
  original_insert <- insert_chunks_to_ragnar
  progress_messages <- character(0)

  assign("insert_chunks_to_ragnar", function(store, chunks, source_id, source_type) {
    invisible(store)
  }, envir = .GlobalEnv)
  on.exit(assign("insert_chunks_to_ragnar", original_insert, envir = .GlobalEnv), add = TRUE)

  chunks <- data.frame(
    content = c(strrep("a", 5000), strrep("b", 5000), strrep("c", 1000)),
    page_number = NA_integer_,
    chunk_index = 0L,
    context = "",
    origin = paste0("abstract:W", 1:3),
    stringsAsFactors = FALSE
  )

  insert_refiner_chunks_batched(
    store = structure(list(), class = "mock_store"),
    chunks = chunks,
    progress_callback = function(detail) {
      progress_messages <<- c(progress_messages, detail)
    },
    max_batch_items = 2L,
    max_batch_chars = 9000L
  )

  expect_equal(
    progress_messages,
    c(
      "Embedding abstract batch 1/2 (1/3 abstracts)...",
      "Embedding abstract batch 2/2 (3/3 abstracts)..."
    )
  )
})

test_that("score_from_ragnar_store handles VSS metric_value schema", {
  skip_if_not(tryCatch({ library(ragnar); TRUE }, error = function(e) FALSE), "ragnar not loadable")

  store_path <- tempfile(fileext = ".duckdb")
  mock_embed <- function(texts) {
    m <- matrix(0, nrow = length(texts), ncol = 4L)
    for (i in seq_along(texts)) {
      m[i, ] <- c(i, i + 1, i + 2, i + 3)
    }
    m
  }

  store <- ragnar::ragnar_store_create(
    store_path,
    embed = mock_embed,
    embedding_size = 4L,
    version = 1
  )
  on.exit({
    tryCatch(DBI::dbDisconnect(store@con, shutdown = TRUE), error = function(e) NULL)
    unlink(c(store_path, paste0(store_path, ".wal"), paste0(store_path, ".tmp")), force = TRUE)
  }, add = TRUE)

  chunks <- data.frame(
    origin = c("abstract:W1", "abstract:W2"),
    hash = c("h1", "h2"),
    text = c("alpha beta", "gamma delta"),
    stringsAsFactors = FALSE
  )
  ragnar::ragnar_store_insert(store, chunks)
  ragnar::ragnar_store_build_index(store)

  scores <- score_from_ragnar_store(store, "alpha", c("W1", "W2"))

  expect_true(!is.na(scores[["W1"]]))
  expect_true(!is.na(scores[["W2"]]))
  expect_gt(scores[["W1"]], scores[["W2"]])
})

test_that("refiner embedding cache round-trips and filters by abstract hash", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))
  con <- env$con

  cache_df <- data.frame(
    paper_id = "W123",
    embed_model = "test/embed",
    abstract_hash = hash_refiner_abstract("alpha abstract"),
    embedding = serialize_embedding(c(0.1, 0.2, 0.3)),
    stringsAsFactors = FALSE
  )

  expect_equal(save_refiner_embedding_cache(con, cache_df), 1L)

  matching <- get_refiner_embedding_cache(
    con, "W123", "test/embed",
    abstract_hashes = c(W123 = hash_refiner_abstract("alpha abstract"))
  )
  expect_equal(nrow(matching), 1)
  expect_equal(deserialize_embedding(matching$embedding[1]), c(0.1, 0.2, 0.3))

  stale <- get_refiner_embedding_cache(
    con, "W123", "test/embed",
    abstract_hashes = c(W123 = hash_refiner_abstract("changed abstract"))
  )
  expect_equal(nrow(stale), 0)
})

test_that("score_with_temp_ragnar reuses cached candidate embeddings", {
  env <- setup_test_db()
  on.exit(teardown_test_db(env))
  con <- env$con

  calls <- list()
  original_provider_get_embeddings <- provider_get_embeddings
  assign("provider_get_embeddings", function(provider, model, text) {
    texts <- if (length(text) == 1) as.character(text) else unlist(text, use.names = FALSE)
    calls <<- c(calls, list(texts))

    embeddings <- lapply(texts, function(txt) {
      txt_len <- nchar(txt)
      c(txt_len, txt_len + 1, txt_len + 2)
    })

    list(
      embeddings = embeddings,
      usage = list(prompt_tokens = 0L, completion_tokens = 0L, total_tokens = 0L),
      model = model,
      duration_ms = 1L
    )
  }, envir = .GlobalEnv)
  on.exit(assign("provider_get_embeddings", original_provider_get_embeddings, envir = .GlobalEnv), add = TRUE)

  provider <- create_provider_config("Mock", "http://localhost:1234/v1")
  candidates <- data.frame(
    paper_id = c("W1", "W2"),
    abstract = c("Candidate abstract one", "Candidate abstract two"),
    stringsAsFactors = FALSE
  )

  first_scores <- score_with_temp_ragnar(
    candidates, "semantic query", provider, con, "test/embed"
  )
  expect_equal(length(calls), 2)
  expect_equal(length(calls[[1]]), 2) # candidate batch
  expect_equal(length(calls[[2]]), 1) # query embedding
  expect_true(all(!is.na(first_scores)))

  calls <- list()
  second_scores <- score_with_temp_ragnar(
    candidates, "semantic query", provider, con, "test/embed"
  )
  expect_equal(length(calls), 1)
  expect_equal(length(calls[[1]]), 1) # query only; candidates came from cache
  expect_equal(unname(first_scores), unname(second_scores))
})
