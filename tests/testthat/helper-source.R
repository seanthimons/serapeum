# Auto-loaded by testthat before any test file runs.
# Provides source_app() and app_root() to replace the getwd() anti-pattern.

.app_root <- tryCatch(
  normalizePath(
    file.path(testthat::test_path(), "..", ".."),
    mustWork = TRUE
  ),
  error = function(e) {
    stop(
      "helper-source.R: failed to resolve app root. ",
      "test_path() = ", testthat::test_path(), ". ",
      "Error: ", e$message
    )
  }
)

# Set as a global option so run_pending_migrations() can find the migrations
# directory when testthat changes cwd to tests/testthat/.
options(.serapeum_app_root = .app_root)

#' Source R files from the app's R/ directory
#' @param ... Character file names (e.g., "config.R", "db.R")
source_app <- function(...) {
  files <- c(...)
  for (f in files) {
    source(file.path(.app_root, "R", f), local = FALSE)
  }
}

#' Get the project root path (for migrations, data files, etc.)
app_root <- function() .app_root

#' Get the migrations directory path
migrations_path <- function() file.path(.app_root, "migrations")
