#' OpenAlex filter validation utilities

#' Valid OpenAlex work filter attribute names
#' @description Allowlist of filter attributes recognized by OpenAlex API
OPENALEX_FILTER_ALLOWLIST <- c(
  # Metrics
  "publication_year",
  "publication_date",
  "cited_by_count",
  "fwci",
  "authors_count",

  # Boolean
  "is_oa",
  "has_abstract",
  "has_fulltext",
  "is_retracted",

  # Categorical
  "type",
  "oa_status",
  "language",

  # Relationships
  "cites",
  "cited_by",
  "related_to",

  # Dates
  "from_publication_date",
  "to_publication_date",

  # Search
  "title.search",
  "abstract.search",
  "default.search",
  "title_and_abstract.search",
  "fulltext.search",

  # Entities
  "author.id",
  "author.orcid",
  "institutions.id",
  "institutions.country_code",
  "concepts.id",
  "primary_topic.id",
  "primary_topic.domain.id",
  "primary_topic.field.id",
  "primary_topic.subfield.id",
  "locations.source.id",
  "primary_location.source.id",
  "grants.funder"
)

#' Validate OpenAlex filter string
#' @param filter_string Comma-separated filter string (e.g., "publication_year:2024,has_abstract:true")
#' @return List with valid (TRUE/FALSE) and error (NULL or error message)
#' @examples
#' validate_openalex_filters("publication_year:2024,has_abstract:true")
#' validate_openalex_filters("fake_filter:bad")
validate_openalex_filters <- function(filter_string) {
  # Empty or NULL filters are valid
  if (is.null(filter_string) || nchar(trimws(filter_string)) == 0) {
    return(list(valid = TRUE, error = NULL))
  }

  # Split by comma
  filter_parts <- strsplit(filter_string, ",")[[1]]

  # Extract attribute name from each filter (everything before first colon)
  for (part in filter_parts) {
    part <- trimws(part)
    if (nchar(part) == 0) next

    # Extract attribute (before first colon)
    colon_pos <- regexpr(":", part, fixed = TRUE)
    if (colon_pos == -1) {
      return(list(
        valid = FALSE,
        error = sprintf("Invalid filter '%s': missing colon separator", part)
      ))
    }

    attribute <- substr(part, 1, colon_pos - 1)

    # Check against allowlist
    if (!attribute %in% OPENALEX_FILTER_ALLOWLIST) {
      return(list(
        valid = FALSE,
        error = sprintf(
          "Invalid filter '%s': attribute not recognized. Must be one of: %s",
          attribute,
          paste(head(OPENALEX_FILTER_ALLOWLIST, 10), collapse = ", ")
        )
      ))
    }
  }

  # All filters valid
  list(valid = TRUE, error = NULL)
}
