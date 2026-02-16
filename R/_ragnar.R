#' Ragnar Store Integration
#'
#' Manages the ragnar-powered vector store for semantic chunking and retrieval.
#' This provides VSS (vector similarity search) + BM25 hybrid retrieval.

# ---- Path and Metadata Helpers ----

#' Get deterministic ragnar store path for a notebook
#'
#' Constructs the file path for a notebook's isolated ragnar store without
#' requiring database lookups. This is a pure function for path construction.
#'
#' @param notebook_id The notebook ID (UUID)
#' @return Character path to the ragnar store database file
#' @examples
#' get_notebook_ragnar_path("48fb8820-fbc0-4e75-bf46-92c6dae1db0b")
#' # Returns: "data/ragnar/48fb8820-fbc0-4e75-bf46-92c6dae1db0b.duckdb"
get_notebook_ragnar_path <- function(notebook_id) {
  # Validate input
  if (is.null(notebook_id) || is.na(notebook_id) || nchar(trimws(notebook_id)) == 0) {
    stop("notebook_id must be a non-empty string")
  }

  file.path("data", "ragnar", paste0(notebook_id, ".duckdb"))
}

#' Encode origin metadata into pipe-delimited format
#'
#' Encodes section hint, DOI, and source type into the origin field for storage
#' in ragnar chunks. Uses human-readable pipe-delimited format with key=value pairs.
#'
#' @param base_origin The base origin identifier (e.g., "paper.pdf#page=5")
#' @param section_hint Section classification ("general", "methods", "conclusion", etc.)
#' @param doi Document DOI (optional, omitted if NULL)
#' @param source_type Source type identifier (default: "pdf")
#' @return Character string in format: base_origin|section=...|doi=...|type=...
#' @examples
#' encode_origin_metadata("paper.pdf#page=5", "conclusion", "10.1234/abc", "pdf")
#' # Returns: "paper.pdf#page=5|section=conclusion|doi=10.1234/abc|type=pdf"
encode_origin_metadata <- function(base_origin,
                                    section_hint = "general",
                                    doi = NULL,
                                    source_type = "pdf") {
  # Validate required fields
  if (is.null(section_hint) || nchar(trimws(section_hint)) == 0) {
    stop("section_hint must be a non-empty string")
  }
  if (is.null(source_type) || nchar(trimws(source_type)) == 0) {
    stop("source_type must be a non-empty string")
  }

  # Build pipe-delimited string with key=value pairs
  parts <- c(
    base_origin,
    paste0("section=", section_hint),
    if (!is.null(doi) && nchar(trimws(doi)) > 0) paste0("doi=", doi),
    paste0("type=", source_type)
  )

  paste(parts, collapse = "|")
}

#' Decode origin metadata from pipe-delimited format
#'
#' Parses the encoded origin field to extract section hint, DOI, and source type.
#' Gracefully falls back to "general" section on malformed input.
#'
#' @param origin The encoded origin string
#' @return Named list with: base_origin, section_hint, doi, source_type
#' @examples
#' decode_origin_metadata("paper.pdf#page=5|section=conclusion|doi=10.1234/abc|type=pdf")
#' # Returns: list(base_origin="paper.pdf#page=5", section_hint="conclusion",
#' #               doi="10.1234/abc", source_type="pdf")
decode_origin_metadata <- function(origin) {
  # Wrap in tryCatch for graceful fallback
  tryCatch({
    # Split on pipe delimiter
    parts <- strsplit(origin, "\\|", fixed = FALSE)[[1]]

    if (length(parts) == 0) {
      # Empty string
      return(list(
        base_origin = "",
        section_hint = "general",
        doi = NA_character_,
        source_type = NA_character_
      ))
    }

    # First element is always base_origin
    base_origin <- parts[1]

    # Parse remaining elements as key=value pairs
    metadata <- list(
      section_hint = "general",  # Default fallback
      doi = NA_character_,
      source_type = NA_character_
    )

    if (length(parts) > 1) {
      for (i in 2:length(parts)) {
        kv <- strsplit(parts[i], "=", fixed = TRUE)[[1]]
        if (length(kv) == 2) {
          key <- trimws(kv[1])
          value <- trimws(kv[2])

          if (key == "section") {
            metadata$section_hint <- value
          } else if (key == "doi") {
            metadata$doi <- value
          } else if (key == "type") {
            metadata$source_type <- value
          }
        }
      }
    }

    list(
      base_origin = base_origin,
      section_hint = metadata$section_hint,
      doi = metadata$doi,
      source_type = metadata$source_type
    )
  }, error = function(e) {
    # Graceful fallback on any parsing error
    list(
      base_origin = origin,
      section_hint = "general",
      doi = NA_character_,
      source_type = NA_character_
    )
  })
}

# ---- Ragnar Store Management ----

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

# ---- Version Check and Connection Lifecycle ----

