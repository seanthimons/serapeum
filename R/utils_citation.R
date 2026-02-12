library(stringi)

#' Escape LaTeX special characters for BibTeX field values
#'
#' Escapes the 9 LaTeX special characters: \, {, }, %, #, &, _, ^, ~, $
#' Order matters: backslash FIRST (to avoid double-escaping), then others.
#'
#' @param text Character string to escape
#' @return Escaped string, or NA_character_ if input is NA/NULL
#' @examples
#' escape_latex("10% of {test} & more_$") # "10\\% of \\{test\\} \\& more\\_\\$"
escape_latex <- function(text) {
  if (is.null(text) || is.na(text)) return(NA_character_)

  # CRITICAL: Backslash FIRST to avoid double-escaping
  # Use a placeholder to avoid the braces in \textbackslash{} being escaped
  # With fixed=TRUE, pattern "\\" in source = one backslash to match
  text <- gsub("\\", "<<BACKSLASH>>", text, fixed = TRUE)

  # Then escape braces (need to escape for regex pattern, and escape the \ in replacement)
  text <- gsub("\\{", "\\\\{", text)
  text <- gsub("\\}", "\\\\}", text)

  # Replace placeholder with actual LaTeX command
  # With fixed=TRUE, replacement "\\" in source = one backslash in output
  text <- gsub("<<BACKSLASH>>", "\\textbackslash{}", text, fixed = TRUE)

  # Then other special chars (use fixed=TRUE where possible to avoid regex issues)
  text <- gsub("%", "\\%", text, fixed = TRUE)
  text <- gsub("#", "\\#", text, fixed = TRUE)
  text <- gsub("&", "\\&", text, fixed = TRUE)
  text <- gsub("_", "\\_", text, fixed = TRUE)
  text <- gsub("^", "\\^{}", text, fixed = TRUE)
  text <- gsub("~", "\\~{}", text, fixed = TRUE)
  text <- gsub("$", "\\$", text, fixed = TRUE)

  text
}

#' Extract first author's last name from authors JSON
#'
#' Parses JSON array of display names, takes first author, extracts last word
#' as last name, removes diacritics using stringi, sanitizes for citation keys.
#'
#' @param authors_json JSON string of author display names (e.g. '["John Smith"]')
#' @return Lowercase alphanumeric last name, or "unknown" if parsing fails
#' @examples
#' extract_first_author_lastname('["Hans Mueller"]') # "mueller"
#' extract_first_author_lastname('["Madonna"]') # "madonna"
extract_first_author_lastname <- function(authors_json) {
  if (is.null(authors_json) || is.na(authors_json) || authors_json == "" || authors_json == "[]") {
    return("unknown")
  }

  tryCatch({
    # Parse JSON array
    authors <- jsonlite::fromJSON(authors_json)

    if (length(authors) == 0 || is.na(authors[1]) || authors[1] == "") {
      return("unknown")
    }

    # Get first author display name
    first_author <- authors[1]

    # Remove diacritics (Müller -> Muller)
    ascii_name <- stringi::stri_trans_general(first_author, "Latin-ASCII")

    # Extract last word as last name
    words <- strsplit(ascii_name, "\\s+")[[1]]
    last_name <- words[length(words)]

    # Sanitize: lowercase, alphanumeric only
    last_name <- tolower(gsub("[^a-zA-Z0-9]", "", last_name))

    if (nchar(last_name) == 0) {
      return("unknown")
    }

    last_name

  }, error = function(e) {
    return("unknown")
  })
}

#' Generate unique BibTeX citation key
#'
#' Creates key in format "lastname_year" (lowercase, alphanumeric only).
#' Checks for collisions against existing_keys and appends suffix (a, b, c...) if needed.
#' Falls back to title-based key for papers without authors.
#'
#' @param authors_json JSON string of author display names
#' @param year Publication year
#' @param existing_keys Vector of already-used citation keys
#' @return Unique citation key (e.g. "smith2023" or "smith2023a")
#' @examples
#' generate_bibtex_key('["John Smith"]', 2023, character()) # "smith2023"
#' generate_bibtex_key('["John Smith"]', 2023, "smith2023") # "smith2023a"
generate_bibtex_key <- function(authors_json, year, existing_keys = character()) {
  # Extract last name
  last_name <- extract_first_author_lastname(authors_json)

  # Base key: lastname + year
  base_key <- paste0(last_name, year)

  # Check for collisions and add suffix
  key <- base_key
  suffix_index <- 1

  while (key %in% existing_keys) {
    if (suffix_index > 26) {
      stop("Too many collisions for key: ", base_key)
    }
    key <- paste0(base_key, letters[suffix_index])
    suffix_index <- suffix_index + 1
  }

  key
}

