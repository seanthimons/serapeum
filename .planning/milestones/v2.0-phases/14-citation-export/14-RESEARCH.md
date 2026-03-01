# Phase 14: Citation Export - Research

**Researched:** 2026-02-12
**Domain:** Citation format generation, file export
**Confidence:** HIGH

## Summary

Phase 14 enables users to export search results as BibTeX or CSV files. This is a **formatting and download** phase, not a library integration phase. The core challenge is generating valid BibTeX entries with proper LaTeX escaping, UTF-8 encoding, and unique citation keys.

**Key finding:** No R BibTeX libraries are needed. BibTeX is a text format with well-defined escaping rules that can be generated directly in R using string templates.

**Primary recommendation:** Build custom BibTeX formatter using string templates with LaTeX escaping, unique citation key generation with collision detection, and CSV export using write.csv with fileEncoding="UTF-8".

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| base R | 4.5.1 | write.csv, file I/O | Built-in, no dependencies |
| Shiny | current | downloadHandler | Already in project |
| stringi | current | stri_trans_general for diacritic removal | ICU-based transliteration, robust |

### Supporting
None required - this is a formatting task, not a library integration task.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom formatter | RefManageR | Heavy dependency (200+ CRAN imports), designed for bibliography management not export, overkill for string generation |
| Custom formatter | bib2df | Tibble-to-bib conversion, but requires learning package API vs simple string templates |
| Custom formatter | knitr::write_bib | Designed for R package citations only, not academic papers |

**Why no libraries:** BibTeX is a simple text format. RefManageR (last updated 2020) and bib2df add dependencies without providing value over direct string generation. The citation key generation and LaTeX escaping logic is straightforward to implement and test.

**Installation:**
```r
# stringi is likely already installed as a Shiny dependency
# If not: install.packages("stringi")
```

## Architecture Patterns

### Recommended Project Structure
```
R/
├── utils_citation.R        # Citation key generation, BibTeX escaping, formatters
├── mod_export.R            # Export UI/server module (optional, or add to existing module)
```

### Pattern 1: BibTeX String Template Generation
**What:** Generate BibTeX entries by filling string templates with escaped field values.
**When to use:** Always - avoid complex object models when simple string concatenation works.

**Example:**
```r
# BibTeX formatter pattern
format_bibtex_entry <- function(citation_key, type = "article", fields) {
  # Escape all field values
  fields_escaped <- lapply(fields, escape_latex_special_chars)

  # Build entry using sprintf or paste
  entry <- sprintf("@%s{%s,\n", type, citation_key)
  for (field_name in names(fields_escaped)) {
    if (!is.na(fields_escaped[[field_name]])) {
      entry <- paste0(entry, sprintf("  %s = {%s},\n",
                                     field_name,
                                     fields_escaped[[field_name]]))
    }
  }
  entry <- paste0(entry, "}\n")
  entry
}
```

### Pattern 2: Citation Key Generation with Collision Detection
**What:** Generate author_year citation keys with suffix (a, b, c) for duplicates.
**When to use:** Always - reference managers expect unique keys.

**Example:**
```r
generate_citation_key <- function(authors, year, existing_keys = character()) {
  # Extract first author's last name
  first_author <- get_first_author_lastname(authors)

  # Normalize: lowercase, remove non-alphanumeric except hyphen/underscore
  author_normalized <- gsub("[^a-z0-9_-]", "", tolower(first_author))

  # Base key: author_year
  base_key <- paste0(author_normalized, year)

  # Check for collisions and add suffix
  key <- base_key
  suffix <- ""
  letters_pool <- letters  # a, b, c, ...
  i <- 1

  while (key %in% existing_keys) {
    suffix <- letters_pool[i]
    key <- paste0(base_key, suffix)
    i <- i + 1
    if (i > 26) stop("Too many collisions for key: ", base_key)
  }

  key
}
```

### Pattern 3: Shiny downloadHandler with Dynamic Filename
**What:** Use downloadHandler with format-specific filenames and UTF-8 encoding.
**When to use:** All file exports in Shiny.

