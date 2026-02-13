# Note: ragnar_available() is defined in R/_ragnar.R (sourced first alphabetically)

#' Build RAG context from retrieved chunks
#' @param chunks Data frame of chunks from search_chunks
#' @return Formatted context string
build_context <- function(chunks) {
  if (!is.data.frame(chunks) || nrow(chunks) == 0) return("")

  contexts <- vapply(seq_len(nrow(chunks)), function(i) {
    chunk <- chunks[i, , drop = FALSE]

    # Safely extract scalar values (handle potential vector/NULL cases)
    doc_name <- NA_character_
    if ("doc_name" %in% names(chunk)) {
      val <- chunk$doc_name
      if (length(val) > 0) doc_name <- as.character(val)[1]
    }

    abstract_title <- NA_character_
    if ("abstract_title" %in% names(chunk)) {
      val <- chunk$abstract_title
      if (length(val) > 0) abstract_title <- as.character(val)[1]
    }

    page_number <- NA_integer_
    if ("page_number" %in% names(chunk)) {
      val <- chunk$page_number
      if (length(val) > 0) page_number <- as.integer(val)[1]
    }

    content <- ""
    if ("content" %in% names(chunk)) {
      val <- chunk$content
      if (length(val) > 0) content <- as.character(val)[1]
    }

    # Determine source label using safe scalar checks
    source <- "[Source]"
    if (!isTRUE(is.na(doc_name)) && isTRUE(nchar(doc_name) > 0)) {
      source <- sprintf("[%s, p.%d]", doc_name, page_number)
    } else if (!isTRUE(is.na(abstract_title)) && isTRUE(nchar(abstract_title) > 0)) {
      source <- sprintf("[%s]", abstract_title)
    }

    sprintf("Source %s:\n%s", source, content)
  }, FUN.VALUE = character(1))

  paste(contexts, collapse = "\n\n---\n\n")
}

#' Generate RAG response
#'
#' Uses ragnar's hybrid VSS + BM25 search when available for improved retrieval.
#' Falls back to legacy cosine similarity search otherwise.
#'
#' @param con Database connection
#' @param config App config
#' @param question User question
#' @param notebook_id Notebook to query
#' @param use_ragnar Try ragnar hybrid search first (default TRUE)
#' @param session_id Optional Shiny session ID for cost logging (default NULL)
#' @return Generated response with citations
rag_query <- function(con, config, question, notebook_id, use_ragnar = TRUE, session_id = NULL) {
  # Extract settings with defensive scalar checks
  api_key <- get_setting(config, "openrouter", "api_key")
  if (length(api_key) > 1) api_key <- api_key[1]

  chat_model <- get_setting(config, "defaults", "chat_model") %||% "anthropic/claude-sonnet-4"
  if (length(chat_model) > 1) chat_model <- chat_model[1]

  embed_model <- get_setting(config, "defaults", "embedding_model") %||% "openai/text-embedding-3-small"
  if (length(embed_model) > 1) embed_model <- embed_model[1]

  # Safely check api_key
  api_key_empty <- is.null(api_key) || isTRUE(is.na(api_key)) ||
                   (is.character(api_key) && nchar(api_key) == 0)
  if (api_key_empty) {
    return("Error: OpenRouter API key not configured. Please set your API key in Settings.")
  }

  chunks <- NULL

  # Try ragnar hybrid search first (no need to pre-embed query)
  if (use_ragnar && ragnar_available()) {
    chunks <- tryCatch({
      search_chunks_hybrid(con, question, notebook_id, limit = 5)
    }, error = function(e) {
      message("Ragnar search failed: ", e$message)
      NULL
    })
  }

  # Fall back to legacy embedding-based search
  if (is.null(chunks) || nrow(chunks) == 0) {
    # Embed the question for legacy search
    question_embedding <- tryCatch({
      result <- get_embeddings(api_key, embed_model, question)

      # Log cost if session_id provided
      if (!is.null(session_id) && !is.null(result$usage)) {
        cost <- estimate_cost(embed_model, result$usage$prompt_tokens %||% 0, 0)
        log_cost(con, "embedding", embed_model, result$usage$prompt_tokens %||% 0, 0,
                 result$usage$total_tokens %||% 0, cost, session_id)
      }

      if (is.list(result$embeddings) && length(result$embeddings) > 0) result$embeddings[[1]] else NULL
    }, error = function(e) {
      return(NULL)
    })

    if (is.null(question_embedding) || !is.numeric(question_embedding)) {
      return("Error: Failed to generate embeddings. Please check your API key and try again.")
    }

    # Search for relevant chunks using legacy method
    chunks <- tryCatch({
      search_chunks(con, question_embedding, notebook_id, limit = 5)
    }, error = function(e) {
      return(data.frame())
    })
  }

  if (!is.data.frame(chunks) || nrow(chunks) == 0) {
    return("I couldn't find any relevant information in your documents to answer this question. Make sure your documents have been processed and embedded.")
  }

  # Build context
  context <- tryCatch({
    build_context(chunks)
  }, error = function(e) {
    return("")
  })

  if (nchar(context) == 0) {
    return("Error: Failed to build context from documents.")
  }

  # Build prompt
  system_prompt <- "You are a helpful research assistant. Answer questions based ONLY on the provided sources. Always cite your sources using the format [Document Name, p.X] or [Paper Title]. If the sources don't contain enough information to fully answer the question, say so clearly."

  user_prompt <- sprintf("Sources:\n%s\n\nQuestion: %s", context, question)

  messages <- format_chat_messages(system_prompt, user_prompt)

  # Generate response
  response <- tryCatch({
    result <- chat_completion(api_key, chat_model, messages)

    # Log cost if session_id provided
    if (!is.null(session_id) && !is.null(result$usage)) {
      cost <- estimate_cost(chat_model,
                          result$usage$prompt_tokens %||% 0,
                          result$usage$completion_tokens %||% 0)
      log_cost(con, "chat", chat_model,
               result$usage$prompt_tokens %||% 0,
               result$usage$completion_tokens %||% 0,
               result$usage$total_tokens %||% 0,
               cost, session_id)
    }

    result$content
  }, error = function(e) {
    return(sprintf("Error generating response: %s", e$message))
  })

  response
}

