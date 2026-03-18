# R/api_provider.R
#
# Provider Abstraction Layer
#
# Unified interface for any OpenAI-compatible LLM endpoint.
# All chat completions and embeddings route through this module,
# which handles timing, usage normalization, and error formatting.

library(httr2)
library(jsonlite)

#' Create a provider configuration
#'
#' @param name Human-readable provider name (e.g., "OpenRouter", "Ollama")
#' @param base_url Base URL for the OpenAI-compatible API (e.g., "https://openrouter.ai/api/v1")
#' @param api_key Optional API key (NULL for local providers)
#' @param provider_type Provider type: "openrouter" or "openai-compatible"
#' @param timeout_chat Timeout in seconds for chat completions (default 120)
#' @param timeout_embed Timeout in seconds for embeddings (default 60)
#' @return Provider config list
create_provider_config <- function(name,
                                    base_url,
                                    api_key = NULL,
                                    provider_type = "openai-compatible",
                                    timeout_chat = 120,
                                    timeout_embed = 60) {
  # Strip trailing slash from base_url
  base_url <- sub("/+$", "", base_url)

  structure(
    list(
      name = name,
      base_url = base_url,
      api_key = api_key,
      provider_type = provider_type,
      timeout_chat = timeout_chat,
      timeout_embed = timeout_embed
    ),
    class = "provider_config"
  )
}

#' Check if a provider config is valid
#' @param x Object to check
#' @return TRUE if x is a provider_config
is_provider_config <- function(x) {
  inherits(x, "provider_config")
}

#' Build the default OpenRouter provider from an API key
#'
#' @param api_key OpenRouter API key
#' @return provider_config for OpenRouter
openrouter_provider <- function(api_key) {
  create_provider_config(
    name = "OpenRouter",
    base_url = "https://openrouter.ai/api/v1",
    api_key = api_key,
    provider_type = "openrouter",
    timeout_chat = 120,
    timeout_embed = 60
  )
}

# ---- Internal HTTP helpers ----

#' Build an HTTP request for a provider endpoint
#' @param provider provider_config
#' @param endpoint API endpoint (e.g., "chat/completions")
#' @return httr2 request object
build_provider_request <- function(provider, endpoint) {
  req <- request(paste0(provider$base_url, "/", endpoint)) |>
    req_headers("Content-Type" = "application/json")

  if (!is.null(provider$api_key) && nchar(provider$api_key) > 0) {
    req <- req |> req_headers("Authorization" = paste("Bearer", provider$api_key))
  }

  req
}

#' Normalize usage from an API response
#'
#' Handles NULL/missing usage fields (common with local models).
#'
#' @param usage Usage object from API response (may be NULL)
#' @return Normalized list with prompt_tokens, completion_tokens, total_tokens
normalize_usage <- function(usage) {
  prompt <- as.integer(usage$prompt_tokens %||% 0L)
  completion <- as.integer(usage$completion_tokens %||% 0L)
  total <- as.integer(usage$total_tokens %||% (prompt + completion))

  list(
    prompt_tokens = prompt,
    completion_tokens = completion,
    total_tokens = total
  )
}

# ---- Public API ----

#' Send a chat completion request through the provider layer
#'
#' @param provider provider_config object
#' @param model Model ID string
#' @param messages Message list (list of list(role, content))
#' @return List with content, usage (normalized), model, id, duration_ms
provider_chat_completion <- function(provider, model, messages) {
  req <- build_provider_request(provider, "chat/completions") |>
    req_body_json(list(
      model = model,
      messages = messages
    )) |>
    req_timeout(provider$timeout_chat)

  start_time <- proc.time()

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    stop_api_error(e, provider$name)
  })

  elapsed <- proc.time() - start_time
  duration_ms <- as.integer(round(elapsed[["elapsed"]] * 1000))

  body <- resp_body_json(resp)

  if (!is.null(body$error)) {
    stop(provider$name, " error: ", body$error$message)
  }

  list(
    content = body$choices[[1]]$message$content,
    usage = normalize_usage(body$usage),
    model = model,
    id = body$id,
    duration_ms = duration_ms
  )
}

