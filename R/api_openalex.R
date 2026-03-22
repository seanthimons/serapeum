library(httr2)
library(jsonlite)

OPENALEX_BASE_URL <- "https://api.openalex.org"

#' Perform an OpenAlex API request with optional verbose logging
#' @param req httr2 request object
#' @return httr2 response
perform_openalex <- function(req) {
  if (isTRUE(getOption("serapeum.verbose_api", FALSE))) {
    url <- gsub("api_key=[^&]+", "api_key=<REDACTED>", req$url)
    url <- gsub("mailto=[^&]+", "mailto=<REDACTED>", url)
    message("[OpenAlex API] ", url)
  }
  req_perform(req)
}

#' Classify an API error into user-friendly message with details
#' @param e Error object or condition
#' @param service Service name ("OpenAlex" or "OpenRouter")
#' @return list(message, details, severity) where severity is "error" or "warning"
classify_api_error <- function(e, service = "API") {
  msg <- conditionMessage(e)

  # Extract HTTP status code if present (httr2 pattern)
  status <- NULL
  if (grepl("HTTP (\\d{3})", msg)) {
    status <- as.integer(regmatches(msg, regexpr("\\d{3}", msg)))
  }

  # Classify by status code
  if (!is.null(status)) {
    result <- switch(as.character(status),
      "401" = list(
        message = paste(service, "authentication failed. Check your API key in Settings."),
        severity = "error"
      ),
      "403" = list(
        message = paste(service, "access denied. Your API key may lack required permissions."),
        severity = "error"
      ),
      "404" = list(
        message = paste(service, "resource not found. The requested endpoint may have changed."),
        severity = "error"
      ),
      "429" = list(
        message = paste(service, "rate limit reached. Please wait a moment and try again."),
        severity = "warning"
      ),
      "500" = list(
        message = paste(service, "is experiencing issues. Please try again later."),
        severity = "error"
      ),
      "502" = ,
      "503" = ,
      "504" = list(
        message = paste(service, "is temporarily unavailable. Please try again in a few minutes."),
        severity = "warning"
      ),
      # Default for other status codes
      list(
        message = paste(service, "request failed. Please try again."),
        severity = "error"
      )
    )
  } else if (grepl("timed? ?out|timeout", msg, ignore.case = TRUE)) {
    result <- list(
      message = paste(service, "request timed out. The service may be slow — try again."),
      severity = "warning"
    )
  } else if (grepl("could not resolve|connection refused|no internet", msg, ignore.case = TRUE)) {
    result <- list(
      message = paste("Cannot reach", service, ". Check your internet connection."),
      severity = "error"
    )
  } else {
    result <- list(
      message = paste(service, "request failed unexpectedly."),
      severity = "error"
    )
  }

  result$details <- msg
  result
}

#' Classify and throw an API error as a custom condition
#' The condition carries message, details, and severity so callers
#' can extract all three without re-classifying.
#' @param e Original error/condition
#' @param service Service name ("OpenAlex" or "OpenRouter")
stop_api_error <- function(e, service = "API") {
  err <- classify_api_error(e, service)
  cond <- structure(
    class = c("api_error", "error", "condition"),
    list(
      message = err$message,
      details = err$details,
      severity = err$severity
    )
  )
  stop(cond)
}

#' Build OpenAlex API request
#' @param endpoint API endpoint
#' @param email User email for polite pool
#' @param api_key Optional API key
#' @return httr2 request object
build_openalex_request <- function(endpoint, email = NULL, api_key = NULL) {
  req <- request(paste0(OPENALEX_BASE_URL, "/", endpoint))

  if (!is.null(email)) {
    req <- req |> req_url_query(mailto = email)
  }

  if (!is.null(api_key) && nchar(api_key) > 0 && !grepl("^your-", api_key)) {
    req <- req |> req_url_query(api_key = api_key)
  }

  req |>
    req_timeout(30) |>
    req_retry(
      max_tries = 3,
      is_transient = \(resp) httr2::resp_status(resp) %in% c(429, 503),
      backoff = \(i) 2^(i - 1)
    )
}

#' Parse OpenAlex rate-limit headers from a response
#'
#' Extracts X-RateLimit-* headers. Returns NAs gracefully when headers
#' are absent (polite-pool users without an API key).
#'
#' @param resp httr2 response object
#' @return Named list with daily_limit, remaining, credits_used, reset_seconds (all numeric or NA)
parse_oa_usage_headers <- function(resp) {
  safe_header <- function(name) {
    val <- tryCatch(httr2::resp_header(resp, name), error = function(e) NULL)
    if (is.null(val) || is.na(val)) NA_real_ else as.numeric(val)
  }

  list(
    daily_limit = safe_header("X-RateLimit-Limit"),
    remaining = safe_header("X-RateLimit-Remaining"),
    credits_used = safe_header("X-RateLimit-Credits-Used"),
    reset_seconds = {
      val <- safe_header("X-RateLimit-Reset")
      if (is.na(val)) NA_integer_ else as.integer(val)
    }
  )
}

