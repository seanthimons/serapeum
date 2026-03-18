# ==============================================================================
# PDF Image Pipeline — File Utilities, Vision, & Orchestrator (Epic #44)
#
# File utilities (Stage 2), vision description (Stage 5), and the high-level
# extract_and_describe_figures() orchestrator that ties Stages 1-5 together.
# ==============================================================================

#' Get the base directory for figure storage
#' @return Path to figures root directory
figures_base_dir <- function() {
  "data/figures"
}

#' Create figure directory for a document
#'
#' Creates the nested directory structure: data/figures/{notebook_id}/{document_id}/
#'
#' @param notebook_id Notebook ID
#' @param document_id Document ID (optional, creates notebook-level dir if NULL)
#' @return Path to the created directory
create_figure_dir <- function(notebook_id, document_id = NULL) {
  path <- if (is.null(document_id)) {
    file.path(figures_base_dir(), notebook_id)
  } else {
    file.path(figures_base_dir(), notebook_id, document_id)
  }

  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}

#' Save a figure image to disk
#'
#' Writes a PNG image to the figure storage directory and returns the
#' relative path (relative to project root) for storage in the database.
#'
#' @param image_data Raw vector of PNG data, or a file path to copy from
#' @param notebook_id Notebook ID
#' @param document_id Document ID
#' @param page Page number
#' @param index Figure index on that page (1-based)
#' @return Relative file path (e.g., "data/figures/{nb_id}/{doc_id}/fig_3_1.png")
save_figure <- function(image_data, notebook_id, document_id, page, index = 1L) {
  dir_path <- create_figure_dir(notebook_id, document_id)
  filename <- sprintf("fig_%03d_%d.png", as.integer(page), as.integer(index))
  file_path <- file.path(dir_path, filename)

  if (is.character(image_data) && file.exists(image_data)) {
    # Copy from source path
    file.copy(image_data, file_path, overwrite = TRUE)
  } else if (is.raw(image_data)) {
    # Write raw PNG bytes
    writeBin(image_data, file_path)
  } else {
    stop("image_data must be a raw vector or an existing file path")
  }

  file_path
}

#' Clean up figure files for a document or notebook
#'
#' Deletes the figure directory and all contents. When called with only
#' notebook_id, deletes the entire notebook's figure directory. When called
#' with both, deletes only that document's subdirectory.
#'
#' @param notebook_id Notebook ID
#' @param document_id Document ID (optional)
cleanup_figure_files <- function(notebook_id, document_id = NULL) {
  path <- if (is.null(document_id)) {
    file.path(figures_base_dir(), notebook_id)
  } else {
    file.path(figures_base_dir(), notebook_id, document_id)
  }

  if (dir.exists(path)) {
    unlink(path, recursive = TRUE)
  }

  invisible(TRUE)
}


# ==============================================================================
# Vision Description (Stage 5)
# ==============================================================================

#' Default vision model configuration
#' @return Named list of vision config values
figure_vision_config <- function() {
  list(
    primary_model  = "openai/gpt-4.1-nano",
    fallback_model = "google/gemini-2.5-flash-lite",
    max_tokens     = 500,
    temperature    = 0.2,
    timeout        = 60
  )
}

#' Build the system prompt for academic figure description
#' @return Character string
#' @keywords internal
build_figure_system_prompt <- function() {
  paste0(
    "You are an expert at analyzing figures from academic papers. ",
    "For each figure image, provide a structured description with these fields:\n\n",
    "1. **type**: One of: chart, plot, diagram, photograph, micrograph, schematic, ",
    "table, map, flowchart, illustration, composite, other\n",
    "2. **summary**: A 1-2 sentence plain-language summary of what the figure shows\n",
    "3. **details**: Key observations — axes, trends, notable data points, labels, ",
    "or structural elements\n",
    "4. **suggested_caption**: A concise, publication-quality caption\n\n",
    "Respond in JSON format with these exact keys: type, summary, details, suggested_caption\n\n",
    "Be precise and scientific. If you cannot determine something, say so rather than guessing."
  )
}

#' Build vision API messages for a figure
#'
#' @param image_data Raw PNG bytes or a file path to a PNG
#' @param figure_label Optional figure label (e.g., "Figure 3")
#' @param extracted_caption Optional existing caption text
#' @return List of message objects for chat_completion()
#' @keywords internal
build_vision_messages <- function(image_data, figure_label = NULL,
                                  extracted_caption = NULL) {
  system_msg <- list(role = "system", content = build_figure_system_prompt())

  # Encode image to base64 data URL
  if (is.character(image_data) && file.exists(image_data)) {
    raw_bytes <- readBin(image_data, "raw", file.info(image_data)$size)
  } else if (is.raw(image_data)) {
    raw_bytes <- image_data
  } else {
    stop("image_data must be raw PNG bytes or a file path")
  }
  b64 <- base64enc::base64encode(raw_bytes)
  data_url <- paste0("data:image/png;base64,", b64)

  # Build user prompt with context
  user_text <- "Describe this figure from an academic paper."
  if (!is.null(figure_label) && !is.na(figure_label) && nchar(figure_label) > 0) {
    user_text <- paste0(user_text, "\nLabel: ", figure_label)
  }
  if (!is.null(extracted_caption) && !is.na(extracted_caption) && nchar(extracted_caption) > 0) {
    user_text <- paste0(user_text, "\nExtracted caption: ", extracted_caption)
  }
  user_text <- paste0(user_text, "\n\nRespond with JSON only.")

  user_msg <- list(
    role = "user",
    content = list(
      list(type = "text", text = user_text),
      list(type = "image_url", image_url = list(url = data_url))
    )
  )

  list(system_msg, user_msg)
}

