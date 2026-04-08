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
#'
#' Supports text and multipart (vision) messages. Optional parameters are only
#' included in the request body when non-NULL, so existing callers are unaffected.
#'
#' @param api_key API key
#' @param model Model ID
#' @param messages Message list (can include multipart content arrays for vision)
#' @param max_tokens Maximum tokens to generate (NULL = model default)
#' @param temperature Sampling temperature (NULL = model default)
#' @param timeout Request timeout in seconds
#' @return List with content, usage (tokens), model, and id
chat_completion <- function(api_key, model, messages,
                            max_tokens = NULL, temperature = NULL,
                            timeout = 120) {
  body <- list(model = model, messages = messages)
  if (!is.null(max_tokens)) body$max_tokens <- max_tokens
  if (!is.null(temperature)) body$temperature <- temperature

  req <- build_openrouter_request(api_key, "chat/completions") |>
    req_body_json(body) |>
    req_timeout(timeout)

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    stop_api_error(e, "OpenRouter")
  })

  resp_body <- resp_body_json(resp)

  if (!is.null(resp_body$error)) {
    stop("OpenRouter error: ", resp_body$error$message)
  }

  msg <- resp_body$choices[[1]]$message
  content <- extract_message_content(msg)

  list(
    content = content,
    usage = resp_body$usage,
    model = model,
    id = resp_body$id
  )
}

#' Extract text content from a chat completion message
#'
#' Handles three response shapes:
#' 1. Normal: msg$content is a string
#' 2. Reasoning models: msg$content is NULL, text is in msg$reasoning
#' 3. Multipart: msg$content is a list of {type, text} parts
#'
#' @param msg Message object from API response
#' @return Character string of content
#' @keywords internal
extract_message_content <- function(msg) {
  content <- msg$content

  # Reasoning models (e.g. gpt-5-nano) put output in $reasoning, $content is NULL

  if (is.null(content) || (is.character(content) && (length(content) == 0 || all(nchar(content) == 0)))) {
    if (!is.null(msg$reasoning)) {
      return(msg$reasoning)
    }
  }

  # Some models return content as a list of parts
  if (is.list(content) && !is.null(content)) {
    text_parts <- vapply(content, function(p) {
      if (is.list(p) && !is.null(p$text)) p$text
      else if (is.character(p)) p
      else ""
    }, character(1))
    return(paste(text_parts, collapse = "\n"))
  }

  content
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
    stop_api_error(e, "OpenRouter")
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
      "google/gemini-3.1-flash-lite-preview",
      "deepseek/deepseek-v3.2",
      "google/gemini-2.5-flash",
      "openai/gpt-4.1-mini",
      "openai/gpt-5-mini",
      # Mid tier
      "moonshotai/kimi-k2.5",
      "anthropic/claude-haiku-4.5",
      "google/gemini-2.5-pro",
      "openai/gpt-5",
      # Premium tier
      "anthropic/claude-sonnet-4.5",
      "openai/gpt-5.2",
      "google/gemini-3-pro-preview"
    ),
    name = c(
      # Budget tier
      "Gemini 3.1 Flash Lite",
      "DeepSeek V3.2",
      "Gemini 2.5 Flash",
      "GPT-4.1 Mini",
      "GPT-5 Mini",
      # Mid tier
      "Kimi K2.5",
      "Claude Haiku 4.5",
      "Gemini 2.5 Pro",
      "GPT-5",
      # Premium tier
      "Claude Sonnet 4.5",
      "GPT-5.2",
      "Gemini 3 Pro"
    ),
    context_length = c(
      # Budget tier
      1048576, 163840, 1048576, 1047576, 400000,
      # Mid tier
      262144, 200000, 1048576, 400000,
      # Premium tier
      1000000, 400000, 1048576
    ),
    prompt_price = c(
      # Budget tier
      0.10, 0.25, 0.30, 0.40, 0.25,
      # Mid tier
      0.45, 1.00, 1.25, 1.25,
      # Premium tier
      3.00, 1.75, 2.00
    ),
    completion_price = c(
      # Budget tier
      0.40, 0.38, 2.50, 1.60, 2.00,
      # Mid tier
      2.25, 5.00, 10.00, 10.00,
      # Premium tier
      15.00, 14.00, 12.00
    ),
    tier = c(
      # Budget tier
      "budget", "budget", "budget", "budget", "budget",
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
  has_aa <- "intelligence_index" %in% names(models_df)

  labels <- sapply(1:nrow(models_df), function(i) {
    row <- models_df[i, ]

    if (has_aa && !is.na(row$intelligence_index)) {
      # AA-enriched label: quality score, speed, blended price
      qi <- sprintf("Q:%d", as.integer(row$intelligence_index))
      speed <- if (!is.na(row$tokens_per_second)) {
        sprintf("%d tok/s", as.integer(row$tokens_per_second))
      } else {
        "-- tok/s"
      }
      price <- if (!is.na(row$price_blended_1m)) {
        sprintf("$%.2f/M", row$price_blended_1m)
      } else {
        sprintf("$%.2f/M", row$prompt_price)
      }
      sprintf("%s  |  %s  %s  %s", row$name, qi, speed, price)
    } else {
      # Fallback: tier + context + pricing
      tier_icons <- c("budget" = "$", "mid" = "$$", "premium" = "$$$")
      ctx <- if (row$context_length >= 1000000) {
        sprintf("%.1fM", row$context_length / 1000000)
      } else {
        sprintf("%dk", round(row$context_length / 1000))
      }
      sprintf("[%s] %s (ctx: %s, $%.2f/M in, $%.2f/M out)",
              tier_icons[row$tier],
              row$name,
              ctx,
              row$prompt_price,
              row$completion_price)
    }
  })

  setNames(models_df$id, labels)
}

#' Get OpenRouter account credits
#' @param api_key API key
#' @return list(total_credits, total_usage, remaining) or NULL on error
get_openrouter_credits <- function(api_key) {
  if (is.null(api_key) || nchar(api_key) < 10) return(NULL)

  tryCatch({
    resp <- build_openrouter_request(api_key, "credits") |> req_perform()
    body <- resp_body_json(resp)
    data <- body$data
    list(
      total_credits = as.numeric(data$total_credits %||% 0),
      total_usage = as.numeric(data$total_usage %||% 0),
      remaining = as.numeric(data$total_credits %||% 0) - as.numeric(data$total_usage %||% 0)
    )
  }, error = function(e) NULL)
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