#' Format a single BibTeX entry
#'
#' Creates a @article{} entry with proper LaTeX escaping and field formatting.
#' Handles optional fields gracefully (omits if NA/empty).
#'
#' @param paper_row Single row from list_abstracts() result (data.frame)
#' @param citation_key Unique citation key for this paper
#' @return BibTeX entry as character string
#' @examples
#' paper <- data.frame(
#'   title = "Test Paper",
#'   authors = '["John Smith"]',
#'   year = 2023,
#'   venue = "J Test",
#'   doi = "10.1234/test",
#'   abstract = "An abstract.",
#'   pdf_url = NA,
#'   work_type = "article",
#'   stringsAsFactors = FALSE
#' )
#' format_bibtex_entry(paper, "smith2023")
format_bibtex_entry <- function(paper_row, citation_key) {
  # Start entry
  entry <- sprintf("@article{%s,\n", citation_key)

  # Author field: parse JSON, join with " and ", escape
  if (!is.na(paper_row$authors) && paper_row$authors != "" && paper_row$authors != "[]") {
    tryCatch({
      authors_vec <- jsonlite::fromJSON(paper_row$authors)
      if (length(authors_vec) > 0) {
        authors_str <- paste(authors_vec, collapse = " and ")
        authors_escaped <- escape_latex(authors_str)
        entry <- paste0(entry, sprintf("  author = {%s},\n", authors_escaped))
      }
    }, error = function(e) {
      # Skip author field if parsing fails
    })
  }

  # Title: escaped, wrapped in double braces to preserve capitalization
  if (!is.na(paper_row$title) && paper_row$title != "") {
    title_escaped <- escape_latex(paper_row$title)
    entry <- paste0(entry, sprintf("  title = {{%s}},\n", title_escaped))
  }

  # Journal (venue)
  if (!is.na(paper_row$venue) && paper_row$venue != "") {
    venue_escaped <- escape_latex(paper_row$venue)
    entry <- paste0(entry, sprintf("  journal = {%s},\n", venue_escaped))
  }

  # Year (required)
  if (!is.na(paper_row$year)) {
    entry <- paste0(entry, sprintf("  year = {%s},\n", paper_row$year))
  }

  # DOI: bare format (already stored as bare "10.xxxx/yyyy" from Phase 11)
  if (!is.na(paper_row$doi) && paper_row$doi != "") {
    entry <- paste0(entry, sprintf("  doi = {%s},\n", paper_row$doi))
  }

  # URL: only if doi IS NULL and pdf_url IS NOT NULL (fallback for papers without DOI)
  if ((is.na(paper_row$doi) || paper_row$doi == "") &&
      !is.na(paper_row$pdf_url) && paper_row$pdf_url != "") {
    entry <- paste0(entry, sprintf("  url = {%s},\n", paper_row$pdf_url))
  }

  # Abstract
  if (!is.na(paper_row$abstract) && paper_row$abstract != "") {
    abstract_escaped <- escape_latex(paper_row$abstract)
    entry <- paste0(entry, sprintf("  abstract = {%s},\n", abstract_escaped))
  }

  # Close entry
  entry <- paste0(entry, "}\n")

  entry
}

#' Generate BibTeX for multiple papers
#'
#' Processes all papers, generates unique citation keys, formats as BibTeX entries.
#' Papers without DOI fall back to title-based keys from utils_doi.R.
#'
#' @param papers_df Data frame from list_abstracts()
#' @return Single string with all BibTeX entries separated by blank lines
#' @examples
#' papers <- data.frame(
#'   title = c("Paper 1", "Paper 2"),
#'   authors = c('["John Smith"]', '["Jane Doe"]'),
#'   year = c(2023, 2023),
#'   venue = c("J Test", "J Test"),
#'   doi = c("10.1234/test1", NA),
#'   abstract = c("Abstract 1", "Abstract 2"),
#'   pdf_url = c(NA, "http://example.com/paper2.pdf"),
#'   work_type = c("article", "article"),
#'   stringsAsFactors = FALSE
#' )
#' cat(generate_bibtex_batch(papers))
generate_bibtex_batch <- function(papers_df) {
  if (nrow(papers_df) == 0) {
    return("")
  }

  existing_keys <- character()
  entries <- character(nrow(papers_df))

  for (i in seq_len(nrow(papers_df))) {
    paper <- papers_df[i, ]

    # Generate citation key
    # If DOI exists: use author+year approach
    # If no DOI: fall back to title-based key (calls generate_citation_key from utils_doi.R)
    if (!is.na(paper$doi) && paper$doi != "") {
      citation_key <- generate_bibtex_key(paper$authors, paper$year, existing_keys)
    } else {
      # Fallback for papers without DOI
      citation_key <- generate_citation_key(paper$title, paper$year)

      # Check for collision and add suffix
      base_key <- citation_key
      suffix_index <- 1
      while (citation_key %in% existing_keys) {
        if (suffix_index > 26) {
          stop("Too many collisions for key: ", base_key)
        }
        citation_key <- paste0(base_key, letters[suffix_index])
        suffix_index <- suffix_index + 1
      }
    }

    existing_keys <- c(existing_keys, citation_key)

    # Format entry
    entries[i] <- format_bibtex_entry(paper, citation_key)
  }

  # Join with blank lines
  paste(entries, collapse = "\n")
}

