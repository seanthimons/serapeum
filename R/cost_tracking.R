library(DBI)
library(uuid)

#' Mutable environment for storing model pricing
#' This allows pricing to be updated from API responses
pricing_env <- new.env(parent = emptyenv())

#' OpenRouter model pricing table (USD per million tokens)
#'
#' Prices are stored as "per million tokens" for readability.
#' Embedding models typically don't charge for completion tokens.
pricing_env$MODEL_PRICING <- list(
  "openai/gpt-4o-mini" = list(prompt = 0.15, completion = 0.60),
  "openai/gpt-4o" = list(prompt = 2.50, completion = 10.00),
  "google/gemini-3.1-flash-lite-preview" = list(prompt = 0.10, completion = 0.40),
  "google/gemini-2.0-flash-001" = list(prompt = 0.10, completion = 0.40),
  "google/gemini-2.5-flash-preview-05-20" = list(prompt = 0.15, completion = 0.60),
  "anthropic/claude-sonnet-4" = list(prompt = 3.00, completion = 15.00),
  "openai/text-embedding-3-small" = list(prompt = 0.02, completion = 0.00),
  "openai/text-embedding-3-large" = list(prompt = 0.13, completion = 0.00),
  "openai/gpt-4.1-nano" = list(prompt = 0.10, completion = 0.40),
  "google/gemini-2.5-flash-lite" = list(prompt = 0.10, completion = 0.40)
)

# Default pricing for unknown models (conservative estimate)
DEFAULT_PRICING <- list(prompt = 1.00, completion = 3.00)

#' Cost operation display metadata
#'
#' Centralized here so the cost tracker UI does not duplicate stale switch blocks.
COST_OPERATION_META <- list(
  "chat" = list(label = "Chat", slot = "quality", icon_fun = "icon_comments", accent_class = "text-info"),
  "embedding" = list(label = "Embeddings", slot = "embedding", icon_fun = "icon_brain", accent_class = "text-secondary"),
  "query_build" = list(label = "Query Builder", slot = "fast", icon_fun = "icon_wand", accent_class = "text-warning"),
  "slide_generation" = list(label = "Slide Generation", slot = "quality", icon_fun = "icon_file_powerpoint", accent_class = "text-danger"),
  "slide_healing" = list(label = "Slide Healing", slot = "quality", icon_fun = "icon_wrench", accent_class = "text-warning"),
  "conclusion_synthesis" = list(label = "Conclusion Synthesis", slot = "quality", icon_fun = "icon_microscope", accent_class = "text-primary"),
  "overview" = list(label = "Overview", slot = "quality", icon_fun = "icon_layer_group", accent_class = "text-primary"),
  "overview_summary" = list(label = "Overview Summary", slot = "quality", icon_fun = "icon_clipboard", accent_class = "text-info"),
  "overview_keypoints" = list(label = "Overview Key Points", slot = "quality", icon_fun = "icon_key_points", accent_class = "text-success"),
  "research_questions" = list(label = "Research Questions", slot = "quality", icon_fun = "icon_lightbulb", accent_class = "text-warning"),
  "lit_review_table" = list(label = "Literature Review Table", slot = "quality", icon_fun = "icon_table", accent_class = "text-success"),
  "methodology_extractor" = list(label = "Methodology Extractor", slot = "quality", icon_fun = "icon_flask", accent_class = "text-danger"),
  "gap_analysis" = list(label = "Gap Analysis", slot = "quality", icon_fun = "icon_search", accent_class = "text-info"),
  "figure_description" = list(label = "Figure Description", slot = "quality", icon_fun = "icon_image", accent_class = "text-success"),
  "refiner_eval" = list(label = "Research Refiner", slot = "quality", icon_fun = "icon_funnel", accent_class = "text-warning"),
  "content_download" = list(label = "OA PDF Download", slot = NA, icon_fun = "icon_file_pdf", accent_class = "text-danger"),
  "openalex_search" = list(label = "OA Search", slot = NA, icon_fun = "icon_search", accent_class = "text-success"),
  "openalex_fetch" = list(label = "OA Fetch", slot = NA, icon_fun = "icon_download", accent_class = "text-success"),
  "openalex_topics" = list(label = "OA Topics", slot = "fast", icon_fun = "icon_layer_group", accent_class = "text-success"),
  "query_reformulation" = list(label = "Query Reformulation", slot = "fast", icon_fun = "icon_wand", accent_class = "text-info"),
  "theme_generation" = list(label = "Theme Generation", slot = "quality", icon_fun = "icon_wand", accent_class = "text-info")
)