#' Parse a JSON description from a vision model response
#'
#' Strips markdown code fences and extracts the JSON object.
#' Falls back to using raw text as the summary if parsing fails.
#'
#' @param raw_content Character string from the model
#' @return Named list with type, summary, details, suggested_caption
#' @keywords internal
parse_vision_response <- function(raw_content) {
  tryCatch({
    cleaned <- raw_content
    cleaned <- gsub("^```json\\s*\n?", "", cleaned)
    cleaned <- gsub("^```\\s*\n?", "", cleaned)
    cleaned <- gsub("\n?\\s*```\\s*$", "", cleaned)
    cleaned <- trimws(cleaned)
    parsed <- jsonlite::fromJSON(cleaned)
    list(
      type = parsed$type %||% "unknown",
      summary = parsed$summary %||% NA_character_,
      details = parsed$details %||% NA_character_,
      suggested_caption = parsed$suggested_caption %||% NA_character_
    )
  }, error = function(e) {
    message("[vision] Warning: could not parse JSON, using raw text as summary")
    list(
      type = "unknown",
      summary = raw_content,
      details = NA_character_,
      suggested_caption = NA_character_
    )
  })
}

#' Describe a single figure using the vision API
#'
#' Calls chat_completion() with the primary model; on failure, retries with the
#' fallback model. Returns a structured description.
#'
#' @param api_key OpenRouter API key
#' @param image_data Raw PNG bytes or file path
#' @param figure_label Optional label
#' @param extracted_caption Optional caption
#' @param vision_config Config list from figure_vision_config()
#' @return Named list: success, type, summary, details, suggested_caption,
#'   model_used, prompt_tokens, completion_tokens
describe_figure <- function(api_key, image_data, figure_label = NULL,
                            extracted_caption = NULL,
                            vision_config = figure_vision_config()) {
  messages <- build_vision_messages(image_data, figure_label, extracted_caption)

  # Try primary model
  result <- tryCatch({
    r <- chat_completion(api_key, vision_config$primary_model, messages,
                         max_tokens = vision_config$max_tokens,
                         temperature = vision_config$temperature,
                         timeout = vision_config$timeout)
    r$model_used <- vision_config$primary_model
    r
  }, error = function(e) {
    message(sprintf("[vision] Primary model failed: %s", conditionMessage(e)))
    NULL
  })

  # Fallback
  if (is.null(result) && !is.null(vision_config$fallback_model)) {
    result <- tryCatch({
      message(sprintf("[vision] Retrying with %s", vision_config$fallback_model))
      r <- chat_completion(api_key, vision_config$fallback_model, messages,
                           max_tokens = vision_config$max_tokens,
                           temperature = vision_config$temperature,
                           timeout = vision_config$timeout)
      r$model_used <- vision_config$fallback_model
      r
    }, error = function(e) {
      message(sprintf("[vision] Fallback model failed: %s", conditionMessage(e)))
      NULL
    })
  }

  if (is.null(result)) {
    return(list(
      success = FALSE,
      type = NA_character_, summary = NA_character_,
      details = NA_character_, suggested_caption = NA_character_,
      model_used = NA_character_,
      prompt_tokens = 0L, completion_tokens = 0L
    ))
  }

  parsed <- parse_vision_response(result$content)

  list(
    success = TRUE,
    type = parsed$type,
    summary = parsed$summary,
    details = parsed$details,
    suggested_caption = parsed$suggested_caption,
    model_used = result$model_used,
    prompt_tokens = result$usage$prompt_tokens %||% 0L,
    completion_tokens = result$usage$completion_tokens %||% 0L
  )
}


# ==============================================================================
# Pipeline Orchestrator
# ==============================================================================

