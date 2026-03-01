# Phase 11: DOI Storage & Migration Infrastructure - Research

**Researched:** 2026-02-12
**Domain:** Database schema migration, DOI storage and normalization
**Confidence:** HIGH

## Summary

Phase 11 adds DOI storage to the abstracts table to enable downstream export workflows (BibTeX, citation formats) and seeded discovery. The project already has a migration infrastructure (`R/db_migrations.R`), and OpenAlex API already extracts DOI from responses (`api_openalex.R:181-186`). This phase requires:

1. Creating migration `005_add_doi_column.sql` to add nullable DOI column
2. Updating `create_abstract()` to accept and store DOI parameter
3. Implementing DOI normalization to ensure consistency (strip URL prefix, lowercase)
4. Backfilling NULL DOI values for existing papers using OpenAlex batch API
5. Displaying DOI in abstract preview UI with graceful degradation for legacy papers

**Primary recommendation:** Use existing migration infrastructure (version 005), normalize DOIs on insert (strip https://doi.org/ prefix, lowercase), implement async backfill for existing papers, handle NULL DOIs gracefully in UI.

## Standard Stack

### Core (Already Installed)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| DBI | 1.2.3 | Database interface for R | Standard R database abstraction layer |
| duckdb | 1.3.2 | In-process database | Project's existing database backend |
| jsonlite | 2.0.0 | JSON parsing/generation | Already used for storing arrays as JSON strings |
| uuid | 1.2-1 | Generate unique IDs | Already used for record IDs |

### Supporting (No New Dependencies)
All requirements met by existing stack. No new packages needed for Phase 11.

**Installation:**
None required - all libraries already installed.

## Architecture Patterns

### Recommended Migration File Structure
```
migrations/
├── 001_bootstrap_existing_schema.sql
├── 002_create_topics_table.sql
├── 003_create_cost_log.sql
├── 004_create_blocked_journals.sql
└── 005_add_doi_column.sql            # NEW: Phase 11
```

### Pattern 1: Versioned SQL Migration
**What:** Sequential numbered migration files executed on startup
**When to use:** Adding columns, creating tables, schema changes
**Example:**
```sql
-- migrations/005_add_doi_column.sql
-- Migration 005: Add DOI Column to Abstracts Table
--
-- Adds nullable DOI column for citation export and seeded discovery.
-- Existing papers will have NULL DOI until backfilled.

ALTER TABLE abstracts ADD COLUMN doi VARCHAR;

-- Index for fast DOI lookups (export workflows, duplicate detection)
CREATE INDEX IF NOT EXISTS idx_abstracts_doi ON abstracts(doi);
```
**Source:** Existing migration pattern from `migrations/002_create_topics_table.sql`

### Pattern 2: DOI Normalization Function
**What:** Normalize DOI format on insert (strip URL prefix, lowercase)
**When to use:** Before storing DOI in database
**Example:**
```r
# Source: Verified pattern from Crossref/DOI best practices
normalize_doi <- function(doi) {
  if (is.null(doi) || is.na(doi) || doi == "") return(NA_character_)

  # Remove common URL prefixes
  doi <- gsub("^https?://doi\\.org/", "", doi, ignore.case = TRUE)
  doi <- gsub("^https?://dx\\.doi\\.org/", "", doi, ignore.case = TRUE)
  doi <- gsub("^doi:\\s*", "", doi, ignore.case = TRUE)
  doi <- trimws(doi)

  # Lowercase for consistency (DOI is case-insensitive but lowercase is standard)
  doi <- tolower(doi)

  # Validate format: must start with "10."
  if (!grepl("^10\\.", doi)) {
    warning("Invalid DOI format: ", doi)
    return(NA_character_)
  }

  doi
}
```
**Why:** Prevents duplicate papers with same DOI in different formats (https://doi.org/10.1234/abc vs 10.1234/abc). Ensures consistent exports.

### Pattern 3: Async Backfill for Existing Papers
**What:** Background job fetches DOIs for papers with NULL DOI
**When to use:** After migration adds DOI column to existing database
**Example:**
```r
# Backfill strategy (called after migration 005 applied)
backfill_dois <- function(con, batch_size = 50) {
  # Get papers with NULL DOI and valid OpenAlex paper_id
  papers <- dbGetQuery(con, "
    SELECT id, paper_id
    FROM abstracts
    WHERE doi IS NULL AND paper_id LIKE 'W%'
    LIMIT ?
  ", list(as.integer(batch_size)))

  if (nrow(papers) == 0) return(0)

  # Batch fetch from OpenAlex API using pipe-separated filter
  work_ids <- papers$paper_id
  # Use existing fetch_works_batch() or build_openalex_request()

  # Update database with fetched DOIs
  for (i in seq_len(nrow(papers))) {
    doi_normalized <- normalize_doi(fetched_dois[i])
    dbExecute(con, "UPDATE abstracts SET doi = ? WHERE id = ?",
              list(doi_normalized, papers$id[i]))
  }

  nrow(papers)  # Return count of backfilled papers
}
```
**Why:** Don't block app startup with API calls for 1000+ papers. Run incrementally in background.

### Pattern 4: Update create_abstract() Function Signature
**What:** Add `doi` parameter to `create_abstract()` in `R/db.R`
**When:** Storing new papers from OpenAlex
**Example:**
```r
# R/db.R (around line 536)
create_abstract <- function(con, notebook_id, paper_id, title, authors,
                            abstract, year, venue, pdf_url, keywords = NULL,
                            work_type = NULL, work_type_crossref = NULL,
                            oa_status = NULL, is_oa = FALSE,
                            cited_by_count = 0, referenced_works_count = 0,
                            fwci = NULL, doi = NULL) {  # NEW PARAMETER
  id <- uuid::UUIDgenerate()

  # ... existing code ...

  # Normalize DOI before storage
  doi_val <- if (is.null(doi) || is.na(doi)) {
    NA_character_
  } else {
    normalize_doi(doi)
  }

  dbExecute(con, "
    INSERT INTO abstracts (id, notebook_id, paper_id, title, authors, abstract,
                          keywords, year, venue, pdf_url, work_type, work_type_crossref,
                          oa_status, is_oa, cited_by_count, referenced_works_count,
                          fwci, doi)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ", list(id, notebook_id, paper_id, title, authors_json, abstract_val,
          keywords_json, year_val, venue_val, pdf_url_val, work_type_val,
          work_type_crossref_val, oa_status_val, is_oa_val, cited_by_count_val,
          referenced_works_count_val, fwci_val, doi_val))  # NEW PARAMETER

  id
}
```
**Source:** Existing pattern from `create_abstract()` in `R/db.R:536-581`

### Pattern 5: DOI Display in Abstract Preview
**What:** Show DOI as clickable link in abstract detail view with graceful fallback
**When:** User clicks paper in search results
**Example:**
```r
# In mod_search_notebook.R abstract detail rendering
output$abstract_detail <- renderUI({
  paper <- viewed_paper_data()
  if (is.null(paper)) return(NULL)

  # DOI display with graceful degradation
  doi_display <- if (!is.null(paper$doi) && !is.na(paper$doi)) {
    tags$p(
      tags$strong("DOI: "),
      tags$a(
        href = paste0("https://doi.org/", paper$doi),
        target = "_blank",
        paper$doi,
        class = "text-primary"
      )
    )
  } else {
    # Fallback: generate citation key from title+year
    citation_key <- generate_citation_key(paper$title, paper$year)
    tags$p(
      tags$strong("Citation Key: "),
      tags$code(citation_key),
      tags$small(
        class = "text-muted ms-2",
        "(DOI unavailable for legacy papers)"
      )
    )
  }

  card(
    card_header(paper$title),
    card_body(
      tags$p(tags$strong("Authors: "), paper$authors),
      tags$p(tags$strong("Year: "), paper$year),
      doi_display,  # NEW
      tags$p(tags$strong("Abstract: "), paper$abstract)
    )
  )
})
```

### Anti-Patterns to Avoid

- **NOT NULL constraint on new column:** Adding `ALTER TABLE abstracts ADD COLUMN doi VARCHAR NOT NULL` fails if table has existing rows. DuckDB doesn't support adding NOT NULL columns to populated tables ([DuckDB Issue #3248](https://github.com/duckdb/duckdb/issues/3248)).

- **Storing DOI as URL:** Don't store `https://doi.org/10.1234/abc`. Store bare DOI `10.1234/abc` and generate URL on display. BibTeX export expects bare DOI format.

- **Synchronous backfill in migration:** Don't fetch DOIs for 1000+ papers during migration (blocks startup). Mark as NULL, backfill asynchronously.

- **Case-sensitive DOI matching:** DOI is case-insensitive but should be stored lowercase for consistent duplicate detection.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Database migration versioning | Custom migration tracker | Existing `db_migrations.R` + numbered SQL files | Already implemented in Phase 00, tested, production-ready |
| DOI validation regex | Custom regex | Crossref recommended pattern `/^10.\d{4,9}/[-._;()/:A-Z0-9]+$/i` | Matches 74.4M out of 74.9M DOIs in Crossref ([Crossref Blog](https://www.crossref.org/blog/dois-and-matching-regular-expressions/)) |
| UUID generation | Custom ID generator | `uuid::UUIDgenerate()` | Already used in project for abstract IDs |
| JSON array storage | Custom serialization | `jsonlite::toJSON()` | Already used for keywords, authors arrays |

**Key insight:** Project already has migration infrastructure and storage patterns. Don't reinvent - extend existing patterns.

## Common Pitfalls

### Pitfall 1: Migration Breaking Existing Databases
**What goes wrong:** User with 1000+ existing papers upgrades. Migration adds `doi` column but all existing papers have NULL DOI. Export-to-seed workflow fails with "DOI required" error. User frustrated.

**Why it happens:** Migration only adds column, doesn't populate data. No backfill strategy. Export code assumes DOI is always present.

**How to avoid:**
1. Migration adds nullable column (no default, no NOT NULL)
2. New papers get DOI on insert (from OpenAlex response)
3. Existing papers remain NULL until backfilled
4. Export workflows handle NULL DOI gracefully (generate citation key from title+year)
5. Background job backfills DOIs incrementally (50 papers/batch)
6. UI shows backfill progress: "Fetching DOI for 450/1000 papers..."

**Warning signs:**
- Export buttons visible but fail for papers without DOI
- Users complain "feature doesn't work for my papers"
- Database query: `SELECT COUNT(*) FROM abstracts WHERE doi IS NULL` returns 99% of papers

### Pitfall 2: DOI Format Inconsistency
**What goes wrong:** Database has DOIs in mixed formats: `10.1234/abc`, `https://doi.org/10.1234/abc`, `DOI: 10.1234/ABC`. Duplicate detection fails. BibTeX export invalid. Citation managers reject imports.

**Why it happens:** OpenAlex returns DOI as full URL (`https://doi.org/10.1234/abc`). No normalization before storage. Different papers from different sources have different formats.

**How to avoid:**
1. Normalize DOI on insert: strip URL prefix, lowercase, trim whitespace
2. Validate format: must start with `10.`
3. Store only bare DOI: `10.1234/abc`
4. Generate URL on display: `https://doi.org/{doi}`
5. BibTeX export uses bare DOI in `doi` field

**Warning signs:**
- Database query: `SELECT DISTINCT doi FROM abstracts WHERE doi LIKE '%://%'` returns rows
- Same paper appears twice with different DOI formats
- BibTeX import fails with "invalid DOI format"

### Pitfall 3: DuckDB ALTER TABLE Constraints
**What goes wrong:** Migration tries `ALTER TABLE abstracts ADD COLUMN doi VARCHAR NOT NULL DEFAULT ''`. DuckDB error: "Cannot add NOT NULL column to table with existing rows."

**Why it happens:** DuckDB doesn't support adding NOT NULL columns to populated tables. Default constraints only apply to new rows, not existing rows.

**How to avoid:**
1. Add column as nullable: `ALTER TABLE abstracts ADD COLUMN doi VARCHAR`
2. Don't use NOT NULL constraint
3. Don't use DEFAULT constraint (won't backfill existing rows)
4. Handle NULL in application code (normalize_doi returns NA_character_)

**Warning signs:**
- Migration fails on existing database but succeeds on fresh database
- Error message: "Cannot add NOT NULL column"
- App won't start after upgrade

**Source:** [DuckDB ALTER TABLE Docs](https://duckdb.org/docs/stable/sql/statements/alter_table), [DuckDB Issue #3248](https://github.com/duckdb/duckdb/issues/3248)

### Pitfall 4: Encoding Issues in DOI Storage
**What goes wrong:** DOI with special characters (`10.1234/foo(bar)`) gets corrupted. Export fails. DOI links broken.

**Why it happens:** DOI contains URL-unsafe characters: `()`, `[]`, `;`, `:`. Database encoding issues. String escaping bugs.

**How to avoid:**
1. Store DOI as VARCHAR (supports all characters)
2. URL-encode when generating links: `URLencode(paste0("https://doi.org/", doi))`
3. Don't strip special characters from DOI (they're valid)
4. Test with edge cases: `10.1000/456(78)90`, `10.1234/foo;bar`

**Warning signs:**
- DOI links return 404
- Export validation fails
- Database corruption warnings

## Code Examples

Verified patterns from official sources and existing codebase.

### Migration File (005_add_doi_column.sql)
```sql
-- Migration 005: Add DOI Column to Abstracts Table
--
-- DOI (Digital Object Identifier) enables:
-- - BibTeX/RIS citation export
-- - Seeded discovery workflows (use paper as seed)
-- - CrossRef API lookups
-- - Duplicate detection
--
-- Existing papers will have NULL DOI until backfilled via OpenAlex API.

ALTER TABLE abstracts ADD COLUMN doi VARCHAR;

-- Index for fast DOI lookups (export workflows, duplicate detection)
CREATE INDEX IF NOT EXISTS idx_abstracts_doi ON abstracts(doi);
```
**Source:** Pattern from `migrations/002_create_topics_table.sql`, verified DuckDB ALTER TABLE syntax

### DOI Normalization Utility (R/utils_doi.R)
```r
# Source: Crossref DOI best practices + project normalization patterns

#' Normalize DOI to standard format
#'
#' Strips URL prefixes, converts to lowercase, validates format.
#' Returns NA_character_ for invalid DOIs.
#'
#' @param doi Raw DOI string (may include URL prefix)
#' @return Normalized DOI or NA_character_
#' @examples
#' normalize_doi("https://doi.org/10.1234/ABC") # "10.1234/abc"
#' normalize_doi("DOI: 10.5678/xyz") # "10.5678/xyz"
#' normalize_doi("invalid") # NA_character_
normalize_doi <- function(doi) {
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
    warning("Invalid DOI format: ", doi)
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
#'
#' @param title Paper title
#' @param year Publication year
#' @return Citation key (e.g., "deep_learning_2020")
generate_citation_key <- function(title, year) {
  # Take first 3 words of title
  words <- tolower(strsplit(title, "\\s+")[[1]])
  words <- words[!grepl("^(a|an|the)$", words)]  # Remove articles
  words <- head(words, 3)

  # Clean special characters
  words <- gsub("[^a-z0-9]", "", words)

  # Combine with year
  paste(c(words, year), collapse = "_")
}
```

### Updated create_abstract() Call Site
```r
# In app.R or api_openalex.R where abstracts are stored
# OpenAlex response → parse_openalex_work() → create_abstract()

parsed_work <- parse_openalex_work(openalex_response)

abstract_id <- create_abstract(
  con = con,
  notebook_id = notebook_id,
  paper_id = parsed_work$paper_id,
  title = parsed_work$title,
  authors = parsed_work$authors,
  abstract = parsed_work$abstract,
  year = parsed_work$year,
  venue = parsed_work$venue,
  pdf_url = parsed_work$pdf_url,
  keywords = parsed_work$keywords,
  work_type = parsed_work$work_type,
  work_type_crossref = parsed_work$work_type_crossref,
  oa_status = parsed_work$oa_status,
  is_oa = parsed_work$is_oa,
  cited_by_count = parsed_work$cited_by_count,
  referenced_works_count = parsed_work$referenced_works_count,
  fwci = parsed_work$fwci,
  doi = parsed_work$doi  # NEW: Already extracted at api_openalex.R:181-186
)
```
**Note:** OpenAlex already extracts DOI. No API changes needed. Only storage changes.

### Abstract Preview with DOI Display
```r
# In mod_search_notebook.R
output$abstract_detail <- renderUI({
  paper <- viewed_paper_data()
  if (is.null(paper)) return(NULL)

  # Build metadata list
  metadata_items <- list(
    tags$p(tags$strong("Authors: "), paste(paper$authors, collapse = "; ")),
    tags$p(tags$strong("Year: "), paper$year),
    tags$p(tags$strong("Venue: "), paper$venue)
  )

  # Add DOI if available, otherwise citation key
  if (!is.null(paper$doi) && !is.na(paper$doi) && paper$doi != "") {
    metadata_items <- c(metadata_items, list(
      tags$p(
        tags$strong("DOI: "),
        tags$a(
          href = paste0("https://doi.org/", paper$doi),
          target = "_blank",
          paper$doi,
          class = "text-primary"
        )
      )
    ))
  } else {
    # Fallback for legacy papers without DOI
    citation_key <- generate_citation_key(paper$title, paper$year)
    metadata_items <- c(metadata_items, list(
      tags$p(
        tags$strong("Citation Key: "),
        tags$code(citation_key),
        tags$small(
          class = "text-muted ms-2",
          "(DOI unavailable)"
        )
      )
    ))
  }

  card(
    card_header(paper$title),
    card_body(
      metadata_items,
      tags$hr(),
      tags$p(tags$strong("Abstract:")),
      tags$p(paper$abstract)
    )
  )
})
```

## State of the Art

| Approach | Status | When Changed | Impact |
|----------|--------|--------------|--------|
| DOI storage in database | **Adding in Phase 11** | N/A (new feature) | Enables BibTeX export, seeded discovery |
| Migration infrastructure | Already implemented | Phase 00 (2026-02-11) | Versioned migrations ready for DOI column |
| OpenAlex DOI extraction | Already implemented | Project start | `api_openalex.R:181-186` extracts DOI |
| Normalized string storage | Already used | Project start | Keywords, authors stored as JSON strings |

**Current state:**
- Migration files: 001-004 exist, 005 will be DOI column
- DOI extracted from API but NOT stored in database
- `create_abstract()` has 16 parameters, will need 17th for DOI
- No DOI display in UI yet

## Open Questions

1. **Backfill timing:** When should background DOI backfill run?
   - What we know: App startup triggers migrations automatically
   - What's unclear: Should backfill run on first startup after migration, or on-demand?
   - Recommendation: On-demand via Settings page "Backfill DOI" button. Avoids blocking startup for large databases.

2. **Backfill progress indicator:** How to show backfill progress to user?
   - What we know: Shiny supports `withProgress()` for long-running operations
   - What's unclear: Should backfill run in background thread or block UI?
   - Recommendation: Use `future` package for async backfill with reactive progress indicator. Don't block UI.

3. **DOI index performance:** Does DOI column need index?
   - What we know: Export workflows filter by `WHERE doi IS NOT NULL`
   - What's unclear: Query performance impact on 10k+ papers
   - Recommendation: Add index `CREATE INDEX idx_abstracts_doi ON abstracts(doi)` for fast lookups.

4. **Duplicate detection:** Should we prevent duplicate DOIs?
   - What we know: Same paper might be added to multiple notebooks
   - What's unclear: Is duplicate DOI across notebooks valid or error?
   - Recommendation: Allow duplicates across notebooks (same paper in different searches). Add UNIQUE constraint per-notebook if needed later.

## Sources

### Primary (HIGH confidence)
- DuckDB ALTER TABLE Documentation: https://duckdb.org/docs/stable/sql/statements/alter_table
- DuckDB NOT NULL Limitation (Issue #3248): https://github.com/duckdb/duckdb/issues/3248
- Crossref DOI Regex Pattern: https://www.crossref.org/blog/dois-and-matching-regular-expressions/
- Existing migration infrastructure: `R/db_migrations.R` (verified in codebase)
- Existing DOI extraction: `R/api_openalex.R:181-186` (verified in codebase)

### Secondary (MEDIUM confidence)
- Database Schema Design Simplified (ByteByteGo): https://blog.bytebytego.com/p/database-schema-design-simplified
- DuckDB Schema Migration Versioning: https://www.getorchestra.io/guides/duckdb-sqlconcepts-alter-table
- SQLite user_version PRAGMA (reference pattern): https://gluer.org/blog/sqlites-user_version-pragma-for-schema-versioning/
- doi-regex Library: https://www.npmjs.com/package/doi-regex

### Tertiary (LOW confidence)
- Schema Migration Wikipedia: https://en.wikipedia.org/wiki/Schema_migration
- Database Version Control Tools: https://dbmstools.com/categories/version-control-tools

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already installed and verified
- Architecture patterns: HIGH - Migration infrastructure exists, DOI normalization verified with Crossref
- Common pitfalls: HIGH - DuckDB constraints documented, migration patterns tested in Phase 00
- Code examples: HIGH - Based on existing codebase patterns and official documentation

**Research date:** 2026-02-12
**Valid until:** 2026-03-12 (30 days - stable domain, DuckDB and DOI specs unlikely to change)
