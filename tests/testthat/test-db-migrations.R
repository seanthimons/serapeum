library(testthat)

# Source required files from project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "config.R"))) {
  # Fallback: we may already be in project root
  project_root <- getwd()
}
source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "db.R"))
source(file.path(project_root, "R", "db_migrations.R"))

test_that("get_applied_migrations creates tracking table and returns empty", {
  # Create a fresh in-memory database
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  # Call get_applied_migrations
  applied <- get_applied_migrations(con)

  # Verify tracking table exists
  tables <- DBI::dbListTables(con)
  expect_true("schema_migrations" %in% tables)

  # Verify result is empty integer vector
  expect_true(is.integer(applied))
  expect_equal(length(applied), 0)
})

test_that("apply_migration records version in tracking table", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  # Create tracking table
  get_applied_migrations(con)

  # Apply a test migration
  test_sql <- "CREATE TABLE test_table (id INTEGER)"
  result <- apply_migration(con, 1, "Create test table", test_sql)

  # Verify it was applied
  expect_true(result)

  # Verify test_table exists
  tables <- DBI::dbListTables(con)
  expect_true("test_table" %in% tables)

  # Verify version 1 is recorded
  applied <- get_applied_migrations(con)
  expect_true(1 %in% applied)
})

test_that("apply_migration skips already-applied versions", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  get_applied_migrations(con)

  # Apply version 1
  test_sql <- "CREATE TABLE test_table (id INTEGER)"
  result1 <- apply_migration(con, 1, "Create test table", test_sql)
  expect_true(result1)

  # Try to apply version 1 again
  result2 <- apply_migration(con, 1, "Create test table", test_sql)
  expect_false(result2)

  # Verify only one row in schema_migrations
  migrations <- DBI::dbGetQuery(con, "SELECT * FROM schema_migrations WHERE version = 1")
  expect_equal(nrow(migrations), 1)
})

test_that("apply_migration rolls back on SQL error", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  get_applied_migrations(con)

  # Try to apply migration with invalid SQL
  invalid_sql <- "CREATE INVALID SYNTAX HERE"

  # Should throw an error
  expect_error(
    apply_migration(con, 99, "Invalid migration", invalid_sql),
    regexp = ".*"
  )

  # Verify version 99 is NOT recorded
  applied <- get_applied_migrations(con)
  expect_false(99 %in% applied)
})

test_that("run_pending_migrations applies all pending in order", {
  # Create a temporary directory for test migrations
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  migrations_dir <- file.path(tmp_dir, "migrations")
  dir.create(migrations_dir)

  # Create test migration files
  writeLines(
    c("-- Test migration 1", "CREATE TABLE mig_test_1 (id INTEGER)"),
    file.path(migrations_dir, "010_test_migration_1.sql")
  )
  writeLines(
    c("-- Test migration 2", "CREATE TABLE mig_test_2 (id INTEGER)"),
    file.path(migrations_dir, "020_test_migration_2.sql")
  )

  # Change to temp directory so run_pending_migrations can find migrations/
  old_wd <- getwd()
  setwd(tmp_dir)
  on.exit({
    setwd(old_wd)
    unlink(tmp_dir, recursive = TRUE)
  }, add = TRUE)

  # Create database and run migrations
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  run_pending_migrations(con)

  # Verify both versions recorded
  applied <- get_applied_migrations(con)
  expect_true(10 %in% applied)
  expect_true(20 %in% applied)

  # Verify tables created
  tables <- DBI::dbListTables(con)
  expect_true("mig_test_1" %in% tables)
  expect_true("mig_test_2" %in% tables)
})

test_that("bootstrap marks existing database as version 001", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  # Create tracking table
  get_applied_migrations(con)

  # Create a notebooks table to simulate existing database
  DBI::dbExecute(con, "CREATE TABLE notebooks (id VARCHAR PRIMARY KEY)")

  # Call bootstrap
  result <- bootstrap_existing_database(con)

  # Should return TRUE (bootstrap was performed)
  expect_true(result)

  # Verify version 1 is recorded
  applied <- get_applied_migrations(con)
  expect_true(1 %in% applied)

  # Verify description
  migration <- DBI::dbGetQuery(con, "SELECT * FROM schema_migrations WHERE version = 1")
  expect_match(migration$description[1], "Bootstrap")
})

test_that("topics table created by migration 002", {
  # Create a temp directory with actual migrations
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  migrations_dir <- file.path(tmp_dir, "migrations")
  dir.create(migrations_dir)

  # Copy actual migration files
  project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
  if (!file.exists(file.path(project_root, "migrations"))) {
    project_root <- getwd()
  }

  # Read and write migration 002
  mig_002_content <- readLines(file.path(project_root, "migrations", "002_create_topics_table.sql"))
  writeLines(mig_002_content, file.path(migrations_dir, "002_create_topics_table.sql"))

  # Change to temp directory
  old_wd <- getwd()
  setwd(tmp_dir)
  on.exit({
    setwd(old_wd)
    unlink(tmp_dir, recursive = TRUE)
  }, add = TRUE)

  # Create fresh database
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  # Run init_schema (simulates app startup)
  init_schema(con)

  # Run pending migrations
  run_pending_migrations(con)

  # Verify topics table exists
  tables <- DBI::dbListTables(con)
  expect_true("topics" %in% tables)

  # Verify expected columns exist
  columns <- DBI::dbGetQuery(con, "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_name = 'topics'
  ")

  expected_columns <- c(
    "topic_id", "display_name", "description", "keywords", "works_count",
    "domain_id", "domain_name", "field_id", "field_name",
    "subfield_id", "subfield_name", "updated_at"
  )

  for (col in expected_columns) {
    expect_true(col %in% columns$column_name,
                info = paste("Column", col, "should exist in topics table"))
  }
})
