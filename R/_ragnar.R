#' Ragnar Store Integration
#'
#' Manages the ragnar-powered vector store for semantic chunking and retrieval.
#' This provides VSS (vector similarity search) + BM25 hybrid retrieval.

#' Check if ragnar is available
#' @return TRUE if ragnar is installed and loadable
ragnar_available <- function() {
 requireNamespace("ragnar", quietly = TRUE) &&
   requireNamespace("digest", quietly = TRUE)
}

#' Get or create RagnarStore for chunk embeddings
#'
#' Uses OpenRouter for embeddings (same API key as chat), so no separate
#' OpenAI key is required.
#'
#' @param path Path to the ragnar store database
#' @param openrouter_api_key OpenRouter API key (required for new stores)
#' @param embed_model Embedding model (OpenRouter format, e.g., "openai/text-embedding-3-small")
#' @return RagnarStore object
get_ragnar_store <- function(path = "data/serapeum.ragnar.duckdb",
                              openrouter_api_key = NULL,
                              embed_model = "openai/text-embedding-3-small") {
  if (!ragnar_available()) {
    stop("ragnar package is required. Install with: install.packages('ragnar')")
  }

  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)

  if (file.exists(path)) {
    ragnar::ragnar_store_connect(path)
  } else {
    # Require API key for new stores (needed to generate embeddings)
    if (is.null(openrouter_api_key) || nchar(openrouter_api_key) == 0) {
      stop("OpenRouter API key required to create new ragnar store")
    }

    # Create custom embed function using OpenRouter
    embed_via_openrouter <- function(texts) {
      # get_embeddings returns list(embeddings, usage, model)
      result <- get_embeddings(openrouter_api_key, embed_model, texts)

      # Extract embeddings and convert to matrix format expected by ragnar (each row is an embedding)
      do.call(rbind, result$embeddings)
    }

    ragnar::ragnar_store_create(
      path,
      embed = embed_via_openrouter
    )
  }
}

#' Connect to existing RagnarStore (for retrieval only)
#'
#' Unlike get_ragnar_store(), this only connects to existing stores and
#' does not create new ones. Use this for search/retrieval operations.
#'
#' @param path Path to the ragnar store database
#' @return RagnarStore object or NULL if store doesn't exist
connect_ragnar_store <- function(path = "data/serapeum.ragnar.duckdb") {
  if (!ragnar_available()) {
    return(NULL)
  }

  if (!file.exists(path)) {
    return(NULL)
  }

  tryCatch({
    ragnar::ragnar_store_connect(path)
  }, error = function(e) {
    message("Failed to connect to ragnar store: ", e$message)
    NULL
  })
}

#' Chunk text using ragnar's semantic chunking
#'
#' Wraps ragnar::markdown_chunk() with page number preservation.
#' Processes text page-by-page to maintain citation accuracy.
#'
#' @param pages Character vector of text, one element per page
#' @param origin Document origin identifier (e.g., filename)
#' @param target_size Target chunk size in characters (default: 1600)
#' @param target_overlap Overlap fraction between chunks (default: 0.5)
#' @return Data frame with columns: content, page_number, chunk_index, context, origin
chunk_with_ragnar <- function(pages, origin, target_size = 1600, target_overlap = 0.5) {
  if (!ragnar_available()) {
    stop("ragnar package is required for semantic chunking")
  }

  all_chunks <- data.frame(
    content = character(),
    page_number = integer(),
    chunk_index = integer(),
    context = character(),
    origin = character(),
    stringsAsFactors = FALSE
  )

  global_index <- 0

  for (page_num in seq_along(pages)) {
    page_text <- pages[page_num]

    # Skip empty pages
    if (is.null(page_text) || nchar(trimws(page_text)) == 0) next

    # Create markdown document for this page
    # Use page-specific origin for deduplication
    page_origin <- sprintf("%s#page=%d", origin, page_num)
    md_doc <- ragnar::MarkdownDocument(page_text, origin = page_origin)

    # Chunk the page
    page_chunks <- tryCatch({
      ragnar::markdown_chunk(
        md_doc,
        target_size = target_size,
        target_overlap = target_overlap,
        context = TRUE
      )
    }, error = function(e) {
      # Fallback: treat entire page as one chunk
      data.frame(
        text = page_text,
        context = "",
        stringsAsFactors = FALSE
      )
    })

    # Extract chunks from result
    if (nrow(page_chunks) == 0) next

    for (i in seq_len(nrow(page_chunks))) {
      chunk_text <- if ("text" %in% names(page_chunks)) {
        page_chunks$text[i]
      } else {
        page_text
      }

      chunk_context <- if ("context" %in% names(page_chunks)) {
        page_chunks$context[i]
      } else {
        ""
      }

      if (is.null(chunk_text) || nchar(trimws(chunk_text)) == 0) next

      all_chunks <- rbind(all_chunks, data.frame(
        content = chunk_text,
        page_number = page_num,
        chunk_index = global_index,
        context = chunk_context %||% "",
        origin = page_origin,
        stringsAsFactors = FALSE
      ))

      global_index <- global_index + 1
    }
  }

  all_chunks
}