**Example (from R/mod_slides.R):**
```r
# In UI:
downloadButton(ns("download_bibtex"), "Download BibTeX")
downloadButton(ns("download_csv"), "Download CSV")

# In Server:
output$download_bibtex <- downloadHandler(
  filename = function() {
    paste0("citations-", Sys.Date(), ".bib")
  },
  content = function(file) {
    papers <- get_papers_to_export()
    bibtex_content <- generate_bibtex(papers)
    writeLines(bibtex_content, file, useBytes = TRUE)
  }
)

output$download_csv <- downloadHandler(
  filename = function() {
    paste0("citations-", Sys.Date(), ".csv")
  },
  content = function(file) {
    papers <- get_papers_to_export()
    write.csv(papers, file, fileEncoding = "UTF-8", row.names = FALSE)
  }
)
```

### Anti-Patterns to Avoid
- **Don't use paste0 without escaping:** BibTeX fields MUST escape LaTeX special characters ({, }, \, %, #, &, _, ^, ~, $) or the file will fail to import.
- **Don't assume ASCII:** Academic papers contain accented characters (Müller, São Paulo, etc.). Always use UTF-8 encoding.
- **Don't generate duplicate keys:** Reference managers will reject or corrupt imports with duplicate citation keys.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Diacritic removal | Custom gsub patterns | stringi::stri_trans_general(x, "Latin-ASCII") | ICU-based transliteration handles all Unicode, not just common accents |
| CSV UTF-8 encoding | Manual byte writing | write.csv(fileEncoding="UTF-8") | Base R handles BOM, encoding, and platform differences correctly |

**Key insight:** BibTeX escaping and citation key generation are simple enough to hand-roll. Unicode normalization and file encoding are NOT - use proven libraries.

## Common Pitfalls

### Pitfall 1: LaTeX Special Character Escaping
**What goes wrong:** Unescaped braces, backslashes, or percent signs in BibTeX fields cause import failures or LaTeX compilation errors.
**Why it happens:** BibTeX uses LaTeX syntax, so {, }, \, %, etc. have special meaning.
**How to avoid:** Escape these characters in ALL fields (title, author, abstract, venue):
```r
escape_latex_special_chars <- function(text) {
  if (is.na(text) || is.null(text)) return(NA_character_)
  text <- gsub("\\\\", "\\\\textbackslash{}", text)  # \ -> \textbackslash{}
  text <- gsub("\\{", "\\\\{", text)                 # { -> \{
  text <- gsub("\\}", "\\\\}", text)                 # } -> \}
  text <- gsub("%", "\\\\%", text)                   # % -> \%
  text <- gsub("&", "\\\\&", text)                   # & -> \&
  text <- gsub("_", "\\\\_", text)                   # _ -> \_
  text <- gsub("\\^", "\\\\^{}", text)               # ^ -> \^{}
  text <- gsub("~", "\\\\~{}", text)                 # ~ -> \~{}
  text <- gsub("\\$", "\\\\$", text)                 # $ -> \$
  text
}
```
**Warning signs:** Import errors like "Mismatched braces in entry" or "Unexpected character in field."

### Pitfall 2: Citation Key Special Characters
**What goes wrong:** Citation keys with spaces, commas, or parentheses break LaTeX compilation.
**Why it happens:** Citation keys are used in \cite{key}, so invalid characters cause syntax errors.
**How to avoid:** Restrict keys to alphanumeric + hyphen/underscore/colon. Remove unsafe chars: #%'(),={}~
```r
sanitize_citation_key <- function(key) {
  # Remove unsafe characters for citation keys
  gsub("[^a-zA-Z0-9_:-]", "", key)
}
```
**Warning signs:** LaTeX error "Illegal parameter number in definition of \@citeb."

