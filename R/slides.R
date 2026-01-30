# R/slides.R
library(processx)

#' Check if Quarto CLI is installed
#' @return TRUE if quarto command exists, FALSE otherwise
check_quarto_installed <- function() {
  result <- tryCatch({
    run("quarto", "--version", error_on_status = FALSE)
    TRUE
  }, error = function(e) {
    FALSE
  })
  result
}

#' Get Quarto version string
#' @return Version string like "1.4.550" or NULL if not installed
get_quarto_version <- function() {
  tryCatch({
    result <- run("quarto", "--version", error_on_status = FALSE)
    if (result$status == 0) {
      trimws(result$stdout)
    } else {
      NULL
    }
  }, error = function(e) {
    NULL
  })
}
