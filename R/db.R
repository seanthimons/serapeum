library(duckdb)
library(DBI)

#' Get DuckDB connection
#' @param path Path to database file
#' @return DuckDB connection object
get_db_connection <- function(path = "data/notebooks.duckdb") {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)

  # Use connections package if available (shows in Connections pane for easier management)
  if (requireNamespace("connections", quietly = TRUE)) {
    con <- connections::connection_open(duckdb::duckdb(), path)
  } else {
    con <- dbConnect(duckdb(), dbdir = path)
  }

  # Run pending migrations before returning connection
  run_pending_migrations(con)

  con
}

#' Close DuckDB connection safely
#' @param con DuckDB connection (may be connConnection or standard DBI)
close_db_connection <- function(con) {
  tryCatch({
    if (inherits(con, "connConnection") && requireNamespace("connections", quietly = TRUE)) {
      connections::connection_close(con)
    } else {
      DBI::dbDisconnect(con, shutdown = TRUE)
    }
  }, error = function(e) {
    message("Note: ", e$message)
  })
}

#' Initialize database schema
#' @param con DuckDB connection
init_schema <- function(con) {
  # Notebooks table
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS notebooks (
      id VARCHAR PRIMARY KEY,
      name VARCHAR NOT NULL,
      type VARCHAR NOT NULL,
      search_query VARCHAR,
      search_filters VARCHAR,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")

  # Documents table
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS documents (
      id VARCHAR PRIMARY KEY,
      notebook_id VARCHAR NOT NULL,
      filename VARCHAR NOT NULL,
      filepath VARCHAR NOT NULL,
      full_text VARCHAR,
      page_count INTEGER,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (notebook_id) REFERENCES notebooks(id)
    )
  ")

  # Abstracts table
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS abstracts (
      id VARCHAR PRIMARY KEY,
      notebook_id VARCHAR NOT NULL,
      paper_id VARCHAR NOT NULL,
      title VARCHAR NOT NULL,
      authors VARCHAR,
      abstract VARCHAR,
      keywords VARCHAR,
      year INTEGER,
      venue VARCHAR,
      pdf_url VARCHAR,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (notebook_id) REFERENCES notebooks(id)
    )
  ")

  # Chunks table (embedding stored as comma-separated string for portability)
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS chunks (
      id VARCHAR PRIMARY KEY,
      source_id VARCHAR NOT NULL,
      source_type VARCHAR NOT NULL,
      chunk_index INTEGER NOT NULL,
      content VARCHAR NOT NULL,
      embedding VARCHAR,
      page_number INTEGER
    )
  ")

  # Settings table
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS settings (
      key VARCHAR PRIMARY KEY,
      value VARCHAR
    )
  ")

  # Migrations: Add columns to existing tables if missing
  # Migration: Add keywords column to abstracts table (added 2026-02-05)
  tryCatch({
    dbExecute(con, "ALTER TABLE abstracts ADD COLUMN keywords VARCHAR")
  }, error = function(e) {
    # Column already exists, ignore
  })

  # Migration: Add excluded_paper_ids column to notebooks table (added 2026-02-06)
  tryCatch({
    dbExecute(con, "ALTER TABLE notebooks ADD COLUMN excluded_paper_ids VARCHAR DEFAULT '[]'")
  }, error = function(e) {
    # Column already exists, ignore
  })

  # Migration: Add work_type columns to abstracts table (added 2026-02-06)
  tryCatch({
    dbExecute(con, "ALTER TABLE abstracts ADD COLUMN work_type VARCHAR")
  }, error = function(e) {
    # Column already exists, ignore
  })
  tryCatch({
    dbExecute(con, "ALTER TABLE abstracts ADD COLUMN work_type_crossref VARCHAR")
  }, error = function(e) {
    # Column already exists, ignore
  })

  # Migration: Add OA status and citation columns to abstracts table (added 2026-02-06, Phase 2)
  tryCatch({
    dbExecute(con, "ALTER TABLE abstracts ADD COLUMN oa_status VARCHAR")
  }, error = function(e) {
    # Column already exists, ignore
  })
  tryCatch({
    dbExecute(con, "ALTER TABLE abstracts ADD COLUMN is_oa BOOLEAN DEFAULT FALSE")
  }, error = function(e) {
    # Column already exists, ignore
  })
  tryCatch({
    dbExecute(con, "ALTER TABLE abstracts ADD COLUMN cited_by_count INTEGER DEFAULT 0")
  }, error = function(e) {
    # Column already exists, ignore
  })
  tryCatch({
    dbExecute(con, "ALTER TABLE abstracts ADD COLUMN referenced_works_count INTEGER DEFAULT 0")
  }, error = function(e) {
    # Column already exists, ignore
  })
  tryCatch({
    dbExecute(con, "ALTER TABLE abstracts ADD COLUMN fwci DOUBLE")
  }, error = function(e) {
    # Column already exists, ignore
  })

  # Quality filter cache tables (added 2026-02-06)
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS predatory_publishers (
      id INTEGER PRIMARY KEY,
      name VARCHAR NOT NULL,
      name_normalized VARCHAR NOT NULL,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")

  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS predatory_journals (
      id INTEGER PRIMARY KEY,
      name VARCHAR NOT NULL,
      name_normalized VARCHAR NOT NULL,
      is_hijacked BOOLEAN DEFAULT FALSE,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")

  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS retracted_papers (
      doi VARCHAR PRIMARY KEY,
      title VARCHAR,
      retraction_date VARCHAR,
      reason VARCHAR,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")

  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS quality_cache_meta (
      source VARCHAR PRIMARY KEY,
      last_updated TIMESTAMP,
      record_count INTEGER
    )
  ")

  # Migration: Fix retraction_date column type (DATE -> VARCHAR) if needed
  # This handles the case where the table was created with DATE type
  tryCatch({
    # Check if table exists and has wrong column type
    col_info <- dbGetQuery(con, "
      SELECT data_type FROM information_schema.columns
      WHERE table_name = 'retracted_papers' AND column_name = 'retraction_date'
    ")
    if (nrow(col_info) > 0 && col_info$data_type[1] == "DATE") {
      message("[db_migration] Recreating retracted_papers table with VARCHAR date column")
      dbExecute(con, "DROP TABLE IF EXISTS retracted_papers")
      dbExecute(con, "
        CREATE TABLE retracted_papers (
          doi VARCHAR PRIMARY KEY,
          title VARCHAR,
          retraction_date VARCHAR,
          reason VARCHAR,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ")
      # Also clear the cache meta so it gets refreshed
      dbExecute(con, "DELETE FROM quality_cache_meta WHERE source = 'retraction_watch'")
    }
  }, error = function(e) {
    # Table doesn't exist or other issue, ignore
  })
}

#' Create a new notebook
#' @param con DuckDB connection
#' @param name Notebook name
#' @param type "document" or "search"
#' @param search_query Query string (for search notebooks)
#' @param search_filters Filter list (for search notebooks)
#' @return Notebook ID
create_notebook <- function(con, name, type, search_query = NULL, search_filters = NULL) {
  id <- uuid::UUIDgenerate()

  # Convert NULL to NA for database binding (NULL has length 0, NA has length 1)
  search_query_val <- if (is.null(search_query)) NA_character_ else search_query
  filters_json <- if (!is.null(search_filters)) jsonlite::toJSON(search_filters, auto_unbox = TRUE) else NA_character_

  dbExecute(con, "
    INSERT INTO notebooks (id, name, type, search_query, search_filters)
    VALUES (?, ?, ?, ?, ?)
  ", list(id, name, type, search_query_val, filters_json))

  id
}

#' List all notebooks
#' @param con DuckDB connection
#' @return Data frame of notebooks
list_notebooks <- function(con) {
  dbGetQuery(con, "SELECT * FROM notebooks ORDER BY created_at DESC")
}

#' Get a single notebook by ID
#' @param con DuckDB connection
#' @param id Notebook ID
#' @return Single row data frame or NULL
get_notebook <- function(con, id) {
  result <- dbGetQuery(con, "SELECT * FROM notebooks WHERE id = ?", list(id))
  if (nrow(result) == 0) return(NULL)
  result
}

#' Delete a notebook and its contents
#' @param con DuckDB connection
#' @param id Notebook ID
delete_notebook <- function(con, id) {
  # Delete chunks for documents in this notebook
  dbExecute(con, "
    DELETE FROM chunks WHERE source_id IN (
      SELECT id FROM documents WHERE notebook_id = ?
    )
  ", list(id))

  # Delete chunks for abstracts in this notebook
  dbExecute(con, "
    DELETE FROM chunks WHERE source_id IN (
      SELECT id FROM abstracts WHERE notebook_id = ?
    )
  ", list(id))

  # Delete documents
  dbExecute(con, "DELETE FROM documents WHERE notebook_id = ?", list(id))

  # Delete abstracts
  dbExecute(con, "DELETE FROM abstracts WHERE notebook_id = ?", list(id))

  # Delete notebook
  dbExecute(con, "DELETE FROM notebooks WHERE id = ?", list(id))
}

#' Create a document record
#' @param con DuckDB connection
#' @param notebook_id Notebook ID
#' @param filename Original filename
#' @param filepath Storage path
#' @param full_text Extracted text
#' @param page_count Number of pages
#' @return Document ID
create_document <- function(con, notebook_id, filename, filepath, full_text, page_count) {
  id <- uuid::UUIDgenerate()

  dbExecute(con, "
    INSERT INTO documents (id, notebook_id, filename, filepath, full_text, page_count)
    VALUES (?, ?, ?, ?, ?, ?)
  ", list(id, notebook_id, filename, filepath, full_text, page_count))

  id
}

#' List documents in a notebook
#' @param con DuckDB connection
#' @param notebook_id Notebook ID
#' @return Data frame of documents
list_documents <- function(con, notebook_id) {
  dbGetQuery(con, "
    SELECT * FROM documents WHERE notebook_id = ? ORDER BY created_at DESC
  ", list(notebook_id))
}

#' Get a single document by ID
#' @param con DuckDB connection
#' @param id Document ID
#' @return Single row data frame or NULL
get_document <- function(con, id) {
  result <- dbGetQuery(con, "SELECT * FROM documents WHERE id = ?", list(id))
  if (nrow(result) == 0) return(NULL)
  result
}

#' Delete a document
#' @param con DuckDB connection
#' @param id Document ID
delete_document <- function(con, id) {
  dbExecute(con, "DELETE FROM chunks WHERE source_id = ?", list(id))
  dbExecute(con, "DELETE FROM documents WHERE id = ?", list(id))
}

#' Create a chunk record
#' @param con DuckDB connection
#' @param source_id Document or abstract ID
#' @param source_type "document" or "abstract"
#' @param chunk_index Chunk position
#' @param content Chunk text
#' @param embedding Vector embedding (optional)
#' @param page_number Page number (optional)
#' @return Chunk ID
create_chunk <- function(con, source_id, source_type, chunk_index, content,
                         embedding = NULL, page_number = NULL) {
  id <- uuid::UUIDgenerate()

  # Convert NULL to NA for proper DBI binding
  page_num <- if (is.null(page_number)) NA_integer_ else as.integer(page_number)

  dbExecute(con, "
    INSERT INTO chunks (id, source_id, source_type, chunk_index, content, page_number)
    VALUES (?, ?, ?, ?, ?, ?)
  ", list(id, source_id, source_type, as.integer(chunk_index), content, page_num))

  id
}

#' List chunks for a source
#' @param con DuckDB connection
#' @param source_id Document or abstract ID
#' @return Data frame of chunks
list_chunks <- function(con, source_id) {
  dbGetQuery(con, "
    SELECT * FROM chunks WHERE source_id = ? ORDER BY chunk_index
  ", list(source_id))
}

#' Update chunk embedding
#' @param con DuckDB connection
#' @param chunk_id Chunk ID
#' @param embedding Numeric vector
update_chunk_embedding <- function(con, chunk_id, embedding) {
  # Store as comma-separated string for portability
  embedding_str <- paste(embedding, collapse = ",")
  dbExecute(con, "UPDATE chunks SET embedding = ? WHERE id = ?", list(embedding_str, chunk_id))
}

#' Calculate cosine similarity between two vectors
#' @param a First vector
#' @param b Second vector
#' @return Cosine similarity score
cosine_similarity <- function(a, b) {
  # Validate inputs are numeric vectors
  if (!is.numeric(a) || !is.numeric(b)) return(0)
  if (length(a) != length(b)) return(0)
  if (length(a) == 0) return(0)

  dot_product <- sum(a * b)
  norm_a <- sqrt(sum(a^2))
  norm_b <- sqrt(sum(b^2))

  # Use single value comparison safely
  if (isTRUE(norm_a == 0) || isTRUE(norm_b == 0)) return(0)

  dot_product / (norm_a * norm_b)
}

#' Parse embedding string from database
#' @param embedding_str Comma-separated string like "0.1,0.2,0.3"
#' @return Numeric vector
parse_embedding <- function(embedding_str) {
  # Handle NULL
  if (is.null(embedding_str)) {
    return(NULL)
  }
  # If already a numeric vector, return as-is
  if (is.numeric(embedding_str)) {
    return(embedding_str)
  }
  # Ensure we have a single string value
  if (length(embedding_str) != 1) {
    return(NULL)
  }
  # Handle NA and empty string (use isTRUE to safely check single value)
  if (isTRUE(is.na(embedding_str)) || isTRUE(embedding_str == "")) {
    return(NULL)
  }
  # Handle both formats: with or without brackets
  cleaned <- gsub("^\\[|\\]$", "", embedding_str)
  # Split and trim whitespace from each element
  parts <- trimws(strsplit(cleaned, ",")[[1]])
  # Remove any empty strings
  parts <- parts[nchar(parts) > 0]
  if (length(parts) == 0) {
    return(NULL)
  }
  # Convert to numeric, suppressing warnings for malformed data
  result <- suppressWarnings(as.numeric(parts))
  # If too many NAs, the data is likely corrupt - return NULL
  if (sum(is.na(result)) > length(result) * 0.1) {
    return(NULL)
  }
  # Replace any remaining NAs with 0
  result[is.na(result)] <- 0
  result
}

#' Search chunks by embedding similarity
#' @param con DuckDB connection
#' @param query_embedding Query vector
#' @param notebook_id Limit to specific notebook
#' @param limit Number of results
#' @return Data frame of matching chunks with source info
search_chunks <- function(con, query_embedding, notebook_id = NULL, limit = 5) {
  # Build query to get chunks with their source info
  if (!is.null(notebook_id)) {
    query <- "
      SELECT
        c.id, c.source_id, c.source_type, c.chunk_index, c.content, c.page_number,
        c.embedding,
        d.filename as doc_name,
        a.title as abstract_title
      FROM chunks c
      LEFT JOIN documents d ON c.source_id = d.id AND c.source_type = 'document'
      LEFT JOIN abstracts a ON c.source_id = a.id AND c.source_type = 'abstract'
      WHERE c.embedding IS NOT NULL
        AND (d.notebook_id = ? OR a.notebook_id = ?)
    "
    chunks <- dbGetQuery(con, query, list(notebook_id, notebook_id))
  } else {
    query <- "
      SELECT
        c.id, c.source_id, c.source_type, c.chunk_index, c.content, c.page_number,
        c.embedding,
        d.filename as doc_name,
        a.title as abstract_title
      FROM chunks c
      LEFT JOIN documents d ON c.source_id = d.id AND c.source_type = 'document'
      LEFT JOIN abstracts a ON c.source_id = a.id AND c.source_type = 'abstract'
      WHERE c.embedding IS NOT NULL
    "
    chunks <- dbGetQuery(con, query)
  }

  if (nrow(chunks) == 0) {
    return(chunks)
  }

  # Calculate similarity for each chunk in R
  # Access embedding column as vector, then iterate
  embedding_col <- as.character(chunks$embedding)
  similarities <- numeric(nrow(chunks))

  for (i in seq_len(nrow(chunks))) {
    emb_str <- embedding_col[i]
    emb <- parse_embedding(emb_str)
    if (is.null(emb)) {
      similarities[i] <- 0
    } else {
      similarities[i] <- cosine_similarity(query_embedding, emb)
    }
  }
  chunks$similarity <- similarities

  # Sort by similarity and return top results
  chunks <- chunks[order(chunks$similarity, decreasing = TRUE), ]
  chunks <- head(chunks, limit)

  # Remove the raw embedding column to reduce memory
  chunks$embedding <- NULL

  chunks
}

#' Create an abstract record
#' @param con DuckDB connection
#' @param notebook_id Notebook ID
#' @param paper_id OpenAlex paper ID
#' @param title Paper title
#' @param authors List of author names
#' @param abstract Abstract text
#' @param year Publication year
#' @param venue Publication venue
#' @param pdf_url URL to PDF
#' @param keywords Character vector of keywords (optional)
#' @param work_type OpenAlex work type (e.g., "article", "review", "preprint")
#' @param work_type_crossref Crossref work type (e.g., "journal-article", "posted-content")
#' @param oa_status Open access status (e.g., "gold", "green", "hybrid", "bronze", "closed")
#' @param is_oa Boolean indicating if paper is open access
#' @param cited_by_count Number of citations this paper has received
#' @param referenced_works_count Number of references in this paper
#' @param fwci Field-weighted citation impact
#' @return Abstract ID
create_abstract <- function(con, notebook_id, paper_id, title, authors,
                            abstract, year, venue, pdf_url, keywords = NULL,
                            work_type = NULL, work_type_crossref = NULL,
                            oa_status = NULL, is_oa = FALSE,
                            cited_by_count = 0, referenced_works_count = 0,
                            fwci = NULL) {
  id <- uuid::UUIDgenerate()

 # Handle edge cases
  authors_json <- if (is.null(authors) || length(authors) == 0) {
    "[]"
  } else {
    jsonlite::toJSON(authors, auto_unbox = TRUE)
  }

  # Convert NULL/empty to NA for proper binding
  abstract_val <- if (is.null(abstract) || (is.character(abstract) && is.na(abstract))) NA_character_ else abstract
  year_val <- if (is.null(year) || (is.numeric(year) && is.na(year))) NA_integer_ else as.integer(year)
  venue_val <- if (is.null(venue) || (is.character(venue) && is.na(venue))) NA_character_ else venue
  pdf_url_val <- if (is.null(pdf_url) || (is.character(pdf_url) && is.na(pdf_url))) NA_character_ else pdf_url

  # Convert keywords to JSON (empty array if NULL)
  keywords_json <- if (is.null(keywords) || length(keywords) == 0) {
    "[]"
  } else {
    jsonlite::toJSON(keywords, auto_unbox = FALSE)
  }

  # Convert work_type fields to NA if NULL
  work_type_val <- if (is.null(work_type) || (is.character(work_type) && is.na(work_type))) NA_character_ else work_type
  work_type_crossref_val <- if (is.null(work_type_crossref) || (is.character(work_type_crossref) && is.na(work_type_crossref))) NA_character_ else work_type_crossref

  # Convert OA and citation fields
  oa_status_val <- if (is.null(oa_status) || (is.character(oa_status) && is.na(oa_status))) NA_character_ else oa_status
  is_oa_val <- if (is.null(is_oa)) FALSE else as.logical(is_oa)
  cited_by_count_val <- if (is.null(cited_by_count) || is.na(cited_by_count)) 0L else as.integer(cited_by_count)
  referenced_works_count_val <- if (is.null(referenced_works_count) || is.na(referenced_works_count)) 0L else as.integer(referenced_works_count)
  fwci_val <- if (is.null(fwci) || (is.numeric(fwci) && is.na(fwci))) NA_real_ else as.numeric(fwci)

  dbExecute(con, "
    INSERT INTO abstracts (id, notebook_id, paper_id, title, authors, abstract, keywords, year, venue, pdf_url, work_type, work_type_crossref, oa_status, is_oa, cited_by_count, referenced_works_count, fwci)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ", list(id, notebook_id, paper_id, title, authors_json, abstract_val, keywords_json, year_val, venue_val, pdf_url_val, work_type_val, work_type_crossref_val, oa_status_val, is_oa_val, cited_by_count_val, referenced_works_count_val, fwci_val))

  id
}

#' Delete an abstract and its chunks
#' @param con DuckDB connection
#' @param id Abstract ID
delete_abstract <- function(con, id) {
  # Delete chunks first (foreign key-like behavior)
  dbExecute(con, "DELETE FROM chunks WHERE source_id = ?", list(id))
  # Delete the abstract
  dbExecute(con, "DELETE FROM abstracts WHERE id = ?", list(id))
}

#' List abstracts in a notebook
#' @param con DuckDB connection
#' @param notebook_id Notebook ID
#' @return Data frame of abstracts
list_abstracts <- function(con, notebook_id) {
  dbGetQuery(con, "
    SELECT * FROM abstracts WHERE notebook_id = ? ORDER BY year DESC, created_at DESC
  ", list(notebook_id))
}

#' Save a setting to the database
#' @param con DuckDB connection
#' @param key Setting key
#' @param value Setting value
save_db_setting <- function(con, key, value) {
  value_json <- jsonlite::toJSON(value, auto_unbox = TRUE)
  dbExecute(con, "
    INSERT INTO settings (key, value) VALUES (?, ?)
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value
  ", list(key, value_json))
}

#' Get a setting from the database
#' @param con DuckDB connection
#' @param key Setting key
#' @return Setting value or NULL
get_db_setting <- function(con, key) {
  result <- dbGetQuery(con, "SELECT value FROM settings WHERE key = ?", list(key))
  if (nrow(result) == 0) return(NULL)
  jsonlite::fromJSON(result$value[1])
}

#' Update a notebook's search query and filters
#' @param con DuckDB connection
#' @param id Notebook ID
#' @param search_query New search query (NULL to keep existing)
#' @param search_filters New filter list (NULL to keep existing)
#' @param excluded_paper_ids Character vector of paper IDs to exclude (NULL to keep existing)
#' @return TRUE on success
update_notebook <- function(con, id, search_query = NULL, search_filters = NULL, excluded_paper_ids = NULL) {
  # Build dynamic update
  updates <- c()
  params <- list()

  if (!is.null(search_query)) {
    updates <- c(updates, "search_query = ?")
    params <- c(params, list(search_query))
  }

  if (!is.null(search_filters)) {
    filters_json <- jsonlite::toJSON(search_filters, auto_unbox = TRUE)
    updates <- c(updates, "search_filters = ?")
    params <- c(params, list(filters_json))
  }

  if (!is.null(excluded_paper_ids)) {
    excluded_json <- jsonlite::toJSON(excluded_paper_ids, auto_unbox = FALSE)
    updates <- c(updates, "excluded_paper_ids = ?")
    params <- c(params, list(excluded_json))
  }

  if (length(updates) == 0) return(TRUE)

  # Always update timestamp
  updates <- c(updates, "updated_at = CURRENT_TIMESTAMP")

  sql <- paste0("UPDATE notebooks SET ", paste(updates, collapse = ", "), " WHERE id = ?")
  params <- c(params, list(id))

  dbExecute(con, sql, params)
  TRUE
}

#' Get all chunks for specific documents with source info
#' @param con DuckDB connection
#' @param document_ids Vector of document IDs
#' @return Data frame of chunks with document metadata
get_chunks_for_documents <- function(con, document_ids) {
  if (length(document_ids) == 0) {
    return(data.frame(
      id = character(),
      source_id = character(),
      chunk_index = integer(),
      content = character(),
      page_number = integer(),
      doc_name = character(),
      stringsAsFactors = FALSE
    ))
  }

  # Build parameterized query
  placeholders <- paste(rep("?", length(document_ids)), collapse = ", ")
  query <- sprintf("
    SELECT
      c.id,
      c.source_id,
      c.chunk_index,
      c.content,
      c.page_number,
      d.filename as doc_name
    FROM chunks c
    JOIN documents d ON c.source_id = d.id
    WHERE c.source_id IN (%s)
    ORDER BY d.filename, c.chunk_index
  ", placeholders)

  dbGetQuery(con, query, as.list(document_ids))
}

#' Search chunks using ragnar's hybrid VSS + BM25 retrieval
#'
#' Uses ragnar's vector similarity search combined with BM25 text matching
#' for improved retrieval quality. Falls back to legacy cosine similarity
#' if ragnar is not available.
#'
#' @param con DuckDB connection (for metadata lookup)
#' @param query Text query to search for
#' @param notebook_id Limit to specific notebook
#' @param limit Number of results
#' @param ragnar_store Optional RagnarStore object (created if NULL and ragnar available)
#' @param ragnar_store_path Path to ragnar store database
#' @return Data frame of matching chunks with source info
search_chunks_hybrid <- function(con, query, notebook_id = NULL, limit = 5,
                                  ragnar_store = NULL,
                                  ragnar_store_path = "data/serapeum.ragnar.duckdb") {

  # Try ragnar search if available (connect only, don't create new store)
  if (ragnar_available() && file.exists(ragnar_store_path)) {
    store <- ragnar_store %||% connect_ragnar_store(ragnar_store_path)

    if (!is.null(store)) {
      results <- tryCatch({
        retrieve_with_ragnar(store, query, top_k = limit * 2)  # Get extra for filtering
      }, error = function(e) NULL)

      if (!is.null(results) && nrow(results) > 0) {
        # Filter by notebook if specified
        if (!is.null(notebook_id)) {
          # Get document filenames for this notebook
          notebook_docs <- dbGetQuery(con, "
            SELECT filename FROM documents WHERE notebook_id = ?
          ", list(notebook_id))

          # Get abstract IDs for this notebook
          notebook_abstracts <- dbGetQuery(con, "
            SELECT id FROM abstracts WHERE notebook_id = ?
          ", list(notebook_id))

          # Filter results to only include items from this notebook
          keep_rows <- vapply(seq_len(nrow(results)), function(i) {
            origin <- results$origin[i]
            if (grepl("^abstract:", origin)) {
              # Extract abstract ID and check if it belongs to this notebook
              abstract_id <- sub("^abstract:", "", origin)
              # Explicit type coercion to ensure string comparison works
              as.character(abstract_id) %in% as.character(notebook_abstracts$id)
            } else {
              # Check if document filename belongs to this notebook
              doc_name <- results$doc_name[i]
              !is.na(doc_name) && doc_name %in% notebook_docs$filename
            }
          }, logical(1))

          results <- results[keep_rows, , drop = FALSE]
        }

        # Look up actual titles for abstract results
        if (nrow(results) > 0 && "abstract_title" %in% names(results)) {
          abstract_origins <- results$origin[grepl("^abstract:", results$origin)]
          if (length(abstract_origins) > 0) {
            abstract_ids <- sub("^abstract:", "", abstract_origins)
            # Fetch titles from database
            if (length(abstract_ids) > 0) {
              placeholders <- paste(rep("?", length(abstract_ids)), collapse = ", ")
              titles_df <- dbGetQuery(con, sprintf("
                SELECT id, title FROM abstracts WHERE id IN (%s)
              ", placeholders), as.list(abstract_ids))

              # Update abstract_title for matching rows
              for (i in seq_len(nrow(results))) {
                if (grepl("^abstract:", results$origin[i])) {
                  abs_id <- sub("^abstract:", "", results$origin[i])
                  # Explicit type coercion to ensure string comparison works
                  title_match <- titles_df$title[as.character(titles_df$id) == as.character(abs_id)]
                  if (length(title_match) > 0) {
                    results$abstract_title[i] <- title_match[1]
                  }
                }
              }
            }
          }
        }

        # Limit and return
        results <- head(results, limit)

        # Ensure consistent column names
        if (!"content" %in% names(results) && "text" %in% names(results)) {
          results$content <- results$text
        }

        return(results)
      }
    }
  }

  # Fallback to legacy search (requires pre-computed embeddings)
  message("Ragnar search not available, using legacy embedding search")
  message("Note: Legacy search requires query to be pre-embedded")

  # Return empty frame with expected structure
  data.frame(
    id = character(),
    source_id = character(),
    source_type = character(),
    chunk_index = integer(),
    content = character(),
    page_number = integer(),
    doc_name = character(),
    abstract_title = character(),
    similarity = numeric(),
    stringsAsFactors = FALSE
  )
}

# ============================================================================
# Quality Filter Cache Functions
# ============================================================================

#' Get quality cache metadata
#' @param con DuckDB connection
#' @param source Source name (e.g., "predatory_publishers", "retraction_watch")
#' @return Data frame with last_updated and record_count, or NULL if not found
get_quality_cache_meta <- function(con, source = NULL) {
  if (is.null(source)) {
    dbGetQuery(con, "SELECT * FROM quality_cache_meta")
  } else {
    result <- dbGetQuery(con, "SELECT * FROM quality_cache_meta WHERE source = ?", list(source))
    if (nrow(result) == 0) return(NULL)
    result
  }
}

#' Update quality cache metadata
#' @param con DuckDB connection
#' @param source Source name
#' @param record_count Number of records
update_quality_cache_meta <- function(con, source, record_count) {
  # Use now() for DuckDB timestamp
  now_ts <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  dbExecute(con, "
    INSERT INTO quality_cache_meta (source, last_updated, record_count)
    VALUES (?, ?, ?)
    ON CONFLICT (source) DO UPDATE SET
      last_updated = EXCLUDED.last_updated,
      record_count = EXCLUDED.record_count
  ", list(source, now_ts, as.integer(record_count)))
}

#' Clear and repopulate predatory publishers cache
#' @param con DuckDB connection
#' @param publishers Data frame with 'name' column
#' @param normalize_fn Function to normalize names
#' @return Number of records inserted
cache_predatory_publishers <- function(con, publishers, normalize_fn) {
  message("[quality_cache] Caching ", nrow(publishers), " publishers...")

  # Clear existing data
  dbExecute(con, "DELETE FROM predatory_publishers")

  if (nrow(publishers) == 0) return(0)

  # Prepare data frame for bulk insert
  publishers_clean <- data.frame(
    id = seq_len(nrow(publishers)),
    name = as.character(publishers$name),
    name_normalized = vapply(publishers$name, normalize_fn, character(1)),
    updated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    stringsAsFactors = FALSE
  )

  # Bulk insert
  dbWriteTable(con, "predatory_publishers", publishers_clean, append = TRUE)

  update_quality_cache_meta(con, "predatory_publishers", nrow(publishers))
  nrow(publishers)
}

#' Clear and repopulate predatory journals cache
#' @param con DuckDB connection
#' @param journals Data frame with 'name' column and optional 'is_hijacked'
#' @param normalize_fn Function to normalize names
#' @return Number of records inserted
cache_predatory_journals <- function(con, journals, normalize_fn) {
  message("[quality_cache] Caching ", nrow(journals), " journals...")

  # Clear existing data
  dbExecute(con, "DELETE FROM predatory_journals")

  if (nrow(journals) == 0) return(0)

  # Prepare data frame for bulk insert
  if (!"is_hijacked" %in% names(journals)) {
    journals$is_hijacked <- FALSE
  }

  journals_clean <- data.frame(
    id = seq_len(nrow(journals)),
    name = as.character(journals$name),
    name_normalized = vapply(journals$name, normalize_fn, character(1)),
    is_hijacked = as.logical(journals$is_hijacked),
    updated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    stringsAsFactors = FALSE
  )

  # Bulk insert
  dbWriteTable(con, "predatory_journals", journals_clean, append = TRUE)

  update_quality_cache_meta(con, "predatory_journals", nrow(journals))
  nrow(journals)
}

#' Clear and repopulate retracted papers cache
#' @param con DuckDB connection
#' @param papers Data frame with 'doi', 'title', 'retraction_date', 'reason' columns
#' @return Number of records inserted
cache_retracted_papers <- function(con, papers) {
  message("[quality_cache] Starting retracted papers cache update...")

  # Clear existing data
  dbExecute(con, "DELETE FROM retracted_papers")

  if (nrow(papers) == 0) {
    message("[quality_cache] No papers to insert")
    return(0)
  }

  message("[quality_cache] Bulk inserting ", nrow(papers), " retracted papers...")

  # Prepare data frame with correct column types
  papers_clean <- data.frame(
    doi = as.character(papers$doi),
    title = as.character(papers$title),
    retraction_date = as.character(papers$retraction_date),
    reason = as.character(papers$reason),
    updated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    stringsAsFactors = FALSE
  )

  # Remove duplicates by DOI (keep first occurrence)
  papers_clean <- papers_clean[!duplicated(papers_clean$doi), ]

  # Bulk insert using DuckDB's native support
  tryCatch({
    # Use temporary table + INSERT to handle the primary key
    dbWriteTable(con, "retracted_papers_temp", papers_clean, overwrite = TRUE)

    dbExecute(con, "
      INSERT INTO retracted_papers (doi, title, retraction_date, reason, updated_at)
      SELECT doi, title, retraction_date, reason, updated_at
      FROM retracted_papers_temp
      ON CONFLICT (doi) DO NOTHING
    ")

    dbExecute(con, "DROP TABLE IF EXISTS retracted_papers_temp")

    inserted <- nrow(papers_clean)
    message("[quality_cache] Bulk insert completed: ", inserted, " records")
  }, error = function(e) {
    message("[quality_cache] Bulk insert error: ", e$message)
    dbExecute(con, "DROP TABLE IF EXISTS retracted_papers_temp")
    stop(e)
  })

  update_quality_cache_meta(con, "retraction_watch", inserted)
  inserted
}

#' Check if a DOI is in the retracted papers list
#' @param con DuckDB connection
#' @param doi DOI to check
#' @return TRUE if retracted, FALSE otherwise
is_paper_retracted <- function(con, doi) {
  if (is.null(doi) || is.na(doi) || doi == "") return(FALSE)

  result <- dbGetQuery(con, "
    SELECT 1 FROM retracted_papers WHERE doi = ? LIMIT 1
  ", list(doi))

  nrow(result) > 0
}

#' Check if a journal name matches predatory journals list
#' @param con DuckDB connection
#' @param journal_name Journal name to check
#' @param normalize_fn Function to normalize names
#' @return TRUE if predatory, FALSE otherwise
is_journal_predatory <- function(con, journal_name, normalize_fn) {
  if (is.null(journal_name) || is.na(journal_name) || journal_name == "") return(FALSE)

  normalized <- normalize_fn(journal_name)

  result <- dbGetQuery(con, "
    SELECT 1 FROM predatory_journals WHERE name_normalized = ? LIMIT 1
  ", list(normalized))

  nrow(result) > 0
}

#' Check if a publisher name matches predatory publishers list
#' @param con DuckDB connection
#' @param publisher_name Publisher name to check
#' @param normalize_fn Function to normalize names
#' @return TRUE if predatory, FALSE otherwise
is_publisher_predatory <- function(con, publisher_name, normalize_fn) {
  if (is.null(publisher_name) || is.na(publisher_name) || publisher_name == "") return(FALSE)

  normalized <- normalize_fn(publisher_name)

  result <- dbGetQuery(con, "
    SELECT 1 FROM predatory_publishers WHERE name_normalized = ? LIMIT 1
  ", list(normalized))

  nrow(result) > 0
}

#' Get all predatory journal names (normalized) for in-memory matching
#' @param con DuckDB connection
#' @return Character vector of normalized journal names
get_predatory_journals_set <- function(con) {
  result <- dbGetQuery(con, "SELECT name_normalized FROM predatory_journals")
  result$name_normalized
}

#' Get all predatory publisher names (normalized) for in-memory matching
#' @param con DuckDB connection
#' @return Character vector of normalized publisher names
get_predatory_publishers_set <- function(con) {
  result <- dbGetQuery(con, "SELECT name_normalized FROM predatory_publishers")
  result$name_normalized
}

#' Get all retracted DOIs for in-memory matching
#' @param con DuckDB connection
#' @return Character vector of DOIs
get_retracted_dois_set <- function(con) {
  result <- dbGetQuery(con, "SELECT doi FROM retracted_papers")
  result$doi
}
