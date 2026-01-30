#' Load configuration from YAML file
#' @param path Path to config file
#' @return List of config values or NULL if file doesn't exist
load_config <- function(path = "config.yml") {
  if (!file.exists(path)) {
    return(NULL)
  }
  yaml::read_yaml(path)
}

#' Get a nested setting from config
#' @param config Config list from load_config
#' @param ... Path to setting (e.g., "defaults", "chat_model")
#' @return Setting value or NULL if not found
get_setting <- function(config, ...) {
  keys <- list(...)
  result <- config
  for (key in keys) {
    if (is.null(result) || !key %in% names(result)) {
      return(NULL)
    }
    result <- result[[key]]
  }
  result
}

#' Null-coalescing operator
#' @param x Value to check
#' @param y Default value if x is NULL
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