KNOWN_MODEL_LABELS <- c(
  "openai/gpt-4o-mini" = "GPT-4o mini",
  "openai/gpt-4o" = "GPT-4o",
  "anthropic/claude-sonnet-4" = "Claude Sonnet 4",
  "google/gemini-3.1-flash-lite-preview" = "Gemini 3.1 Flash Lite",
  "google/gemini-2.0-flash-001" = "Gemini 2.0 Flash",
  "google/gemini-2.5-flash-preview-05-20" = "Gemini 2.5 Flash",
  "openai/text-embedding-3-small" = "Text Embedding 3 Small",
  "openai/text-embedding-3-large" = "Text Embedding 3 Large",
  "openai/gpt-4.1-nano" = "GPT-4.1 Nano",
  "google/gemini-2.5-flash-lite" = "Gemini 2.5 Flash Lite"
)

#' Update model pricing from live data
#'
#' @param models_df Data frame with columns: id, prompt_price, completion_price
#' @return NULL (modifies pricing_env$MODEL_PRICING in place)
update_model_pricing <- function(models_df) {
  if (is.null(models_df) || nrow(models_df) == 0) {
    return(invisible(NULL))
  }

  for (i in 1:nrow(models_df)) {
    row <- models_df[i, ]
    pricing_env$MODEL_PRICING[[row$id]] <- list(
      prompt = row$prompt_price,
      completion = row$completion_price
    )
  }

  invisible(NULL)
}

#' Estimate cost from token usage
#'
#' Returns $0 for models with no known pricing (e.g., local models).
#' Only falls back to DEFAULT_PRICING for OpenRouter models without
#' explicit pricing data.
#'
#' @param model Model ID string
#' @param prompt_tokens Number of prompt tokens
#' @param completion_tokens Number of completion tokens (default 0 for embeddings)
#' @param is_local Whether this model is served by a local provider (default FALSE)
#' @return Numeric USD cost
estimate_cost <- function(model, prompt_tokens, completion_tokens = 0, is_local = FALSE) {
  pricing <- pricing_env$MODEL_PRICING[[model]]

  # Local models with no pricing data are free

  if (is.null(pricing) && is_local) {
    return(0.0)
  }

  # Cloud models with no pricing fall back to conservative default
  pricing <- pricing %||% DEFAULT_PRICING

  # Calculate cost: (tokens / 1,000,000) * price_per_million
  prompt_cost <- (prompt_tokens / 1000000) * pricing$prompt
  completion_cost <- (completion_tokens / 1000000) * pricing$completion

  prompt_cost + completion_cost
}

#' Get display metadata for a logged cost operation
#'
#' @param operation Operation key stored in cost_log
#' @return Named list with label, icon_fun, and accent_class
get_cost_operation_meta <- function(operation) {
  operation <- as.character(operation %||% "")
  operation <- operation[1]

  if (is.na(operation) || !nzchar(trimws(operation))) {
    return(list(
      label = "Unknown Operation",
      icon_fun = "icon_dollar",
      accent_class = "text-secondary"
    ))
  }

  meta <- COST_OPERATION_META[[operation]]
  if (!is.null(meta)) {
    return(meta)
  }

  label <- gsub("_", " ", operation, fixed = TRUE)
  label <- tools::toTitleCase(label)

  list(
    label = label,
    icon_fun = "icon_dollar",
    accent_class = "text-secondary"
  )
}

#' Format a cost operation key for display
#'
#' @param operation Operation key stored in cost_log
#' @return Human-friendly label string
format_cost_operation_name <- function(operation) {
  get_cost_operation_meta(operation)$label
}

