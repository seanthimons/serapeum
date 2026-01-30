#' Build RAG context from retrieved chunks
#' @param chunks Data frame of chunks from search_chunks
#' @return Formatted context string
build_context <- function(chunks) {
  if (nrow(chunks) == 0) return("")

  contexts <- sapply(seq_len(nrow(chunks)), function(i) {
    chunk <- chunks[i, ]

    # Determine source label
    if (!is.na(chunk$doc_name) && nchar(chunk$doc_name) > 0) {
      source <- sprintf("[%s, p.%d]", chunk$doc_name, chunk$page_number)
    } else if (!is.na(chunk$abstract_title) && nchar(chunk$abstract_title) > 0) {
      source <- sprintf("[%s]", chunk$abstract_title)
    } else {
      source <- "[Source]"
    }

    sprintf("Source %s:\n%s", source, chunk$content)
  })

  paste(contexts, collapse = "\n\n---\n\n")
}

#' Generate RAG response
#' @param con Database connection
#' @param config App config
#' @param question User question
#' @param notebook_id Notebook to query
#' @return Generated response with citations
rag_query <- function(con, config, question, notebook_id) {
  api_key <- get_setting(config, "openrouter", "api_key")
  chat_model <- get_setting(config, "defaults", "chat_model") %||% "anthropic/claude-sonnet-4"
  embed_model <- get_setting(config, "defaults", "embedding_model") %||% "openai/text-embedding-3-small"

  if (is.null(api_key) || nchar(api_key) == 0) {
    return("Error: OpenRouter API key not configured. Please set your API key in Settings.")
  }

  # Embed the question
  question_embedding <- tryCatch({
    get_embeddings(api_key, embed_model, question)[[1]]
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(question_embedding)) {
    return("Error: Failed to generate embeddings. Please check your API key and try again.")
  }

  # Search for relevant chunks
  chunks <- search_chunks(con, question_embedding, notebook_id, limit = 5)

  if (nrow(chunks) == 0) {
    return("I couldn't find any relevant information in your documents to answer this question. Make sure your documents have been processed and embedded.")
  }

  # Build context
  context <- build_context(chunks)

  # Build prompt
  system_prompt <- "You are a helpful research assistant. Answer questions based ONLY on the provided sources. Always cite your sources using the format [Document Name, p.X] or [Paper Title]. If the sources don't contain enough information to fully answer the question, say so clearly."

  user_prompt <- sprintf("Sources:\n%s\n\nQuestion: %s", context, question)

  messages <- format_chat_messages(system_prompt, user_prompt)

  # Generate response
  response <- tryCatch({
    chat_completion(api_key, chat_model, messages)
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
#' @return Generated content
generate_preset <- function(con, config, notebook_id, preset_type) {
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
  chat_model <- get_setting(config, "defaults", "chat_model") %||% "anthropic/claude-sonnet-4"

  if (is.null(api_key) || nchar(api_key) == 0) {
    return("Error: OpenRouter API key not configured. Please set your API key in Settings.")
  }

  # Get notebook type to determine which table to query
  notebook <- get_notebook(con, notebook_id)
  if (is.null(notebook)) {
    return("Error: Notebook not found.")
  }

  # Get chunks based on notebook type
  if (notebook$type == "document") {
    chunks <- dbGetQuery(con, "
      SELECT c.*, d.filename as doc_name
      FROM chunks c
      JOIN documents d ON c.source_id = d.id
      WHERE d.notebook_id = ?
      ORDER BY d.created_at, c.chunk_index
      LIMIT 50
    ", list(notebook_id))
  } else {
    chunks <- dbGetQuery(con, "
      SELECT c.*, a.title as abstract_title
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
    chat_completion(api_key, chat_model, messages)
  }, error = function(e) {
    return(sprintf("Error generating content: %s", e$message))
  })

  response
}