#' Log OpenAlex usage to the oa_usage_log table
#'
#' @param con DuckDB connection
#' @param operation Operation label (e.g., "search", "fetch", "topics")
#' @param endpoint API endpoint called
#' @param usage Named list from parse_oa_usage_headers()
#' @param cost_usd Optional cost_usd from response meta (numeric or NA)
#' @return Inserted row ID (invisible)
log_oa_usage <- function(con, operation, endpoint = NA_character_, usage, cost_usd = NA_real_) {
  # Guard: table may not exist yet (first run before migration)
  has_table <- tryCatch({
    DBI::dbExistsTable(con, "oa_usage_log")
  }, error = function(e) FALSE)

  if (!has_table) return(invisible(NULL))

  id <- uuid::UUIDgenerate()
  DBI::dbExecute(con, "
    INSERT INTO oa_usage_log (id, operation, endpoint, daily_limit, remaining, credits_used, cost_usd, reset_seconds)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  ", list(
    id,
    operation,
    endpoint,
    usage$daily_limit,
    usage$remaining,
    usage$credits_used,
    cost_usd,
    usage$reset_seconds
  ))

  invisible(id)
}

#' Perform an OpenAlex request with usage tracking
#'
#' Central wrapper that replaces direct req_perform() calls. Extracts
#' rate-limit headers, logs usage, and returns the parsed JSON body —
#' preserving the existing return contract.
#'
#' @param req httr2 request object (from build_openalex_request)
#' @param con Optional DuckDB connection for logging (NULL skips logging)
#' @param operation Operation label for the log (default "request")
#' @return Parsed JSON body (same as resp_body_json would return)
perform_oa_request <- function(req, con = NULL, operation = "request") {
  resp <- perform_openalex(req)
  body <- resp_body_json(resp)

  # Parse usage headers and log if connection provided
  if (!is.null(con)) {
    usage <- parse_oa_usage_headers(resp)

    # Extract cost_usd from response meta if present
    cost_usd <- NA_real_
    if (!is.null(body$meta) && !is.null(body$meta$cost_usd)) {
      cost_usd <- as.numeric(body$meta$cost_usd)
    }

    # Extract endpoint from request URL for logging
    endpoint <- tryCatch({
      url <- req$url
      parsed <- httr2::url_parse(url)
      parsed$path
    }, error = function(e) NA_character_)

    tryCatch(
      log_oa_usage(con, operation, endpoint, usage, cost_usd),
      error = function(e) message("[oa_usage] Logging failed (non-fatal): ", e$message)
    )
  }

  body
}

#' Check whether the OA migration nudge should be shown
#'
#' Returns TRUE when the user has an email configured but no API key,
#' and hasn't dismissed the nudge.
#'
#' @param email Current openalex email (character or "")
#' @param api_key Current openalex API key (character or "")
#' @param con DuckDB connection (to check dismiss flag)
#' @return logical
should_show_oa_migration_nudge <- function(email, api_key, con = NULL) {
  # Must have an email set
  if (is.null(email) || !nzchar(trimws(email))) return(FALSE)

  # Must NOT have an API key set
  if (!is.null(api_key) && nzchar(trimws(api_key))) return(FALSE)

  # Check dismiss flag

  if (!is.null(con)) {
    dismissed <- tryCatch(get_db_setting(con, "oa_migration_nudge_dismissed"), error = function(e) NULL)
    if (isTRUE(dismissed)) return(FALSE)
  }

  TRUE
}

#' Reconstruct abstract from inverted index
#' @param inverted_index OpenAlex inverted index format
#' @return Plain text abstract
reconstruct_abstract <- function(inverted_index) {
  if (is.null(inverted_index) || length(inverted_index) == 0) {
    return(NA_character_)
  }

  # Build position -> word mapping
  max_pos <- 0
  for (word in names(inverted_index)) {
    positions <- inverted_index[[word]]
    if (length(positions) > 0) {
      max_pos <- max(max_pos, max(unlist(positions)))
    }
  }

  if (max_pos == 0) return(NA_character_)

  words <- character(max_pos + 1)

  for (word in names(inverted_index)) {
    positions <- inverted_index[[word]]
    for (pos in positions) {
      words[pos + 1] <- word
    }
  }

  paste(words[words != ""], collapse = " ")
}