#' Get embeddings through the provider layer
#'
#' @param provider provider_config object
#' @param model Embedding model ID string
#' @param text Character vector of texts to embed
#' @return List with embeddings (list of numeric vectors), usage (normalized), model, duration_ms
provider_get_embeddings <- function(provider, model, text) {
  req <- build_provider_request(provider, "embeddings") |>
    req_body_json(list(
      model = model,
      input = as.list(text)
    )) |>
    req_timeout(provider$timeout_embed)

  start_time <- proc.time()

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    stop_api_error(e, provider$name)
  })

  elapsed <- proc.time() - start_time
  duration_ms <- as.integer(round(elapsed[["elapsed"]] * 1000))

  body <- resp_body_json(resp)

  if (!is.null(body$error)) {
    stop(provider$name, " error: ", body$error$message)
  }

  list(
    embeddings = lapply(body$data, function(x) unlist(x$embedding)),
    usage = normalize_usage(body$usage),
    model = model,
    duration_ms = duration_ms
  )
}

#' List available models from a provider
#'
#' @param provider provider_config object
#' @return Data frame with id, name columns (empty data.frame on error)
provider_list_models <- function(provider) {
  req <- build_provider_request(provider, "models")

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    return(data.frame(id = character(), name = character(), stringsAsFactors = FALSE))
  })

  body <- tryCatch({
    resp_body_json(resp)
  }, error = function(e) {
    return(data.frame(id = character(), name = character(), stringsAsFactors = FALSE))
  })

  if (is.null(body$data) || length(body$data) == 0) {
    return(data.frame(id = character(), name = character(), stringsAsFactors = FALSE))
  }

  data.frame(
    id = vapply(body$data, function(x) x$id %||% "", character(1)),
    name = vapply(body$data, function(x) x$name %||% x$id %||% "", character(1)),
    stringsAsFactors = FALSE
  )
}

#' Check provider health and connectivity
#'
#' Probes the /models endpoint with a short timeout.
#'
#' @param provider provider_config object
#' @param timeout Probe timeout in seconds (default 3)
#' @return List with alive (logical), model_count (integer), server_type (character)
provider_check_health <- function(provider, timeout = 3) {
  tryCatch({
    req <- build_provider_request(provider, "models") |>
      req_timeout(timeout)

    resp <- req_perform(req)
    body <- resp_body_json(resp)

    models <- if (!is.null(body$data)) body$data else list()
    model_ids <- vapply(models, function(m) m$id %||% "", character(1))

    # Detect server type from model ID patterns
    server_type <- if (any(grepl("\\.gguf$", model_ids, ignore.case = TRUE))) {
      "lmstudio"
    } else if (any(grepl(":", model_ids))) {
      "ollama"
    } else if (provider$provider_type == "openrouter") {
      "openrouter"
    } else {
      "openai-compatible"
    }

    list(
      alive = TRUE,
      model_count = length(models),
      server_type = server_type
    )
  }, error = function(e) {
    list(
      alive = FALSE,
      model_count = 0L,
      server_type = "unknown"
    )
  })
}

# ---- Model Slot Resolution ----

#' Resolve which model to use for a given operation
#'
#' Looks up the operation's slot in COST_OPERATION_META, then returns the
#' appropriate model from config$defaults. Fast slot falls back to quality
#' model when not configured.
#'
#' @param config effective_config list (from mod_settings_server)
#' @param operation Operation key (must exist in COST_OPERATION_META)
#' @return Model ID string
resolve_model_for_operation <- function(config, operation) {
  meta <- COST_OPERATION_META[[operation]]
  if (is.null(meta)) {
    stop("Unknown operation '", operation, "' — not in COST_OPERATION_META")
  }

  slot <- meta$slot
  if (is.na(slot)) {
    stop("Operation '", operation, "' is not an LLM operation (slot = NA)")
  }

  model <- switch(slot,
    fast      = config$defaults$fast_model %||% config$defaults$quality_model,
    quality   = config$defaults$quality_model,
    embedding = config$defaults$embedding_model
  )

  if (is.null(model) || model == "") {
    stop("No model configured for slot '", slot, "'. Please configure a ", slot, " model in Settings.")
  }

  model
}

# ---- Config Helper ----

#' Build provider config from effective_config
#'
#' Extracts the OpenRouter API key from the effective_config list
#' and returns a provider_config. This bridges the existing settings
#' system with the provider layer.
#'
#' @param config effective_config list (from mod_settings_server)
#' @return provider_config for OpenRouter
provider_from_config <- function(config) {
  api_key <- get_setting(config, "openrouter", "api_key")
  openrouter_provider(api_key)
}
