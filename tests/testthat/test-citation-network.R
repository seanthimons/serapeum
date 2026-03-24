library(testthat)


source_app("citation_network.R")

# ============================================================================
# compute_node_sizes tests
# ============================================================================

test_that("compute_node_sizes handles empty input", {
  expect_equal(compute_node_sizes(numeric(0)), numeric(0))
})

test_that("compute_node_sizes handles single value", {
  expect_equal(compute_node_sizes(100), 30)
})

test_that("compute_node_sizes handles uniform values", {
  result <- compute_node_sizes(c(50, 50, 50))
  expect_true(all(result == 30))
})

test_that("compute_node_sizes returns range 10-100", {
  result <- compute_node_sizes(c(1, 100, 1000, 10000))
  expect_true(min(result) >= 10)
  expect_true(max(result) <= 100)
})

test_that("compute_node_sizes handles NA values", {
  result <- compute_node_sizes(c(100, NA, 1000))
  expect_equal(length(result), 3)
  expect_false(any(is.na(result)))
})

test_that("compute_node_sizes handles zeros", {
  result <- compute_node_sizes(c(0, 0, 100))
  expect_equal(length(result), 3)
  expect_true(all(result >= 10))
})

# ============================================================================
# get_sizing_metric tests
# ============================================================================

test_that("get_sizing_metric returns citations by default", {
  df <- data.frame(
    cited_by_count = c(100, 200, 300),
    year = c(2020, 2021, 2022),
    fwci = c(1.5, 2.0, NA)
  )
  result <- get_sizing_metric(df, "citations")
  expect_equal(result, c(100, 200, 300))
})

test_that("get_sizing_metric age_weighted divides by age", {
  current_year <- as.integer(format(Sys.Date(), "%Y"))
  df <- data.frame(
    cited_by_count = c(100, 100),
    year = c(current_year, current_year - 9),
    fwci = c(NA, NA)
  )
  result <- get_sizing_metric(df, "age_weighted")
  # Paper from this year: 100 / 1 = 100
  # Paper from 10 years ago: 100 / 10 = 10
  expect_equal(result[1], 100)
  expect_equal(result[2], 10)
})

test_that("get_sizing_metric age_weighted handles NA years", {
  df <- data.frame(
    cited_by_count = c(100, 200),
    year = c(NA, 2020),
    fwci = c(NA, NA)
  )
  result <- get_sizing_metric(df, "age_weighted")
  # NA year -> age = 1 -> cited_by_count / 1
  expect_equal(result[1], 100)
})

test_that("get_sizing_metric fwci replaces NA with 0", {
  df <- data.frame(
    cited_by_count = c(100, 200),
    year = c(2020, 2021),
    fwci = c(1.5, NA)
  )
  result <- get_sizing_metric(df, "fwci")
  expect_equal(result[1], 1.5)
  expect_equal(result[2], 0)
})

test_that("get_sizing_metric fwci works when column is missing", {
  df <- data.frame(
    cited_by_count = c(100, 200),
    year = c(2020, 2021)
  )
  result <- get_sizing_metric(df, "fwci")
  expect_true(all(result == 0))
})

test_that("get_sizing_metric connectivity falls back to cited_by_count", {
  df <- data.frame(
    cited_by_count = c(100, 200),
    year = c(2020, 2021),
    fwci = c(NA, NA)
  )
  result <- get_sizing_metric(df, "connectivity")
  expect_equal(result, c(100, 200))
})

test_that("get_sizing_metric connectivity uses column when present", {
  df <- data.frame(
    cited_by_count = c(100, 200),
    year = c(2020, 2021),
    fwci = c(NA, NA),
    connectivity = c(5, 10)
  )
  result <- get_sizing_metric(df, "connectivity")
  expect_equal(result, c(5, 10))
})

# ============================================================================
# enrich_ranked_with_metadata FWCI tests (sourced from citation_audit.R)
# ============================================================================

source_app("config.R")
source_app("utils_doi.R")
source_app("api_openalex.R")
source_app("interrupt.R")
source_app("citation_audit.R")