#' Parse OpenAlex work object
#' @param work Raw work object from API
#' @return Cleaned list with relevant fields
parse_openalex_work <- function(work) {
  # Extract paper ID from URL
  paper_id <- gsub("https://openalex.org/", "", work$id)

  # Extract author names
  authors <- character()
  if (!is.null(work$authorships) && length(work$authorships) > 0) {
    authors <- sapply(work$authorships, function(a) {
      if (!is.null(a$author$display_name)) a$author$display_name else "Unknown"
    })
  }

  # Get venue

  venue <- NA_character_
  if (!is.null(work$primary_location) &&
      !is.null(work$primary_location$source) &&
      !is.null(work$primary_location$source$display_name)) {
    venue <- work$primary_location$source$display_name
  }

  # Get PDF URL
  pdf_url <- NA_character_
  if (!is.null(work$open_access) && !is.null(work$open_access$oa_url)) {
    pdf_url <- work$open_access$oa_url
  }

  # Get publisher/host organization name (for predatory publisher matching)
  publisher <- NA_character_
  if (!is.null(work$primary_location) &&
      !is.null(work$primary_location$source) &&
      !is.null(work$primary_location$source$host_organization_name)) {
    publisher <- work$primary_location$source$host_organization_name
  }

  # Get DOI (for retraction matching)
  doi <- NA_character_
  if (!is.null(work$doi)) {
    # OpenAlex returns full URL, extract just the DOI
    doi <- gsub("^https://doi.org/", "", work$doi)
  }

  # Get citation count
  cited_by_count <- 0
  if (!is.null(work$cited_by_count)) {
    cited_by_count <- work$cited_by_count
  }

  # Extract keywords (OpenAlex uses display_name field)
  keywords <- character()
  if (!is.null(work$keywords) && length(work$keywords) > 0) {
    keywords <- sapply(work$keywords, function(k) {
      if (!is.null(k$display_name)) k$display_name else ""
    })
    keywords <- keywords[keywords != ""]
  }

  # Extract work type (OpenAlex simplified type)
  work_type <- NA_character_
  if (!is.null(work$type)) {
    work_type <- work$type
  }

  # Extract Crossref type (more granular)
  work_type_crossref <- NA_character_
  if (!is.null(work$type_crossref)) {
    work_type_crossref <- work$type_crossref
  }

  # Extract OA status (Phase 2)
  oa_status <- NA_character_
  is_oa <- FALSE
  if (!is.null(work$open_access)) {
    oa_status <- work$open_access$oa_status %||% NA_character_
    is_oa <- isTRUE(work$open_access$is_oa)
  }

  # Extract referenced works count (outgoing citations)
  referenced_works_count <- 0
  if (!is.null(work$referenced_works_count)) {
    referenced_works_count <- work$referenced_works_count
  }

  # Extract FWCI (field-weighted citation impact)
  fwci <- NA_real_
  if (!is.null(work$fwci)) {
    fwci <- work$fwci
  }

  # Extract retraction status (Phase 34)
  is_retracted <- isTRUE(work$is_retracted)

  # Extract cited-by percentile (Phase 34)
  cited_by_percentile <- NA_real_
  if (!is.null(work$cited_by_percentile_year) && !is.null(work$cited_by_percentile_year$min)) {
    cited_by_percentile <- as.numeric(work$cited_by_percentile_year$min)
  }

  # Extract topics (Phase 34)
  topics <- list()
  if (!is.null(work$topics) && length(work$topics) > 0) {
    topics <- lapply(work$topics, function(t) {
      list(
        id = gsub("https://openalex.org/", "", t$id %||% ""),
        name = t$display_name %||% NA_character_,
        score = t$score %||% NA_real_
      )
    })
  }

  list(
    paper_id = paper_id,
    title = work$title %||% "Untitled",
    authors = as.list(authors),
    abstract = reconstruct_abstract(work$abstract_inverted_index),
    year = work$publication_year,
    venue = venue,
    publisher = publisher,
    doi = doi,
    cited_by_count = cited_by_count,
    pdf_url = pdf_url,
    keywords = as.list(keywords),
    work_type = work_type,
    work_type_crossref = work_type_crossref,
    oa_status = oa_status,
    is_oa = is_oa,
    referenced_works_count = referenced_works_count,
    referenced_works = if (!is.null(work$referenced_works)) as.character(work$referenced_works) else character(),
    fwci = fwci,
    is_retracted = is_retracted,
    cited_by_percentile = cited_by_percentile,
    topics = topics
  )
}

#' Parse OpenAlex search response body into structured format
#' @param body Parsed JSON response body from OpenAlex API
#' @return List with papers (list), next_cursor (string or NULL), count (integer)
parse_search_response <- function(body) {
  if (is.null(body$meta) || is.null(body$results)) {
    stop("Unexpected OpenAlex response format: missing 'meta' or 'results' field")
  }

  next_cursor <- body$meta$next_cursor
  count <- body$meta$count %||% 0L

  papers <- if (length(body$results) > 0) {
    lapply(body$results, parse_openalex_work)
  } else {
    list()
  }

  list(papers = papers, next_cursor = next_cursor, count = count)
}

