# ==============================================================================
# Stage 5 Prototype: Vision Model Figure Description
# ==============================================================================
#
# Sends extracted figure PNGs to a vision model via OpenRouter to generate
# structured descriptions for academic figure enrichment.
#
# Usage:
#   1. Set SMOKE <- TRUE for a single-figure test, FALSE for full batch
#   2. Set INPUT_DIR to the directory containing extracted PNGs
#   3. Run from IDE or Rscript
#
# Requires: httr2, jsonlite, base64enc
# ==============================================================================

library(httr2)
library(jsonlite)
library(base64enc)

# ── Config ───────────────────────────────────────────────────────────────────

SMOKE       <- TRUE                          # TRUE = process 1 figure only
INPUT_DIR   <- "extracted_figures"            # Directory with PNGs from Stage 1
OUT_CSV     <- "vision_descriptions.csv"      # Output manifest

# Vision model config
VISION_CONFIG <- list(
  primary_model   = "openai/gpt-4.1-nano",
  fallback_model  = "google/gemini-2.5-flash-lite",
  max_tokens      = 500,
  temperature     = 0.2,                     # Low temp for factual descriptions
  timeout_secs    = 60,
  retry_on_fail   = TRUE                     # Try fallback if primary fails
)

# ── API Key ──────────────────────────────────────────────────────────────────

get_api_key <- function() {
  # Try config.yml first (matches app behavior)
  if (file.exists("config.yml")) {
    cfg <- yaml::read_yaml("config.yml")
    key <- cfg$openrouter$api_key
    if (!is.null(key) && nchar(key) > 0) return(key)
  }

  # Fall back to env var
  key <- Sys.getenv("OPENROUTER_API_KEY", unset = "")
  if (nchar(key) > 0) return(key)

  stop("No OpenRouter API key found. Set in config.yml or OPENROUTER_API_KEY env var.")
}

# ── Vision API Call ──────────────────────────────────────────────────────────

#' Encode a PNG file as a base64 data URL
#' @param file_path Path to PNG file
#' @return data URL string
encode_image_base64 <- function(file_path) {
  raw_bytes <- readBin(file_path, "raw", file.info(file_path)$size)
  b64 <- base64enc::base64encode(raw_bytes)
  paste0("data:image/png;base64,", b64)
}

#' Build the system prompt for academic figure description
build_figure_system_prompt <- function() {
  "You are an expert at analyzing figures from academic papers. For each figure image, provide a structured description with the following fields:

1. **type**: The figure type. One of: chart, plot, diagram, photograph, micrograph, schematic, table, map, flowchart, illustration, composite, other
2. **summary**: A 1-2 sentence plain-language summary of what the figure shows
3. **details**: Key observations — axes, trends, notable data points, labels, or structural elements visible in the figure
4. **suggested_caption**: A concise, publication-quality caption (if the original caption is missing or unclear)

Respond in JSON format with these exact keys: type, summary, details, suggested_caption

Be precise and scientific. If you cannot determine something, say so rather than guessing."
}

#' Build a vision message with image content
#' @param image_path Path to PNG file
#' @param figure_label Optional figure label (e.g., "Figure 3")
#' @param extracted_caption Optional existing caption text
#' @return List of messages for chat_completion
build_vision_messages <- function(image_path, figure_label = NULL, extracted_caption = NULL) {
  system_msg <- list(
    role = "system",
    content = build_figure_system_prompt()
  )

  # Build user prompt with context
  user_text <- "Describe this figure from an academic paper."
  if (!is.null(figure_label) && !is.na(figure_label) && nchar(figure_label) > 0) {
    user_text <- paste0(user_text, "\nLabel: ", figure_label)
  }
  if (!is.null(extracted_caption) && !is.na(extracted_caption) && nchar(extracted_caption) > 0) {
    user_text <- paste0(user_text, "\nExtracted caption: ", extracted_caption)
  }
  user_text <- paste0(user_text, "\n\nRespond with JSON only.")

  # Multipart content: text + image
  image_url <- encode_image_base64(image_path)

  user_msg <- list(
    role = "user",
    content = list(
      list(type = "text", text = user_text),
      list(type = "image_url", image_url = list(url = image_url))
    )
  )

  list(system_msg, user_msg)
}

