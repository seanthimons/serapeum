# Refresh Artificial Analysis model benchmarks
#
# Usage:
#   Rscript data/support/refresh_aa_data.R <AA_API_KEY>
#
# Fetches latest model data from the Artificial Analysis API and saves
# as data/support/aa_models.rds for bundling with the app.

library(httr2)
library(jsonlite)

AA_API_URL <- "https://artificialanalysis.ai/api/v2/data/llms/models"

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1 || nchar(args[1]) == 0) {
  stop("Usage: Rscript data/support/refresh_aa_data.R <AA_API_KEY>")
}
api_key <- args[1]

message("[AA] Fetching models from Artificial Analysis API...")

resp <- request(AA_API_URL) |>
  req_headers("x-api-key" = api_key) |>
  req_timeout(30) |>
  req_perform()

body <- resp_body_json(resp)

# API returns an array of model objects (or nested under $data)
models <- if (is.list(body) && !is.null(body$data)) body$data else body

message("[AA] Received ", length(models), " models")

# Extract fields we care about
extract_field <- function(m, ...) {
  keys <- list(...)
  for (key_path in keys) {
    val <- m
    for (k in key_path) {
      val <- val[[k]]
      if (is.null(val)) break
    }
    if (!is.null(val)) return(val)
  }
  NA
}

df <- data.frame(
  aa_model_id = vapply(models, function(m) {
    as.character(extract_field(m, "id", "aa_model_id"))
  }, character(1)),
  aa_model_name = vapply(models, function(m) {
    as.character(extract_field(m, "name", "aa_model_name"))
  }, character(1)),
  aa_model_slug = vapply(models, function(m) {
    as.character(extract_field(m, "slug", "aa_model_slug"))
  }, character(1)),
  creator_name = vapply(models, function(m) {
    as.character(extract_field(m, c("model_creator", "name"), "creator_name"))
  }, character(1)),
  intelligence_index = vapply(models, function(m) {
    as.numeric(extract_field(m,
      c("evaluations", "artificial_analysis_intelligence_index"),
      "intelligence_index"))
  }, numeric(1)),
  coding_index = vapply(models, function(m) {
    as.numeric(extract_field(m,
      c("evaluations", "artificial_analysis_coding_index"),
      "coding_index"))
  }, numeric(1)),
  tokens_per_second = vapply(models, function(m) {
    as.numeric(extract_field(m, "median_output_tokens_per_second", "tokens_per_second"))
  }, numeric(1)),
  ttft_seconds = vapply(models, function(m) {
    as.numeric(extract_field(m, "median_time_to_first_token_seconds", "ttft_seconds"))
  }, numeric(1)),
  price_input_1m = vapply(models, function(m) {
    as.numeric(extract_field(m, c("pricing", "price_1m_input_tokens"), "price_input_1m"))
  }, numeric(1)),
  price_output_1m = vapply(models, function(m) {
    as.numeric(extract_field(m, c("pricing", "price_1m_output_tokens"), "price_output_1m"))
  }, numeric(1)),
  price_blended_1m = vapply(models, function(m) {
    as.numeric(extract_field(m, c("pricing", "price_1m_blended_3_to_1"), "price_blended_1m"))
  }, numeric(1)),
  stringsAsFactors = FALSE
)

# Drop models with no name or slug
df <- df[!is.na(df$aa_model_name) & nchar(df$aa_model_name) > 0, ]

out_path <- file.path("data", "support", "aa_models.rds")
saveRDS(df, out_path)

message("[AA] Saved ", nrow(df), " models to ", out_path)
message("[AA] Preview:")
print(head(df[, c("aa_model_name", "creator_name", "intelligence_index",
                   "tokens_per_second", "price_blended_1m")], 10))
