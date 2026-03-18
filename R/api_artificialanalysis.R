library(httr2)
library(jsonlite)

AA_API_BASE <- "https://artificialanalysis.ai/api/v2/data/llms"

# ---- Data Loading ----

#' Load bundled AA snapshot from disk
#'
#' @param base_path Base directory to search from (default: working directory)
#' @return Data frame of AA model data, or empty data frame if file missing
load_bundled_aa_data <- function(base_path = NULL) {
  candidates <- c(
    if (!is.null(base_path)) file.path(base_path, "data/support/aa_models.json"),
    "data/support/aa_models.json",
    file.path(system.file(package = "base"), "..", "..", "data/support/aa_models.json")
  )
  path <- Find(file.exists, candidates)
  if (is.null(path)) {
    return(empty_aa_frame())
  }

  tryCatch({
    raw <- jsonlite::fromJSON(path, simplifyDataFrame = FALSE)
    parse_aa_models(raw$models)
  }, error = function(e) {
    message("[AA] Failed to load bundled data: ", e$message)
    empty_aa_frame()
  })
}

#' Fetch latest AA data from API
#'
#' @param api_key AA API key (required)
#' @return Data frame of AA model data
fetch_aa_models <- function(api_key) {
  if (is.null(api_key) || nchar(api_key) == 0) {
    stop("Artificial Analytics API key is required to fetch fresh data.")
  }

  req <- request(paste0(AA_API_BASE, "/models")) |>
    req_headers("x-api-key" = api_key) |>
    req_timeout(15)

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    stop("Failed to reach Artificial Analytics API: ", e$message)
  })

  body <- resp_body_json(resp)

  # API returns an array of model objects
  models <- if (is.list(body) && !is.null(body$data)) body$data else body

  if (length(models) == 0) {
    return(empty_aa_frame())
  }

  parse_aa_models(models)
}

#' Get AA model data (cached > bundled fallback)
#'
#' @param con DuckDB connection
#' @return Data frame of AA model data
get_aa_models <- function(con) {
  # Try DB cache first
  cached <- tryCatch({
    raw <- get_db_setting(con, "aa_model_cache")
    if (!is.null(raw) && !is.null(raw$models)) {
      models <- raw$models
      # fromJSON may return a data.frame or list — handle both
      if (is.data.frame(models)) {
        # Already a data frame from simplified JSON
        names_needed <- c("aa_model_id", "aa_model_name", "aa_model_slug",
                          "creator_name", "intelligence_index", "coding_index",
                          "tokens_per_second", "ttft_seconds",
                          "price_input_1m", "price_output_1m", "price_blended_1m")
        missing <- setdiff(names_needed, names(models))
        for (col in missing) models[[col]] <- NA
        models
      } else {
        parse_aa_models(models)
      }
    } else {
      NULL
    }
  }, error = function(e) NULL)

  if (!is.null(cached) && nrow(cached) > 0) {
    return(cached)
  }

  # Fall back to bundled
  load_bundled_aa_data()
}

#' Save AA data to DB cache
#'
#' @param con DuckDB connection
#' @param aa_df Data frame from fetch_aa_models or load_bundled_aa_data
save_aa_cache <- function(con, aa_df) {
  cache <- list(
    refreshed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    models = lapply(seq_len(nrow(aa_df)), function(i) as.list(aa_df[i, ]))
  )
  save_db_setting(con, "aa_model_cache", cache)
}

# ---- Model Matching ----

#' Load the manual model ID mapping
#'
#' @param base_path Base directory to search from (default: working directory)
#' @return Named character vector (openrouter_id -> aa_slug)
load_aa_model_mapping <- function(base_path = NULL) {
  candidates <- c(
    if (!is.null(base_path)) file.path(base_path, "data/support/aa_model_mapping.json"),
    "data/support/aa_model_mapping.json"
  )
  path <- Find(file.exists, candidates)
  if (is.null(path)) return(character())

  tryCatch({
    raw <- jsonlite::fromJSON(path)
    # Remove comment entries
    raw <- raw[!grepl("^_", names(raw))]
    unlist(raw)
  }, error = function(e) character())
}

