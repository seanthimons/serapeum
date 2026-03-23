#' Reciprocal Rank Fusion (RRF) merge of multiple ranked lists
#'
#' Combines ranked lists using the formula: score = SUM(1 / (k + rank_i))
#' where rank_i is the 1-based position in each list.
#'
#' @param ranked_lists List of data frames, each must have a `hash` column for dedup
#'   and a `text` column. Other columns (origin, etc.) are preserved from the first occurrence.
#' @param k RRF constant (default 60, standard in literature)
#' @return Data frame sorted by RRF score descending, with `rrf_score` column added
rrf_merge <- function(ranked_lists, k = 60) {
  # Filter out empty lists
  ranked_lists <- ranked_lists[vapply(ranked_lists, function(df) {
    is.data.frame(df) && nrow(df) > 0
  }, logical(1))]

  if (length(ranked_lists) == 0) {
    return(data.frame(
      text = character(), origin = character(), hash = character(),
      rrf_score = numeric(), stringsAsFactors = FALSE
    ))
  }

  # Accumulate scores by hash
  scores <- list()  # hash -> score
  first_seen <- list()  # hash -> row data (preserve metadata from first occurrence)

  for (df in ranked_lists) {
    # Ensure hash column exists
    if (!"hash" %in% names(df)) next

    for (rank_i in seq_len(nrow(df))) {
      h <- df$hash[rank_i]
      if (is.na(h) || !nzchar(h)) next

      rrf_contribution <- 1 / (k + rank_i)

      if (is.null(scores[[h]])) {
        scores[[h]] <- rrf_contribution
        first_seen[[h]] <- df[rank_i, , drop = FALSE]
      } else {
        scores[[h]] <- scores[[h]] + rrf_contribution
      }
    }
  }

  if (length(scores) == 0) {
    return(data.frame(
      text = character(), origin = character(), hash = character(),
      rrf_score = numeric(), stringsAsFactors = FALSE
    ))
  }

  # Build result data frame
  # Align columns across all rows before rbind — VSS and BM25 results from ragnar

  # can have different schemas (e.g., VSS includes `embedding` column, BM25 does not).
  # NOTE: The `embedding` column from VSS contains the raw embedding vector for each
  # chunk. This is not currently used in the RAG chat path, but IS relevant for the
  # Research Refiner's embedding_similarity scoring (utils_scoring.R / mod_research_refiner.R).
  # If you drop it here, RR semantic scoring will lose its signal.
  all_cols <- unique(unlist(lapply(first_seen, names)))
  first_seen <- lapply(first_seen, function(row) {
    missing <- setdiff(all_cols, names(row))
    for (col in missing) row[[col]] <- NA
    row[, all_cols, drop = FALSE]
  })
  result <- do.call(rbind, first_seen)
  result$rrf_score <- vapply(result$hash, function(h) scores[[h]], numeric(1))

  # Sort by RRF score descending
  result <- result[order(-result$rrf_score), , drop = FALSE]
  rownames(result) <- NULL

  result
}

#' Parse LLM output into individual query variants
#'
#' Handles both plain newline-separated and numbered list formats.
#'
#' @param text Raw LLM response text
#' @return Character vector of clean query variants
parse_query_variants <- function(text) {
  lines <- strsplit(text, "\n")[[1]]
  lines <- trimws(lines)
  lines <- lines[nchar(lines) > 0]

  # Strip numbering: "1. query" or "1) query" or "- query"
  lines <- sub("^\\d+[.):]\\s*", "", lines)
  lines <- sub("^[-*]\\s*", "", lines)
  lines <- trimws(lines)
  lines <- lines[nchar(lines) > 0]

  lines
}

#' Generate query variants for RAG-Fusion retrieval
#'
#' Uses a fast LLM call to generate alternative search queries that capture
#' different vocabulary and angles. Always includes the original query.
#'
#' @param query Original user query
#' @param provider provider_config object
#' @param model LLM model to use
#' @param con Optional DuckDB connection for cost logging
#' @param session_id Optional session ID for cost logging
#' @param n_variants Number of variants to generate (default 3)
#' @return Character vector: original query + n_variants alternatives
generate_query_variants <- function(query, provider, model, con = NULL,
                                     session_id = NULL, n_variants = 3) {
  system_prompt <- sprintf(
    "Generate %d alternative search queries for the following research question. Each variant should use different vocabulary, synonyms, or approach the topic from a different angle. Return only the queries, one per line.",
    n_variants
  )

  messages <- format_chat_messages(system_prompt, query)

  result <- tryCatch({
    provider_chat_completion(provider, model, messages)
  }, error = function(e) {
    message("[rag] Query reformulation failed: ", e$message)
    return(NULL)
  })

  if (is.null(result)) return(query)

  # Log cost
  if (!is.null(con) && !is.null(session_id) && !is.null(result$usage)) {
    cost <- estimate_cost(model,
                          result$usage$prompt_tokens %||% 0,
                          result$usage$completion_tokens %||% 0,
                          is_local = is_local_provider(provider))
    log_cost(con, "query_reformulation", model,
             result$usage$prompt_tokens %||% 0,
             result$usage$completion_tokens %||% 0,
             result$usage$total_tokens %||% 0,
             cost, session_id,
             duration_ms = result$duration_ms)
  }

  # Parse variants and prepend original
  variants <- parse_query_variants(result$content)
  unique(c(query, variants))
}

#' Format a citation label from author JSON and year
#'
#' Parses author JSON (array of strings or objects with display_name) and year
#' into academic citation format like "Smith et al. (2023)".
#'
#' @param authors_json JSON string of authors, or NULL/NA
#' @param year Integer year, or NULL/NA
#' @param fallback_label Character fallback when author/year unavailable
#' @return Formatted label string
format_citation_label <- function(authors_json, year, fallback_label = "[Source]") {
  # Parse authors to "LastName et al." format

  author_str <- tryCatch({
    if (is.null(authors_json) || length(authors_json) == 0 ||
        isTRUE(is.na(authors_json)) || !nzchar(trimws(authors_json))) {
      NULL
    } else {
      parsed <- jsonlite::fromJSON(authors_json)

      # Handle double-encoding (#177): if fromJSON returns a string that looks
      # like JSON, try parsing again
      if (is.character(parsed) && length(parsed) == 1 && grepl("^\\[", parsed)) {
        parsed <- tryCatch(jsonlite::fromJSON(parsed), error = function(e) parsed)
      }

      if (is.null(parsed) || length(parsed) == 0) {
        NULL
      } else if (is.data.frame(parsed) && "display_name" %in% names(parsed)) {
        last_names <- vapply(parsed$display_name, function(a) {
          parts <- strsplit(trimws(a), "\\s+")[[1]]
          parts[length(parts)]
        }, character(1))
        if (length(last_names) == 0) NULL
        else if (length(last_names) > 2) paste0(last_names[1], " et al.")
        else if (length(last_names) == 2) paste0(last_names[1], " & ", last_names[2])
        else last_names[1]
      } else if (is.character(parsed)) {
        last_names <- vapply(parsed, function(a) {
          parts <- strsplit(trimws(a), "\\s+")[[1]]
          parts[length(parts)]
        }, character(1))
        if (length(last_names) == 0) NULL
        else if (length(last_names) > 2) paste0(last_names[1], " et al.")
        else if (length(last_names) == 2) paste0(last_names[1], " & ", last_names[2])
        else last_names[1]
      } else {
        NULL
      }
    }
  }, error = function(e) NULL)

  # Normalize year
  yr <- tryCatch(as.integer(year), error = function(e) NA_integer_)
  if (length(yr) == 0 || isTRUE(is.na(yr))) yr <- NA_integer_

  # Build label with fallback chain
  if (!is.null(author_str) && !is.na(yr)) {
    sprintf("%s (%d)", author_str, yr)
  } else if (!is.null(author_str)) {
    sprintf("%s (n.d.)", author_str)
  } else if (!is.na(yr)) {
    sprintf("Unknown (%d)", yr)
  } else {
    fallback_label
  }
}

