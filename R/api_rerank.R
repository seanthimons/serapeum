#' Rerank API Client
#'
#' Shared rerank utility for RAG chunks and paper search/citation audit.
#' Uses OpenRouter's /rerank endpoint with Cohere models.

#' Get fallback rerank model list when API unavailable
#' @return Data frame of rerank models with id, name, price_per_search
get_default_rerank_models <- function() {
  data.frame(
    id = c("cohere/rerank-4-fast",
           "cohere/rerank-v3.5"),
    name = c("Cohere Rerank 4 Fast ($0.002/search)",
             "Cohere Rerank v3.5 ($0.001/search)"),
    price_per_search = c(0.002, 0.001),
    stringsAsFactors = FALSE
  )
}

#' List available rerank models from OpenRouter
#' @param api_key API key
#' @return Data frame of rerank models with id, name, price_per_search
list_rerank_models <- function(api_key) {
  if (is.null(api_key) || nchar(api_key) < 10) {
    return(get_default_rerank_models())
  }

  req <- build_openrouter_request(api_key, "models")

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(resp)) {
    return(get_default_rerank_models())
  }

  body <- tryCatch({
    resp_body_json(resp)
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(body) || is.null(body$data)) {
    return(get_default_rerank_models())
  }

  # Filter to rerank models (output modality contains "rerank" or id contains "rerank")
  rerank_models <- Filter(function(m) {
    modality <- tolower(m$architecture$modality %||% "")
    output <- tolower(m$architecture$output_modality %||% "")
    id <- tolower(m$id %||% "")
    grepl("rerank", modality) || grepl("rerank", output) || grepl("rerank", id)
  }, body$data)

  if (length(rerank_models) == 0) {
    return(get_default_rerank_models())
  }

  df <- data.frame(
    id = sapply(rerank_models, function(x) x$id),
    name = sapply(rerank_models, function(x) {
      # Rerank pricing is per-search, stored in pricing$prompt
      price <- as.numeric(x$pricing$prompt %||% 0)
      price_str <- if (price > 0) sprintf("$%.3f/search", price) else "Free"
      paste0(x$name %||% x$id, " (", price_str, ")")
    }),
    price_per_search = sapply(rerank_models, function(x) {
      as.numeric(x$pricing$prompt %||% 0)
    }),
    stringsAsFactors = FALSE
  )

  # Sort by price (cheapest first)
  df[order(df$price_per_search), ]
}

#' Rerank documents by relevance to a query
#'
#' Calls the OpenRouter /rerank endpoint. On failure, returns documents
#' in original order (graceful degradation).
#'
#' @param api_key API key
#' @param model Rerank model ID
#' @param query Query string
#' @param documents Character vector of document texts
#' @param top_n Number of top results to return (NULL = return all)
#' @return Data frame with index (original position), relevance_score, document,
#'   sorted by score descending
rerank <- function(api_key, model, query, documents, top_n = NULL) {
  if (length(documents) == 0) {
    return(data.frame(
      index = integer(0),
      relevance_score = numeric(0),
      document = character(0),
      stringsAsFactors = FALSE
    ))
  }

  body <- list(
    model = model,
    query = query,
    documents = as.list(documents)
  )
  if (!is.null(top_n)) body$top_n <- as.integer(top_n)

  result <- tryCatch({
    req <- build_openrouter_request(api_key, "rerank") |>
      req_body_json(body) |>
      req_timeout(60)

    resp <- req_perform(req)
    resp_body <- resp_body_json(resp)

    if (!is.null(resp_body$error)) {
      stop("OpenRouter rerank error: ", resp_body$error$message)
    }

    results <- resp_body$results
    if (is.null(results) || length(results) == 0) {
      stop("No rerank results returned")
    }

    data.frame(
      index = sapply(results, function(r) as.integer(r$index) + 1L),
      relevance_score = sapply(results, function(r) as.numeric(r$relevance_score)),
      document = sapply(results, function(r) {
        # Some models return document text, others just index
        if (!is.null(r$document) && !is.null(r$document$text)) {
          r$document$text
        } else {
          documents[as.integer(r$index) + 1L]
        }
      }),
      stringsAsFactors = FALSE
    )
  }, error = function(e) {
    err <- classify_api_error(e, "OpenRouter")
    message("Rerank failed (graceful degradation): ", err$message)

    # Return documents in original order as fallback
    n <- if (!is.null(top_n) && top_n < length(documents)) top_n else length(documents)
    data.frame(
      index = seq_len(n),
      relevance_score = rep(0, n),
      document = documents[seq_len(n)],
      stringsAsFactors = FALSE
    )
  })

  # Sort by relevance score descending
  result[order(result$relevance_score, decreasing = TRUE), ]
}