#' Check ragnar version compatibility (lazy, session-cached)
#'
#' Verifies ragnar is installed and meets minimum version requirement.
#' Caches result in session to avoid repeated checks. Per user decision,
#' warns but allows use on version mismatch (renv will handle strict pinning).
#'
#' @param session Shiny session object for caching (optional)
#' @return TRUE if ragnar is compatible/allowed, FALSE if not installed
#' @examples
#' if (check_ragnar_version(session)) {
#'   # Proceed with RAG operations
#' }
check_ragnar_version <- function(session = NULL) {
  # Check session cache first
  if (!is.null(session)) {
    cached <- session$userData$ragnar_version_checked
    if (!is.null(cached)) {
      return(cached)
    }
  }

  # Check if ragnar is installed
  if (!requireNamespace("ragnar", quietly = TRUE)) {
    message("[ragnar] Package not installed - RAG features disabled")
    result <- FALSE
  } else {
    # Get installed version
    installed <- as.character(packageVersion("ragnar"))
    minimum <- "0.3.0"

    # Compare versions (-1 = installed < minimum, 0 = equal, 1 = installed > minimum)
    comparison <- compareVersion(installed, minimum)

    if (comparison < 0) {
      # Installed version too old
      warning(
        "[ragnar] Version ", installed, " is older than required ", minimum, ". ",
        "RAG features may not work correctly. Please update ragnar."
      )
      result <- FALSE
    } else if (comparison > 0) {
      # Installed version newer - allow but warn about potential breaking changes
      # Per user decision: allow patch updates (0.3.1, 0.3.2), warn on major/minor
      installed_parts <- strsplit(installed, "\\.")[[1]]
      minimum_parts <- strsplit(minimum, "\\.")[[1]]

      if (installed_parts[1] != minimum_parts[1] || installed_parts[2] != minimum_parts[2]) {
        # Major or minor version difference
        warning(
          "[ragnar] Version ", installed, " differs from tested ", minimum, ". ",
          "RAG features may behave unexpectedly. ",
          # TODO: This could be replaced by renv version pinning
          "Consider pinning to ", minimum, " via renv."
        )
      }
      result <- TRUE
    } else {
      # Exact match
      result <- TRUE
    }
  }

  # Cache result in session
  if (!is.null(session)) {
    session$userData$ragnar_version_checked <- result
  }

  result
}

#' Execute function with ragnar store, guaranteeing cleanup
#'
#' Opens a ragnar store, executes the provided function, and ensures the store
#' is closed even on error or early return. Per user decision, uses aggressive
#' cleanup (closes on any exit) with TODO marker for future optimization.
#'
#' @param path Path to ragnar store database
#' @param expr_fn Function to execute, receives store as first argument
#' @param session Shiny session for global error notifications (optional)
#' @return Result of expr_fn on success, NULL on error
#' @examples
#' with_ragnar_store("data/ragnar/notebook-id.duckdb", function(store) {
#'   ragnar::ragnar_retrieve(store, "my query")
#' })
with_ragnar_store <- function(path, expr_fn, session = NULL) {
  store <- NULL

  result <- tryCatch({
    # Open connection
    store <- ragnar::ragnar_store_connect(path)

    # Guarantee cleanup on ANY exit (error, early return, or normal completion)
    # TODO: This aggressive cleanup could be relaxed to selective cleanup later
    on.exit({
      if (!is.null(store)) {
        tryCatch({
          # Ragnar stores are DuckDB connections, close via disconnect
          DBI::dbDisconnect(store, shutdown = TRUE)
        }, error = function(e) {
          # Already closed or invalid, ignore
        })
      }
    }, add = TRUE)

    # Execute user function with store
    expr_fn(store)

  }, error = function(e) {
    # Global notification on connection error (per user decision: toast, not inline)
    msg <- paste("Failed to access notebook search index:", e$message)
    message("[ragnar] ", msg)

    if (!is.null(session)) {
      shiny::showNotification(
        msg,
        type = "error",
        duration = 10
      )
    }

    NULL
  })

  result
}

#' Register session cleanup hook for ragnar store
#'
#' Registers a callback to close the active ragnar store when the browser tab
#' closes or the session ends. Per user decision, closes connections on browser
#' tab close to prevent resource leaks.
#'
#' @param session Shiny session object
#' @param store_rv reactiveVal holding the active RagnarStore object
#' @examples
#' active_store <- reactiveVal(NULL)
#' register_ragnar_cleanup(session, active_store)
register_ragnar_cleanup <- function(session, store_rv) {
  session$onSessionEnded(function() {
    store <- store_rv()
    if (!is.null(store)) {
      tryCatch({
        # Close ragnar store (DuckDB connection)
        DBI::dbDisconnect(store, shutdown = TRUE)
      }, error = function(e) {
        # Already closed or invalid, ignore
      })
    }
  })
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
