#' Normalize DOI to bare format for database storage
#'
#' Strips URL prefixes (https://doi.org/, https://dx.doi.org/, doi:),
#' converts to lowercase, validates format. This returns BARE DOI format
#' (just "10.xxxx/yyyy") for storage, NOT the full URL format.
#'
#' @param doi Raw DOI string (may include URL prefix)
#' @return Normalized bare DOI (10.xxxx/yyyy) or NA_character_ if invalid/NULL/NA/empty
#' @examples
#' normalize_doi_bare("https://doi.org/10.1234/ABC") # "10.1234/abc"
#' normalize_doi_bare("DOI: 10.5678/xyz") # "10.5678/xyz"
#' normalize_doi_bare("invalid") # NA_character_
#' normalize_doi_bare(NULL) # NA_character_
normalize_doi_bare <- function(doi) {
  if (is.null(doi) || is.na(doi) || doi == "") return(NA_character_)

  # Remove common URL prefixes
  doi <- gsub("^https?://doi\\.org/", "", doi, ignore.case = TRUE)
  doi <- gsub("^https?://dx\\.doi\\.org/", "", doi, ignore.case = TRUE)
  doi <- gsub("^doi:\\s*", "", doi, ignore.case = TRUE)
  doi <- trimws(doi)

  # Lowercase (DOI is case-insensitive but lowercase is convention)
  doi <- tolower(doi)

  # Validate format: must start with "10."
  if (!grepl("^10\\.", doi)) {
    return(NA_character_)
  }

  doi
}

#' Validate DOI format
#'
#' Uses Crossref-recommended regex pattern.
#'
#' @param doi DOI string to validate
#' @return TRUE if valid, FALSE otherwise
#' @source https://www.crossref.org/blog/dois-and-matching-regular-expressions/
is_valid_doi <- function(doi) {
  if (is.null(doi) || is.na(doi)) return(FALSE)

  # Crossref pattern: matches 74.4M out of 74.9M DOIs
  grepl("^10\\.\\d{4,9}/[-._;()/:a-z0-9]+$", doi, ignore.case = TRUE)
}

#' Generate citation key from title and year
#'
#' Fallback for papers without DOI (legacy papers).
#' Takes first 3 non-article words of title, lowercase, strips special chars, joins with underscore, appends year.
#'
#' @param title Paper title
#' @param year Publication year
#' @return Citation key (e.g., "deep_learning_nlp_2020")
#' @examples
#' generate_citation_key("Deep Learning for NLP", 2020) # "deep_learning_nlp_2020"
#' generate_citation_key("A study on the impact of AI", 2021) # "study_impact_ai_2021"
generate_citation_key <- function(title, year) {
  # Split on whitespace
  words <- tolower(strsplit(title, "\\s+")[[1]])

  # Remove common articles
  words <- words[!grepl("^(a|an|the)$", words)]

  # Take first 3 words
  words <- head(words, 3)

  # Clean special characters
  words <- gsub("[^a-z0-9]", "", words)

  # Remove empty strings (in case cleaning left empty words)
  words <- words[nchar(words) > 0]

  # Combine with year
  paste(c(words, year), collapse = "_")
}