#' Normalize a model ID for fuzzy matching
#'
#' @param model_id Model ID string
#' @return Normalized lowercase string
normalize_model_id <- function(model_id) {
  id <- tolower(model_id)
  # Strip provider prefix (e.g., "openai/" -> "")
  id <- sub("^[a-z0-9-]+/", "", id)
  # Strip version suffixes like -preview, -001, -preview-2026-01-01
  id <- sub("-preview.*$", "", id)
  id <- sub("-[0-9]{3,}$", "", id)
  id <- sub("-latest$", "", id)
  # Normalize dots to dashes
  id <- gsub("\\.", "-", id)
  id
}

#' Match an OpenRouter model ID to AA data
#'
#' Tries manual mapping first, then normalized fuzzy match.
#'
#' @param openrouter_id OpenRouter model ID
#' @param aa_df Data frame of AA models (from get_aa_models)
#' @param mapping Manual mapping (from load_aa_model_mapping)
#' @return Single-row data frame of AA data, or NULL if no match
match_aa_model <- function(openrouter_id, aa_df, mapping = NULL, base_path = NULL) {
  if (is.null(aa_df) || nrow(aa_df) == 0) return(NULL)

  if (is.null(mapping)) {
    mapping <- load_aa_model_mapping(base_path)
  }

  # Try manual mapping
  aa_slug <- if (openrouter_id %in% names(mapping)) mapping[[openrouter_id]] else NULL
  if (!is.null(aa_slug)) {
    row <- aa_df[aa_df$aa_model_slug == aa_slug, , drop = FALSE]
    if (nrow(row) > 0) return(row[1, , drop = FALSE])
  }

  # Fuzzy match: normalize both sides
  normalized_id <- normalize_model_id(openrouter_id)

  aa_df$normalized <- vapply(aa_df$aa_model_slug, normalize_model_id, character(1))
  match_row <- aa_df[aa_df$normalized == normalized_id, , drop = FALSE]
  if (nrow(match_row) > 0) {
    match_row$normalized <- NULL
    return(match_row[1, , drop = FALSE])
  }

  aa_df$normalized <- NULL
  NULL
}

#' Enrich a chat models data frame with AA data
#'
#' @param models_df Data frame from list_chat_models
#' @param aa_df Data frame from get_aa_models
#' @return models_df with added AA columns (intelligence_index, tokens_per_second, price_blended_1m)
enrich_models_with_aa <- function(models_df, aa_df, base_path = NULL) {
  if (is.null(aa_df) || nrow(aa_df) == 0 || nrow(models_df) == 0) {
    models_df$intelligence_index <- NA_real_
    models_df$tokens_per_second <- NA_real_
    models_df$price_blended_1m <- NA_real_
    return(models_df)
  }

  mapping <- load_aa_model_mapping(base_path)

  aa_data <- lapply(models_df$id, function(model_id) {
    row <- match_aa_model(model_id, aa_df, mapping)
    if (is.null(row)) {
      list(intelligence_index = NA_real_, tokens_per_second = NA_real_,
           price_blended_1m = NA_real_)
    } else {
      list(intelligence_index = row$intelligence_index,
           tokens_per_second = row$tokens_per_second,
           price_blended_1m = row$price_blended_1m)
    }
  })

  models_df$intelligence_index <- vapply(aa_data, function(x) x$intelligence_index %||% NA_real_, numeric(1))
  models_df$tokens_per_second <- vapply(aa_data, function(x) x$tokens_per_second %||% NA_real_, numeric(1))
  models_df$price_blended_1m <- vapply(aa_data, function(x) x$price_blended_1m %||% NA_real_, numeric(1))

  models_df
}

# ---- Smart Defaults ----