#' Search for papers
#' @param query Search query
#' @param email User email
#' @param api_key Optional API key
#' @param from_year Filter by start year
#' @param to_year Filter by end year
#' @param per_page Results per page (max 200)
#' @param search_field Field to search: "default", "title", "abstract", "title_and_abstract"
#' @param is_oa Filter to open access only (boolean)
#' @param min_citations Minimum citation count (optional)
#' @param has_abstract Restrict results to papers with abstracts (boolean)
#' @param exclude_retracted Exclude retracted papers (boolean)
#' @param work_types Character vector of work types to include (e.g., c("article", "review"))
#' @param cursor Pagination cursor (NULL initiates pagination, string continues)
#' @param sort Sort order (default "relevance_score")
#' @return List with papers (list), next_cursor (string or NULL), count (integer)
search_papers <- function(query, email, api_key = NULL,
                          from_year = NULL, to_year = NULL, per_page = 100,
                          search_field = "default", is_oa = FALSE,
                          min_citations = NULL, has_abstract = TRUE, exclude_retracted = TRUE,
                          work_types = NULL, cursor = NULL, sort = NULL) {

  # Build filter components
  filters <- character()

  if (isTRUE(has_abstract)) {
    filters <- c(filters, "has_abstract:true")
  }

  if (!is.null(from_year)) {
    filters <- c(filters, paste0("from_publication_date:", from_year, "-01-01"))
  }
  if (!is.null(to_year)) {
    filters <- c(filters, paste0("to_publication_date:", to_year, "-12-31"))
  }

  # Open access filter
  if (isTRUE(is_oa)) {
    filters <- c(filters, "is_oa:true")
  }
  # Coerce min_citations — jsonlite may parse as list from filter JSON
  if (is.list(min_citations)) min_citations <- if (length(min_citations) > 0) as.numeric(min_citations[[1]]) else NULL
  # Citation count filter
  if (!is.null(min_citations) && !is.na(min_citations) && min_citations > 0) {
    filters <- c(filters, paste0("cited_by_count:>", as.integer(min_citations) - 1))
  }

  # Retraction filter (exclude retracted papers)
  if (isTRUE(exclude_retracted)) {
    filters <- c(filters, "is_retracted:false")
  }
  # Work type filter (e.g., article, review, preprint)
  if (!is.null(work_types) && length(work_types) > 0) {
    # OpenAlex uses pipe for OR: type:article|review
    filters <- c(filters, paste0("type:", paste(work_types, collapse = "|")))
  }

  # Field-specific search - add to filters instead of using search param
  use_search_param <- TRUE
  if (!is.null(search_field) && search_field != "default" && nchar(query) > 0) {
    if (search_field == "title") {
      filters <- c(filters, paste0("title.search:", query))
      use_search_param <- FALSE
    } else if (search_field == "abstract") {
      filters <- c(filters, paste0("abstract.search:", query))
      use_search_param <- FALSE
    } else if (search_field == "title_and_abstract") {
      # OpenAlex doesn't support OR in filter, so we use title.search
      # and let abstract.search be additive (AND). For true OR, we'd need
      # to use the default search param. So for "title_and_abstract",
      # use the default fulltext search which covers both.
      use_search_param <- TRUE
    }
  }

  filter_str <- paste(filters, collapse = ",")

  # Build request
  req <- build_openalex_request("works", email, api_key)

  if (use_search_param && nchar(query) > 0) {
    req <- req |> req_url_query(search = query)
  }

  req <- req |> req_url_query(
    filter = filter_str,
    per_page = per_page,
    cursor = if (is.null(cursor)) "*" else cursor
  )

  if (!is.null(sort)) {
    req <- req |> req_url_query(sort = sort)
  }

  body <- tryCatch({
    perform_oa_request(req, con = NULL, operation = "search")
  }, error = function(e) {
    stop_api_error(e, "OpenAlex")
  })

  parse_search_response(body)
}

#' Build API query preview string (for UI display)
#' @param query Search query
#' @param from_year Start year
#' @param to_year End year
#' @param search_field Field to search
#' @param is_oa Open access filter
#' @param min_citations Minimum citation count (optional)
#' @param has_abstract Restrict results to papers with abstracts (boolean)
#' @param exclude_retracted Exclude retracted papers (boolean)
#' @param work_types Character vector of work types to include
#' @return List with search and filter strings
build_query_preview <- function(query, from_year = NULL, to_year = NULL,
                                 search_field = "default", is_oa = FALSE,
                                 min_citations = NULL, has_abstract = TRUE, exclude_retracted = TRUE,
                                 work_types = NULL) {
  filters <- character()

  if (isTRUE(has_abstract)) {
    filters <- c(filters, "has_abstract:true")
  }

  if (!is.null(from_year)) {
    filters <- c(filters, paste0("from_publication_date:", from_year, "-01-01"))
  }
  if (!is.null(to_year)) {
    filters <- c(filters, paste0("to_publication_date:", to_year, "-12-31"))
  }

  if (isTRUE(is_oa)) {
    filters <- c(filters, "is_oa:true")
  }

  # Coerce min_citations — jsonlite may parse as list from filter JSON
  if (is.list(min_citations)) min_citations <- if (length(min_citations) > 0) as.numeric(min_citations[[1]]) else NULL
  # Citation count filter
  if (!is.null(min_citations) && !is.na(min_citations) && min_citations > 0) {
    filters <- c(filters, paste0("cited_by_count:>", as.integer(min_citations) - 1))
  }

  # Retraction filter
  if (isTRUE(exclude_retracted)) {
    filters <- c(filters, "is_retracted:false")
  }

  # Work type filter
  if (!is.null(work_types) && length(work_types) > 0) {
    filters <- c(filters, paste0("type:", paste(work_types, collapse = "|")))
  }

  search_param <- NULL
  if (!is.null(search_field) && search_field != "default" && nchar(query) > 0) {
    if (search_field == "title") {
      filters <- c(filters, paste0("title.search:", query))
    } else if (search_field == "abstract") {
      filters <- c(filters, paste0("abstract.search:", query))
    } else {
      search_param <- query
    }
  } else if (nchar(query) > 0) {
    search_param <- query
  }

  list(
    search = search_param,
    filter = paste(filters, collapse = ",")
  )
}

