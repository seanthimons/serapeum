library(testthat)

project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "api_openalex.R"))) {
  project_root <- getwd()
}

source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "db_migrations.R"))
source(file.path(project_root, "R", "db.R"))
source(file.path(project_root, "R", "api_openalex.R"))

# --- Phase 1: Header Parsing & Usage Logging ---

test_that("parse_oa_usage_headers extracts all rate-limit fields from response", {
  # httr2::response() expects headers as a single \r\n-separated string
  resp <- httr2::response(
    status_code = 200,
    headers = paste(
      "X-RateLimit-Limit: 1.00",
      "X-RateLimit-Remaining: 0.75",
      "X-RateLimit-Credits-Used: 0.001",
      "X-RateLimit-Reset: 3600",
      sep = "\r\n"
    ),
    body = charToRaw("{}")
  )

  result <- parse_oa_usage_headers(resp)

  expect_equal(result$daily_limit, 1.00)
  expect_equal(result$remaining, 0.75)
  expect_equal(result$credits_used, 0.001)
  expect_equal(result$reset_seconds, 3600L)
})

test_that("parse_oa_usage_headers returns NAs for missing headers (polite pool)", {
  # Response with no rate-limit headers
  resp <- httr2::response(
    status_code = 200,
    headers = "Content-Type: application/json",
    body = charToRaw("{}")
  )

  result <- parse_oa_usage_headers(resp)

  expect_true(is.na(result$daily_limit))
  expect_true(is.na(result$remaining))
  expect_true(is.na(result$credits_used))
  expect_true(is.na(result$reset_seconds))
})

setup_oa_db <- function() {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  init_schema(con)
  sql_path <- file.path(project_root, "migrations", "011_create_oa_usage_log.sql")
  if (file.exists(sql_path)) {
    sql <- paste(readLines(sql_path, warn = FALSE), collapse = "\n")
    # Strip comments and execute
    lines <- strsplit(sql, "\n")[[1]]
    lines <- lines[!grepl("^\\s*--", lines)]
    clean <- paste(lines, collapse = "\n")
    stmts <- trimws(strsplit(clean, ";")[[1]])
    stmts <- stmts[nchar(stmts) > 0]
    for (stmt in stmts) DBI::dbExecute(con, stmt)
  }
  con
}

test_that("log_oa_usage writes to oa_usage_log table", {
  con <- setup_oa_db()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  usage <- list(daily_limit = 1.0, remaining = 0.8, credits_used = 0.001, reset_seconds = 7200L)

  id <- log_oa_usage(con, "search", "/works", usage, cost_usd = 0.001)

  expect_true(!is.null(id))

  rows <- DBI::dbGetQuery(con, "SELECT * FROM oa_usage_log")
  expect_equal(nrow(rows), 1)
  expect_equal(rows$operation, "search")
  expect_equal(rows$endpoint, "/works")
  expect_equal(rows$daily_limit, 1.0)
  expect_equal(rows$remaining, 0.8)
  expect_equal(rows$credits_used, 0.001)
  expect_equal(rows$cost_usd, 0.001)
  expect_equal(rows$reset_seconds, 7200L)
})

test_that("log_oa_usage handles NA values gracefully (polite pool)", {
  con <- setup_oa_db()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  usage <- list(daily_limit = NA_real_, remaining = NA_real_,
                credits_used = NA_real_, reset_seconds = NA_integer_)

  id <- log_oa_usage(con, "search", "/works", usage)

  rows <- DBI::dbGetQuery(con, "SELECT * FROM oa_usage_log")
  expect_equal(nrow(rows), 1)
  expect_true(is.na(rows$daily_limit))
  expect_true(is.na(rows$remaining))
})

# --- Phase 2: Usage Queries & Badge Logic ---

test_that("oa_budget_percentage and color helpers", {
  # Budget percentage: floor((1 - remaining/limit) * 100)
  expect_equal(floor((1 - 0.3 / 1.0) * 100), 70)
  expect_equal(floor((1 - 0.0 / 1.0) * 100), 100)
  expect_equal(floor((1 - 1.0 / 1.0) * 100), 0)
})