#' Suggest a model for a slot based on AA data
#'
#' @param models_df Enriched models data frame (with AA columns)
#' @param slot "fast", "quality", or "embedding"
#' @return Model ID string, or NULL if no suggestion
suggest_model_for_slot <- function(models_df, slot = c("fast", "quality", "embedding")) {
  slot <- match.arg(slot)

  if (is.null(models_df) || nrow(models_df) == 0) return(NULL)

  if (slot == "embedding") return(NULL)  # Keep current default

  if (slot == "fast") {
    # Cheapest model with intelligence >= 50
    candidates <- models_df[!is.na(models_df$intelligence_index) &
                              models_df$intelligence_index >= 50, , drop = FALSE]
    if (nrow(candidates) == 0) {
      # Fallback: prefer models with "mini" or "flash" in name
      flash_models <- models_df[grepl("mini|flash|lite", tolower(models_df$name)), , drop = FALSE]
      if (nrow(flash_models) > 0) return(flash_models$id[1])
      return(NULL)
    }
    candidates <- candidates[order(candidates$price_blended_1m, na.last = TRUE), , drop = FALSE]
    return(candidates$id[1])
  }

  if (slot == "quality") {
    # Highest intelligence with price <= $10/M
    candidates <- models_df[!is.na(models_df$intelligence_index), , drop = FALSE]
    candidates <- candidates[is.na(candidates$price_blended_1m) |
                               candidates$price_blended_1m <= 10, , drop = FALSE]
    if (nrow(candidates) == 0) return(NULL)
    candidates <- candidates[order(-candidates$intelligence_index), , drop = FALSE]
    return(candidates$id[1])
  }

  NULL
}

# ---- Internal Helpers ----

#' Parse raw AA model list into a data frame
#'
#' @param models List of model objects
#' @return Data frame with standardized columns
parse_aa_models <- function(models) {
  if (length(models) == 0) return(empty_aa_frame())

  data.frame(
    aa_model_id = vapply(models, function(m) m$aa_model_id %||% m$id %||% "", character(1)),
    aa_model_name = vapply(models, function(m) m$aa_model_name %||% m$name %||% "", character(1)),
    aa_model_slug = vapply(models, function(m) m$aa_model_slug %||% m$slug %||% "", character(1)),
    creator_name = vapply(models, function(m) {
      m$creator_name %||% m$model_creator$name %||% ""
    }, character(1)),
    intelligence_index = vapply(models, function(m) {
      as.numeric(m$intelligence_index %||% m$evaluations$artificial_analysis_intelligence_index %||% NA_real_)
    }, numeric(1)),
    coding_index = vapply(models, function(m) {
      as.numeric(m$coding_index %||% m$evaluations$artificial_analysis_coding_index %||% NA_real_)
    }, numeric(1)),
    tokens_per_second = vapply(models, function(m) {
      as.numeric(m$tokens_per_second %||% m$median_output_tokens_per_second %||% NA_real_)
    }, numeric(1)),
    ttft_seconds = vapply(models, function(m) {
      as.numeric(m$ttft_seconds %||% m$median_time_to_first_token_seconds %||% NA_real_)
    }, numeric(1)),
    price_input_1m = vapply(models, function(m) {
      as.numeric(m$price_input_1m %||% m$pricing$price_1m_input_tokens %||% NA_real_)
    }, numeric(1)),
    price_output_1m = vapply(models, function(m) {
      as.numeric(m$price_output_1m %||% m$pricing$price_1m_output_tokens %||% NA_real_)
    }, numeric(1)),
    price_blended_1m = vapply(models, function(m) {
      as.numeric(m$price_blended_1m %||% m$pricing$price_1m_blended_3_to_1 %||% NA_real_)
    }, numeric(1)),
    stringsAsFactors = FALSE
  )
}

#' Empty AA data frame with correct column types
empty_aa_frame <- function() {
  data.frame(
    aa_model_id = character(), aa_model_name = character(),
    aa_model_slug = character(), creator_name = character(),
    intelligence_index = numeric(), coding_index = numeric(),
    tokens_per_second = numeric(), ttft_seconds = numeric(),
    price_input_1m = numeric(), price_output_1m = numeric(),
    price_blended_1m = numeric(), stringsAsFactors = FALSE
  )
}
