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

  # Decode URL encoding first (e.g., %2F -> /)
  doi <- utils::URLdecode(doi)

  # Strip query parameters (e.g., ?ref=pdf, ?locatt=label:secondary)
  doi <- sub("\\?.*$", "", doi)

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

#' Split DOI input string on newlines and commas
#'
#' Splits a single string containing multiple DOIs separated by newlines
#' or commas into a character vector. Trims whitespace from each entry.
#'
#' @param input Single string with DOIs separated by newlines or commas
#' @return Character vector of trimmed DOI strings
#' @examples
#' split_doi_input("10.1234/abc\n10.5678/xyz")
#' split_doi_input("10.1234/abc, 10.5678/xyz")
split_doi_input <- function(input) {
  parts <- strsplit(input, "[\n,]+", perl = TRUE)[[1]]
  trimws(parts)
}

#' Categorize why a DOI string is invalid
#'
#' Examines a string that failed DOI normalization and returns a specific
#' error reason for user feedback in bulk import workflows.
#'
#' @param doi_string The original input string that failed normalization
#' @return One of: "missing_prefix", "invalid_registrant", "empty_suffix",
#'   "unrecognized_format"
#' @examples
#' categorize_doi_error("not-a-doi")    # "missing_prefix"
#' categorize_doi_error("10.12/abc")    # "invalid_registrant"
#' categorize_doi_error("10.1234/")     # "empty_suffix"
categorize_doi_error <- function(doi_string) {
  # Check for DOI prefix (must start with 10.)
  if (!grepl("^10\\.", doi_string, perl = TRUE)) {
    return("missing_prefix")
  }

  # Check for valid registrant (4-9 digits after 10.)
  if (!grepl("^10\\.\\d{4,9}/", doi_string, perl = TRUE)) {
    return("invalid_registrant")
  }

  # Check for non-empty suffix after registrant/
  if (grepl("^10\\.\\d{4,9}/$", doi_string, perl = TRUE)) {
    return("empty_suffix")
  }

  # Fallback: unrecognized format
  "unrecognized_format"
}

#' Parse a list of DOIs from mixed-format input
#'
#' Accepts a single string (newline/comma-separated) or character vector of DOIs.
#' Normalizes each to bare lowercase format, validates structure, categorizes
#' errors for invalid entries, and deduplicates valid DOIs.
#'
#' @param input Single string with DOIs (separated by newlines or commas) or
#'   a character vector of DOI strings. Supports bare DOIs (10.xxxx/yyyy),
#'   DOI URLs (https://doi.org/..., https://dx.doi.org/...), and doi: prefix.
#' @return A list with three components:
#'   \describe{
#'     \item{valid}{Character vector of unique normalized bare DOIs}
#'     \item{invalid}{Data frame with columns `original` and `reason`
#'       (one of: missing_prefix, invalid_registrant, empty_suffix, unrecognized_format)}
#'     \item{duplicates}{Data frame with columns `doi` and `count` for DOIs
#'       appearing 2+ times in input}
#'   }
#' @examples
#' parse_doi_list("10.1234/abc\nhttps://doi.org/10.5678/XYZ")
#' parse_doi_list(c("10.1234/abc", "invalid-string", "10.1234/abc"))
parse_doi_list <- function(input) {
  # Empty structure for early returns
  empty_result <- list(
    valid = character(0),
    invalid = data.frame(original = character(0), reason = character(0),
                         stringsAsFactors = FALSE),
    duplicates = data.frame(doi = character(0), count = integer(0),
                            stringsAsFactors = FALSE)
  )

  # Handle NULL/NA/empty

  if (is.null(input) || length(input) == 0) return(empty_result)
  if (length(input) == 1 && (is.na(input) || input == "")) return(empty_result)

  # Auto-detect: single string with delimiters vs character vector
  if (length(input) == 1) {
    if (grepl("[\n,]", input)) {
      input <- split_doi_input(input)
    }
    # Single DOI without delimiters: wrap in vector (already is one)
  }

  # Pre-process: trim whitespace, strip trailing punctuation, drop empties
  input <- trimws(input)
  input <- gsub("[.,;]$", "", input)
  input <- input[nchar(input) > 0]

  # If nothing left after cleaning

  if (length(input) == 0) return(empty_result)

  # Track original input for error reporting
  original_input <- input

  # Normalize each DOI (reuses existing normalize_doi_bare)
  normalized <- sapply(input, normalize_doi_bare, USE.NAMES = FALSE)

  # Separate valid from invalid
  # First pass: NA from normalize_doi_bare (missing 10. prefix)
  # Second pass: is_valid_doi structural check (registrant, suffix)
  valid_idx <- !is.na(normalized)
  # For normalized DOIs, also check structural validity
  structurally_valid <- rep(FALSE, length(normalized))
  structurally_valid[valid_idx] <- vapply(normalized[valid_idx], is_valid_doi, logical(1), USE.NAMES = FALSE)

  valid_dois <- normalized[structurally_valid]
  # Invalid = failed normalization OR failed structural validation
  invalid_input <- original_input[!structurally_valid]
  # For categorization, use the normalized form if available, otherwise the original
  invalid_for_categorize <- ifelse(!is.na(normalized[!structurally_valid]),
                                    normalized[!structurally_valid],
                                    original_input[!structurally_valid])

  # Categorize errors for invalid entries
  if (length(invalid_input) > 0) {
    invalid_reasons <- sapply(invalid_for_categorize, categorize_doi_error, USE.NAMES = FALSE)
    invalid_df <- data.frame(
      original = invalid_input,
      reason = invalid_reasons,
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  } else {
    invalid_df <- data.frame(
      original = character(0),
      reason = character(0),
      stringsAsFactors = FALSE
    )
  }

  # Detect duplicates in valid set
  if (length(valid_dois) > 0) {
    dup_table <- table(valid_dois)
    duplicates <- dup_table[dup_table > 1]
    if (length(duplicates) > 0) {
      dup_df <- data.frame(
        doi = names(duplicates),
        count = as.integer(duplicates),
        stringsAsFactors = FALSE,
        row.names = NULL
      )
    } else {
      dup_df <- data.frame(
        doi = character(0),
        count = integer(0),
        stringsAsFactors = FALSE
      )
    }
  } else {
    dup_df <- data.frame(
      doi = character(0),
      count = integer(0),
      stringsAsFactors = FALSE
    )
  }

  # Return structured list
  list(
    valid = unique(valid_dois),
    invalid = invalid_df,
    duplicates = dup_df
  )
}
