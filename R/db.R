library(duckdb)
library(DBI)

#' Get DuckDB connection
#' @param path Path to database file
#' @return DuckDB connection object
get_db_connection <- function(path = "data/notebooks.duckdb") {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  con <- dbConnect(duckdb(), dbdir = path)
  con
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
#' @return Abstract ID
create_abstract <- function(con, notebook_id, paper_id, title, authors,
                            abstract, year, venue, pdf_url) {
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

  dbExecute(con, "
    INSERT INTO abstracts (id, notebook_id, paper_id, title, authors, abstract, year, venue, pdf_url)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  ", list(id, notebook_id, paper_id, title, authors_json, abstract_val, year_val, venue_val, pdf_url_val))

  id
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
