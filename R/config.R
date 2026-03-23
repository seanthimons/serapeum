# App version — single source of truth
SERAPEUM_VERSION <- "18.0.0"

#' Load configuration from YAML file or environment variables
#' @param path Path to config file
#' @return List of config values (from file, env vars, or NULL)
load_config <- function(path = "config.yml") {
  # Try file first
  if (file.exists(path)) {
    return(yaml::read_yaml(path))
  }


  # Fall back to environment variables (for shinyapps.io / Posit Connect Cloud)
  env_config <- list(
    openrouter = list(
      api_key = Sys.getenv("OPENROUTER_API_KEY", unset = NA)
    ),
    openalex = list(
      email = Sys.getenv("OPENALEX_EMAIL", unset = NA),
      api_key = Sys.getenv("OPENALEX_API_KEY", unset = NA)
    )
  )

  # Only return if at least one env var is set

  has_openrouter <- !is.na(env_config$openrouter$api_key) &&
                    nchar(env_config$openrouter$api_key) > 0
  has_openalex_email <- !is.na(env_config$openalex$email) &&
                        nchar(env_config$openalex$email) > 0
  has_openalex_key <- !is.na(env_config$openalex$api_key) &&
                      nchar(env_config$openalex$api_key) > 0

  if (has_openrouter || has_openalex_email || has_openalex_key) {
    # Convert NA to NULL for consistency with YAML config
    if (!has_openrouter) env_config$openrouter$api_key <- NULL
    if (!has_openalex_email) env_config$openalex$email <- NULL
    if (!has_openalex_key) env_config$openalex$api_key <- NULL
    return(env_config)
  }

  NULL
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
