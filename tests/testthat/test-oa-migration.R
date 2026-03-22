library(testthat)

project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "api_openalex.R"))) {
  project_root <- getwd()
}

source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "db_migrations.R"))
source(file.path(project_root, "R", "db.R"))
source(file.path(project_root, "R", "api_openalex.R"))

# --- Phase 1: Migration & Settings ---

test_that("migration 011 creates oa_usage_log table", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  # Set up tracking table
  get_applied_migrations(con)

  # Read and apply migration 011 directly
  sql_path <- file.path(project_root, "migrations", "017_create_oa_usage_log.sql")
  skip_if_not(file.exists(sql_path), "Migration file not found")

  sql <- paste(readLines(sql_path, warn = FALSE), collapse = "\n")
  apply_migration(con, 17, "create oa usage log", sql)

  # Verify table exists
  tables <- DBI::dbGetQuery(con, "
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'main'
  ")
  expect_true("oa_usage_log" %in% tables$table_name)

  # Verify column structure
  cols <- DBI::dbGetQuery(con, "
    SELECT column_name FROM information_schema.columns
    WHERE table_name = 'oa_usage_log'
  ")

  expected_cols <- c("id", "operation", "endpoint", "daily_limit",
                     "remaining", "credits_used", "cost_usd",
                     "reset_seconds", "created_at")
  for (col in expected_cols) {
    expect_true(col %in% cols$column_name,
                info = paste("Missing column:", col))
  }
})

test_that("effective config includes openalex api_key from env var", {
  withr::with_envvar(c(
    OPENALEX_API_KEY = "test-env-key",
    OPENALEX_EMAIL = "test@example.com",
    OPENROUTER_API_KEY = ""
  ), {
    cfg <- load_config(path = "nonexistent_config_for_testing.yml")
    expect_equal(cfg$openalex$api_key, "test-env-key")
    expect_equal(cfg$openalex$email, "test@example.com")
  })
})

test_that("effective config excludes openalex api_key when env var empty", {
  withr::with_envvar(c(
    OPENALEX_API_KEY = "",
    OPENALEX_EMAIL = "test@example.com",
    OPENROUTER_API_KEY = ""
  ), {
    cfg <- load_config(path = "nonexistent_config_for_testing.yml")
    expect_null(cfg$openalex$api_key)
    expect_equal(cfg$openalex$email, "test@example.com")
  })
})

test_that("migration nudge shown when email set but no api_key", {
  expect_true(should_show_oa_migration_nudge("user@example.com", "", con = NULL))
  expect_true(should_show_oa_migration_nudge("user@example.com", NULL, con = NULL))
})

test_that("migration nudge hidden when api_key present", {
  expect_false(should_show_oa_migration_nudge("user@example.com", "oakey_12345", con = NULL))
})

test_that("migration nudge hidden when no email", {
  expect_false(should_show_oa_migration_nudge("", "", con = NULL))
  expect_false(should_show_oa_migration_nudge(NULL, NULL, con = NULL))
})

test_that("migration nudge hidden when dismissed", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))

  save_db_setting(con, "oa_migration_nudge_dismissed", TRUE)
  expect_false(should_show_oa_migration_nudge("user@example.com", "", con))
})