#' Format a model ID for display
#'
#' @param model Full model ID
#' @return Human-friendly label string
format_cost_model_name <- function(model) {
  model <- as.character(model %||% "")
  model <- model[1]

  if (is.na(model) || !nzchar(trimws(model))) {
    return("Unknown Model")
  }

  known <- unname(KNOWN_MODEL_LABELS[model])
  if (length(known) == 1 && !is.na(known)) {
    return(known)
  }

  stripped <- sub("^[^/]+/", "", model)
  stripped <- gsub("-preview-[0-9-]+$", "", stripped)
  stripped <- gsub("-latest$", "", stripped)
  stripped <- gsub("-", " ", stripped)
  tools::toTitleCase(stripped)
}

#' Log a cost record to the database
#'
#' @param con DuckDB connection
#' @param operation Operation type: "chat", "embedding", "query_build", "slide_generation"
#' @param model Model ID string
#' @param prompt_tokens Number of prompt tokens
#' @param completion_tokens Number of completion tokens (default 0)
#' @param total_tokens Total tokens (default sum of prompt + completion)
#' @param estimated_cost Estimated USD cost
#' @param session_id Shiny session ID for grouping costs
#' @param duration_ms Request duration in milliseconds (NULL if not captured)
#' @return Cost log record ID
log_cost <- function(con, operation, model, prompt_tokens, completion_tokens = 0,
                     total_tokens = NULL, estimated_cost, session_id,
                     duration_ms = NULL) {
  id <- UUIDgenerate()

  # Calculate total_tokens if not provided
  if (is.null(total_tokens)) {
    total_tokens <- prompt_tokens + completion_tokens
  }

  # Check if duration_ms column exists (migration 012 may not have run yet)
  has_duration <- tryCatch({
    cols <- DBI::dbListFields(con, "cost_log")
    "duration_ms" %in% cols
  }, error = function(e) FALSE)

  tryCatch({
    if (has_duration && !is.null(duration_ms)) {
      dbExecute(con, "
        INSERT INTO cost_log (id, session_id, operation, model, prompt_tokens, completion_tokens, total_tokens, estimated_cost, duration_ms)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ", list(
        id, session_id, operation, model,
        as.integer(prompt_tokens), as.integer(completion_tokens),
        as.integer(total_tokens), as.numeric(estimated_cost),
        as.integer(duration_ms)
      ))
    } else {
      dbExecute(con, "
        INSERT INTO cost_log (id, session_id, operation, model, prompt_tokens, completion_tokens, total_tokens, estimated_cost)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ", list(
        id, session_id, operation, model,
        as.integer(prompt_tokens), as.integer(completion_tokens),
        as.integer(total_tokens), as.numeric(estimated_cost)
      ))
    }
  }, error = function(e) {
    warning("Failed to log cost: ", e$message)
    return(invisible(NULL))
  })

  id
}

