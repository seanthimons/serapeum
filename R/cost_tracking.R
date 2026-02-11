library(DBI)
library(uuid)

#' OpenRouter model pricing table (USD per million tokens)
#'
#' Prices are stored as "per million tokens" for readability.
#' Embedding models typically don't charge for completion tokens.
MODEL_PRICING <- list(
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

#' Estimate cost from token usage
#'
#' @param model Model ID string
#' @param prompt_tokens Number of prompt tokens
#' @param completion_tokens Number of completion tokens (default 0 for embeddings)
#' @return Numeric USD cost
estimate_cost <- function(model, prompt_tokens, completion_tokens = 0) {
  # Get pricing for this model, or use default
  pricing <- MODEL_PRICING[[model]] %||% DEFAULT_PRICING

  # Calculate cost: (tokens / 1,000,000) * price_per_million
  prompt_cost <- (prompt_tokens / 1000000) * pricing$prompt
  completion_cost <- (completion_tokens / 1000000) * pricing$completion

  prompt_cost + completion_cost
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

#' Get cost breakdown by operation type
#'
#' @param con DuckDB connection
#' @param days Number of days to look back (default 30)
#' @return Data frame with columns: operation, total_cost, request_count, avg_cost_per_request
get_cost_by_operation <- function(con, days = 30) {
  cutoff_date <- Sys.Date() - days

  dbGetQuery(con, "
    SELECT
      operation,
      SUM(estimated_cost) as total_cost,
      COUNT(*) as request_count,
      AVG(estimated_cost) as avg_cost_per_request
    FROM cost_log
    WHERE DATE(created_at) >= ?
    GROUP BY operation
    ORDER BY total_cost DESC
  ", list(as.character(cutoff_date)))
}