#' Normalize DOI to standard format
#' @param input DOI in various formats (plain, with prefix, URL, or OpenAlex Work ID)
#' @return Normalized DOI as https://doi.org/{doi} or original Work ID, NULL if invalid
normalize_doi <- function(input) {
  if (is.null(input) || is.na(input) || nchar(trimws(input)) == 0) {
    return(NULL)
  }

  input <- trimws(input)

  # Handle OpenAlex Work IDs (e.g., W2741809807)
  if (grepl("^W\\d+$", input)) {
    return(input)
  }

  # Extract from OpenAlex URL
  if (grepl("^https?://openalex\\.org/", input, ignore.case = TRUE)) {
    input <- gsub("^https?://openalex\\.org/", "", input, ignore.case = TRUE)
    # If it's a Work ID, return as-is
    if (grepl("^W\\d+$", input)) {
      return(input)
    }
  }

  # Strip doi: prefix (case-insensitive)
  input <- gsub("^doi:", "", input, ignore.case = TRUE)

  # Replace dx.doi.org with doi.org
  input <- gsub("dx\\.doi\\.org", "doi.org", input, ignore.case = TRUE)

  # Replace http:// with https://
  input <- gsub("^http://", "https://", input, ignore.case = TRUE)

  # Extract DOI from URL if it's a full URL
  if (grepl("^https://doi\\.org/", input, ignore.case = TRUE)) {
    input <- gsub("^https://doi\\.org/", "", input, ignore.case = TRUE)
  }

  # Validate format: must start with 10.\d{4,}/
  if (!grepl("^10\\.\\d{4,}/\\S+", input)) {
    return(NULL)
  }

  # Return standard format
  paste0("https://doi.org/", input)
}

