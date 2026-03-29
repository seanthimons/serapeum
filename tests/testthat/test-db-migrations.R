library(testthat)

source_app("config.R", "db.R", "db_migrations.R")

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

test_that("fresh install startup path does not duplicate migration records on rerun", {
  tmp_dir <- tempfile("migration-rerun-")
  dir.create(tmp_dir)
  db_path <- file.path(tmp_dir, "rerun.duckdb")

  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  con <- get_db_connection(db_path)
  applied_first <- get_applied_migrations(con)
  expect_true(length(applied_first) > 0)
  close_db_connection(con)
  gc()  # ensure DuckDB releases file lock on Windows
  Sys.sleep(0.5)

  con_rerun <- get_db_connection(db_path)
  on.exit(DBI::dbDisconnect(con_rerun, shutdown = TRUE), add = TRUE)

  applied_second <- get_applied_migrations(con_rerun)
  expect_equal(applied_second, applied_first)

  migration_counts <- DBI::dbGetQuery(con_rerun, "
    SELECT version, COUNT(*) AS n
    FROM schema_migrations
    GROUP BY version
    HAVING COUNT(*) > 1
  ")
  expect_equal(nrow(migration_counts), 0)
})

test_that("topics table created by migration 002", {
  # Create a temp directory with actual migrations
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  migrations_dir <- file.path(tmp_dir, "migrations")
  dir.create(migrations_dir)


  # Read and write migration 002
  mig_002_content <- readLines(file.path(app_root(), "migrations", "002_create_topics_table.sql"))
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

test_that("prompt_versions table created by migration 011", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  migrations_dir <- file.path(tmp_dir, "migrations")
  dir.create(migrations_dir)


  mig_011_content <- readLines(file.path(app_root(), "migrations", "018_create_prompt_versions.sql"))
  writeLines(mig_011_content, file.path(migrations_dir, "018_create_prompt_versions.sql"))

  old_wd <- getwd()
  setwd(tmp_dir)
  on.exit({
    setwd(old_wd)
    unlink(tmp_dir, recursive = TRUE)
  }, add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  run_pending_migrations(con)

  tables <- DBI::dbListTables(con)
  expect_true("prompt_versions" %in% tables)

  columns <- DBI::dbGetQuery(con, "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_name = 'prompt_versions'
  ")

  expected_columns <- c("preset_slug", "version_date", "prompt_text", "created_at")
  for (col in expected_columns) {
    expect_true(col %in% columns$column_name,
                info = paste("Column", col, "should exist in prompt_versions table"))
  }

  # Verify composite PK via UPSERT: second insert replaces first
  DBI::dbExecute(con, "
    INSERT OR REPLACE INTO prompt_versions (preset_slug, version_date, prompt_text)
    VALUES ('summarize', '2026-03-20', 'Original prompt')
  ")
  DBI::dbExecute(con, "
    INSERT OR REPLACE INTO prompt_versions (preset_slug, version_date, prompt_text)
    VALUES ('summarize', '2026-03-20', 'Updated prompt')
  ")
  result <- DBI::dbGetQuery(con, "
    SELECT prompt_text FROM prompt_versions
    WHERE preset_slug = 'summarize' AND version_date = '2026-03-20'
  ")
  expect_equal(nrow(result), 1)
  expect_equal(result$prompt_text[1], "Updated prompt")
})