#' Format papers for CSV export
#'
#' Prepares data frame for CSV export with clean column names and parsed authors.
#' Includes all available metadata for spreadsheet analysis.
#'
#' @param papers_df Data frame from list_abstracts()
#' @return Data frame with citation_key, title, authors (parsed), year, venue, doi, abstract, work_type, oa_status, cited_by_count, fwci, referenced_works_count, pdf_url
#' @examples
#' papers <- data.frame(
#'   title = "Test Paper",
#'   authors = '["John Smith", "Jane Doe"]',
#'   year = 2023,
#'   venue = "J Test",
#'   doi = "10.1234/test",
#'   abstract = "An abstract.",
#'   work_type = "article",
#'   oa_status = "gold",
#'   cited_by_count = 5,
#'   fwci = 1.2,
#'   referenced_works_count = 10,
#'   pdf_url = "http://example.com/paper.pdf",
#'   stringsAsFactors = FALSE
#' )
#' format_csv_export(papers)
format_csv_export <- function(papers_df) {
  if (nrow(papers_df) == 0) {
    return(data.frame(
      citation_key = character(),
      title = character(),
      authors = character(),
      year = integer(),
      venue = character(),
      doi = character(),
      abstract = character(),
      work_type = character(),
      oa_status = character(),
      cited_by_count = integer(),
      fwci = numeric(),
      referenced_works_count = integer(),
      pdf_url = character(),
      stringsAsFactors = FALSE
    ))
  }

  # Generate citation keys (reuse logic from generate_bibtex_batch)
  existing_keys <- character()
  citation_keys <- character(nrow(papers_df))

  for (i in seq_len(nrow(papers_df))) {
    paper <- papers_df[i, ]

    if (!is.na(paper$doi) && paper$doi != "") {
      citation_key <- generate_bibtex_key(paper$authors, paper$year, existing_keys)
    } else {
      citation_key <- generate_citation_key(paper$title, paper$year)

      # Check for collision
      base_key <- citation_key
      suffix_index <- 1
      while (citation_key %in% existing_keys) {
        if (suffix_index > 26) {
          stop("Too many collisions for key: ", base_key)
        }
        citation_key <- paste0(base_key, letters[suffix_index])
        suffix_index <- suffix_index + 1
      }
    }

    existing_keys <- c(existing_keys, citation_key)
    citation_keys[i] <- citation_key
  }

  # Parse authors JSON to semicolon-separated string
  authors_display <- character(nrow(papers_df))
  for (i in seq_len(nrow(papers_df))) {
    if (!is.na(papers_df$authors[i]) && papers_df$authors[i] != "" && papers_df$authors[i] != "[]") {
      tryCatch({
        authors_vec <- jsonlite::fromJSON(papers_df$authors[i])
        if (length(authors_vec) > 0) {
          authors_display[i] <- paste(authors_vec, collapse = "; ")
        } else {
          authors_display[i] <- ""
        }
      }, error = function(e) {
        authors_display[i] <- ""
      })
    } else {
      authors_display[i] <- ""
    }
  }

  # Build export data frame
  data.frame(
    citation_key = citation_keys,
    title = papers_df$title,
    authors = authors_display,
    year = papers_df$year,
    venue = ifelse(is.na(papers_df$venue), "", papers_df$venue),
    doi = ifelse(is.na(papers_df$doi), "", papers_df$doi),
    abstract = ifelse(is.na(papers_df$abstract), "", papers_df$abstract),
    work_type = ifelse(is.na(papers_df$work_type), "", papers_df$work_type),
    oa_status = ifelse(is.na(papers_df$oa_status), "", papers_df$oa_status),
    cited_by_count = ifelse(is.na(papers_df$cited_by_count), 0, papers_df$cited_by_count),
    fwci = ifelse(is.na(papers_df$fwci), NA_real_, papers_df$fwci),
    referenced_works_count = ifelse(is.na(papers_df$referenced_works_count), 0, papers_df$referenced_works_count),
    pdf_url = ifelse(is.na(papers_df$pdf_url), "", papers_df$pdf_url),
    stringsAsFactors = FALSE
  )
}