#' Generate preset content (summary, key points, etc.)
#' @param con Database connection
#' @param config App config
#' @param notebook_id Notebook ID
#' @param preset_type Type of preset ("summarize", "keypoints", "studyguide", "outline")
#' @param session_id Optional Shiny session ID for cost logging (default NULL)
#' @return Generated content
generate_preset <- function(con, config, notebook_id, preset_type, session_id = NULL) {
  presets <- list(
    summarize = "Provide a comprehensive summary of all the documents. Highlight the main themes, key findings, and important conclusions. Organize your summary with clear sections.",
    keypoints = "Extract the key points from these documents as a bulleted list. Focus on the most important facts, findings, arguments, and conclusions. Group related points together.",
    studyguide = "Create a study guide based on these documents. Include:\n1. Key concepts and definitions\n2. Important facts and figures\n3. Main arguments and their supporting evidence\n4. Potential exam questions with brief answers",
    outline = "Create a structured outline of the main topics covered in these documents. Use hierarchical headings (I, A, 1, a) to organize the content logically. Include brief descriptions under each heading."
  )

  prompt <- presets[[preset_type]]
  if (is.null(prompt)) {
    return(sprintf("Unknown preset type: %s", preset_type))
  }

  api_key <- get_setting(config, "openrouter", "api_key")
  if (length(api_key) > 1) api_key <- api_key[1]

  chat_model <- get_setting(config, "defaults", "chat_model") %||% "anthropic/claude-sonnet-4"
  if (length(chat_model) > 1) chat_model <- chat_model[1]

  # Safely check api_key
  api_key_empty <- is.null(api_key) || isTRUE(is.na(api_key)) ||
                   (is.character(api_key) && nchar(api_key) == 0)
  if (api_key_empty) {
    return("Error: OpenRouter API key not configured. Please set your API key in Settings.")
  }

  # Get notebook type to determine which table to query
  notebook <- get_notebook(con, notebook_id)
  if (is.null(notebook)) {
    return("Error: Notebook not found.")
  }

  # Get chunks based on notebook type
  # Select explicit columns to avoid pulling large embedding data
  if (notebook$type == "document") {
    chunks <- dbGetQuery(con, "
      SELECT c.id, c.source_id, c.source_type, c.chunk_index, c.content, c.page_number,
             d.filename as doc_name, NULL as abstract_title
      FROM chunks c
      JOIN documents d ON c.source_id = d.id
      WHERE d.notebook_id = ?
      ORDER BY d.created_at, c.chunk_index
      LIMIT 50
    ", list(notebook_id))
  } else {
    chunks <- dbGetQuery(con, "
      SELECT c.id, c.source_id, c.source_type, c.chunk_index, c.content, c.page_number,
             NULL as doc_name, a.title as abstract_title
      FROM chunks c
      JOIN abstracts a ON c.source_id = a.id
      WHERE a.notebook_id = ?
      ORDER BY a.year DESC, c.chunk_index
      LIMIT 50
    ", list(notebook_id))
  }

  if (nrow(chunks) == 0) {
    return("No content found in this notebook. Please add documents or search for papers first.")
  }

  # Build context
  context <- build_context(chunks)

  system_prompt <- "You are a helpful research assistant. Generate the requested content based on the provided sources. Be thorough and well-organized."
  user_prompt <- sprintf("Sources:\n%s\n\nTask: %s", context, prompt)

  messages <- format_chat_messages(system_prompt, user_prompt)

  response <- tryCatch({
    result <- chat_completion(api_key, chat_model, messages)

    # Log cost if session_id provided
    if (!is.null(session_id) && !is.null(result$usage)) {
      cost <- estimate_cost(chat_model,
                          result$usage$prompt_tokens %||% 0,
                          result$usage$completion_tokens %||% 0)
      log_cost(con, "chat", chat_model,
               result$usage$prompt_tokens %||% 0,
               result$usage$completion_tokens %||% 0,
               result$usage$total_tokens %||% 0,
               cost, session_id)
    }

    result$content
  }, error = function(e) {
    return(sprintf("Error generating content: %s", e$message))
  })

  response
}

#' Generate conclusion synthesis preset
#'
#' Synthesizes conclusions, limitations, and future directions from research sources.
#' Uses section-targeted RAG retrieval for document notebooks (focuses on conclusion/
#' limitations/future work sections) and generic retrieval for search notebooks (abstracts).
#'
#' @param con Database connection
#' @param config App config
#' @param notebook_id Notebook ID
#' @param notebook_type Type of notebook ("document" or "search")
#' @param session_id Optional Shiny session ID for cost logging (default NULL)
#' @return Generated synthesis content (plain markdown, no AI disclaimer)
generate_conclusions_preset <- function(con, config, notebook_id, notebook_type = "document", session_id = NULL) {
  # Extract settings
  api_key <- get_setting(config, "openrouter", "api_key")
  if (length(api_key) > 1) api_key <- api_key[1]

  chat_model <- get_setting(config, "defaults", "chat_model") %||% "anthropic/claude-sonnet-4"
  if (length(chat_model) > 1) chat_model <- chat_model[1]

  # Check api_key
  api_key_empty <- is.null(api_key) || isTRUE(is.na(api_key)) ||
                   (is.character(api_key) && nchar(api_key) == 0)
  if (api_key_empty) {
    return("Error: OpenRouter API key not configured. Please set your API key in Settings.")
  }

  # Get notebook
  notebook <- get_notebook(con, notebook_id)
  if (is.null(notebook)) {
    return("Error: Notebook not found.")
  }

  # Retrieve chunks with section filtering for document notebooks
  chunks <- NULL

  if (notebook_type == "document") {
    # Try section-filtered search first
    chunks <- tryCatch({
      search_chunks_hybrid(
        con,
        query = "conclusions limitations future work research gaps directions",
        notebook_id = notebook_id,
        limit = 10,
        section_filter = c("conclusion", "limitations", "future_work", "discussion", "late_section")
      )
    }, error = function(e) {
      message("[generate_conclusions_preset] Section-filtered search failed: ", e$message)
      NULL
    })

    # Fallback: retry without section filter (graceful degradation for pre-migration data)
    if (is.null(chunks) || nrow(chunks) == 0) {
      message("[generate_conclusions_preset] Retrying without section filter")
      chunks <- tryCatch({
        search_chunks_hybrid(
          con,
          query = "conclusions limitations future work research gaps directions",
          notebook_id = notebook_id,
          limit = 10
        )
      }, error = function(e) {
        message("[generate_conclusions_preset] Fallback search failed: ", e$message)
        NULL
      })
    }
  } else {
    # Search notebooks: use generic retrieval (abstracts don't have section structure)
    chunks <- tryCatch({
      search_chunks_hybrid(
        con,
        query = "conclusions limitations future work research gaps",
        notebook_id = notebook_id,
        limit = 10
      )
    }, error = function(e) {
      message("[generate_conclusions_preset] Search notebook retrieval failed: ", e$message)
      NULL
    })
  }

  # Final fallback: direct DB query if hybrid search returned nothing
  # (matches generate_preset pattern — works even without ragnar/embeddings)
  if (is.null(chunks) || !is.data.frame(chunks) || nrow(chunks) == 0) {
    message("[generate_conclusions_preset] Hybrid search empty, falling back to direct DB query")
    chunks <- tryCatch({
      if (notebook_type == "document") {
        dbGetQuery(con, "
          SELECT c.id, c.source_id, c.source_type, c.chunk_index, c.content, c.page_number,
                 d.filename as doc_name, NULL as abstract_title
          FROM chunks c
          JOIN documents d ON c.source_id = d.id
          WHERE d.notebook_id = ?
          ORDER BY c.chunk_index DESC
          LIMIT 10
        ", list(notebook_id))
      } else {
        dbGetQuery(con, "
          SELECT c.id, c.source_id, c.source_type, c.chunk_index, c.content, c.page_number,
                 NULL as doc_name, a.title as abstract_title
          FROM chunks c
          JOIN abstracts a ON c.source_id = a.id
          WHERE a.notebook_id = ?
          ORDER BY a.year DESC, c.chunk_index
          LIMIT 10
        ", list(notebook_id))
      }
    }, error = function(e) {
      message("[generate_conclusions_preset] Direct DB fallback failed: ", e$message)
      NULL
    })
  }

  if (is.null(chunks) || !is.data.frame(chunks) || nrow(chunks) == 0) {
    return("No content found in this notebook. Please add documents or search for papers first.")
  }

  # Build context
  context <- build_context(chunks)

  # OWASP LLM01:2025 compliant prompt (instructions BEFORE data, clear delimiters)
  system_prompt <- "You are a research synthesis assistant. Your task is to:
1. Summarize the key conclusions across the provided research sources
2. Identify common themes, agreements, and divergent positions
3. Propose future research directions based on identified gaps and limitations

IMPORTANT: Base your synthesis ONLY on the provided sources. Do not invent findings or cite sources not provided. If sources conflict, note the disagreement explicitly.

OUTPUT FORMAT:
## Research Conclusions
[Synthesized conclusions with citations using [Source Name] format]

## Agreements & Disagreements
[Where sources agree and diverge]

## Research Gaps & Future Directions
[Proposed directions based on limitations and gaps identified in the sources]"

  user_prompt <- sprintf("===== BEGIN RESEARCH SOURCES =====
%s
===== END RESEARCH SOURCES =====

Synthesize the conclusions and future research directions from the sources above.", context)

  messages <- format_chat_messages(system_prompt, user_prompt)

  # Generate response
  response <- tryCatch({
    result <- chat_completion(api_key, chat_model, messages)

    # Log cost if session_id provided
    if (!is.null(session_id) && !is.null(result$usage)) {
      cost <- estimate_cost(chat_model,
                          result$usage$prompt_tokens %||% 0,
                          result$usage$completion_tokens %||% 0)
      log_cost(con, "conclusion_synthesis", chat_model,
               result$usage$prompt_tokens %||% 0,
               result$usage$completion_tokens %||% 0,
               result$usage$total_tokens %||% 0,
               cost, session_id)
    }

    result$content
  }, error = function(e) {
    return(sprintf("Error generating synthesis: %s", e$message))
  })

  response
}
