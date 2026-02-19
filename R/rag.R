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
#' Uses ragnar's hybrid VSS + BM25 search for retrieval.
#'
#' @param con Database connection
#' @param config App config
#' @param question User question
#' @param notebook_id Notebook to query
#' @param session_id Optional Shiny session ID for cost logging (default NULL)
#' @return Generated response with citations
rag_query <- function(con, config, question, notebook_id, session_id = NULL) {
  # Extract settings with defensive scalar checks
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

  chunks <- tryCatch({
    search_chunks_hybrid(con, question, notebook_id, limit = 5)
  }, error = function(e) {
    message("Ragnar search failed: ", e$message)
    NULL
  })

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

#' Generate unified Overview preset (Summary + Key Points)
#'
#' Covers ALL content in the notebook (not RAG top-k).
#' Supports Concise/Detailed depth and Quick/Thorough mode.
#' Large notebooks are automatically batched to stay within LLM context limits.
#'
#' @param con Database connection
#' @param config App config
#' @param notebook_id Notebook ID
#' @param notebook_type Type of notebook ("document" or "search")
#' @param depth Summary depth: "concise" (1-2 paragraphs) or "detailed" (3-4 paragraphs)
#' @param mode LLM call strategy: "quick" (single call) or "thorough" (two calls)
#' @param session_id Optional Shiny session ID for cost logging (default NULL)
#' @return Generated markdown with ## Summary and ## Key Points sections
generate_overview_preset <- function(con, config, notebook_id,
                                     notebook_type = "document",
                                     depth = "concise",
                                     mode = "quick",
                                     session_id = NULL) {
  # Extract settings with defensive scalar checks
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

  # Retrieve ALL content (not RAG top-k) — no LIMIT
  content_df <- tryCatch({
    if (notebook_type == "document") {
      dbGetQuery(con, "
        SELECT c.content, d.filename AS source_name, c.page_number
        FROM chunks c
        JOIN documents d ON c.source_id = d.id
        WHERE d.notebook_id = ?
        ORDER BY d.created_at, c.chunk_index
      ", list(notebook_id))
    } else {
      dbGetQuery(con, "
        SELECT abstract AS content, title AS source_name, year
        FROM abstracts
        WHERE notebook_id = ?
          AND abstract IS NOT NULL
          AND LENGTH(abstract) > 0
        ORDER BY year DESC
      ", list(notebook_id))
    }
  }, error = function(e) {
    message("[generate_overview_preset] DB query failed: ", e$message)
    NULL
  })

  if (is.null(content_df) || nrow(content_df) == 0) {
    return("No content found in this notebook. Please add documents or search for papers first.")
  }

  # Batching thresholds
  BATCH_SIZE   <- if (notebook_type == "document") 10L else 20L
  CHAR_LIMIT   <- 300000L
  total_chars  <- sum(nchar(content_df$content), na.rm = TRUE)
  use_batching <- total_chars > CHAR_LIMIT || nrow(content_df) > BATCH_SIZE * 2L

  # Depth instruction string
  depth_instruction <- if (depth == "detailed") {
    "Write a detailed summary of 3-4 paragraphs."
  } else {
    "Write a summary of 1-2 paragraphs."
  }

  # Helper: format rows as delimited source block
  format_sources <- function(df) {
    rows <- vapply(seq_len(nrow(df)), function(i) {
      row <- df[i, , drop = FALSE]
      content <- as.character(row$content[1])
      if (notebook_type == "document") {
        name <- as.character(row$source_name[1])
        page <- if ("page_number" %in% names(row)) as.integer(row$page_number[1]) else NA_integer_
        header <- if (!is.na(page)) {
          sprintf("[Source: %s, Page %d]", name, page)
        } else {
          sprintf("[Source: %s]", name)
        }
        sprintf("%s\nContent: %s", header, content)
      } else {
        name <- as.character(row$source_name[1])
        year <- if ("year" %in% names(row)) as.integer(row$year[1]) else NA_integer_
        header <- if (!is.na(year)) {
          sprintf("[%d] %s (%d)", i, name, year)
        } else {
          sprintf("[%d] %s", i, name)
        }
        sprintf("%s\nAbstract: %s", header, content)
      }
    }, FUN.VALUE = character(1))
    paste(rows, collapse = "\n\n")
  }

  wrap_sources <- function(df) {
    sprintf("===== BEGIN SOURCES =====\n%s\n===== END SOURCES =====",
            format_sources(df))
  }

  # Helper: single "Quick" LLM call returning full overview text
  call_overview_quick <- function(df) {
    system_prompt <- sprintf(
      "You are a research synthesis assistant. Generate an Overview of the provided research sources.
The Overview must have exactly two sections:

## Summary
%s
Cover main themes, key findings, and important conclusions.
Base your summary ONLY on the provided sources.

## Key Points
Organize key points under thematic subheadings in this order: Background/Context, Methodology, Findings/Results, Limitations, Future Directions/Gaps.
Each subheading should contain 3-5 bullet points.
Do not use a flat bullet list - group all related points under their subheading.

IMPORTANT: Base all content ONLY on the provided sources. Do not invent findings.",
      depth_instruction
    )
    user_prompt <- sprintf("%s\n\nGenerate an Overview with a Summary and thematically organized Key Points.",
                           wrap_sources(df))
    messages <- format_chat_messages(system_prompt, user_prompt)

    tryCatch({
      result <- chat_completion(api_key, chat_model, messages)
      if (!is.null(session_id) && !is.null(result$usage)) {
        cost <- estimate_cost(chat_model,
                              result$usage$prompt_tokens %||% 0,
                              result$usage$completion_tokens %||% 0)
        log_cost(con, "overview", chat_model,
                 result$usage$prompt_tokens %||% 0,
                 result$usage$completion_tokens %||% 0,
                 result$usage$total_tokens %||% 0,
                 cost, session_id)
      }
      result$content
    }, error = function(e) {
      sprintf("Error generating overview: %s", e$message)
    })
  }

  # Helper: "Thorough" Call 1 — Summary only
  call_overview_summary <- function(df) {
    system_prompt <- sprintf(
      "You are a research summarizer. %s Cover main themes, key findings, and conclusions. Base the summary ONLY on the provided sources.",
      depth_instruction
    )
    user_prompt <- sprintf("%s\n\n%s",
                           wrap_sources(df),
                           depth_instruction)
    messages <- format_chat_messages(system_prompt, user_prompt)

    tryCatch({
      result <- chat_completion(api_key, chat_model, messages)
      if (!is.null(session_id) && !is.null(result$usage)) {
        cost <- estimate_cost(chat_model,
                              result$usage$prompt_tokens %||% 0,
                              result$usage$completion_tokens %||% 0)
        log_cost(con, "overview_summary", chat_model,
                 result$usage$prompt_tokens %||% 0,
                 result$usage$completion_tokens %||% 0,
                 result$usage$total_tokens %||% 0,
                 cost, session_id)
      }
      result$content
    }, error = function(e) {
      sprintf("Error generating summary: %s", e$message)
    })
  }

  # Helper: "Thorough" Call 2 — Key Points only
  call_overview_keypoints <- function(df) {
    system_prompt <- "You are a research analyst. Extract key points organized by theme from the provided research. Base all content ONLY on the provided sources. Do not invent findings."
    user_prompt <- sprintf(
      "%s\n\nExtract key points organized under thematic subheadings in this order: Background/Context, Methodology, Findings/Results, Limitations, Future Directions/Gaps. Each subheading: 3-5 bullet points.",
      wrap_sources(df)
    )
    messages <- format_chat_messages(system_prompt, user_prompt)

    tryCatch({
      result <- chat_completion(api_key, chat_model, messages)
      if (!is.null(session_id) && !is.null(result$usage)) {
        cost <- estimate_cost(chat_model,
                              result$usage$prompt_tokens %||% 0,
                              result$usage$completion_tokens %||% 0)
        log_cost(con, "overview_keypoints", chat_model,
                 result$usage$prompt_tokens %||% 0,
                 result$usage$completion_tokens %||% 0,
                 result$usage$total_tokens %||% 0,
                 cost, session_id)
      }
      result$content
    }, error = function(e) {
      sprintf("Error generating key points: %s", e$message)
    })
  }

  # Execute calls with optional batching
  if (mode == "thorough") {
    # --- Thorough mode: two separate LLM calls ---
    if (use_batching) {
      batches <- split(seq_len(nrow(content_df)),
                       ceiling(seq_len(nrow(content_df)) / BATCH_SIZE))
      summary_parts <- lapply(batches, function(idx) {
        call_overview_summary(content_df[idx, , drop = FALSE])
      })
      keypoints_parts <- lapply(batches, function(idx) {
        call_overview_keypoints(content_df[idx, , drop = FALSE])
      })
      summary_text   <- paste(summary_parts, collapse = "\n\n---\n\n")
      keypoints_text <- paste(keypoints_parts, collapse = "\n\n---\n\n")
      # TODO (future): if batch divergence causes inconsistency, add merge-pass LLM call
    } else {
      summary_text   <- call_overview_summary(content_df)
      keypoints_text <- call_overview_keypoints(content_df)
    }
    paste0("## Summary\n\n", summary_text, "\n\n## Key Points\n\n", keypoints_text)
  } else {
    # --- Quick mode: single LLM call ---
    if (use_batching) {
      batches <- split(seq_len(nrow(content_df)),
                       ceiling(seq_len(nrow(content_df)) / BATCH_SIZE))
      batch_results <- lapply(batches, function(idx) {
        call_overview_quick(content_df[idx, , drop = FALSE])
      })
      paste(batch_results, collapse = "\n\n---\n\n")
      # TODO (future): if batch divergence causes inconsistency, add merge-pass LLM call
    } else {
      call_overview_quick(content_df)
    }
  }
}
