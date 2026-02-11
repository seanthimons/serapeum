library(DBI)

#' Get list of applied migrations from database
#'
#' Creates the schema_migrations tracking table if it doesn't exist.
#' Returns a vector of version numbers that have already been applied.
#'
#' @param con DuckDB connection
#' @return Integer vector of applied migration versions
get_applied_migrations <- function(con) {
  # Create tracking table if it doesn't exist
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version INTEGER PRIMARY KEY,
      description VARCHAR NOT NULL,
      applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")

  # Get list of applied versions
  result <- dbGetQuery(con, "SELECT version FROM schema_migrations ORDER BY version")

  if (nrow(result) == 0) {
    return(integer(0))
  }

  as.integer(result$version)
}

#' Apply a single migration to the database
#'
#' Executes a migration SQL file within a transaction. If the version has already
#' been applied, it will be skipped. On error, the transaction is rolled back and
#' the error is re-thrown (halting app startup).
#'
#' DuckDB requires each SQL statement to be executed separately, so this function
#' splits the SQL on semicolons, filters out empty statements, and executes each
#' individually within a transaction.
#'
#' @param con DuckDB connection
#' @param version Migration version number (integer)
#' @param description Human-readable description of the migration
#' @param sql SQL statements to execute (may contain multiple statements separated by semicolons)
#' @return TRUE if migration was applied, FALSE if already applied
apply_migration <- function(con, version, description, sql) {
  # Check if already applied
  applied <- get_applied_migrations(con)
  if (version %in% applied) {
    return(FALSE)
  }

  # Execute within transaction
  tryCatch({
    dbWithTransaction(con, {
      # Split SQL on semicolons and execute each statement separately
      # This handles DuckDB's requirement for separate statement execution
      lines <- strsplit(sql, "\n")[[1]]

      # Remove comment-only lines
      lines <- lines[!grepl("^\\s*--", lines)]

      # Rejoin and split on semicolons
      clean_sql <- paste(lines, collapse = "\n")
      statements <- strsplit(clean_sql, ";")[[1]]

      # Clean up statements: trim whitespace and remove empty ones
      statements <- trimws(statements)
      statements <- statements[nchar(statements) > 0]

      # Execute each statement
      for (stmt in statements) {
        if (nchar(stmt) > 0) {
          dbExecute(con, stmt)
        }
      }

      # Record migration in tracking table
      dbExecute(con, "
        INSERT INTO schema_migrations (version, description)
        VALUES (?, ?)
      ", list(as.integer(version), description))
    })

    message("[migration] Applied migration ", version, ": ", description)
    return(TRUE)

  }, error = function(e) {
    message("[migration] FAILED to apply migration ", version, ": ", e$message)
    stop(e)
  })
}

#' Bootstrap existing database with initial migration marker
#'
#' Called when no migrations have been applied yet (version 0). Checks if this is
#' an existing database (has "notebooks" table) or a fresh database.
#'
#' For existing databases: marks version 001 as applied WITHOUT executing it,
#' since init_schema() has already created those tables via ad-hoc migrations.
#'
#' For fresh databases: does nothing special - init_schema() + migrations will
#' handle setup.
#'
#' @param con DuckDB connection
bootstrap_existing_database <- function(con) {
  # Check if notebooks table exists using a query that works with both connection types
  # This avoids needing to extract the underlying connection
  tables_result <- tryCatch({
    dbGetQuery(con, "
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'main'
    ")
  }, error = function(e) {
    # Fallback: return empty dataframe
    data.frame(table_name = character(0), stringsAsFactors = FALSE)
  })

  if ("notebooks" %in% tables_result$table_name) {
    # Existing database - mark version 001 as already applied
    message("[migration] Detected existing database - bootstrapping at version 001")

    dbExecute(con, "
      INSERT INTO schema_migrations (version, description)
      VALUES (1, 'Bootstrap existing schema (created by init_schema)')
    ")

    return(TRUE)
  }

  # Fresh database - no special action needed
  return(FALSE)
}

#' Run all pending migrations
#'
#' Lists migration files from the migrations/ directory, determines which haven't
#' been applied yet, and applies them in order. Migration files must follow the
#' naming pattern: NNN_description.sql (e.g., 001_bootstrap.sql)
#'
#' For version 0 (no migrations applied), calls bootstrap_existing_database() to
#' handle the transition from ad-hoc migrations to versioned migrations.
#'
#' @param con DuckDB connection
run_pending_migrations <- function(con) {
  # Get list of applied migrations
  applied <- get_applied_migrations(con)

  # Bootstrap existing databases at version 0
  if (length(applied) == 0) {
    bootstrap_existing_database(con)
    applied <- get_applied_migrations(con)
  }

  # Find migrations directory
  # Shiny apps run from project root, so use relative path
  migrations_dir <- "migrations"

  if (!dir.exists(migrations_dir)) {
    message("[migration] No migrations directory found")
    return(invisible(NULL))
  }

  # List migration files matching pattern: 001_description.sql
  migration_files <- list.files(
    migrations_dir,
    pattern = "^\\d{3}_.*\\.sql$",
    full.names = TRUE
  )

  if (length(migration_files) == 0) {
    message("[migration] No migration files found")
    return(invisible(NULL))
  }

  # Sort files to ensure correct order
  migration_files <- sort(migration_files)

  # Process each migration file
  for (filepath in migration_files) {
    # Extract version number from filename
    filename <- basename(filepath)
    version <- as.integer(substr(filename, 1, 3))

    # Skip if already applied
    if (version %in% applied) {
      next
    }

    # Extract description from filename
    description <- sub("^\\d{3}_(.+)\\.sql$", "\\1", filename)
    description <- gsub("_", " ", description)

    # Read SQL file
    sql <- paste(readLines(filepath, warn = FALSE), collapse = "\n")

    # Apply migration
    apply_migration(con, version, description, sql)
  }

  # Get final version
  applied <- get_applied_migrations(con)
  max_version <- if (length(applied) > 0) max(applied) else 0

  message("[migration] Database at version ", max_version)
  invisible(NULL)
}
