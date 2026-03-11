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
  "google/gemini-2.0-flash-001" = list(prompt = 0.10, completion = 0.40),
  "google/gemini-2.5-flash-preview-05-20" = list(prompt = 0.15, completion = 0.60),
  "anthropic/claude-sonnet-4" = list(prompt = 3.00, completion = 15.00),
  "openai/text-embedding-3-small" = list(prompt = 0.02, completion = 0.00),
  "openai/text-embedding-3-large" = list(prompt = 0.13, completion = 0.00)
)

# Default pricing for unknown models (conservative estimate)
DEFAULT_PRICING <- list(prompt = 1.00, completion = 3.00)

#' Cost operation display metadata
#'
#' Centralized here so the cost tracker UI does not duplicate stale switch blocks.
COST_OPERATION_META <- list(
  "chat" = list(label = "Chat", icon_fun = "icon_comments", accent_class = "text-info"),
  "embedding" = list(label = "Embeddings", icon_fun = "icon_brain", accent_class = "text-secondary"),
  "query_build" = list(label = "Query Builder", icon_fun = "icon_wand", accent_class = "text-warning"),
  "slide_generation" = list(label = "Slide Generation", icon_fun = "icon_file_powerpoint", accent_class = "text-danger"),
  "slide_healing" = list(label = "Slide Healing", icon_fun = "icon_wrench", accent_class = "text-warning"),
  "conclusion_synthesis" = list(label = "Conclusion Synthesis", icon_fun = "icon_microscope", accent_class = "text-primary"),
  "overview" = list(label = "Overview", icon_fun = "icon_layer_group", accent_class = "text-primary"),
  "overview_summary" = list(label = "Overview Summary", icon_fun = "icon_clipboard", accent_class = "text-info"),
  "overview_keypoints" = list(label = "Overview Key Points", icon_fun = "icon_key_points", accent_class = "text-success"),
  "research_questions" = list(label = "Research Questions", icon_fun = "icon_lightbulb", accent_class = "text-warning"),
  "lit_review_table" = list(label = "Literature Review Table", icon_fun = "icon_table", accent_class = "text-success"),
  "methodology_extractor" = list(label = "Methodology Extractor", icon_fun = "icon_flask", accent_class = "text-danger"),
  "gap_analysis" = list(label = "Gap Analysis", icon_fun = "icon_search", accent_class = "text-info")
)

KNOWN_MODEL_LABELS <- c(
  "openai/gpt-4o-mini" = "GPT-4o mini",
  "openai/gpt-4o" = "GPT-4o",
  "anthropic/claude-sonnet-4" = "Claude Sonnet 4",
  "google/gemini-2.0-flash-001" = "Gemini 2.0 Flash",
  "google/gemini-2.5-flash-preview-05-20" = "Gemini 2.5 Flash",
  "openai/text-embedding-3-small" = "Text Embedding 3 Small",
  "openai/text-embedding-3-large" = "Text Embedding 3 Large"
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
#' @param model Model ID string
#' @param prompt_tokens Number of prompt tokens
#' @param completion_tokens Number of completion tokens (default 0 for embeddings)
#' @return Numeric USD cost
estimate_cost <- function(model, prompt_tokens, completion_tokens = 0) {
  # Get pricing for this model, or use default
  pricing <- pricing_env$MODEL_PRICING[[model]] %||% DEFAULT_PRICING

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
#' @return Cost log record ID
log_cost <- function(con, operation, model, prompt_tokens, completion_tokens = 0,
                     total_tokens = NULL, estimated_cost, session_id) {
  id <- UUIDgenerate()

  # Calculate total_tokens if not provided
  if (is.null(total_tokens)) {
    total_tokens <- prompt_tokens + completion_tokens
  }

  dbExecute(con, "
    INSERT INTO cost_log (id, session_id, operation, model, prompt_tokens, completion_tokens, total_tokens, estimated_cost)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  ", list(
    id,
    session_id,
    operation,
    model,
    as.integer(prompt_tokens),
    as.integer(completion_tokens),
    as.integer(total_tokens),
    as.numeric(estimated_cost)
  ))

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
