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
#' @return List with content, usage (tokens), model, and id
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

  list(
    content = body$choices[[1]]$message$content,
    usage = body$usage,
    model = model,
    id = body$id
  )
}

#' Get embeddings for text
#' @param api_key API key
#' @param model Embedding model ID
#' @param text Text to embed (character vector)
#' @return List with embeddings (list of vectors), usage (tokens), and model
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

  list(
    embeddings = lapply(body$data, function(x) unlist(x$embedding)),
    usage = body$usage,
    model = model
  )
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

#' Get fallback chat model list when API unavailable
#' @return Data frame of chat models with id, name, context_length, prompt_price, completion_price, tier
get_default_chat_models <- function() {
  data.frame(
    id = c(
      # Budget tier
      "deepseek/deepseek-chat",
      "google/gemini-2.0-flash-001",
      "openai/gpt-4o-mini",
      # Mid tier
      "moonshotai/kimi-k2-0905",
      "anthropic/claude-3-5-haiku",
      "meta-llama/llama-3.3-70b-instruct",
      "google/gemini-2.5-flash-preview-05-20",
      # Premium tier
      "anthropic/claude-sonnet-4",
      "openai/gpt-4o",
      "google/gemini-2.5-pro-preview"
    ),
    name = c(
      # Budget tier
      "DeepSeek V3",
      "Gemini 2.0 Flash",
      "GPT-4o Mini",
      # Mid tier
      "Kimi K2 0905",
      "Claude 3.5 Haiku",
      "Llama 3.3 70B",
      "Gemini 2.5 Flash",
      # Premium tier
      "Claude Sonnet 4",
      "GPT-4o",
      "Gemini 2.5 Pro"
    ),
    context_length = c(
      # Budget tier
      64000, 1000000, 128000,
      # Mid tier
      200000, 200000, 128000, 1000000,
      # Premium tier
      200000, 128000, 2000000
    ),
    prompt_price = c(
      # Budget tier
      0.27, 0.10, 0.15,
      # Mid tier
      0.55, 0.80, 0.88, 0.15,
      # Premium tier
      3.00, 2.50, 2.00
    ),
    completion_price = c(
      # Budget tier
      1.10, 0.40, 0.60,
      # Mid tier
      0.55, 4.00, 0.88, 0.60,
      # Premium tier
      15.00, 10.00, 8.00
    ),
    tier = c(
      # Budget tier
      "budget", "budget", "budget",
      # Mid tier
      "mid", "mid", "mid", "mid",
      # Premium tier
      "premium", "premium", "premium"
    ),
    stringsAsFactors = FALSE
  )
}

#' List available chat models from OpenRouter
#' @param api_key API key
#' @return Data frame of chat models with id, name, context_length, prompt_price, completion_price, tier
list_chat_models <- function(api_key) {
  if (is.null(api_key) || nchar(api_key) < 10) {
    return(get_default_chat_models())
  }

  req <- build_openrouter_request(api_key, "models")

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(resp)) {
    return(get_default_chat_models())
  }

  body <- tryCatch({
    resp_body_json(resp)
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(body) || is.null(body$data)) {
    return(get_default_chat_models())
  }

  # Filter to chat models (text generation, not embeddings)
  chat_models <- Filter(function(m) {
    # Check modality contains "text" and does NOT contain "embed"
    modality <- tolower(m$architecture$modality %||% "")
    id <- tolower(m$id %||% "")

    has_text <- grepl("text", modality)
    no_embed_modality <- !grepl("embed", modality)
    no_embed_id <- !grepl("embed", id)

    has_text && no_embed_modality && no_embed_id
  }, body$data)

  if (length(chat_models) == 0) {
    return(get_default_chat_models())
  }

  # Curated provider list
  allowed_providers <- c("openai", "anthropic", "google", "meta-llama",
                         "deepseek", "moonshotai", "mistralai", "qwen", "cohere")

  # Extract data and filter to curated providers
  df <- data.frame(
    id = sapply(chat_models, function(x) x$id),
    name = sapply(chat_models, function(x) x$name %||% x$id),
    context_length = sapply(chat_models, function(x) as.integer(x$context_length %||% 0)),
    prompt_price = sapply(chat_models, function(x) {
      as.numeric(x$pricing$prompt %||% 0) * 1000000
    }),
    completion_price = sapply(chat_models, function(x) {
      as.numeric(x$pricing$completion %||% 0) * 1000000
    }),
    stringsAsFactors = FALSE
  )

  # Filter to curated providers
  df <- df[sapply(df$id, function(id) {
    provider <- strsplit(id, "/")[[1]][1]
    provider %in% allowed_providers
  }), ]

  # Assign tier based on prompt_price
  df$tier <- sapply(df$prompt_price, function(price) {
    if (price < 0.50) "budget"
    else if (price <= 2.00) "mid"
    else "premium"
  })

  # Sort by tier then name
  df <- df[order(match(df$tier, c("budget", "mid", "premium")), df$name), ]

  # Return defaults if filtering resulted in empty set
  if (nrow(df) == 0) {
    return(get_default_chat_models())
  }

  df
}

#' Format chat model choices for selectizeInput
#' @param models_df Data frame from list_chat_models or get_default_chat_models
#' @return Named character vector (names = display labels, values = model IDs)
format_chat_model_choices <- function(models_df) {
  tier_icons <- c("budget" = "$", "mid" = "$$", "premium" = "$$$")

  labels <- sapply(1:nrow(models_df), function(i) {
    row <- models_df[i, ]

    # Format context length
    ctx <- if (row$context_length >= 1000000) {
      sprintf("%.1fM", row$context_length / 1000000)
    } else {
      sprintf("%dk", round(row$context_length / 1000))
    }

    # Build label
    sprintf("[%s] %s (ctx: %s, $%.2f/M in, $%.2f/M out)",
            tier_icons[row$tier],
            row$name,
            ctx,
            row$prompt_price,
            row$completion_price)
  })

  setNames(models_df$id, labels)
}

#' Validate OpenRouter API key
#' @param api_key API key to validate
#' @return list(valid = TRUE/FALSE, error = NULL or error message)
validate_openrouter_key <- function(api_key) {
  if (is.null(api_key) || nchar(api_key) < 10) {
    return(list(valid = FALSE, error = "Key too short"))
  }

  tryCatch({
    models <- list_models(api_key)
    list(valid = nrow(models) > 0, error = NULL)
  }, error = function(e) {
    list(valid = FALSE, error = e$message)
  })
}