#' Insert chunks into ragnar store with metadata
#'
#' Converts our chunk format to ragnar's expected format and inserts.
#'
#' @param store RagnarStore object
#' @param chunks Data frame from chunk_with_ragnar()
#' @param source_id Our internal document/abstract ID
#' @param source_type "document" or "abstract"
#' @return Invisibly returns the store
insert_chunks_to_ragnar <- function(store, chunks, source_id, source_type) {
  if (!ragnar_available() || nrow(chunks) == 0) {
    return(invisible(store))
  }

  # Prepare chunks for ragnar (version 1 format: origin, hash, text)
  ragnar_chunks <- data.frame(
    origin = chunks$origin,
    hash = vapply(seq_len(nrow(chunks)), function(i) {
      digest::digest(paste(chunks$content[i], chunks$page_number[i], sep = "|"))
    }, character(1)),
    text = chunks$content,
    stringsAsFactors = FALSE
  )

  # Store additional metadata in a separate lookup
  # (ragnar doesn't natively support custom metadata, so we track separately)
  attr(ragnar_chunks, "serapeum_metadata") <- list(
    source_id = source_id,
    source_type = source_type,
    page_numbers = chunks$page_number,
    contexts = chunks$context
  )

  ragnar::ragnar_store_insert(store, ragnar_chunks)
  invisible(store)
}

#' Retrieve chunks using ragnar's hybrid search
#'
#' Uses VSS + BM25 for better retrieval quality.
#'
#' @param store RagnarStore object
#' @param query Search query
#' @param top_k Number of results to return
#' @return Data frame of matching chunks with metadata
retrieve_with_ragnar <- function(store, query, top_k = 5) {
  if (!ragnar_available()) {
    stop("ragnar package is required for retrieval")
  }

  results <- ragnar::ragnar_retrieve(store, query, top_k = top_k)

  # Results come back with: text, origin, score (potentially)
  # Parse metadata from origin field based on format:
  # - Documents: "filename#page=N"
  # - Abstracts: "abstract:id"
  if (nrow(results) > 0 && "origin" %in% names(results)) {
    results$source_type <- vapply(results$origin, function(o) {
      if (grepl("^abstract:", o)) "abstract" else "document"
    }, character(1))

    results$page_number <- vapply(results$origin, function(o) {
      match <- regmatches(o, regexec("#page=(\\d+)$", o))[[1]]
      if (length(match) >= 2) as.integer(match[2]) else NA_integer_
    }, integer(1))

    results$doc_name <- vapply(results$origin, function(o) {
      if (grepl("^abstract:", o)) {
        NA_character_  # Abstracts don't have doc_name
      } else {
        sub("#page=\\d+$", "", o)
      }
    }, character(1))

    results$abstract_title <- vapply(results$origin, function(o) {
      if (grepl("^abstract:", o)) {
        # For abstracts, we'd need to look up the title from DB
        # For now, just mark as abstract
        "[Abstract]"
      } else {
        NA_character_
      }
    }, character(1))
  }

  results
}

#' Build the ragnar store index after inserting chunks
#'
#' This must be called after inserting chunks to enable efficient search.
#'
#' @param store RagnarStore object
#' @return Invisibly returns the store
build_ragnar_index <- function(store) {
  if (!ragnar_available()) {
    return(invisible(store))
  }

  ragnar::ragnar_store_build_index(store)
  invisible(store)
}
