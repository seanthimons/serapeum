#' Create interrupt flag file for cross-process cancellation
#'
#' Creates a temporary file that can be used to signal cancellation
#' across process boundaries (e.g., from main Shiny session to mirai worker).
#'
#' @param session_id Unique session identifier (e.g., session$token)
#' @return Character string: path to the flag file
#' @export
create_interrupt_flag <- function(session_id) {
  flag_file <- tempfile(
    pattern = sprintf("serapeum_interrupt_%s_", session_id),
    fileext = ".flag"
  )
  writeLines("running", flag_file)
  flag_file
}

#' Check if interrupt has been signaled
#'
#' @param flag_file Path to interrupt flag file
#' @return Logical: TRUE if interrupted, FALSE otherwise
#' @export
check_interrupt <- function(flag_file) {
  if (is.null(flag_file) || !file.exists(flag_file)) {
    return(FALSE)
  }

  status <- tryCatch({
    readLines(flag_file, n = 1, warn = FALSE)
  }, error = function(e) {
    "running"
  })

  identical(status, "interrupt")
}

#' Signal interrupt to flag file
#'
#' Writes "interrupt" status to the flag file to signal cancellation.
#'
#' @param flag_file Path to interrupt flag file
#' @return NULL (called for side effect)
#' @export
signal_interrupt <- function(flag_file) {
  tryCatch({
    writeLines("interrupt", flag_file)
  }, error = function(e) {
    # Silently handle errors (file may be deleted, etc.)
  })
  invisible(NULL)
}

#' Clear interrupt flag file
#'
#' Removes the interrupt flag file from disk.
#'
#' @param flag_file Path to interrupt flag file
#' @return NULL (called for side effect)
#' @export
clear_interrupt_flag <- function(flag_file) {
  if (!is.null(flag_file) && file.exists(flag_file)) {
    unlink(flag_file)
  }
  invisible(NULL)
}

#' Clean up all interrupt flags for a session
#'
#' Removes all interrupt flag files associated with a session ID.
#' Useful for session cleanup to prevent orphaned temp files.
#'
#' @param session_id Unique session identifier
#' @return Integer: count of files cleaned (invisible)
#' @export
cleanup_session_flags <- function(session_id) {
  pattern <- sprintf("serapeum_interrupt_%s_.*\\.flag$", session_id)
  temp_dir <- tempdir()
  flag_files <- list.files(temp_dir, pattern = pattern, full.names = TRUE)

  if (length(flag_files) > 0) {
    unlink(flag_files)
  }

  invisible(length(flag_files))
}
