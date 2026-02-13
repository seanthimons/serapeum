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

#' Create progress file for cross-process progress reporting
#'
#' Creates a temporary file for the mirai worker to write progress updates
#' that the Shiny main session can poll.
#'
#' @param session_id Unique session identifier
#' @return Character string: path to the progress file
#' @export
create_progress_file <- function(session_id) {
  progress_file <- tempfile(
    pattern = sprintf("serapeum_progress_%s_", session_id),
    fileext = ".progress"
  )
  writeLines("0|1|0|0|Initializing...", progress_file)
  progress_file
}

#' Write progress to progress file
#'
#' Format: "hop|total_hops|paper_idx|frontier_size|message"
#'
#' @param progress_file Path to progress file
#' @param hop Current BFS hop number
#' @param total_hops Total depth
#' @param paper_idx Current paper index within hop (0 = hop start)
#' @param frontier_size Total papers in current frontier
#' @param message Human-readable status message
#' @return NULL (called for side effect)
#' @export
write_progress <- function(progress_file, hop, total_hops, paper_idx, frontier_size, message) {
  if (is.null(progress_file)) return(invisible(NULL))
  tryCatch({
    writeLines(paste(hop, total_hops, paper_idx, frontier_size, message, sep = "|"), progress_file)
  }, error = function(e) {
    # Silently handle errors (file may be deleted)
  })
  invisible(NULL)
}

#' Read progress from progress file
#'
#' @param progress_file Path to progress file
#' @return List with hop, total_hops, paper_idx, frontier_size, message, and pct (0-100)
#' @export
read_progress <- function(progress_file) {
  if (is.null(progress_file) || !file.exists(progress_file)) {
    return(list(hop = 0, total_hops = 1, paper_idx = 0, frontier_size = 0, message = "Waiting...", pct = 0))
  }
  line <- tryCatch(readLines(progress_file, n = 1, warn = FALSE), error = function(e) "0|1|0|0|Waiting...")
  parts <- strsplit(line, "\\|", fixed = FALSE)[[1]]
  if (length(parts) < 5) {
    return(list(hop = 0, total_hops = 1, paper_idx = 0, frontier_size = 0, message = "Waiting...", pct = 0))
  }
  hop <- as.integer(parts[1])
  total_hops <- max(as.integer(parts[2]), 1L)
  paper_idx <- as.integer(parts[3])
  frontier_size <- max(as.integer(parts[4]), 1L)
  message <- paste(parts[5:length(parts)], collapse = "|")

  # Calculate overall percentage: each hop is an equal slice, paper progress within hop
  hop_pct <- (hop - 1) / total_hops  # completed hops
  within_hop_pct <- paper_idx / frontier_size / total_hops  # progress within current hop
  pct <- round(min((hop_pct + within_hop_pct) * 100, 99))

  list(hop = hop, total_hops = total_hops, paper_idx = paper_idx,
       frontier_size = frontier_size, message = message, pct = pct)
}

#' Clear progress file
#'
#' @param progress_file Path to progress file
#' @return NULL (called for side effect)
#' @export
clear_progress_file <- function(progress_file) {
  if (!is.null(progress_file) && file.exists(progress_file)) {
    unlink(progress_file)
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
  temp_dir <- tempdir()

  # Clean interrupt flags
  flag_pattern <- sprintf("serapeum_interrupt_%s_.*\\.flag$", session_id)
  flag_files <- list.files(temp_dir, pattern = flag_pattern, full.names = TRUE)

  # Clean progress files
  progress_pattern <- sprintf("serapeum_progress_%s_.*\\.progress$", session_id)
  progress_files <- list.files(temp_dir, pattern = progress_pattern, full.names = TRUE)

  all_files <- c(flag_files, progress_files)
  if (length(all_files) > 0) {
    unlink(all_files)
  }

  invisible(length(all_files))
}
