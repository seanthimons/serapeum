# App version — single source of truth
SERAPEUM_VERSION <- "22.0.0"

# Cost estimate for OpenAlex content API PDF download (USD per request)
OA_CONTENT_DOWNLOAD_COST_USD <- 0.01

# Default number of persistent mirai daemons for async tasks.
DEFAULT_MIRAI_DAEMONS <- 2L

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

#' Resolve configured mirai daemon count
#'
#' Reads `app.mirai_daemons` and falls back to `default` when the setting is
#' missing, negative, non-scalar, non-integer, or otherwise invalid.
#'
#' @param config Config list from load_config
#' @param default Fallback daemon count
#' @param warn Whether to warn when falling back
#' @return Non-negative integer daemon count
resolve_mirai_daemons <- function(config, default = DEFAULT_MIRAI_DAEMONS,
                                  warn = TRUE) {
  fallback <- as.integer(default)
  value <- get_setting(config, "app", "mirai_daemons")

  warn_fallback <- function(reason) {
    if (isTRUE(warn)) {
      warning(
        paste0(
          "Invalid app.mirai_daemons config (",
          reason,
          "); using default ",
          fallback,
          "."
        ),
        call. = FALSE
      )
    }
    fallback
  }

  if (is.null(value)) {
    return(warn_fallback("missing"))
  }

  if (is.list(value) || length(value) != 1 || is.logical(value)) {
    return(warn_fallback("must be a single non-negative integer"))
  }

  numeric_value <- suppressWarnings(as.numeric(value))
  if (
    is.na(numeric_value) ||
      !is.finite(numeric_value) ||
      numeric_value < 0 ||
      numeric_value != floor(numeric_value)
  ) {
    return(warn_fallback("must be a single non-negative integer"))
  }

  as.integer(numeric_value)
}

#' Null-coalescing operator
#' @param x Value to check
#' @param y Default value if x is NULL
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
