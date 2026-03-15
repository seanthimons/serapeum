# ==============================================================================
# PDF Image Pipeline — File Utilities (Stage 2, Epic #44)
# ==============================================================================

#' Get the base directory for figure storage
#' @return Path to figures root directory
figures_base_dir <- function() {
  "data/figures"
}

#' Create figure directory for a document
#'
#' Creates the nested directory structure: data/figures/{notebook_id}/{document_id}/
#'
#' @param notebook_id Notebook ID
#' @param document_id Document ID (optional, creates notebook-level dir if NULL)
#' @return Path to the created directory
create_figure_dir <- function(notebook_id, document_id = NULL) {
  path <- if (is.null(document_id)) {
    file.path(figures_base_dir(), notebook_id)
  } else {
    file.path(figures_base_dir(), notebook_id, document_id)
  }

  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}

#' Save a figure image to disk
#'
#' Writes a PNG image to the figure storage directory and returns the
#' relative path (relative to project root) for storage in the database.
#'
#' @param image_data Raw vector of PNG data, or a file path to copy from
#' @param notebook_id Notebook ID
#' @param document_id Document ID
#' @param page Page number
#' @param index Figure index on that page (1-based)
#' @return Relative file path (e.g., "data/figures/{nb_id}/{doc_id}/fig_3_1.png")
save_figure <- function(image_data, notebook_id, document_id, page, index = 1L) {
  dir_path <- create_figure_dir(notebook_id, document_id)
  filename <- sprintf("fig_%03d_%d.png", as.integer(page), as.integer(index))
  file_path <- file.path(dir_path, filename)

  if (is.character(image_data) && file.exists(image_data)) {
    # Copy from source path
    file.copy(image_data, file_path, overwrite = TRUE)
  } else if (is.raw(image_data)) {
    # Write raw PNG bytes
    writeBin(image_data, file_path)
  } else {
    stop("image_data must be a raw vector or an existing file path")
  }

  file_path
}

#' Clean up figure files for a document or notebook
#'
#' Deletes the figure directory and all contents. When called with only
#' notebook_id, deletes the entire notebook's figure directory. When called
#' with both, deletes only that document's subdirectory.
#'
#' @param notebook_id Notebook ID
#' @param document_id Document ID (optional)
cleanup_figure_files <- function(notebook_id, document_id = NULL) {
  path <- if (is.null(document_id)) {
    file.path(figures_base_dir(), notebook_id)
  } else {
    file.path(figures_base_dir(), notebook_id, document_id)
  }

  if (dir.exists(path)) {
    unlink(path, recursive = TRUE)
  }

  invisible(TRUE)
}
