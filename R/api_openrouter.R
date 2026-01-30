library(httr2)
library(jsonlite)

OPENROUTER_BASE_URL <- "https://openrouter.ai/api/v1"

#' Build OpenRouter API request
#' @param api_key API key
#' @param endpoint API endpoint
#' @return httr2 request object
build_openrouter_request <- function(api_key, endpoint) {
  request(paste0(OPENROUTER_BASE_URL, "/", endpoint)) |>
    req_headers(
      "Authorization" = paste("Bearer", api_key),
      "Content-Type" = "application/json"
    )
}

#' Format messages for chat API
#' @param system_prompt System message
#' @param user_message User message
#' @param history Previous messages (optional)
#' @return List of message objects
format_chat_messages <- function(system_prompt, user_message, history = list()) {
  messages <- list(
    list(role = "system", content = system_prompt)
  )
  messages <- c(messages, history)
  messages <- c(messages, list(list(role = "user", content = user_message)))
  messages
}

#' Send chat completion request
#' @param api_key API key
#' @param model Model ID
#' @param messages Message list
#' @return Response content
chat_completion <- function(api_key, model, messages) {
  req <- build_openrouter_request(api_key, "chat/completions") |>
    req_body_json(list(
      model = model,
      messages = messages
    )) |>
    req_timeout(120)

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    stop("OpenRouter API error: ", e$message)
  })

  body <- resp_body_json(resp)

  if (!is.null(body$error)) {
    stop("OpenRouter error: ", body$error$message)
  }

  body$choices[[1]]$message$content
}

#' Get embeddings for text
#' @param api_key API key
#' @param model Embedding model ID
#' @param text Text to embed (character vector)
#' @return List of embedding vectors
get_embeddings <- function(api_key, model, text) {
  req <- build_openrouter_request(api_key, "embeddings") |>
    req_body_json(list(
      model = model,
      input = as.list(text)
    )) |>
    req_timeout(60)

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    stop("OpenRouter embeddings error: ", e$message)
  })

  body <- resp_body_json(resp)

  if (!is.null(body$error)) {
    stop("OpenRouter error: ", body$error$message)
  }

  lapply(body$data, function(x) unlist(x$embedding))
}

#' List available models from OpenRouter
#' @param api_key API key
#' @return Data frame of models
list_models <- function(api_key) {
  req <- build_openrouter_request(api_key, "models")

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    return(data.frame())
  })

  body <- resp_body_json(resp)

  if (is.null(body$data)) {
    return(data.frame())
  }

  data.frame(
    id = sapply(body$data, function(x) x$id),
    name = sapply(body$data, function(x) x$name %||% x$id),
    stringsAsFactors = FALSE
  )
}

#' Get fallback embedding model list when API unavailable
#' @return Data frame of embedding models with id, name, price_per_million
get_default_embedding_models <- function() {
  data.frame(
    id = c("openai/text-embedding-3-small",
           "openai/text-embedding-3-large",
           "google/gemini-embedding-001",
           "qwen/qwen3-embedding-8b",
           "mistralai/mistral-embed-2312"),
    name = c("OpenAI text-embedding-3-small ($0.02/M)",
             "OpenAI text-embedding-3-large ($0.13/M)",
             "Google Gemini Embedding ($0.15/M) - MTEB #1",
             "Qwen3 Embedding 8B ($0.01/M) - Budget",
             "Mistral Embed ($0.10/M)"),
    price_per_million = c(0.02, 0.13, 0.15, 0.01, 0.10),
    stringsAsFactors = FALSE
  )
}

#' List available embedding models from OpenRouter
#' @param api_key API key
#' @return Data frame of embedding models with id, name, price_per_million
list_embedding_models <- function(api_key) {
  if (is.null(api_key) || nchar(api_key) < 10) {
    return(get_default_embedding_models())
  }

  req <- build_openrouter_request(api_key, "models")

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(resp)) {
    return(get_default_embedding_models())
  }

  body <- tryCatch({
    resp_body_json(resp)
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(body) || is.null(body$data)) {
    return(get_default_embedding_models())
  }

  # Filter to embedding models only (architecture contains "embedding" or modality includes "embedding")
  embedding_models <- Filter(function(m) {
    arch <- tolower(m$architecture$modality %||% "")
    id <- tolower(m$id %||% "")
    grepl("embed", arch) || grepl("embed", id)
  }, body$data)

  if (length(embedding_models) == 0) {
    return(get_default_embedding_models())
  }

  # Extract pricing info and format display names
  df <- data.frame(
    id = sapply(embedding_models, function(x) x$id),
    name = sapply(embedding_models, function(x) {
      price <- as.numeric(x$pricing$prompt %||% 0) * 1000000
      price_str <- if (price > 0) sprintf("$%.2f/M", price) else "Free"
      paste0(x$name %||% x$id, " (", price_str, ")")
    }),
    price_per_million = sapply(embedding_models, function(x) {
      as.numeric(x$pricing$prompt %||% 0) * 1000000
    }),
    stringsAsFactors = FALSE
  )

  # Sort by price (cheapest first)
  df[order(df$price_per_million), ]
}