#' Send a vision request to OpenRouter
#' @param api_key OpenRouter API key
#' @param model Model ID
#' @param messages Message list (with image content)
#' @param max_tokens Max response tokens
#' @param temperature Sampling temperature
#' @param timeout_secs Request timeout
#' @return List with content, usage, model, id
vision_completion <- function(api_key, model, messages,
                               max_tokens = 500, temperature = 0.2,
                               timeout_secs = 60) {
  req <- request("https://openrouter.ai/api/v1/chat/completions") |>
    req_headers(
      "Authorization" = paste("Bearer", api_key),
      "Content-Type" = "application/json"
    ) |>
    req_body_json(list(
      model = model,
      messages = messages,
      max_tokens = max_tokens,
      temperature = temperature
    )) |>
    req_timeout(timeout_secs)

  resp <- req_perform(req)
  body <- resp_body_json(resp)

  if (!is.null(body$error)) {
    stop("OpenRouter error: ", body$error$message)
  }

  msg <- body$choices[[1]]$message

  # Extract content — handle reasoning models that put output in reasoning field
  content <- msg$content

  # If content is NULL, check reasoning/reasoning_details (o-series / GPT-5 nano)
  if (is.null(content) || (is.character(content) && nchar(content) == 0)) {
    if (!is.null(msg$reasoning)) {
      content <- msg$reasoning
    } else if (!is.null(msg$reasoning_details)) {
      # reasoning_details is a list of content parts
      parts <- msg$reasoning_details
      text_parts <- vapply(parts, function(p) {
        if (is.list(p) && !is.null(p$content)) p$content
        else if (is.character(p)) p
        else ""
      }, character(1))
      content <- paste(text_parts, collapse = "\n")
    }
  }

  # Some models return content as a list of parts instead of a string
  if (is.list(content) && !is.null(content)) {
    text_parts <- vapply(content, function(p) {
      if (is.list(p) && !is.null(p$text)) p$text
      else if (is.character(p)) p
      else ""
    }, character(1))
    content <- paste(text_parts, collapse = "\n")
  }

  list(
    content = content,
    usage = body$usage,
    model = model,
    id = body$id
  )
}

#' Describe a single figure with vision model, with fallback
#' @param api_key API key
#' @param image_path Path to PNG
#' @param figure_label Optional label
#' @param extracted_caption Optional caption
#' @param config Vision config list
#' @return List with description fields + usage metadata
describe_figure <- function(api_key, image_path, figure_label = NULL,
                            extracted_caption = NULL, config = VISION_CONFIG) {
  messages <- build_vision_messages(image_path, figure_label, extracted_caption)

  result <- tryCatch({
    cat("  Calling", config$primary_model, "... ")
    r <- vision_completion(api_key, config$primary_model, messages,
                           config$max_tokens, config$temperature, config$timeout_secs)
    cat("OK\n")
    r$model_used <- config$primary_model
    r
  }, error = function(e) {
    cat("FAILED:", conditionMessage(e), "\n")
    if (config$retry_on_fail) {
      cat("  Retrying with", config$fallback_model, "... ")
      r <- tryCatch({
        r <- vision_completion(api_key, config$fallback_model, messages,
                               config$max_tokens, config$temperature, config$timeout_secs)
        cat("OK\n")
        r$model_used <- config$fallback_model
        r
      }, error = function(e2) {
        cat("FAILED:", conditionMessage(e2), "\n")
        NULL
      })
      r
    } else {
      NULL
    }
  })

  if (is.null(result)) {
    return(list(
      success = FALSE,
      error = "Both primary and fallback models failed",
      image_path = image_path
    ))
  }

  # Parse JSON response
  parsed <- tryCatch({
    # Strip markdown code fences if present
    raw_content <- result$content
    raw_content <- gsub("^```json\\s*\n?", "", raw_content)
    raw_content <- gsub("^```\\s*\n?", "", raw_content)
    raw_content <- gsub("\n?\\s*```\\s*$", "", raw_content)
    raw_content <- trimws(raw_content)
    fromJSON(raw_content)
  }, error = function(e) {
    cat("  Warning: Could not parse JSON response, using raw text\n")
    list(
      type = "unknown",
      summary = result$content,  # Use raw response as summary
      details = NA_character_,
      suggested_caption = NA_character_
    )
  })

  list(
    success = TRUE,
    image_path = image_path,
    figure_label = figure_label,
    extracted_caption = extracted_caption,
    type = parsed$type %||% "unknown",
    summary = parsed$summary %||% NA_character_,
    details = parsed$details %||% NA_character_,
    suggested_caption = parsed$suggested_caption %||% NA_character_,
    model_used = result$model_used,
    prompt_tokens = result$usage$prompt_tokens %||% 0,
    completion_tokens = result$usage$completion_tokens %||% 0
  )
}

# ── Batch Processing ─────────────────────────────────────────────────────────