test_that("enrich_ranked_with_metadata includes fwci column", {
  ranked <- data.frame(
    work_id = c("W1", "W2"),
    backward_count = c(3, 2),
    forward_count = c(1, 1),
    collection_frequency = c(4, 3),
    stringsAsFactors = FALSE
  )
  metadata <- list(
    list(paper_id = "W1", title = "Paper 1", authors = list("Auth A"),
         year = 2020, doi = "10.1/a", cited_by_count = 50, fwci = 1.5),
    list(paper_id = "W2", title = "Paper 2", authors = list("Auth B"),
         year = 2021, doi = "10.1/b", cited_by_count = 30, fwci = NULL)
  )

  result <- enrich_ranked_with_metadata(ranked, metadata)

  expect_true("fwci" %in% names(result))
  expect_equal(result$fwci[1], 1.5)
  expect_true(is.na(result$fwci[2]))
})


# ============================================================================
# save_network / load_network round-trip (regression: community column)
# ============================================================================

source_app("db.R", "db_migrations.R")

test_that("save_network succeeds with community column after migrations", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  # Set up citation network tables with community column (migration 006 + 010 + 020)
  DBI::dbExecute(con, "CREATE TABLE citation_networks (
    id VARCHAR PRIMARY KEY, name VARCHAR NOT NULL, seed_paper_id VARCHAR NOT NULL,
    seed_paper_title VARCHAR NOT NULL, direction VARCHAR NOT NULL, depth INTEGER NOT NULL,
    node_limit INTEGER NOT NULL, palette VARCHAR DEFAULT 'viridis',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    seed_paper_ids VARCHAR, source_notebook_id VARCHAR
  )")
  DBI::dbExecute(con, "CREATE TABLE network_nodes (
    network_id VARCHAR NOT NULL, paper_id VARCHAR NOT NULL,
    is_seed BOOLEAN DEFAULT FALSE, title VARCHAR NOT NULL, authors VARCHAR,
    year INTEGER, venue VARCHAR, doi VARCHAR, cited_by_count INTEGER DEFAULT 0,
    x_position DOUBLE, y_position DOUBLE,
    is_overlap BOOLEAN DEFAULT FALSE, community VARCHAR,
    PRIMARY KEY (network_id, paper_id),
    FOREIGN KEY (network_id) REFERENCES citation_networks(id)
  )")
  DBI::dbExecute(con, "CREATE TABLE network_edges (
    network_id VARCHAR NOT NULL, from_paper_id VARCHAR NOT NULL,
    to_paper_id VARCHAR NOT NULL,
    PRIMARY KEY (network_id, from_paper_id, to_paper_id),
    FOREIGN KEY (network_id) REFERENCES citation_networks(id)
  )")

  nodes <- data.frame(
    paper_id = c("W1", "W2"),
    is_seed = c(TRUE, FALSE),
    paper_title = c("Seed Paper", "Cited Paper"),
    authors = c("Auth A", "Auth B"),
    year = c(2020L, 2021L),
    venue = c("Journal A", "Journal B"),
    doi = c("10.1/a", "10.1/b"),
    cited_by_count = c(100L, 50L),
    x = c(0.0, 1.0),
    y = c(0.0, 1.0),
    is_overlap = c(FALSE, FALSE),
    community = c("1", "2"),
    stringsAsFactors = FALSE
  )

  edges <- data.frame(
    from_paper_id = "W1",
    to_paper_id = "W2",
    stringsAsFactors = FALSE
  )

  id <- save_network(
    con, name = "Test Network", seed_paper_id = "W1",
    seed_paper_title = "Seed Paper", direction = "forward",
    depth = 1, node_limit = 50, palette = "default",
    nodes_df = nodes, edges_df = edges,
    seed_paper_ids = c("W1"), source_notebook_id = "nb-1"
  )

  expect_type(id, "character")

  saved_nodes <- DBI::dbGetQuery(con, "SELECT * FROM network_nodes WHERE network_id = ?", list(id))
  expect_equal(nrow(saved_nodes), 2)
  expect_true("community" %in% names(saved_nodes))
  expect_equal(saved_nodes$community, c("1", "2"))
})

test_that("enrich_ranked_with_metadata adds fwci for empty metadata", {
  ranked <- data.frame(
    work_id = "W1",
    backward_count = 3,
    forward_count = 1,
    collection_frequency = 4,
    stringsAsFactors = FALSE
  )
  result <- enrich_ranked_with_metadata(ranked, list())

  expect_true("fwci" %in% names(result))
  expect_true(is.na(result$fwci[1]))
})
