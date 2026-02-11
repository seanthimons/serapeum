library(httr2)
library(jsonlite)

OPENALEX_BASE_URL <- "https://api.openalex.org"

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

  if (!is.null(api_key) && nchar(api_key) > 0) {
    req <- req |> req_headers("Authorization" = paste("Bearer", api_key))
  }

  req |> req_timeout(30)
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
    fwci = fwci
  )
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
#' @param exclude_retracted Exclude retracted papers (boolean)
#' @param work_types Character vector of work types to include (e.g., c("article", "review"))
#' @return List of parsed works
search_papers <- function(query, email, api_key = NULL,
                          from_year = NULL, to_year = NULL, per_page = 25,
                          search_field = "default", is_oa = FALSE,
                          min_citations = NULL, exclude_retracted = TRUE,
                          work_types = NULL) {

  # Build filter components
  filters <- c("has_abstract:true")

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
    per_page = per_page
  )

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    stop("OpenAlex API error: ", e$message)
  })

  body <- resp_body_json(resp)

  if (is.null(body$results)) {
    return(list())
  }

  lapply(body$results, parse_openalex_work)
}

#' Build API query preview string (for UI display)
#' @param query Search query
#' @param from_year Start year
#' @param to_year End year
#' @param search_field Field to search
#' @param is_oa Open access filter
#' @param min_citations Minimum citation count (optional)
#' @param exclude_retracted Exclude retracted papers (boolean)
#' @param work_types Character vector of work types to include
#' @return List with search and filter strings
build_query_preview <- function(query, from_year = NULL, to_year = NULL,
                                 search_field = "default", is_oa = FALSE,
                                 min_citations = NULL, exclude_retracted = TRUE,
                                 work_types = NULL) {
  filters <- c("has_abstract:true")

  if (!is.null(from_year)) {
    filters <- c(filters, paste0("from_publication_date:", from_year, "-01-01"))
  }
  if (!is.null(to_year)) {
    filters <- c(filters, paste0("to_publication_date:", to_year, "-12-31"))
  }

  if (isTRUE(is_oa)) {
    filters <- c(filters, "is_oa:true")
  }

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

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(resp)) return(NULL)

  body <- resp_body_json(resp)
  parse_openalex_work(body)
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

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    message("OpenAlex API error in get_citing_papers: ", e$message)
    return(NULL)
  })

  if (is.null(resp)) return(list())

  body <- resp_body_json(resp)

  if (is.null(body$results)) {
    return(list())
  }

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

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    message("OpenAlex API error in get_cited_papers: ", e$message)
    return(NULL)
  })

  if (is.null(resp)) return(list())

  body <- resp_body_json(resp)

  if (is.null(body$results)) {
    return(list())
  }

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

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    message("OpenAlex API error in get_related_papers: ", e$message)
    return(NULL)
  })

  if (is.null(resp)) return(list())

  body <- resp_body_json(resp)

  if (is.null(body$results)) {
    return(list())
  }

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
    resp <- req_perform(req)
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
  # Validate API key is present
  if (is.null(api_key) || nchar(api_key) == 0) {
    stop("OpenAlex API key required. Please add your key in Settings.")
  }

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
    resp <- tryCatch({
      req_perform(req)
    }, error = function(e) {
      stop("OpenAlex API error while fetching topics: ", e$message)
    })

    body <- resp_body_json(resp)

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
