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

  list(
    paper_id = paper_id,
    title = work$title %||% "Untitled",
    authors = as.list(authors),
    abstract = reconstruct_abstract(work$abstract_inverted_index),
    year = work$publication_year,
    venue = venue,
    pdf_url = pdf_url
  )
}

#' Search for papers
#' @param query Search query
#' @param email User email
#' @param api_key Optional API key
#' @param from_year Filter by start year
#' @param to_year Filter by end year
#' @param per_page Results per page (max 200)
#' @return List of parsed works
search_papers <- function(query, email, api_key = NULL,
                          from_year = NULL, to_year = NULL, per_page = 25) {

  # Build filter string
  filters <- c("has_abstract:true")
  if (!is.null(from_year)) {
    filters <- c(filters, paste0("from_publication_date:", from_year, "-01-01"))
  }
  if (!is.null(to_year)) {
    filters <- c(filters, paste0("to_publication_date:", to_year, "-12-31"))
  }
  filter_str <- paste(filters, collapse = ",")

  req <- build_openalex_request("works", email, api_key) |>
    req_url_query(
      search = query,
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

#' Get a single paper by ID
#' @param paper_id OpenAlex paper ID (e.g., "W123456")
#' @param email User email
#' @param api_key Optional API key
#' @return Parsed work or NULL
get_paper <- function(paper_id, email, api_key = NULL) {
  # Ensure paper_id has the full URL format
  if (!grepl("^https://", paper_id)) {
    paper_id <- paste0("https://openalex.org/", paper_id)
  }

  req <- build_openalex_request(paste0("works/", URLencode(paper_id, reserved = TRUE)), email, api_key)

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(resp)) return(NULL)

  body <- resp_body_json(resp)
  parse_openalex_work(body)
}