#' Build RAG context from retrieved chunks
#' @param chunks Data frame of chunks from search_chunks
#' @return Formatted context string
build_context <- function(chunks) {
  if (!is.data.frame(chunks) || nrow(chunks) == 0) return("")

  contexts <- vapply(seq_len(nrow(chunks)), function(i) {
    chunk <- chunks[i, , drop = FALSE]

    # Safely extract scalar values (handle potential vector/NULL cases)
    safe_chr <- function(field) {
      if (field %in% names(chunk)) {
        val <- chunk[[field]]
        if (length(val) > 0 && !isTRUE(is.na(val[1]))) return(as.character(val)[1])
      }
      NA_character_
    }
    safe_int <- function(field) {
      if (field %in% names(chunk)) {
        val <- chunk[[field]]
        if (length(val) > 0 && !isTRUE(is.na(val[1]))) return(as.integer(val)[1])
      }
      NA_integer_
    }

    doc_name <- safe_chr("doc_name")
    abstract_title <- safe_chr("abstract_title")
    abstract_authors <- safe_chr("abstract_authors")
    doc_authors <- safe_chr("doc_authors")
    page_number <- safe_int("page_number")
    abstract_year <- safe_int("abstract_year")
    doc_year <- safe_int("doc_year")
    content <- safe_chr("content")
    if (is.na(content)) content <- ""

    # Build source label using format_citation_label() when metadata available
    source <- "[Source]"
    if (!is.na(doc_name) && nchar(doc_name) > 0) {
      # Document chunk: try author/year, fall back to filename
      label <- format_citation_label(doc_authors, doc_year, fallback_label = doc_name)
      if (!is.na(page_number)) {
        source <- sprintf("[%s, p.%d]", label, page_number)
      } else {
        source <- sprintf("[%s]", label)
      }
    } else if (!is.na(abstract_title) && nchar(abstract_title) > 0) {
      # Abstract chunk: try author/year, fall back to title
      source <- sprintf("[%s]",
        format_citation_label(abstract_authors, abstract_year,
                               fallback_label = abstract_title))
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
  # Build provider from config
  provider <- provider_from_config(config, con)

  chat_model <- resolve_model_for_operation(config, "chat")

  # Safely check api_key
  api_key <- provider$api_key
  api_key_empty <- is.null(api_key) || isTRUE(is.na(api_key)) ||
                   (is.character(api_key) && nchar(api_key) == 0)
  if (api_key_empty) {
    return("Error: OpenRouter API key not configured. Please set your API key in Settings.")
  }

  embed_model <- resolve_model_for_operation(config, "embedding")

  # Debug: check store existence
  store_path <- get_notebook_ragnar_path(notebook_id)
  message("[rag_query] Store path: ", store_path, " exists: ", file.exists(store_path))

  chunks <- tryCatch({
    search_chunks_hybrid(con, question, notebook_id, limit = 5,
                         provider = provider, embed_model = embed_model,
                         config = config, session_id = session_id)
  }, error = function(e) {
    message("[rag_query] Ragnar search failed: ", e$message)
    NULL
  })

  if (!is.data.frame(chunks) || nrow(chunks) == 0) {
    # Provide actionable feedback based on store state
    if (!file.exists(store_path)) {
      return("No search index found for this notebook. Please re-index to enable RAG chat (use the rebuild button in the document list).")
    }
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
  system_prompt <- "You are a helpful research assistant. Answer questions based ONLY on the provided sources. If the sources don't contain enough information to fully answer the question, say so clearly.

CITATION RULES:
- Each source is labeled with its citation in brackets, e.g., [Smith et al. (2023), p.5] or [Jones & Lee (2021)]
- Cite every substantive claim using the author and year from the source label: (Smith et al., 2023, p.5)
- When the label includes a page number: (Author, Year, p.X)
- When the source is an abstract with no page: (Author, Year)
- When multiple sources support a claim, cite all: (Smith et al., 2023, p.5; Jones & Lee, 2021)
- Use the citation exactly as it appears in the source label — do not invent author names or years

Correct: \"Studies show increased resistance rates (Smith et al., 2023, p.12; WHO, 2024, p.45).\"
Wrong: \"Studies show increased resistance rates [Abstract].\"
Wrong: \"Studies show increased resistance rates.\" (missing citation)"

  user_prompt <- sprintf("Sources:\n%s\n\nQuestion: %s", context, question)

  messages <- format_chat_messages(system_prompt, user_prompt)

  # Generate response
  response <- tryCatch({
    result <- provider_chat_completion(provider, chat_model, messages)

    # Log cost if session_id provided
    if (!is.null(session_id) && !is.null(result$usage)) {
      cost <- estimate_cost(chat_model,
                          result$usage$prompt_tokens %||% 0,
                          result$usage$completion_tokens %||% 0,
                          is_local = is_local_provider(provider))
      log_cost(con, "chat", chat_model,
               result$usage$prompt_tokens %||% 0,
               result$usage$completion_tokens %||% 0,
               result$usage$total_tokens %||% 0,
               cost, session_id,
               duration_ms = result$duration_ms)
    }

    result$content
  }, error = function(e) {
    return(sprintf("Error generating response: %s", e$message))
  })

  response
}

#' Get the task instruction for a preset type
#' @param preset_type Preset type string
#' @return Task instruction string, or NULL if unknown
get_preset_instruction <- function(preset_type) {
  presets <- list(
    summarize = "Provide a comprehensive summary of all the documents. Highlight the main themes, key findings, and important conclusions. Organize your summary with clear sections.",
    keypoints = "Extract the key points from these documents as a bulleted list. Focus on the most important facts, findings, arguments, and conclusions. Group related points together.",
    studyguide = "Create a study guide based on these documents. Include:\n1. Key concepts and definitions\n2. Important facts and figures\n3. Main arguments and their supporting evidence\n4. Potential exam questions with brief answers",
    outline = "Create a structured outline of the main topics covered in these documents. Use hierarchical headings (I, A, 1, a) to organize the content logically. Include brief descriptions under each heading.",
    overview = "Generate an overview with a summary and thematically organized key points from the research sources.",
    conclusions = "Synthesize the conclusions, limitations, and future research directions from these papers. Identify common themes and divergences across studies.",
    lit_review = "Create a literature review comparison table with columns: Paper, Year, Methods, Key Findings, Limitations. Cover all papers in the collection.",
    methodology_extractor = "Extract and compare research methodologies across these papers. For each paper, identify: study design, data sources, sample/population, analytical methods, and key variables.",
    gap_analysis = "Identify research gaps by analyzing what topics, methods, and questions are NOT covered by the current collection. Suggest specific future research directions."
  )
  presets[[preset_type]]
}

#' Generate preset content (summary, key points, etc.)
#' @param con Database connection
#' @param config App config
#' @param notebook_id Notebook ID
#' @param preset_type Type of preset ("summarize", "keypoints", "studyguide", "outline",
#'   "overview", "conclusions", "lit_review", "methodology_extractor", "gap_analysis")
#' @param session_id Optional Shiny session ID for cost logging (default NULL)
#' @param custom_prompt Optional custom prompt to override the default preset instruction
#' @return Generated content
generate_preset <- function(con, config, notebook_id, preset_type, session_id = NULL,
                            custom_prompt = NULL) {
  prompt <- custom_prompt %||% get_effective_prompt(con, preset_type)
  if (is.null(prompt)) {
    return(sprintf("Unknown preset type: %s", preset_type))
  }

  provider <- provider_from_config(config, con)

  chat_model <- resolve_model_for_operation(config, "chat")

  # Safely check api_key
  api_key <- provider$api_key
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
             d.filename as doc_name, NULL as abstract_title,
             d.authors as doc_authors, d.year as doc_year,
             NULL as abstract_authors, NULL as abstract_year
      FROM chunks c
      JOIN documents d ON c.source_id = d.id
      WHERE d.notebook_id = ?
      ORDER BY d.created_at, c.chunk_index
      LIMIT 50
    ", list(notebook_id))
  } else {
    chunks <- dbGetQuery(con, "
      SELECT c.id, c.source_id, c.source_type, c.chunk_index, c.content, c.page_number,
             NULL as doc_name, a.title as abstract_title,
             NULL as doc_authors, NULL as doc_year,
             a.authors as abstract_authors, a.year as abstract_year
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

  system_prompt <- "You are a helpful research assistant. Generate the requested content based on the provided sources. Be thorough and well-organized.

CITATION RULES:
- Each source is labeled with its citation in brackets, e.g., [Smith et al. (2023), p.5] or [Jones & Lee (2021)]
- Cite every substantive claim using the author and year from the source label: (Smith et al., 2023, p.5)
- When the label includes a page number: (Author, Year, p.X)
- When the source is an abstract with no page: (Author, Year)
- When multiple sources support a claim, cite all: (Smith et al., 2023, p.5; Jones & Lee, 2021)
- Use the citation exactly as it appears in the source label — do not invent author names or years

Correct: \"Machine learning improves diagnostic accuracy (Chen et al., 2023, p.15; WHO, 2024, p.8).\"
Wrong: \"Machine learning improves diagnostic accuracy.\" (missing citation)"
  user_prompt <- sprintf("Sources:\n%s\n\nTask: %s", context, prompt)

  messages <- format_chat_messages(system_prompt, user_prompt)

  response <- tryCatch({
    result <- provider_chat_completion(provider, chat_model, messages)

    # Log cost if session_id provided
    if (!is.null(session_id) && !is.null(result$usage)) {
      cost <- estimate_cost(chat_model,
                          result$usage$prompt_tokens %||% 0,
                          result$usage$completion_tokens %||% 0,
                          is_local = is_local_provider(provider))
      log_cost(con, "chat", chat_model,
               result$usage$prompt_tokens %||% 0,
               result$usage$completion_tokens %||% 0,
               result$usage$total_tokens %||% 0,
               cost, session_id,
               duration_ms = result$duration_ms)
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
  provider <- provider_from_config(config, con)

  chat_model <- resolve_model_for_operation(config, "conclusion_synthesis")
  embed_model <- resolve_model_for_operation(config, "embedding")

  # Check api_key
  api_key <- provider$api_key
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
        query = "conclusions results findings discussion agreements",
        notebook_id = notebook_id,
        limit = 10,
        section_filter = c("conclusion", "limitations", "future_work", "discussion", "late_section"),
        provider = provider, embed_model = embed_model
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
          query = "conclusions results findings discussion agreements",
          notebook_id = notebook_id,
          limit = 10,
          provider = provider, embed_model = embed_model
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
        query = "conclusions results findings discussion agreements",
        notebook_id = notebook_id,
        limit = 10,
        provider = provider, embed_model = embed_model
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
  task_instruction <- get_effective_prompt(con, "conclusions")
  system_prompt <- paste0(
    "You are a research synthesis assistant. Your task is to:\n",
    task_instruction,
    "\n\nCITATION RULES:\n",
    "- Cite every substantive claim using (Author, Year, p.X) format\n",
    "- When page metadata is available: (Author, Year, p.X)\n",
    "- When source is an abstract only: (Author, Year, abstract)\n",
    "- When page number is missing: (Author, Year, chunk N)\n",
    "- When multiple sources support a claim, cite all: (Smith, 2023, p.5; Jones, 2022, p.12)\n",
    "- Extract author name and year from the source labels provided\n\n",
    "Correct: \"Multiple studies confirm reduced efficacy (Smith, 2023, p.14; Jones, 2022, p.8).\"\n",
    "Wrong: \"Multiple studies confirm reduced efficacy [Source Name].\"\n\n",
    "OUTPUT FORMAT:\n",
    "## Research Conclusions\n",
    "[Synthesized conclusions with (Author, Year, p.X) citations]\n\n",
    "## Agreements & Disagreements\n",
    "[Where sources agree and diverge, with specific (Author, Year, p.X) citations]"
  )

  user_prompt <- sprintf("===== BEGIN RESEARCH SOURCES =====
%s
===== END RESEARCH SOURCES =====

Synthesize the key conclusions and identify where sources agree or diverge.", context)

  messages <- format_chat_messages(system_prompt, user_prompt)

  # Generate response
  response <- tryCatch({
    result <- provider_chat_completion(provider, chat_model, messages)

    # Log cost if session_id provided
    if (!is.null(session_id) && !is.null(result$usage)) {
      cost <- estimate_cost(chat_model,
                          result$usage$prompt_tokens %||% 0,
                          result$usage$completion_tokens %||% 0,
                          is_local = is_local_provider(provider))
      log_cost(con, "conclusion_synthesis", chat_model,
               result$usage$prompt_tokens %||% 0,
               result$usage$completion_tokens %||% 0,
               result$usage$total_tokens %||% 0,
               cost, session_id,
               duration_ms = result$duration_ms)
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
  provider <- provider_from_config(config, con)

  chat_model <- resolve_model_for_operation(config, "overview")

  # Check api_key
  api_key <- provider$api_key
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
    task_instruction <- get_effective_prompt(con, "overview")
    system_prompt <- sprintf(
      "You are a research synthesis assistant. %s\n\nCITATION RULES:\n- Cite every substantive claim using (Author, Year, p.X) format\n- For abstracts: (Author, Year, abstract)\n- For missing page numbers: (Author, Year, chunk N)\n- When multiple sources support a claim, cite all\n- Extract author/year from the source labels in the provided data",
      sprintf(task_instruction, depth_instruction)
    )
    user_prompt <- sprintf("%s\n\nGenerate an Overview with a Summary and thematically organized Key Points.",
                           wrap_sources(df))
    messages <- format_chat_messages(system_prompt, user_prompt)

    tryCatch({
      result <- provider_chat_completion(provider, chat_model, messages)
      if (!is.null(session_id) && !is.null(result$usage)) {
        cost <- estimate_cost(chat_model,
                              result$usage$prompt_tokens %||% 0,
                              result$usage$completion_tokens %||% 0,
                              is_local = is_local_provider(provider))
        log_cost(con, "overview", chat_model,
                 result$usage$prompt_tokens %||% 0,
                 result$usage$completion_tokens %||% 0,
                 result$usage$total_tokens %||% 0,
                 cost, session_id,
               duration_ms = result$duration_ms)
      }
      result$content
    }, error = function(e) {
      sprintf("Error generating overview: %s", e$message)
    })
  }

  # Citation and grounding instructions appended to all overview calls
  citation_rules <- "Base all content ONLY on the provided sources. Do not invent findings. Cite every substantive claim using (Author, Year, p.X) format. For abstracts: (Author, Year, abstract). For missing page numbers: (Author, Year, chunk N)."

  # Helper: "Thorough" Call 1 — Summary only
  call_overview_summary <- function(df) {
    system_prompt <- sprintf(
      "You are a research summarizer. %s %s %s",
      get_effective_prompt(con, "summarize"),
      citation_rules,
      depth_instruction
    )
    user_prompt <- sprintf("%s\n\n%s",
                           wrap_sources(df),
                           depth_instruction)
    messages <- format_chat_messages(system_prompt, user_prompt)

    tryCatch({
      result <- provider_chat_completion(provider, chat_model, messages)
      if (!is.null(session_id) && !is.null(result$usage)) {
        cost <- estimate_cost(chat_model,
                              result$usage$prompt_tokens %||% 0,
                              result$usage$completion_tokens %||% 0,
                              is_local = is_local_provider(provider))
        log_cost(con, "overview_summary", chat_model,
                 result$usage$prompt_tokens %||% 0,
                 result$usage$completion_tokens %||% 0,
                 result$usage$total_tokens %||% 0,
                 cost, session_id,
               duration_ms = result$duration_ms)
      }
      result$content
    }, error = function(e) {
      sprintf("Error generating summary: %s", e$message)
    })
  }

  # Helper: "Thorough" Call 2 — Key Points only
  call_overview_keypoints <- function(df) {
    system_prompt <- sprintf(
      "You are a research analyst. %s %s",
      get_effective_prompt(con, "keypoints"),
      citation_rules
    )
    user_prompt <- sprintf(
      "%s\n\nExtract key points organized under thematic subheadings in this order: Background/Context, Methodology, Findings/Results, Limitations, Future Directions/Gaps. Each subheading: 3-5 bullet points.",
      wrap_sources(df)
    )
    messages <- format_chat_messages(system_prompt, user_prompt)

    tryCatch({
      result <- provider_chat_completion(provider, chat_model, messages)
      if (!is.null(session_id) && !is.null(result$usage)) {
        cost <- estimate_cost(chat_model,
                              result$usage$prompt_tokens %||% 0,
                              result$usage$completion_tokens %||% 0,
                              is_local = is_local_provider(provider))
        log_cost(con, "overview_keypoints", chat_model,
                 result$usage$prompt_tokens %||% 0,
                 result$usage$completion_tokens %||% 0,
                 result$usage$total_tokens %||% 0,
                 cost, session_id,
               duration_ms = result$duration_ms)
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

#' Generate research questions from notebook papers
#'
#' Identifies research gaps across collected papers and generates focused,
#' gap-grounded research questions with author/year citations.
#' Uses hybrid RAG retrieval targeted at gap-revealing content.
#'
#' @param con Database connection
#' @param config App config
#' @param notebook_id Notebook ID
#' @param notebook_type Type of notebook ("search" or "document")
#' @param session_id Optional Shiny session ID for cost logging (default NULL)
#' @return Generated research questions as markdown string
generate_research_questions <- function(con, config, notebook_id, notebook_type = "search", session_id = NULL) {
  # Extract settings
  provider <- provider_from_config(config, con)

  chat_model <- resolve_model_for_operation(config, "research_questions")
  embed_model <- resolve_model_for_operation(config, "embedding")

  # Check api_key
  api_key <- provider$api_key
  api_key_empty <- is.null(api_key) || isTRUE(is.na(api_key)) ||
                   (is.character(api_key) && nchar(api_key) == 0)
  if (api_key_empty) {
    return("Error: OpenRouter API key not configured. Please set your API key in Settings.")
  }

  # Early return for small notebooks (need at least 2 papers to identify gaps)
  paper_count <- tryCatch({
    dbGetQuery(con, "SELECT COUNT(*) as cnt FROM abstracts WHERE notebook_id = ?", list(notebook_id))$cnt[1]
  }, error = function(e) {
    message("[generate_research_questions] Paper count query failed: ", e$message)
    0L
  })

  if (is.na(paper_count) || paper_count < 2) {
    return("At least 2 papers are needed to identify research gaps and generate research questions.")
  }

  # Get paper metadata for citation info
  papers <- tryCatch({
    dbGetQuery(con, "SELECT id, title, authors, year FROM abstracts WHERE notebook_id = ?", list(notebook_id))
  }, error = function(e) {
    message("[generate_research_questions] Paper metadata query failed: ", e$message)
    NULL
  })

  # Format citation-ready paper list for the prompt
  paper_list_text <- if (!is.null(papers) && nrow(papers) > 0) {
    paper_refs <- vapply(seq_len(nrow(papers)), function(i) {
      authors <- tryCatch(
        jsonlite::fromJSON(papers$authors[i]),
        error = function(e) character()
      )
      author_str <- if (length(authors) == 0) "Unknown"
        else if (length(authors) > 2) paste0(authors[1], " et al.")
        else paste(authors, collapse = " & ")
      year_str <- if (is.na(papers$year[i])) "n.d." else as.character(papers$year[i])
      sprintf("- %s (%s): \"%s\"", author_str, year_str, papers$title[i])
    }, character(1))
    paste(paper_refs, collapse = "\n")
  } else {
    "(Paper metadata unavailable)"
  }

  # Retrieve chunks via hybrid search (gap-focused query)
  chunks <- NULL

  # For search notebooks: no section filter (abstracts lack section structure)
  chunks <- tryCatch({
    search_chunks_hybrid(
      con,
      query = "research gaps limitations future work methodology population understudied contradictions",
      notebook_id = notebook_id,
      limit = 15,
      provider = provider, embed_model = embed_model
    )
  }, error = function(e) {
    message("[generate_research_questions] Hybrid search failed: ", e$message)
    NULL
  })

  # Fallback: direct DB query if hybrid search returned nothing
  if (is.null(chunks) || !is.data.frame(chunks) || nrow(chunks) == 0) {
    message("[generate_research_questions] Hybrid search empty, falling back to direct DB query")
    chunks <- tryCatch({
      if (notebook_type == "document") {
        dbGetQuery(con, "
          SELECT c.id, c.source_id, c.source_type, c.chunk_index, c.content, c.page_number,
                 d.filename as doc_name, NULL as abstract_title
          FROM chunks c
          JOIN documents d ON c.source_id = d.id
          WHERE d.notebook_id = ?
          ORDER BY c.chunk_index DESC
          LIMIT 15
        ", list(notebook_id))
      } else {
        dbGetQuery(con, "
          SELECT c.id, c.source_id, c.source_type, c.chunk_index, c.content, c.page_number,
                 NULL as doc_name, a.title as abstract_title
          FROM chunks c
          JOIN abstracts a ON c.source_id = a.id
          WHERE a.notebook_id = ?
          ORDER BY a.year DESC, c.chunk_index
          LIMIT 15
        ", list(notebook_id))
      }
    }, error = function(e) {
      message("[generate_research_questions] Direct DB fallback failed: ", e$message)
      NULL
    })
  }

  if (is.null(chunks) || !is.data.frame(chunks) || nrow(chunks) == 0) {
    return("No content found in this notebook. Please add documents or search for papers first.")
  }

  # Build context
  context <- build_context(chunks)

  # System prompt: gap analyst role with PICO-invisible adaptive framing
  task_instruction <- get_effective_prompt(con, "research_questions")
  system_prompt <- paste0(
    "You are a research gap analyst. Your task is to identify gaps in the existing research and generate focused research questions.\n\n",
    task_instruction
  )

  # User prompt with paper metadata + retrieved content
  user_prompt <- sprintf(
    "===== PAPER METADATA =====\n%s\n\n===== RETRIEVED CONTENT =====\n%s\n===== END SOURCES =====\n\nThis collection contains %d paper%s. Analyze the research above and generate research questions that address identified gaps.",
    paper_list_text,
    context,
    paper_count,
    if (paper_count == 1L) "" else "s"
  )

  messages <- format_chat_messages(system_prompt, user_prompt)

  # Generate response
  response <- tryCatch({
    result <- provider_chat_completion(provider, chat_model, messages)

    # Log cost if session_id provided
    if (!is.null(session_id) && !is.null(result$usage)) {
      cost <- estimate_cost(chat_model,
                          result$usage$prompt_tokens %||% 0,
                          result$usage$completion_tokens %||% 0,
                          is_local = is_local_provider(provider))
      log_cost(con, "research_questions", chat_model,
               result$usage$prompt_tokens %||% 0,
               result$usage$completion_tokens %||% 0,
               result$usage$total_tokens %||% 0,
               cost, session_id,
               duration_ms = result$duration_ms)
    }

    result$content
  }, error = function(e) {
    return(sprintf("Error generating research questions: %s", e$message))
  })

  response
}

#' Build context string grouped by paper with delimiters
#' @param papers_with_chunks List of lists, each with $label, $doc_id, $chunks data frame
#' @return Single string with === PAPER: {label} === delimiters
build_context_by_paper <- function(papers_with_chunks) {
  sections <- vapply(papers_with_chunks, function(paper) {
    if (is.null(paper$chunks) || nrow(paper$chunks) == 0) {
      return(sprintf("=== PAPER: %s ===\n[No content available]", paper$label))
    }

    chunk_texts <- vapply(seq_len(nrow(paper$chunks)), function(i) {
      hint <- if (!is.na(paper$chunks$section_hint[i])) paper$chunks$section_hint[i] else "general"
      page_ref <- if (!isTRUE(is.na(paper$chunks$page_number[i]))) {
        sprintf("p.%d, ", paper$chunks$page_number[i])
      } else {
        ""
      }
      sprintf("[%s%s] %s", page_ref, hint, paper$chunks$content[i])
    }, character(1))

    sprintf("=== PAPER: %s ===\n%s", paper$label, paste(chunk_texts, collapse = "\n\n"))
  }, character(1))

  paste(sections, collapse = "\n\n")
}

#' Validate that LLM output is a well-formed GFM pipe table
#' @param text Character string of LLM output
#' @return TRUE if valid GFM table (consistent pipe counts), FALSE otherwise
validate_gfm_table <- function(text) {
  lines <- strsplit(text, "\n")[[1]]
  table_lines <- trimws(lines[grepl("\\|", lines)])
  table_lines <- table_lines[nchar(table_lines) > 0]

  if (length(table_lines) < 3) return(FALSE)  # header + separator + at least 1 row

  pipe_counts <- vapply(table_lines, function(l) {
    nchar(gsub("[^|]", "", l))
  }, integer(1), USE.NAMES = FALSE)

  length(unique(pipe_counts)) == 1
}

#' Generate a literature review comparison table for all documents in a notebook
#' @param con DuckDB connection
#' @param config Config list with api_key, chat_model
#' @param notebook_id Notebook ID
#' @param session_id Optional session token for cost logging
#' @return GFM pipe table string with DOI injection, or error message string
generate_lit_review_table <- function(con, config, notebook_id, session_id = NULL) {
  tryCatch({
    # API setup
    provider <- provider_from_config(config, con)
    api_key <- provider$api_key %||% ""
    if (nchar(trimws(api_key)) == 0) {
      return("API key not configured. Please add your OpenRouter API key in Settings.")
    }
    chat_model <- resolve_model_for_operation(config, "lit_review_table")

    # Get documents with metadata
    docs <- dbGetQuery(con, "
      SELECT id, filename, title, authors, year, doi
      FROM documents WHERE notebook_id = ?
      ORDER BY year DESC NULLS LAST, filename
    ", list(notebook_id))

    if (nrow(docs) == 0) {
      return("No documents found in this notebook.")
    }

    paper_count <- nrow(docs)

    # Build paper labels with metadata fallback
    paper_labels <- lapply(seq_len(nrow(docs)), function(i) {
      doc <- docs[i, ]
      if (!is.na(doc$title) && !is.na(doc$authors) && !is.na(doc$year)) {
        authors_parsed <- tryCatch(jsonlite::fromJSON(doc$authors), error = function(e) NULL)
        if (!is.null(authors_parsed) && length(authors_parsed) > 0) {
          # Extract last names - authors stored as JSON array of objects with display_name
          if (is.data.frame(authors_parsed) && "display_name" %in% names(authors_parsed)) {
            last_names <- vapply(authors_parsed$display_name, function(a) {
              parts <- strsplit(trimws(a), "\\s+")[[1]]
              parts[length(parts)]
            }, character(1))
          } else if (is.character(authors_parsed)) {
            last_names <- vapply(authors_parsed, function(a) {
              parts <- strsplit(trimws(a), "\\s+")[[1]]
              parts[length(parts)]
            }, character(1))
          } else {
            last_names <- "Unknown"
          }

          author_str <- if (length(last_names) > 2) {
            paste0(last_names[1], " et al.")
          } else if (length(last_names) == 2) {
            paste0(last_names[1], " & ", last_names[2])
          } else {
            last_names[1]
          }
          label <- sprintf("%s (%d)", author_str, doc$year)
        } else {
          label <- sprintf("Unknown (%s)", if (!is.na(doc$year)) as.character(doc$year) else "n.d.")
        }
      } else {
        label <- tools::file_path_sans_ext(doc$filename)
      }
      list(label = label, doi = doc$doi, doc_id = doc$id)
    })

    # Section-aware chunk retrieval with dynamic token budget
    # CRITICAL: lapply is INSIDE the repeat loop so re-querying occurs when chunks_per_paper is reduced
    max_context_tokens <- 80000L
    chunks_per_paper <- 7L

    repeat {
      # Re-query chunks with current chunks_per_paper limit
      papers_data <- lapply(seq_len(nrow(docs)), function(i) {
        doc <- docs[i, ]

        # Try section-filtered first
        section_chunks <- dbGetQuery(con, "
          SELECT chunk_index, content, page_number, section_hint
          FROM chunks
          WHERE source_id = ? AND section_hint IN ('methods', 'methodology', 'results', 'limitations', 'discussion', 'conclusion')
          ORDER BY chunk_index
          LIMIT ?
        ", list(doc$id, chunks_per_paper))

        if (nrow(section_chunks) < 2) {
          # Fallback: distributed sampling
          all_chunks <- dbGetQuery(con, "
            SELECT chunk_index, content, page_number,
                   COALESCE(section_hint, 'general') as section_hint
            FROM chunks WHERE source_id = ?
            ORDER BY chunk_index
          ", list(doc$id))

          if (nrow(all_chunks) > chunks_per_paper) {
            n <- nrow(all_chunks)
            indices <- unique(c(1, 2, ceiling(n/2), n-1, n))
            indices <- indices[indices >= 1 & indices <= n]
            indices <- sort(head(indices, chunks_per_paper))
            all_chunks <- all_chunks[indices, ]
          }
          section_chunks <- all_chunks
        }

        list(label = paper_labels[[i]]$label, doc_id = doc$id, chunks = section_chunks)
      })

      # Estimate tokens
      total_est <- sum(vapply(papers_data, function(p) {
        if (is.null(p$chunks) || nrow(p$chunks) == 0) return(0)
        ceiling(nchar(paste(p$chunks$content, collapse = " ")) / 4)
      }, numeric(1)))

      if (total_est <= max_context_tokens || chunks_per_paper <= 2L) break
      chunks_per_paper <- chunks_per_paper - 1L
    }

    # Token budget hard check after loop
    context <- build_context_by_paper(papers_data)
    est_tokens <- ceiling(nchar(context) / 4)
    if (est_tokens > max_context_tokens) {
      return(sprintf(
        "The combined document content (~%dk tokens) exceeds the analysis limit (%dk). Consider splitting documents across multiple notebooks or reducing the number of papers.",
        round(est_tokens / 1000), round(max_context_tokens / 1000)
      ))
    }

    # System prompt
    task_instruction <- get_effective_prompt(con, "lit_review")
    system_prompt <- paste0(
      "You are a systematic review assistant. Generate a literature review comparison table in GFM (GitHub Flavored Markdown) pipe table format.\n\n",
      task_instruction
    )

    # User prompt
    user_prompt <- sprintf(
      "===== DOCUMENTS (%d papers) =====\n%s\n===== END =====\n\nGenerate the literature review comparison table.",
      paper_count, context
    )

    messages <- format_chat_messages(system_prompt, user_prompt)
    result <- provider_chat_completion(provider, chat_model, messages)

    if (!is.null(session_id) && !is.null(result$usage)) {
      cost <- estimate_cost(chat_model,
                            result$usage$prompt_tokens %||% 0,
                            result$usage$completion_tokens %||% 0,
                            is_local = is_local_provider(provider))
      log_cost(con, "lit_review_table", chat_model,
               result$usage$prompt_tokens %||% 0,
               result$usage$completion_tokens %||% 0,
               result$usage$total_tokens %||% 0,
               cost, session_id,
               duration_ms = result$duration_ms)
    }

    response <- result$content

    # Strip any markdown code fences the LLM might wrap the table in
    response <- gsub("^```[a-z]*\\s*\n", "", response)
    response <- gsub("\n```\\s*$", "", response)
    response <- trimws(response)

    if (!validate_gfm_table(response)) {
      return("Table appears malformed. Please try again by clicking the Lit Review button.")
    }

    # DOI injection: replace Author/Year text with markdown links where DOI is available
    for (pl in paper_labels) {
      if (!is.na(pl$doi) && nchar(pl$doi) > 0) {
        # Use fixed string matching (labels don't need regex)
        doi_link <- sprintf("[%s](https://doi.org/%s)", pl$label, pl$doi)
        response <- gsub(pl$label, doi_link, response, fixed = TRUE)
      }
    }

    # Check for missing papers and add note
    lines <- strsplit(response, "\n")[[1]]
    data_rows <- lines[!grepl("^\\s*\\|[-:| ]+\\|\\s*$", lines)]  # exclude separator row
    data_rows <- data_rows[grepl("\\|", data_rows)]
    # Subtract 1 for header row
    actual_rows <- length(data_rows) - 1
    if (actual_rows < paper_count && actual_rows > 0) {
      missing <- paper_count - actual_rows
      response <- paste0(response, sprintf("\n\n*Note: %d paper(s) could not be analyzed and are not shown.*", missing))
    }

    response
  }, error = function(e) {
    sprintf("Error generating literature review table: %s", e$message)
  })
}

#' Generate a methodology comparison table for all documents in a notebook
#' @param con DuckDB connection
#' @param config Config list with api_key, chat_model, embedding_model
#' @param notebook_id Notebook ID
#' @param session_id Optional session token for cost logging
#' @return GFM pipe table string with DOI injection, or error message string
generate_methodology_extractor <- function(con, config, notebook_id, session_id = NULL) {
  tryCatch({
    # API setup
    provider <- provider_from_config(config, con)
    api_key <- provider$api_key %||% ""
    if (nchar(trimws(api_key)) == 0) {
      return("API key not configured. Please add your OpenRouter API key in Settings.")
    }
    chat_model <- resolve_model_for_operation(config, "methodology_extractor")
    embed_model <- resolve_model_for_operation(config, "embedding")

    # Get documents with metadata
    docs <- dbGetQuery(con, "
      SELECT id, filename, title, authors, year, doi
      FROM documents WHERE notebook_id = ?
      ORDER BY year DESC NULLS LAST, filename
    ", list(notebook_id))

    if (nrow(docs) == 0) {
      return("No documents found in this notebook.")
    }

    paper_count <- nrow(docs)

    # Build paper labels with metadata fallback
    paper_labels <- lapply(seq_len(nrow(docs)), function(i) {
      doc <- docs[i, ]
      if (!is.na(doc$title) && !is.na(doc$authors) && !is.na(doc$year)) {
        authors_parsed <- tryCatch(jsonlite::fromJSON(doc$authors), error = function(e) NULL)
        if (!is.null(authors_parsed) && length(authors_parsed) > 0) {
          # Extract last names - authors stored as JSON array of objects with display_name
          if (is.data.frame(authors_parsed) && "display_name" %in% names(authors_parsed)) {
            last_names <- vapply(authors_parsed$display_name, function(a) {
              parts <- strsplit(trimws(a), "\\s+")[[1]]
              parts[length(parts)]
            }, character(1))
          } else if (is.character(authors_parsed)) {
            last_names <- vapply(authors_parsed, function(a) {
              parts <- strsplit(trimws(a), "\\s+")[[1]]
              parts[length(parts)]
            }, character(1))
          } else {
            last_names <- "Unknown"
          }

          author_str <- if (length(last_names) > 2) {
            paste0(last_names[1], " et al.")
          } else if (length(last_names) == 2) {
            paste0(last_names[1], " & ", last_names[2])
          } else {
            last_names[1]
          }
          label <- sprintf("%s (%d)", author_str, doc$year)
        } else {
          label <- sprintf("Unknown (%s)", if (!is.na(doc$year)) as.character(doc$year) else "n.d.")
        }
      } else {
        label <- tools::file_path_sans_ext(doc$filename)
      }
      list(label = label, doi = doc$doi, doc_id = doc$id)
    })

    # Section-aware chunk retrieval with dynamic token budget
    # CRITICAL: lapply is INSIDE the repeat loop so re-querying occurs when chunks_per_paper is reduced
    max_context_tokens <- 80000L
    chunks_per_paper <- 7L

    repeat {
      # Re-query chunks with current chunks_per_paper limit
      papers_data <- lapply(seq_len(nrow(docs)), function(i) {
        doc <- docs[i, ]

        # Try section-filtered first (methods/methodology only)
        section_chunks <- dbGetQuery(con, "
          SELECT chunk_index, content, page_number, section_hint
          FROM chunks
          WHERE source_id = ? AND section_hint IN ('methods', 'methodology')
          ORDER BY chunk_index
          LIMIT ?
        ", list(doc$id, chunks_per_paper))

        if (nrow(section_chunks) < 2) {
          # Fallback: distributed sampling
          all_chunks <- dbGetQuery(con, "
            SELECT chunk_index, content, page_number,
                   COALESCE(section_hint, 'general') as section_hint
            FROM chunks WHERE source_id = ?
            ORDER BY chunk_index
          ", list(doc$id))

          if (nrow(all_chunks) > chunks_per_paper) {
            n <- nrow(all_chunks)
            indices <- unique(c(1, 2, ceiling(n/2), n-1, n))
            indices <- indices[indices >= 1 & indices <= n]
            indices <- sort(head(indices, chunks_per_paper))
            all_chunks <- all_chunks[indices, ]
          }
          section_chunks <- all_chunks
        }

        list(label = paper_labels[[i]]$label, doc_id = doc$id, chunks = section_chunks)
      })

      # Estimate tokens
      total_est <- sum(vapply(papers_data, function(p) {
        if (is.null(p$chunks) || nrow(p$chunks) == 0) return(0)
        ceiling(nchar(paste(p$chunks$content, collapse = " ")) / 4)
      }, numeric(1)))

      if (total_est <= max_context_tokens || chunks_per_paper <= 2L) break
      chunks_per_paper <- chunks_per_paper - 1L
    }

    # Token budget hard check after loop
    context <- build_context_by_paper(papers_data)
    est_tokens <- ceiling(nchar(context) / 4)
    if (est_tokens > max_context_tokens) {
      return(sprintf(
        "The combined document content (~%dk tokens) exceeds the analysis limit (%dk). Consider splitting documents across multiple notebooks or reducing the number of papers.",
        round(est_tokens / 1000), round(max_context_tokens / 1000)
      ))
    }

    # System prompt
    task_instruction <- get_effective_prompt(con, "methodology")
    system_prompt <- paste0(
      "You are a methodology extraction assistant. Generate a table in GFM (GitHub Flavored Markdown) pipe table format.\n\n",
      task_instruction
    )

    # User prompt
    user_prompt <- sprintf(
      "===== DOCUMENTS (%d papers) =====\n%s\n===== END =====\n\nGenerate the methodology comparison table.",
      paper_count, context
    )

    messages <- format_chat_messages(system_prompt, user_prompt)
    result <- provider_chat_completion(provider, chat_model, messages)

    if (!is.null(session_id) && !is.null(result$usage)) {
      cost <- estimate_cost(chat_model,
                            result$usage$prompt_tokens %||% 0,
                            result$usage$completion_tokens %||% 0,
                            is_local = is_local_provider(provider))
      log_cost(con, "methodology_extractor", chat_model,
               result$usage$prompt_tokens %||% 0,
               result$usage$completion_tokens %||% 0,
               result$usage$total_tokens %||% 0,
               cost, session_id,
               duration_ms = result$duration_ms)
    }

    response <- result$content

    # Strip any markdown code fences the LLM might wrap the table in
    response <- gsub("^```[a-z]*\\s*\n", "", response)
    response <- gsub("\n```\\s*$", "", response)
    response <- trimws(response)

    if (!validate_gfm_table(response)) {
      return("Table appears malformed. Please try again by clicking the Methods button.")
    }

    # DOI injection: replace Paper text with markdown links where DOI is available
    for (pl in paper_labels) {
      if (!is.na(pl$doi) && nchar(pl$doi) > 0) {
        # Use fixed string matching (labels don't need regex)
        doi_link <- sprintf("[%s](https://doi.org/%s)", pl$label, pl$doi)
        response <- gsub(pl$label, doi_link, response, fixed = TRUE)
      }
    }

    # Check for missing papers and add note
    lines <- strsplit(response, "\n")[[1]]
    data_rows <- lines[!grepl("^\\s*\\|[-:| ]+\\|\\s*$", lines)]  # exclude separator row
    data_rows <- data_rows[grepl("\\|", data_rows)]
    # Subtract 1 for header row
    actual_rows <- length(data_rows) - 1
    if (actual_rows < paper_count && actual_rows > 0) {
      missing <- paper_count - actual_rows
      response <- paste0(response, sprintf("\n\n*Note: %d paper(s) could not be analyzed and are not shown.*", missing))
    }

    response
  }, error = function(e) {
    sprintf("Error generating methodology table: %s", e$message)
  })
}

#' Generate Gap Analysis Report
#'
#' Cross-paper synthesis targeting discussion/limitations/future_work sections
#' to identify methodological, geographic, population, measurement, and theoretical gaps.
#'
#' @param con DuckDB connection
#' @param config Shiny config reactiveValues
#' @param notebook_id Notebook UUID
#' @param session_id Optional session UUID for cost logging
#' @return Character string with narrative gap analysis or error message
#' @export
generate_gap_analysis <- function(con, config, notebook_id, session_id = NULL) {
  tryCatch({
    # API setup
    provider <- provider_from_config(config, con)
    api_key <- provider$api_key %||% ""
    if (nchar(trimws(api_key)) == 0) {
      return("API key not configured. Please add your OpenRouter API key in Settings.")
    }
    chat_model <- resolve_model_for_operation(config, "gap_analysis")
    embed_model <- resolve_model_for_operation(config, "embedding")

    # Get documents with metadata
    docs <- dbGetQuery(con, "
      SELECT id, filename, title, authors, year, doi
      FROM documents WHERE notebook_id = ?
      ORDER BY year DESC NULLS LAST, filename
    ", list(notebook_id))

    if (nrow(docs) == 0) {
      return("No documents found in this notebook.")
    }

    # Minimum 3 papers threshold for gap analysis
    if (nrow(docs) < 3) {
      return("Gap analysis requires at least 3 papers to identify meaningful patterns.")
    }

    paper_count <- nrow(docs)

    # Build paper labels with metadata fallback
    paper_labels <- lapply(seq_len(nrow(docs)), function(i) {
      doc <- docs[i, ]
      if (!is.na(doc$title) && !is.na(doc$authors) && !is.na(doc$year)) {
        authors_parsed <- tryCatch(jsonlite::fromJSON(doc$authors), error = function(e) NULL)
        if (!is.null(authors_parsed) && length(authors_parsed) > 0) {
          # Extract last names - authors stored as JSON array of objects with display_name
          if (is.data.frame(authors_parsed) && "display_name" %in% names(authors_parsed)) {
            last_names <- vapply(authors_parsed$display_name, function(a) {
              parts <- strsplit(trimws(a), "\\s+")[[1]]
              parts[length(parts)]
            }, character(1))
          } else if (is.character(authors_parsed)) {
            last_names <- vapply(authors_parsed, function(a) {
              parts <- strsplit(trimws(a), "\\s+")[[1]]
              parts[length(parts)]
            }, character(1))
          } else {
            last_names <- "Unknown"
          }

          author_str <- if (length(last_names) > 2) {
            paste0(last_names[1], " et al.")
          } else if (length(last_names) == 2) {
            paste0(last_names[1], " & ", last_names[2])
          } else {
            last_names[1]
          }
          label <- sprintf("%s (%d)", author_str, doc$year)
        } else {
          label <- sprintf("Unknown (%s)", if (!is.na(doc$year)) as.character(doc$year) else "n.d.")
        }
      } else {
        label <- tools::file_path_sans_ext(doc$filename)
      }
      list(label = label, doi = doc$doi, doc_id = doc$id)
    })

    # Section-aware chunk retrieval with dynamic token budget
    # CRITICAL: lapply is INSIDE the repeat loop so re-querying occurs when chunks_per_paper is reduced
    max_context_tokens <- 80000L
    chunks_per_paper <- 7L
    papers_with_fallback <- character(0)  # Track papers that used fallback

    repeat {
      # Re-query chunks with current chunks_per_paper limit
      papers_data <- lapply(seq_len(nrow(docs)), function(i) {
        doc <- docs[i, ]

        # Try section-filtered first (discussion/limitations/future_work only)
        section_chunks <- dbGetQuery(con, "
          SELECT chunk_index, content, page_number, section_hint
          FROM chunks
          WHERE source_id = ? AND section_hint IN ('discussion', 'limitations', 'future_work')
          ORDER BY chunk_index
          LIMIT ?
        ", list(doc$id, chunks_per_paper))

        used_fallback <- FALSE
        if (nrow(section_chunks) < 2) {
          # Fallback: distributed sampling
          all_chunks <- dbGetQuery(con, "
            SELECT chunk_index, content, page_number,
                   COALESCE(section_hint, 'general') as section_hint
            FROM chunks WHERE source_id = ?
            ORDER BY chunk_index
          ", list(doc$id))

          if (nrow(all_chunks) > chunks_per_paper) {
            n <- nrow(all_chunks)
            indices <- unique(c(1, 2, ceiling(n/2), n-1, n))
            indices <- indices[indices >= 1 & indices <= n]
            indices <- sort(head(indices, chunks_per_paper))
            all_chunks <- all_chunks[indices, ]
          }
          section_chunks <- all_chunks
          used_fallback <- TRUE
        }

        list(
          label = paper_labels[[i]]$label,
          doc_id = doc$id,
          chunks = section_chunks,
          used_fallback = used_fallback
        )
      })

      # Track which papers used fallback (for transparency note)
      papers_with_fallback <- vapply(papers_data, function(p) p$used_fallback, logical(1))

      # Estimate tokens
      total_est <- sum(vapply(papers_data, function(p) {
        if (is.null(p$chunks) || nrow(p$chunks) == 0) return(0)
        ceiling(nchar(paste(p$chunks$content, collapse = " ")) / 4)
      }, numeric(1)))

      if (total_est <= max_context_tokens || chunks_per_paper <= 2L) break
      chunks_per_paper <- chunks_per_paper - 1L
    }

    # Token budget hard check after loop
    context <- build_context_by_paper(papers_data)
    est_tokens <- ceiling(nchar(context) / 4)
    if (est_tokens > max_context_tokens) {
      return(sprintf(
        "The combined document content (~%dk tokens) exceeds the analysis limit (%dk). Consider splitting documents across multiple notebooks or reducing the number of papers.",
        round(est_tokens / 1000), round(max_context_tokens / 1000)
      ))
    }

    # System prompt for gap analysis
    task_instruction <- get_effective_prompt(con, "gap_analysis")
    system_prompt <- paste0(
      "You are a research gap analyst. Generate a narrative prose gap analysis report.\n\n",
      task_instruction
    )

    # User prompt
    user_prompt <- sprintf(
      "===== DOCUMENTS (%d papers) =====\n%s\n===== END =====\n\nGenerate the gap analysis report.",
      paper_count, context
    )

    messages <- format_chat_messages(system_prompt, user_prompt)
    result <- provider_chat_completion(provider, chat_model, messages)

    if (!is.null(session_id) && !is.null(result$usage)) {
      cost <- estimate_cost(chat_model,
                            result$usage$prompt_tokens %||% 0,
                            result$usage$completion_tokens %||% 0,
                            is_local = is_local_provider(provider))
      log_cost(con, "gap_analysis", chat_model,
               result$usage$prompt_tokens %||% 0,
               result$usage$completion_tokens %||% 0,
               result$usage$total_tokens %||% 0,
               cost, session_id,
               duration_ms = result$duration_ms)
    }

    response <- result$content

    # Strip any markdown code fences the LLM might wrap the response in
    response <- gsub("^```[a-z]*\\s*\n", "", response)
    response <- gsub("\n```\\s*$", "", response)
    response <- trimws(response)

    # DOI injection: replace citations with markdown links where DOI is available
    for (pl in paper_labels) {
      if (!is.na(pl$doi) && nchar(pl$doi) > 0) {
        # Create pattern that matches the label in citation format
        # Pattern: match the label anywhere it appears in text
        doi_link <- sprintf("[%s](https://doi.org/%s)", pl$label, pl$doi)
        response <- gsub(pl$label, doi_link, response, fixed = TRUE)
      }
    }

    # Coverage transparency note if any papers used fallback
    if (any(papers_with_fallback)) {
      response <- paste0(
        response,
        "\n\n---\n*Note: Some papers lacked structured Discussion/Limitations sections; analysis drew from available content.*"
      )
    }

    response
  }, error = function(e) {
    sprintf("Error generating gap analysis: %s", e$message)
  })
}