#' Get all cost records for a session
#'
#' @param con DuckDB connection
#' @param session_id Shiny session ID
#' @return Data frame of cost records with total_cost attribute
get_session_costs <- function(con, session_id) {
  costs <- dbGetQuery(con, "
    SELECT
      operation,
      model,
      prompt_tokens,
      completion_tokens,
      total_tokens,
      estimated_cost,
      created_at
    FROM cost_log
    WHERE session_id = ?
    ORDER BY created_at DESC
  ", list(session_id))

  # Calculate total cost
  total <- if (nrow(costs) > 0) sum(costs$estimated_cost) else 0

  # Attach as attribute
  attr(costs, "total_cost") <- total

  costs
}

#' Get cost history aggregated by day
#'
#' @param con DuckDB connection
#' @param days Number of days to look back (default 30)
#' @return Data frame with columns: date, total_cost, request_count, total_tokens
get_cost_history <- function(con, days = 30) {
  cutoff_date <- Sys.Date() - days

  dbGetQuery(con, "
    SELECT
      DATE(created_at) as date,
      SUM(estimated_cost) as total_cost,
      COUNT(*) as request_count,
      SUM(total_tokens) as total_tokens
    FROM cost_log
    WHERE DATE(created_at) >= ?
    GROUP BY DATE(created_at)
    ORDER BY date DESC
  ", list(as.character(cutoff_date)))
}

#' Get cost history grouped for interactive chart segments
#'
#' @param con DuckDB connection
#' @param days Number of days to look back (default 30)
#' @return Data frame grouped by date, operation, and model
get_cost_history_segments <- function(con, days = 30) {
  cutoff_date <- Sys.Date() - days

  segments <- dbGetQuery(con, "
    SELECT
      DATE(created_at) as date,
      operation,
      model,
      SUM(estimated_cost) as total_cost,
      COUNT(*) as request_count,
      SUM(prompt_tokens) as prompt_tokens,
      SUM(completion_tokens) as completion_tokens,
      SUM(total_tokens) as total_tokens
    FROM cost_log
    WHERE DATE(created_at) >= ?
    GROUP BY DATE(created_at), operation, model
    ORDER BY date ASC, total_cost DESC, operation ASC, model ASC
  ", list(as.character(cutoff_date)))

  if (nrow(segments) == 0) {
    segments$operation_label <- character(0)
    segments$model_label <- character(0)
    return(segments)
  }

  segments$date <- as.Date(segments$date)
  segments$operation_label <- vapply(segments$operation, format_cost_operation_name, character(1))
  segments$model_label <- vapply(segments$model, format_cost_model_name, character(1))

  segments
}

#' Get cost breakdown by operation type
#'
#' @param con DuckDB connection
#' @param days Number of days to look back (default 30)
#' @return Data frame with columns: operation, total_cost, request_count, avg_cost_per_request
get_cost_by_operation <- function(con, days = 30) {
  cutoff_date <- Sys.Date() - days
  rows <- dbGetQuery(con, "
    SELECT
      operation,
      model,
      SUM(estimated_cost) as total_cost,
      COUNT(*) as request_count,
      SUM(total_tokens) as total_tokens
    FROM cost_log
    WHERE DATE(created_at) >= ?
    GROUP BY operation, model
    ORDER BY operation ASC, total_cost DESC, model ASC
  ", list(as.character(cutoff_date)))

  if (nrow(rows) == 0) {
    return(data.frame(
      operation = character(0),
      operation_label = character(0),
      total_cost = numeric(0),
      request_count = integer(0),
      avg_cost_per_request = numeric(0),
      total_tokens = numeric(0),
      model_count = integer(0),
      models_used = character(0),
      top_models = character(0),
      stringsAsFactors = FALSE
    ))
  }

  rows$operation_label <- vapply(rows$operation, format_cost_operation_name, character(1))
  rows$model_label <- vapply(rows$model, format_cost_model_name, character(1))

  summarized <- lapply(split(rows, rows$operation), function(group) {
    group <- group[order(-group$total_cost, group$model_label), ]
    total_cost <- sum(group$total_cost)
    request_count <- sum(group$request_count)

    data.frame(
      operation = group$operation[1],
      operation_label = group$operation_label[1],
      total_cost = total_cost,
      request_count = request_count,
      avg_cost_per_request = if (request_count > 0) total_cost / request_count else 0,
      total_tokens = sum(group$total_tokens),
      model_count = length(unique(group$model)),
      models_used = paste(group$model_label, collapse = ", "),
      top_models = paste(
        head(sprintf("%s ($%.4f)", group$model_label, group$total_cost), 3),
        collapse = " | "
      ),
      stringsAsFactors = FALSE
    )
  })

  summary_df <- do.call(rbind, summarized)
  rownames(summary_df) <- NULL
  summary_df[order(summary_df$total_cost, decreasing = TRUE), ]
}

# --- Latency Queries ---

#' Get average latency per model
#'
#' @param con DuckDB connection
#' @param days Number of days to look back (default 7)
#' @return Data frame with columns: model, avg_latency_ms, p50_latency_ms, p95_latency_ms, call_count
get_latency_by_model <- function(con, days = 7) {
  has_col <- tryCatch("duration_ms" %in% DBI::dbListFields(con, "cost_log"), error = function(e) FALSE)
  if (!has_col) {
    return(data.frame(
      model = character(), avg_latency_ms = numeric(),
      p50_latency_ms = numeric(), p95_latency_ms = numeric(),
      call_count = integer(), stringsAsFactors = FALSE
    ))
  }

  cutoff_date <- Sys.Date() - days

  dbGetQuery(con, "
    SELECT
      model,
      CAST(AVG(duration_ms) AS INTEGER) as avg_latency_ms,
      CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration_ms) AS INTEGER) as p50_latency_ms,
      CAST(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) AS INTEGER) as p95_latency_ms,
      COUNT(*) as call_count
    FROM cost_log
    WHERE duration_ms IS NOT NULL
      AND DATE(created_at) >= ?
    GROUP BY model
    ORDER BY avg_latency_ms DESC
  ", list(as.character(cutoff_date)))
}

#' Get average latency per operation type
#'
#' @param con DuckDB connection
#' @param days Number of days to look back (default 7)
#' @return Data frame with columns: operation, avg_latency_ms, p50_latency_ms, p95_latency_ms, call_count
get_latency_by_operation <- function(con, days = 7) {
  has_col <- tryCatch("duration_ms" %in% DBI::dbListFields(con, "cost_log"), error = function(e) FALSE)
  if (!has_col) {
    return(data.frame(
      operation = character(), avg_latency_ms = numeric(),
      p50_latency_ms = numeric(), p95_latency_ms = numeric(),
      call_count = integer(), stringsAsFactors = FALSE
    ))
  }

  cutoff_date <- Sys.Date() - days

  dbGetQuery(con, "
    SELECT
      operation,
      CAST(AVG(duration_ms) AS INTEGER) as avg_latency_ms,
      CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration_ms) AS INTEGER) as p50_latency_ms,
      CAST(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) AS INTEGER) as p95_latency_ms,
      COUNT(*) as call_count
    FROM cost_log
    WHERE duration_ms IS NOT NULL
      AND DATE(created_at) >= ?
    GROUP BY operation
    ORDER BY avg_latency_ms DESC
  ", list(as.character(cutoff_date)))
}