#' Extract figures from a PDF and describe them with a vision model
#'
#' High-level orchestrator that runs the full pipeline:
#' 1. Deletes any existing figures for this document (idempotent re-extraction)
#' 2. Extracts figures from PDF via rendering + text-gap cropping
#' 3. Saves PNGs and inserts DB rows
#' 4. Describes each figure via vision API (skipped if api_key is NULL)
#' 5. Updates DB rows with descriptions and logs costs
#'
#' @param con DuckDB connection
#' @param api_key OpenRouter API key (NULL to skip vision description)
#' @param document_id Document UUID
#' @param notebook_id Notebook UUID
#' @param pdf_path Path to the PDF file
#' @param session_id Shiny session ID for cost logging (NULL to skip logging)
#' @param ext_config Extraction config list (default: extraction_config())
#' @param vis_config Vision config list (default: figure_vision_config())
#' @param progress Optional progress callback: function(value, detail) where
#'   value is 0-1 fraction
#' @return Named list: n_extracted, n_described, n_failed, figures (data.frame)
extract_and_describe_figures <- function(con, api_key = NULL,
                                         document_id, notebook_id, pdf_path,
                                         session_id = NULL,
                                         ext_config = NULL,
                                         vis_config = NULL,
                                         progress = NULL) {
  # Resolve defaults outside the signature to avoid recursive default reference
  if (is.null(ext_config)) ext_config <- extraction_config()
  if (is.null(vis_config)) vis_config <- figure_vision_config()
  # Step 1: Clean up existing figures (idempotent re-extraction)
  db_delete_figures_for_document(con, document_id)

  # Step 2: Extract figures from PDF
  if (!is.null(progress)) progress(0.1, "Extracting figures from PDF...")

  figures_df <- tryCatch(
    extract_figures_from_pdf(pdf_path, ext_config),
    error = function(e) {
      message(sprintf("[pipeline] Extraction failed: %s", conditionMessage(e)))
      empty_figures_df()
    }
  )

  if (nrow(figures_df) == 0) {
    return(list(n_extracted = 0L, n_described = 0L, n_failed = 0L,
                figures = data.frame()))
  }

  # Step 3: Save PNGs and insert DB rows
  if (!is.null(progress)) progress(0.3, sprintf("Saving %d figures...", nrow(figures_df)))

  figure_ids <- character(nrow(figures_df))

  for (i in seq_len(nrow(figures_df))) {
    fig <- figures_df[i, ]

    file_path <- save_figure(
      image_data  = fig$image_data[[1]],
      notebook_id = notebook_id,
      document_id = document_id,
      page        = fig$page,
      index       = fig$figure_index
    )

    figure_ids[i] <- db_insert_figure(con, list(
      document_id      = document_id,
      notebook_id      = notebook_id,
      page_number      = fig$page,
      file_path        = file_path,
      extracted_caption = if ("caption" %in% names(fig)) fig$caption else NA_character_,
      figure_label     = if ("figure_label" %in% names(fig)) fig$figure_label else NA_character_,
      width            = fig$width,
      height           = fig$height,
      file_size        = fig$file_size,
      image_type       = fig$method
    ))
  }

  n_extracted <- nrow(figures_df)
  n_described <- 0L
  n_failed <- 0L

  # Step 4: Describe via vision API (skip if no API key)
  if (!is.null(api_key) && nchar(api_key) > 0) {
    if (!is.null(progress)) progress(0.5, "Describing figures with vision model...")

    for (i in seq_len(n_extracted)) {
      fig <- figures_df[i, ]
      fig_id <- figure_ids[i]

      if (!is.null(progress)) {
        progress(0.5 + 0.4 * (i / n_extracted),
                 sprintf("Describing figure %d of %d...", i, n_extracted))
      }

      desc <- describe_figure(
        api_key            = api_key,
        image_data         = fig$image_data[[1]],
        figure_label       = if ("figure_label" %in% names(fig)) fig$figure_label else NULL,
        extracted_caption  = if ("caption" %in% names(fig)) fig$caption else NULL,
        vision_config      = vis_config
      )

      if (desc$success) {
        # Build description text: combine summary and details
        description_text <- desc$summary
        if (!is.na(desc$details) && nchar(desc$details) > 0) {
          description_text <- paste0(description_text, "\n\n", desc$details)
        }

        db_update_figure(con, fig_id,
          llm_description = description_text,
          image_type = desc$type
        )
        n_described <- n_described + 1L

        # Log cost
        if (!is.null(session_id) && (desc$prompt_tokens > 0 || desc$completion_tokens > 0)) {
          cost <- estimate_cost(desc$model_used, desc$prompt_tokens, desc$completion_tokens)
          log_cost(con, "figure_description", desc$model_used,
                   desc$prompt_tokens, desc$completion_tokens,
                   desc$prompt_tokens + desc$completion_tokens,
                   cost, session_id)
        }
      } else {
        n_failed <- n_failed + 1L
      }

      # Rate limiting pause between API calls
      if (i < n_extracted) Sys.sleep(0.5)
    }
  }

  if (!is.null(progress)) progress(1.0, "Done")

  message(sprintf("[pipeline] Complete: %d extracted, %d described, %d failed",
                  n_extracted, n_described, n_failed))

  list(
    n_extracted = n_extracted,
    n_described = n_described,
    n_failed    = n_failed,
    figures     = db_get_figures_for_document(con, document_id)
  )
}