#' Find all figure PNGs and their metadata from manifest
#' @param input_dir Directory containing extracted figures
#' @return Data frame with file paths and metadata
find_figures <- function(input_dir) {
  # Look for manifest CSV from Stage 1 prototype
  manifest_path <- file.path(input_dir, "manifest_all.csv")

  if (file.exists(manifest_path)) {
    manifest <- read.csv(manifest_path, stringsAsFactors = FALSE)
    # Normalize column name — Stage 1 manifest uses "file_path"
    if ("file_path" %in% names(manifest) && !"output_file" %in% names(manifest)) {
      manifest$output_file <- manifest$file_path
    }
    # Verify files exist
    exists_mask <- vapply(manifest$output_file, file.exists, logical(1))
    manifest <- manifest[exists_mask, ]
    cat("Found", nrow(manifest), "figures from manifest\n")
    return(manifest)
  }

  # Fallback: scan for PNGs directly
  pngs <- list.files(input_dir, pattern = "\\.png$", recursive = TRUE, full.names = TRUE)
  cat("Found", length(pngs), "PNG files (no manifest)\n")

  data.frame(
    output_file = pngs,
    figure_label = NA_character_,
    caption_text = NA_character_,
    stringsAsFactors = FALSE
  )
}

#' Process all figures through vision model
#' @param figures Data frame from find_figures()
#' @param api_key OpenRouter API key
#' @param config Vision config
#' @return Data frame with descriptions
process_figures <- function(figures, api_key, config = VISION_CONFIG) {
  results <- vector("list", nrow(figures))
  total_prompt <- 0
  total_completion <- 0

  for (i in seq_len(nrow(figures))) {
    fig <- figures[i, ]
    cat(sprintf("[%d/%d] %s\n", i, nrow(figures), basename(fig$output_file)))

    result <- describe_figure(
      api_key = api_key,
      image_path = fig$output_file,
      figure_label = if ("figure_label" %in% names(fig)) fig$figure_label else NULL,
      extracted_caption = if ("caption" %in% names(fig)) fig$caption
                          else if ("caption_text" %in% names(fig)) fig$caption_text
                          else NULL,
      config = config
    )

    results[[i]] <- result

    if (result$success) {
      total_prompt <- total_prompt + result$prompt_tokens
      total_completion <- total_completion + result$completion_tokens
    }

    # Brief pause to respect rate limits
    if (i < nrow(figures)) Sys.sleep(0.5)
  }

  cat(sprintf("\nDone. Tokens used: %d prompt + %d completion = %d total\n",
              total_prompt, total_completion, total_prompt + total_completion))

  # Convert to data frame
  do.call(rbind, lapply(results, function(r) {
    data.frame(
      image_path = r$image_path,
      success = r$success,
      figure_label = r$figure_label %||% NA_character_,
      extracted_caption = r$extracted_caption %||% NA_character_,
      type = r$type %||% NA_character_,
      summary = r$summary %||% NA_character_,
      details = r$details %||% NA_character_,
      suggested_caption = r$suggested_caption %||% NA_character_,
      model_used = r$model_used %||% NA_character_,
      prompt_tokens = r$prompt_tokens %||% 0,
      completion_tokens = r$completion_tokens %||% 0,
      stringsAsFactors = FALSE
    )
  }))
}

# ── Main ─────────────────────────────────────────────────────────────────────

main <- function() {
  cat("=== Stage 5: Vision Model Figure Description ===\n\n")

  api_key <- get_api_key()
  cat("API key loaded\n")
  cat("Primary model:", VISION_CONFIG$primary_model, "\n")
  cat("Fallback model:", VISION_CONFIG$fallback_model, "\n\n")

  # Find figures
  figures <- find_figures(INPUT_DIR)

  if (nrow(figures) == 0) {
    cat("No figures found in", INPUT_DIR, "\n")
    return(invisible(NULL))
  }

  # Smoke test: just process first figure
  if (SMOKE) {
    cat("SMOKE mode: processing first figure only\n\n")
    figures <- figures[1, , drop = FALSE]
  }

  # Process
  results <- process_figures(figures, api_key)

  # Save results
  write.csv(results, OUT_CSV, row.names = FALSE)
  cat("\nResults saved to", OUT_CSV, "\n")

  # Print summary
  cat("\n=== Summary ===\n")
  cat("Figures processed:", nrow(results), "\n")
  cat("Successful:", sum(results$success), "\n")
  cat("Failed:", sum(!results$success), "\n")

  if (any(results$success)) {
    cat("\nFigure types found:\n")
    type_counts <- table(results$type[results$success])
    for (t in names(type_counts)) {
      cat(sprintf("  %-15s %d\n", t, type_counts[t]))
    }
  }

  # Print first result as example
  if (nrow(results) > 0 && results$success[1]) {
    cat("\n=== Example (first figure) ===\n")
    cat("File:", results$image_path[1], "\n")
    cat("Type:", results$type[1], "\n")
    cat("Summary:", results$summary[1], "\n")
    cat("Details:", results$details[1], "\n")
    if (!is.na(results$suggested_caption[1])) {
      cat("Suggested caption:", results$suggested_caption[1], "\n")
    }
  }

  invisible(results)
}

main()