#' Get daily latency trend
#'
#' @param con DuckDB connection
#' @param days Number of days to look back (default 30)
#' @return Data frame with columns: date, avg_latency_ms, call_count
get_latency_trend <- function(con, days = 30) {
  has_col <- tryCatch("duration_ms" %in% DBI::dbListFields(con, "cost_log"), error = function(e) FALSE)
  if (!has_col) {
    return(data.frame(
      date = as.Date(character()), avg_latency_ms = numeric(),
      call_count = integer(), stringsAsFactors = FALSE
    ))
  }

  cutoff_date <- Sys.Date() - days

  result <- dbGetQuery(con, "
    SELECT
      DATE(created_at) as date,
      CAST(AVG(duration_ms) AS INTEGER) as avg_latency_ms,
      COUNT(*) as call_count
    FROM cost_log
    WHERE duration_ms IS NOT NULL
      AND DATE(created_at) >= ?
    GROUP BY DATE(created_at)
    ORDER BY date ASC
  ", list(as.character(cutoff_date)))

  if (nrow(result) > 0) {
    result$date <- as.Date(result$date)
  }

  result
}

#' Get overall average latency
#'
#' @param con DuckDB connection
#' @param days Number of days to look back (default 7)
#' @return Named list with avg_latency_ms, total_calls, or NULL if no data
get_latency_summary <- function(con, days = 7) {
  has_col <- tryCatch("duration_ms" %in% DBI::dbListFields(con, "cost_log"), error = function(e) FALSE)
  if (!has_col) return(NULL)

  cutoff_date <- Sys.Date() - days

  row <- dbGetQuery(con, "
    SELECT
      CAST(AVG(duration_ms) AS INTEGER) as avg_latency_ms,
      COUNT(*) as total_calls
    FROM cost_log
    WHERE duration_ms IS NOT NULL
      AND DATE(created_at) >= ?
  ", list(as.character(cutoff_date)))

  if (nrow(row) == 0 || is.na(row$avg_latency_ms[1]) || row$total_calls[1] == 0) {
    return(NULL)
  }

  list(avg_latency_ms = row$avg_latency_ms[1], total_calls = row$total_calls[1])
}

# --- OpenAlex Usage Queries ---

#' Get today's aggregated OA usage
#'
#' @param con DuckDB connection
#' @return Named list with total_credits_used, remaining, daily_limit, request_count, last_updated
get_oa_daily_usage <- function(con) {
  has_table <- tryCatch(DBI::dbExistsTable(con, "oa_usage_log"), error = function(e) FALSE)
  if (!has_table) {
    return(list(total_credits_used = 0, remaining = NA_real_,
                daily_limit = NA_real_, request_count = 0L,
                last_updated = NA))
  }

  today <- as.character(as.Date(as.POSIXct(Sys.time(), tz = "UTC")))

  row <- dbGetQuery(con, "
    SELECT
      COALESCE(SUM(credits_used), 0) as total_credits_used,
      COUNT(*) as request_count
    FROM oa_usage_log
    WHERE DATE(created_at) = ?
  ", list(today))

  # Get the latest remaining/limit from most recent row today
  latest <- dbGetQuery(con, "
    SELECT remaining, daily_limit, created_at
    FROM oa_usage_log
    WHERE DATE(created_at) = ?
    ORDER BY created_at DESC
    LIMIT 1
  ", list(today))

  list(
    total_credits_used = row$total_credits_used,
    remaining = if (nrow(latest) > 0) latest$remaining else NA_real_,
    daily_limit = if (nrow(latest) > 0) latest$daily_limit else NA_real_,
    request_count = as.integer(row$request_count),
    last_updated = if (nrow(latest) > 0) latest$created_at else NA
  )
}

#' Get OA usage history aggregated by day
#'
#' @param con DuckDB connection
#' @param days Number of days to look back (default 30)
#' @return Data frame with columns: date, total_credits_used, request_count
get_oa_usage_history <- function(con, days = 30) {
  has_table <- tryCatch(DBI::dbExistsTable(con, "oa_usage_log"), error = function(e) FALSE)
  if (!has_table) {
    return(data.frame(
      date = as.Date(character()), total_credits_used = numeric(),
      request_count = integer(), stringsAsFactors = FALSE
    ))
  }

  cutoff_date <- Sys.Date() - days

  result <- dbGetQuery(con, "
    SELECT
      DATE(created_at) as date,
      COALESCE(SUM(credits_used), 0) as total_credits_used,
      COUNT(*) as request_count
    FROM oa_usage_log
    WHERE DATE(created_at) >= ?
    GROUP BY DATE(created_at)
    ORDER BY date ASC
  ", list(as.character(cutoff_date)))

  if (nrow(result) > 0) {
    result$date <- as.Date(result$date)
  }

  result
}

#' Calculate OA budget percentage consumed
#'
#' @param remaining Credits remaining (numeric or NA)
#' @param daily_limit Daily credit limit (numeric or NA)
#' @return Integer percentage (0-100) or NA if data unavailable
oa_budget_percentage <- function(remaining, daily_limit) {
  if (is.na(remaining) || is.na(daily_limit) || daily_limit <= 0) return(NA_integer_)
  as.integer(floor((1 - remaining / daily_limit) * 100))
}

#' Get CSS color class for OA budget percentage
#'
#' @param pct Budget percentage (integer or NA)
#' @return Character: "success", "warning", "danger", or NULL for NA
oa_budget_color <- function(pct) {
  if (is.na(pct)) return(NULL)
  if (pct < 60) "success"
  else if (pct < 85) "warning"
  else "danger"
}

#' Check if the 90% OA usage toast should fire
#'
#' Fires once per UTC calendar day when budget >= 90%.
#'
#' @param con DuckDB connection
#' @param pct Current budget percentage
#' @return logical
oa_toast_should_fire <- function(con, pct) {
  if (is.na(pct) || pct < 90) return(FALSE)

  today <- as.character(as.Date(as.POSIXct(Sys.time(), tz = "UTC")))
  last_fired <- tryCatch(get_db_setting(con, "oa_toast_last_fired_date"), error = function(e) NULL)

  if (!is.null(last_fired) && last_fired == today) return(FALSE)

  TRUE
}

#' Record that the OA toast was fired today
#'
#' @param con DuckDB connection
oa_toast_mark_fired <- function(con) {
  save_db_setting(con, "oa_toast_last_fired_date", as.character(as.Date(as.POSIXct(Sys.time(), tz = "UTC"))))
}
