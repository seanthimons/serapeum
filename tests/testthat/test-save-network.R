library(testthat)

# Source required files from project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "config.R"))) {
  project_root <- getwd()
}
source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "db_migrations.R"))
source(file.path(project_root, "R", "db.R"))

# Helper to set up citation network tables
setup_network_tables <- function(con) {
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS citation_networks (
    id VARCHAR PRIMARY KEY, name VARCHAR NOT NULL, seed_paper_id VARCHAR NOT NULL,
    seed_paper_title VARCHAR NOT NULL, direction VARCHAR NOT NULL, depth INTEGER NOT NULL,
    node_limit INTEGER NOT NULL, palette VARCHAR DEFAULT 'viridis',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    seed_paper_ids VARCHAR, source_notebook_id VARCHAR
  )")
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS network_nodes (
    network_id VARCHAR NOT NULL, paper_id VARCHAR NOT NULL,
    is_seed BOOLEAN DEFAULT FALSE, title VARCHAR NOT NULL, authors VARCHAR,
    year INTEGER, venue VARCHAR, doi VARCHAR, cited_by_count INTEGER DEFAULT 0,
    x_position DOUBLE, y_position DOUBLE,
    is_overlap BOOLEAN DEFAULT FALSE, community VARCHAR,
    PRIMARY KEY (network_id, paper_id),
    FOREIGN KEY (network_id) REFERENCES citation_networks(id)
  )")
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS network_edges (
    network_id VARCHAR NOT NULL, from_paper_id VARCHAR NOT NULL,
    to_paper_id VARCHAR NOT NULL,
    PRIMARY KEY (network_id, from_paper_id, to_paper_id),
    FOREIGN KEY (network_id) REFERENCES citation_networks(id)
  )")
}

test_that("save_network succeeds with NULL source_notebook_id and missing columns", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  setup_network_tables(con)

  # Nodes WITHOUT is_overlap and community columns (single-seed network scenario)
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
    stringsAsFactors = FALSE
  )

  edges <- data.frame(
    from_paper_id = "W1",
    to_paper_id = "W2",
    stringsAsFactors = FALSE
  )

  # NULL source_notebook_id + missing is_overlap/community — the bug scenario
  id <- save_network(
    con, name = "Standalone Network", seed_paper_id = "W1",
    seed_paper_title = "Seed Paper", direction = "forward",
    depth = 1, node_limit = 50, palette = "default",
    nodes_df = nodes, edges_df = edges,
    seed_paper_ids = c("W1"), source_notebook_id = NULL
  )

  expect_type(id, "character")

  saved <- DBI::dbGetQuery(con, "SELECT * FROM network_nodes WHERE network_id = ?", list(id))
  expect_equal(nrow(saved), 2)
  expect_true(all(!saved$is_overlap))
  expect_true(all(is.na(saved$community)))

  meta <- DBI::dbGetQuery(con, "SELECT * FROM citation_networks WHERE id = ?", list(id))
  expect_true(is.na(meta$source_notebook_id))
})

test_that("save_network succeeds with all columns present", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  setup_network_tables(con)

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
    is_overlap = c(FALSE, TRUE),
    community = c("1", "2"),
    stringsAsFactors = FALSE
  )

  edges <- data.frame(
    from_paper_id = "W1",
    to_paper_id = "W2",
    stringsAsFactors = FALSE
  )

  id <- save_network(
    con, name = "Full Network", seed_paper_id = "W1",
    seed_paper_title = "Seed Paper", direction = "forward",
    depth = 1, node_limit = 50, palette = "default",
    nodes_df = nodes, edges_df = edges,
    seed_paper_ids = c("W1"), source_notebook_id = "nb-1"
  )

  expect_type(id, "character")

  saved <- DBI::dbGetQuery(con, "SELECT * FROM network_nodes WHERE network_id = ?", list(id))
  expect_equal(nrow(saved), 2)
  expect_equal(saved$community, c("1", "2"))
})