#' Get a single paper by ID or DOI
#' @param paper_id OpenAlex paper ID (e.g., "W123456") or DOI URL
#' @param email User email
#' @param api_key Optional API key
#' @return Parsed work or NULL
get_paper <- function(paper_id, email, api_key = NULL) {
  # If it's a DOI URL (from normalize_doi), use it directly in the request
  if (grepl("^https://doi\\.org/", paper_id)) {
    # OpenAlex API accepts DOI URLs directly: /works/https://doi.org/...
    req <- build_openalex_request(paste0("works/", URLencode(paper_id, reserved = TRUE)), email, api_key)
  } else {
    # Ensure paper_id has the full URL format for Work IDs
    if (!grepl("^https://", paper_id)) {
      paper_id <- paste0("https://openalex.org/", paper_id)
    }
    req <- build_openalex_request(paste0("works/", URLencode(paper_id, reserved = TRUE)), email, api_key)
  }

  body <- tryCatch({
    perform_oa_request(req, con = NULL, operation = "fetch")
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(body)) return(NULL)

  parse_openalex_work(body)
}

#' Fetch paper with DOI-to-Work-ID fallback
#'
#' Tries DOI lookup first. If it fails, silently retries with the
#' OpenAlex Work ID. This handles cases where display DOIs differ
#' from canonical DOIs in OpenAlex.
#'
#' @param doi Optional DOI string
#' @param paper_id Optional OpenAlex Work ID (e.g., "W2626778328")
#' @param email User email for OpenAlex API
#' @param api_key Optional API key
#' @return Parsed work list, or NULL if both fail
fetch_paper_with_fallback <- function(doi = NULL, paper_id = NULL, email, api_key = NULL) {
  # Try DOI first if provided
  if (!is.null(doi) && nchar(doi) > 0) {
    result <- tryCatch(
      get_paper(doi, email, api_key),
      error = function(e) NULL
    )
    if (!is.null(result)) return(result)
  }

  # Silently fallback to Work ID
  if (!is.null(paper_id) && nchar(paper_id) > 0) {
    result <- tryCatch(
      get_paper(paper_id, email, api_key),
      error = function(e) NULL
    )
    if (!is.null(result)) return(result)
  }

  NULL
}

#' Get papers that cite a given work
#' @param paper_id OpenAlex Work ID (e.g., "W2741809807")
#' @param email User email
#' @param api_key Optional API key
#' @param per_page Results per page (max 200)
#' @return List of parsed works with total_count attribute
get_citing_papers <- function(paper_id, email, api_key = NULL, per_page = 25) {
  # Add W prefix if missing
  if (!grepl("^W", paper_id)) {
    paper_id <- paste0("W", paper_id)
  }

  req <- build_openalex_request("works", email, api_key) |>
    req_url_query(
      filter = paste0("cites:", paper_id),
      per_page = per_page
    )

  body <- tryCatch({
    perform_oa_request(req, con = NULL, operation = "citing")
  }, error = function(e) {
    err <- classify_api_error(e, "OpenAlex")
    message("OpenAlex API error in get_citing_papers: ", err$message, " (", err$details, ")")
    return(NULL)
  })

  if (is.null(body) || is.null(body$results)) return(list())

  results <- lapply(body$results, parse_openalex_work)
  attr(results, "total_count") <- body$meta$count %||% 0
  results
}

#' Get papers cited by a given work (outgoing references)
#' @param paper_id OpenAlex Work ID (e.g., "W2741809807")
#' @param email User email
#' @param api_key Optional API key
#' @param per_page Results per page (max 200)
#' @return List of parsed works with total_count attribute
get_cited_papers <- function(paper_id, email, api_key = NULL, per_page = 25) {
  # Add W prefix if missing
  if (!grepl("^W", paper_id)) {
    paper_id <- paste0("W", paper_id)
  }

  req <- build_openalex_request("works", email, api_key) |>
    req_url_query(
      filter = paste0("cited_by:", paper_id),
      per_page = per_page
    )

  body <- tryCatch({
    perform_oa_request(req, con = NULL, operation = "cited_by")
  }, error = function(e) {
    err <- classify_api_error(e, "OpenAlex")
    message("OpenAlex API error in get_cited_papers: ", err$message, " (", err$details, ")")
    return(NULL)
  })

  if (is.null(body) || is.null(body$results)) return(list())

  results <- lapply(body$results, parse_openalex_work)
  attr(results, "total_count") <- body$meta$count %||% 0
  results
}

#' Get papers related to a given work
#' @param paper_id OpenAlex Work ID (e.g., "W2741809807")
#' @param email User email
#' @param api_key Optional API key
#' @param per_page Results per page (max 200)
#' @return List of parsed works with total_count attribute
get_related_papers <- function(paper_id, email, api_key = NULL, per_page = 25) {
  # Add W prefix if missing
  if (!grepl("^W", paper_id)) {
    paper_id <- paste0("W", paper_id)
  }

  req <- build_openalex_request("works", email, api_key) |>
    req_url_query(
      filter = paste0("related_to:", paper_id),
      per_page = per_page
    )

  body <- tryCatch({
    perform_oa_request(req, con = NULL, operation = "related")
  }, error = function(e) {
    err <- classify_api_error(e, "OpenAlex")
    message("OpenAlex API error in get_related_papers: ", err$message, " (", err$details, ")")
    return(NULL)
  })

  if (is.null(body) || is.null(body$results)) return(list())

  results <- lapply(body$results, parse_openalex_work)
  attr(results, "total_count") <- body$meta$count %||% 0
  results
}

#' Validate OpenAlex email by making a minimal API call
#' @param email Email address to validate
#' @return list(valid = TRUE/FALSE, error = NULL or message)
validate_openalex_email <- function(email) {
  if (is.null(email) || nchar(email) < 5 || !grepl("@", email)) {
    return(list(valid = FALSE, error = "Invalid email format"))
  }

  tryCatch({
    req <- build_openalex_request("works", email) |>
      req_url_query(per_page = 1)
    perform_oa_request(req, con = NULL, operation = "validate")
    list(valid = TRUE, error = NULL)
  }, error = function(e) {
    list(valid = FALSE, error = e$message)
  })
}

#' Parse a single OpenAlex topic object
#' @param topic Raw topic object from API
#' @return Flat list with 11 fields matching topics table schema
parse_topic <- function(topic) {
  # Extract topic ID by stripping URL prefix
  topic_id <- gsub("https://openalex.org/", "", topic$id)

  # Extract basic fields
  display_name <- topic$display_name %||% NA_character_
  description <- topic$description %||% NA_character_
  works_count <- topic$works_count %||% 0L

  # Convert keywords list to JSON string
  keywords_json <- "[]"
  if (!is.null(topic$keywords) && length(topic$keywords) > 0) {
    keywords_json <- jsonlite::toJSON(topic$keywords, auto_unbox = FALSE)
  }

  # Flatten hierarchy - domain
  domain_id <- NA_character_
  domain_name <- NA_character_
  if (!is.null(topic$domain)) {
    domain_id <- gsub("https://openalex.org/", "", topic$domain$id %||% "")
    if (domain_id == "") domain_id <- NA_character_
    domain_name <- topic$domain$display_name %||% NA_character_
  }

  # Flatten hierarchy - field
  field_id <- NA_character_
  field_name <- NA_character_
  if (!is.null(topic$field)) {
    field_id <- gsub("https://openalex.org/", "", topic$field$id %||% "")
    if (field_id == "") field_id <- NA_character_
    field_name <- topic$field$display_name %||% NA_character_
  }

  # Flatten hierarchy - subfield
  subfield_id <- NA_character_
  subfield_name <- NA_character_
  if (!is.null(topic$subfield)) {
    subfield_id <- gsub("https://openalex.org/", "", topic$subfield$id %||% "")
    if (subfield_id == "") subfield_id <- NA_character_
    subfield_name <- topic$subfield$display_name %||% NA_character_
  }

  # Return named list with all 11 fields
  list(
    topic_id = topic_id,
    display_name = display_name,
    description = description,
    keywords = keywords_json,
    works_count = as.integer(works_count),
    domain_id = domain_id,
    domain_name = domain_name,
    field_id = field_id,
    field_name = field_name,
    subfield_id = subfield_id,
    subfield_name = subfield_name
  )
}

#' Fetch all topics from OpenAlex with pagination
#' @param email User email for polite pool
#' @param api_key Optional API key
#' @param per_page Results per page (default 100, max 200)
#' @return Data frame of all topics
fetch_all_topics <- function(email, api_key = NULL, per_page = 100) {
  all_topics <- list()
  page <- 1
  total_fetched <- 0

  message("[openalex] Fetching topics from OpenAlex API...")

  repeat {
    message("[openalex] Fetching topics page ", page, "...")

    # Build request using existing helper function
    req <- build_openalex_request("topics", email, api_key) |>
      req_url_query(
        per_page = per_page,
        page = page,
        select = "id,display_name,description,keywords,works_count,domain,field,subfield"
      )

    # Perform request with error handling
    body <- tryCatch({
      perform_oa_request(req, con = NULL, operation = "topics")
    }, error = function(e) {
      stop_api_error(e, "OpenAlex")
    })

    # Check if we have results
    if (is.null(body$results) || length(body$results) == 0) {
      message("[openalex] No more results. Stopping.")
      break
    }

    # Parse topics from this page
    page_topics <- lapply(body$results, parse_topic)
    all_topics <- c(all_topics, page_topics)

    total_fetched <- total_fetched + length(body$results)

    # Check if we've fetched all available topics
    if (!is.null(body$meta$count) && total_fetched >= body$meta$count) {
      message("[openalex] Fetched all ", total_fetched, " topics.")
      break
    }

    # Rate limiting - be polite to the API
    Sys.sleep(0.1)

    page <- page + 1
  }

  message("[openalex] Converting ", length(all_topics), " topics to data frame...")

  # Convert list of lists to data frame
  if (length(all_topics) == 0) {
    return(data.frame(
      topic_id = character(),
      display_name = character(),
      description = character(),
      keywords = character(),
      works_count = integer(),
      domain_id = character(),
      domain_name = character(),
      field_id = character(),
      field_name = character(),
      subfield_id = character(),
      subfield_name = character(),
      stringsAsFactors = FALSE
    ))
  }

  # Use do.call + rbind + lapply pattern to convert to data frame
  topics_df <- do.call(rbind, lapply(all_topics, as.data.frame, stringsAsFactors = FALSE))

  message("[openalex] Successfully fetched ", nrow(topics_df), " topics.")
  topics_df
}

# --- Phase 34: Batch DOI Fetch ---

#' Split a DOI vector into chunks of a given batch size
#' @param dois Character vector of bare DOIs
#' @param batch_size Maximum DOIs per chunk (default 50)
#' @return List of character vectors
chunk_dois <- function(dois, batch_size = 50) {
  if (length(dois) == 0) return(list())
  split(dois, ceiling(seq_along(dois) / batch_size))
}

#' Build pipe-separated DOI filter string for OpenAlex API
#' @param dois Character vector of bare DOIs (10.xxxx/yyyy format)
#' @return Filter string like "doi:10.aaa/x|10.bbb/y"
build_batch_filter <- function(dois) {
  paste0("doi:", paste(dois, collapse = "|"))
}

#' Match returned works back to input DOIs, identify not_found
#' @param works List of parsed work objects (each with $doi field)
#' @param input_dois Character vector of bare DOIs that were queried
#' @return List with $found (works) and $not_found (error entries)
match_results_to_dois <- function(works, input_dois) {
  # Extract bare DOIs from returned works (OpenAlex returns https://doi.org/ prefix)
  found_dois <- vapply(works, function(w) {
    tolower(gsub("^https://doi.org/", "", w$doi %||% ""))
  }, character(1))

  input_lower <- tolower(input_dois)
  matched <- input_lower %in% found_dois

  not_found <- lapply(input_dois[!matched], function(d) {
    list(doi = d, reason = "not_found", details = "DOI not found in OpenAlex")
  })

  list(found = works, not_found = not_found)
}

#' Fetch a single batch of DOIs from OpenAlex with retry logic
#' @param dois Character vector of bare DOIs (max 50)
#' @param email User email for polite pool
#' @param api_key Optional API key
#' @param parse If TRUE, return parsed work objects; if FALSE, return raw
#' @return List with $found (works) and $not_found (error entries)
fetch_single_batch <- function(dois, email, api_key = NULL, parse = TRUE) {
  filter_str <- build_batch_filter(dois)

  req <- build_openalex_request("works", email, api_key) |>
    httr2::req_url_query(filter = filter_str, per_page = length(dois)) |>
    httr2::req_retry(
      max_tries = 3,
      is_transient = function(resp) httr2::resp_status(resp) == 429,
      backoff = function(tries) 2^(tries - 1)  # 1s, 2s, 4s
    )

  body <- perform_oa_request(req, con = NULL, operation = "batch_fetch")

  if (is.null(body$results)) {
    return(match_results_to_dois(list(), dois))
  }

  works <- if (parse) {
    lapply(body$results, parse_openalex_work)
  } else {
    body$results
  }

  match_results_to_dois(works, dois)
}

#' Batch fetch papers from OpenAlex by DOI
#'
#' Queries OpenAlex in batches of up to 50 DOIs using pipe-separated filter
#' syntax. Handles rate limiting with exponential backoff, categorizes errors,
#' and reports progress via optional callback.
#'
#' @param dois Character vector of bare DOIs (10.xxxx/yyyy format)
#' @param email User email for polite pool
#' @param api_key Optional API key
#' @param batch_size DOIs per batch (1-50, default 50)
#' @param delay Seconds between batches (default 0.1)
#' @param parse If TRUE, return normalized objects; if FALSE, return raw
#' @param progress_callback Optional function(batch_current, batch_total, found_so_far, not_found_so_far)
#' @param log_file Optional path for persistent log file
#' @return List with $papers (list of work objects) and $errors (list of error entries)
batch_fetch_papers <- function(dois, email, api_key = NULL,
                                batch_size = 50, delay = 0.1,
                                parse = TRUE, progress_callback = NULL,
                                log_file = NULL) {
  stopifnot(is.character(dois), length(dois) > 0)
  stopifnot(batch_size > 0, batch_size <= 50)

  # Initialize log file if requested
  if (!is.null(log_file)) {
    dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)
    cat(paste0("[", Sys.time(), "] batch_fetch_papers started: ", length(dois), " DOIs in ",
               ceiling(length(dois) / batch_size), " batches\n"),
        file = log_file, append = TRUE)
  }

  # Initialize collectors
  all_papers <- list()
  all_errors <- list()

  # Chunk DOIs
  chunks <- chunk_dois(dois, batch_size)

  for (i in seq_along(chunks)) {
    batch_dois <- chunks[[i]]

    batch_msg <- paste0("[batch ", i, "/", length(chunks), "] Fetching ", length(batch_dois), " DOIs...")
    message(batch_msg)
    if (!is.null(log_file)) {
      cat(paste0("[", Sys.time(), "] ", batch_msg, "\n"), file = log_file, append = TRUE)
    }

    batch_result <- tryCatch({
      fetch_single_batch(batch_dois, email, api_key, parse)
    }, error = function(e) {
      err_msg <- conditionMessage(e)

      # Determine error category
      reason <- if (grepl("429|rate.limit", err_msg, ignore.case = TRUE)) {
        "rate_limited"
      } else {
        "api_error"
      }

      error_entries <- lapply(batch_dois, function(d) {
        list(doi = d, reason = reason, details = err_msg)
      })

      list(found = list(), not_found = error_entries)
    })

    all_papers <- c(all_papers, batch_result$found)
    all_errors <- c(all_errors, batch_result$not_found)

    # Log result
    if (!is.null(log_file)) {
      cat(paste0("[", Sys.time(), "] Batch ", i, ": found=", length(batch_result$found),
                 " not_found=", length(batch_result$not_found), "\n"),
          file = log_file, append = TRUE)
    }

    # Progress callback
    if (!is.null(progress_callback)) {
      found_count <- length(all_papers)
      not_found_count <- sum(vapply(all_errors, function(e) e$reason == "not_found", logical(1)))
      progress_callback(
        batch_current = i,
        batch_total = length(chunks),
        found_so_far = found_count,
        not_found_so_far = not_found_count
      )
    }

    # Inter-batch delay
    if (i < length(chunks)) {
      Sys.sleep(delay)
    }
  }

  # Deduplicate by paper_id (only for parsed results)
  if (parse && length(all_papers) > 0) {
    seen_ids <- character()
    unique_papers <- list()
    for (paper in all_papers) {
      if (!is.null(paper$paper_id) && !(paper$paper_id %in% seen_ids)) {
        seen_ids <- c(seen_ids, paper$paper_id)
        unique_papers <- c(unique_papers, list(paper))
      }
    }
    all_papers <- unique_papers
  }

  # Final log
  if (!is.null(log_file)) {
    cat(paste0("[", Sys.time(), "] batch_fetch_papers complete: ",
               length(all_papers), " papers, ", length(all_errors), " errors\n"),
        file = log_file, append = TRUE)
  }

  list(papers = all_papers, errors = all_errors)
}
