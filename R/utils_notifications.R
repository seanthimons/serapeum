#' Show a user-friendly error toast notification
#' @param message Plain language error message
#' @param details Technical details (HTTP status, raw error)
#' @param severity "error" or "warning"
#' @param duration Auto-dismiss seconds (default 8 for errors, 5 for warnings)
show_error_toast <- function(message, details = NULL, severity = "error", duration = NULL) {
  if (is.null(duration)) {
    duration <- if (severity == "warning") 5 else 8
  }

  # Build notification content with optional expandable details
  content <- if (!is.null(details) && nchar(details) > 0) {
    HTML(paste0(
      '<div>', htmltools::htmlEscape(message), '</div>',
      '<details class="mt-1"><summary class="small text-muted" style="cursor:pointer;">Show details</summary>',
      '<div class="small text-muted mt-1 font-monospace" style="word-break:break-all;">',
      htmltools::htmlEscape(details),
      '</div></details>'
    ))
  } else {
    message
  }

  type <- if (severity == "warning") "warning" else "error"
  showNotification(content, type = type, duration = duration)
}