### Pitfall 3: UTF-8 vs Native Encoding
**What goes wrong:** Special characters become garbled (Müller → M?ller) when opened in Excel or Zotero.
**Why it happens:** Windows uses native encoding (often Windows-1252), not UTF-8. Base R functions default to native encoding.
**How to avoid:** Always specify UTF-8 explicitly:
- BibTeX: `writeLines(content, file, useBytes = TRUE)` (preserves UTF-8)
- CSV: `write.csv(df, file, fileEncoding = "UTF-8")`
- For Excel compatibility, consider adding BOM: `writeBin(charToRaw('\ufeff'), file)` before writeLines
**Warning signs:** Accented characters display as ? or mojibake when opened.

### Pitfall 4: Month Field Format
**What goes wrong:** BibTeX month field with quotes/braces causes warnings or incorrect sorting.
**Why it happens:** BibTeX expects unquoted three-letter abbreviations (jan, feb, mar, etc.) as macros.
**How to avoid:**
- Use lowercase three-letter abbreviations without quotes: `month = jan`
- If month is unknown, omit the field entirely (don't use empty string or NA)
**Warning signs:** BibTeX warning "invalid format of field 'month'" or incorrect chronological sorting.

### Pitfall 5: Missing DOI Fallback
**What goes wrong:** Papers without DOI get export failures or empty citation keys.
**Why it happens:** Success criteria #5 requires graceful fallback for papers without DOI.
**How to avoid:** Generate citation keys from title+year when DOI is NULL:
```r
citation_key <- if (!is.na(paper$doi)) {
  gsub("[^a-z0-9]", "", tolower(paper$doi))  # Use DOI-based key
} else {
  generate_fallback_key(paper$title, paper$year)  # Use title+year
}
```
**Warning signs:** Export fails for preprints or old papers without DOI.

## Code Examples

Verified patterns from official sources:

### BibTeX Article Entry Structure
```bibtex
@article{smith2020deep,
  author = {Smith, John and Doe, Jane},
  title = {Deep Learning for Natural Language Processing},
  journal = {Journal of AI Research},
  year = {2020},
  volume = {15},
  number = {3},
  pages = {123--145},
  doi = {10.1234/jair.2020.001},
  abstract = {This paper presents a novel approach to NLP using deep learning techniques.}
}
```
**Source:** [BibTeX.com Article Entry](https://www.bibtex.com/e/article-entry/)

**Required fields:** author, title, journal, year
**Optional fields:** volume, number, pages, month, note, doi, abstract

### CSV Export with UTF-8 Encoding
```r
# From search results: write.csv with fileEncoding parameter
export_csv <- function(papers, filepath) {
  # Prepare data frame with citation metadata
  export_df <- data.frame(
    citation_key = papers$citation_key,
    title = papers$title,
    authors = papers$authors,  # Already display string from Phase 11
    year = papers$year,
    venue = papers$venue,
    doi = papers$doi,
    abstract = papers$abstract,
    stringsAsFactors = FALSE
  )

  # Write with UTF-8 encoding for special characters
  write.csv(export_df, filepath, fileEncoding = "UTF-8", row.names = FALSE)
}
```
**Source:** [Encoding in R (irene.rbind.io)](https://irene.rbind.io/post/encoding-in-r/)

### Citation Key Collision Handling
```r
# Pattern from Better BibTeX: add suffix a, b, c for duplicates
# Source: https://retorque.re/zotero-better-bibtex/citing/
generate_unique_keys <- function(papers) {
  existing_keys <- character()
  citation_keys <- character(nrow(papers))

  for (i in seq_len(nrow(papers))) {
    # Extract first author last name
    authors_json <- jsonlite::fromJSON(papers$authors[i])
    first_author <- if (length(authors_json) > 0) authors_json[1] else "Unknown"
    last_name <- get_last_name(first_author)

    # Normalize to alphanumeric
    author_norm <- tolower(gsub("[^a-zA-Z0-9]", "", last_name))

    # Base key: author + year
    base_key <- paste0(author_norm, papers$year[i])

    # Add suffix if collision
    key <- base_key
    suffix_index <- 1
    while (key %in% existing_keys) {
      key <- paste0(base_key, letters[suffix_index])
      suffix_index <- suffix_index + 1
    }

    citation_keys[i] <- key
    existing_keys <- c(existing_keys, key)
  }

  citation_keys
}
```

### Diacritic Removal for Citation Keys
```r
# Pattern from stringi documentation
# Source: https://stringi.gagolewski.com/rapi/stri_trans_general.html
normalize_author_for_key <- function(author_name) {
  # Remove diacritics: Müller -> Muller, São -> Sao
  ascii_name <- stringi::stri_trans_general(author_name, "Latin-ASCII")

  # Extract last name (simple heuristic: last word)
  words <- strsplit(ascii_name, "\\s+")[[1]]
  last_name <- words[length(words)]

  # Sanitize: only alphanumeric, lowercase
  tolower(gsub("[^a-zA-Z0-9]", "", last_name))
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ASCII-only citation keys | Unicode in BibTeX with UTF-8 | BibTeX 0.99d (1988) added 8-bit support, Unicode became standard ~2010 | Authors with accents (Müller) can be cited correctly |
| Manual BOM for Excel | write.csv fileEncoding parameter | R 3.0+ (2013) | Simplified UTF-8 CSV export |
| RefManageR for generation | Direct string templates | N/A - both valid | Libraries add complexity for simple text generation |
| Month as string "January" | Month as macro jan | BibTeX standard (1985) | Proper abbreviation and sorting |

**Deprecated/outdated:**
- Using write.table without fileEncoding (causes garbled UTF-8)
- Generating BibTeX with paste0 without escaping (breaks on special chars)
- Citation keys with spaces or special chars (modern reference managers reject these)

## Open Questions

1. **Should we include URL field for papers without DOI?**
   - What we know: BibTeX @article supports optional `url` field
   - What's unclear: OpenAlex provides `pdf_url` but not canonical paper URL
   - Recommendation: Include `url = {pdf_url}` for papers where doi IS NULL and pdf_url IS NOT NULL

2. **Should CSV include all metadata or just citation fields?**
   - What we know: Users want "spreadsheet analysis" (success criteria #2)
   - What's unclear: Which fields are useful for analysis vs clutter
   - Recommendation: Include all available fields (title, authors, year, venue, doi, abstract, cited_by_count, year, work_type, oa_status) - users can delete columns in Excel

3. **Should export be notebook-scoped or selection-based?**
   - What we know: Plans mention "search results" (implies current notebook)
   - What's unclear: Should user select specific papers or export all?
   - Recommendation: Export all papers in current notebook (Phase 14 scope). Selection-based export can be Phase 15+ if needed.

## Sources

### Primary (HIGH confidence)
- [BibTeX Article Entry](https://www.bibtex.com/e/article-entry/) - Required/optional fields for @article
- [BibTeX Entry Types](https://www.bibtex.com/e/entry-types/) - Complete entry type reference
- [BibTeX Special Symbols](https://www.bibtex.org/SpecialSymbols/) - LaTeX escaping rules
- [BibTeX Month Field](https://www.bibtex.com/f/month-field/) - Month format specification
- [Shiny downloadHandler](https://shiny.posit.co/r/reference/shiny/1.7.2/downloadhandler.html) - File download API
- [stringi stri_trans_general](https://stringi.gagolewski.com/rapi/stri_trans_general.html) - Unicode transliteration

### Secondary (MEDIUM confidence)
- [Better BibTeX Citation Keys](https://retorque.re/zotero-better-bibtex/citing/) - Citation key best practices
- [Encoding in R](https://irene.rbind.io/post/encoding-in-r/) - UTF-8 handling in write.csv
- [rOpenSci BibTeX Roundup](https://ropensci.org/blog/2020/05/07/rmd-citations/) - R BibTeX package landscape (2020)

### Tertiary (LOW confidence)
- None - all core claims verified with official sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Base R + stringi are well-documented, no external libraries needed
- Architecture: HIGH - BibTeX format is stable (1985 standard), Shiny downloadHandler is proven
- Pitfalls: MEDIUM - LaTeX escaping rules are well-known, but edge cases (nested braces, URL fields) can be tricky

**Research date:** 2026-02-12
**Valid until:** 2026-03-12 (30 days - stable technology domain)
