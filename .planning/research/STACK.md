# Stack Research

**Domain:** Citation audit, bulk DOI/BibTeX import, and slide generation prompt healing for R/Shiny research assistant
**Researched:** 2026-02-25
**Confidence:** HIGH

## Recommended Stack Additions

### For .bib File Parsing

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| bib2df | 1.1.2.0 | Parse BibTeX files to data frames | Official rOpenSci package, parses directly to tibbles for easy OpenAlex DOI extraction. Clean API: `bib2df(file)` returns one row per entry with standardized field names. Handles multiple BibTeX styles and missing fields gracefully. |

### For Bulk DOI Input

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| readr | 2.2.0 | Parse CSV files with DOI lists | Already in tidyverse, fast CSV parsing (10-100x base R). Use `read_csv()` for user-uploaded CSV files, or `read_lines()` for paste-based text input. Built-in column type detection and error handling. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| httr2 | (existing) | Batch OpenAlex API calls | Already in use. OpenAlex API supports up to 100 DOIs per request using pipe separator: `filter=doi:10.xxx/yyy\|10.zzz/aaa`. Requires `per-page=100` parameter to retrieve all results in single query. |
| DuckDB | (existing) | Citation frequency aggregation | For citation audit: SQL query to aggregate `referenced_works` array column and count frequency across all papers in search notebook. No new dependency needed. |

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| RefManageR | Heavyweight bibliography manager (1.4.3) — overkill for simple .bib parsing, adds complex bibliography management features not needed | bib2df — lighter, focused on parsing to data frames |
| bibtex | Lower-level parser (0.5.1) — returns S3 objects requiring manual conversion to data frames | bib2df — direct tibble output |
| rbibutils | More complex conversion library (latest Jan 2026) — handles multiple bibliography formats but adds unnecessary complexity for BibTeX-only use case | bib2df — BibTeX-focused, simpler API |
| Base R `read.csv()` | 10-100x slower than readr on large files, less robust column type detection | readr::read_csv() — already in project dependencies via tidyverse |

## Integration Points with Existing Stack

### Citation Audit (referenced_works frequency analysis)

**Existing capabilities:**
- OpenAlex API already returns `referenced_works` array in `parse_openalex_work()` (line 252 of api_openalex.R)
- DuckDB can aggregate array columns with `UNNEST()` and `GROUP BY`

**New code needed:**
- SQL query to aggregate frequency across papers in search notebook
- UI component to display missing high-frequency papers

**No new dependencies required.**

### Bulk DOI Upload

**Existing capabilities:**
- `normalize_doi()` function handles various DOI formats (line 418 of api_openalex.R)
- `get_paper()` fetches single paper by DOI (line 467)
- OpenAlex API supports batch lookup (verified 100 DOI limit)

**New code needed:**
- UI for paste/CSV upload (use `shiny::textAreaInput()` or `shiny::fileInput()`)
- DOI extraction using regex: `/^10\.\d{4,}/[-._;()/:A-Z0-9]+$/i` (Crossref standard)
- Batch OpenAlex requests with pipe-separated DOIs: `filter=doi:https://doi.org/10.xxx/yyy|https://doi.org/10.zzz/aaa`
- Progress indicator for 100+ DOI uploads (split into batches)

**Dependencies:**
- readr — for CSV parsing (already in tidyverse)
- httr2 — for batch API calls (already in use)

### Bulk .bib Upload

**Existing capabilities:**
- DOI normalization (line 418)
- Batch OpenAlex lookup pattern (same as bulk DOI)

**New code needed:**
- Parse .bib file with `bib2df::bib2df(file_path)`
- Extract DOI field from each entry
- Feed DOIs into batch OpenAlex lookup
- Handle entries without DOIs (warn user, skip, or log)

**Dependencies:**
- bib2df 1.1.2.0 (new)

### Slide Generation Prompt Healing

**Issue:** LLMs generate invalid YAML frontmatter for Quarto slides (issue #124)

**Existing capabilities:**
- `build_slides_prompt()` creates system/user prompts (line 38 of slides.R)
- `inject_theme_to_qmd()` modifies YAML post-generation (line 101)
- `inject_citation_css()` modifies YAML post-generation (line 136)

**Solution: Provide YAML template in prompt instead of relying on LLM**

**New code needed:**
- Include literal YAML template in system prompt:
  ```yaml
  ---
  title: "[Title Here]"
  format:
    revealjs:
      theme: [theme]
  ---
  ```
- Instruct LLM to fill `[Title Here]` only, not generate YAML structure
- Add regeneration-specific instructions: "If regenerating: keep YAML unchanged, modify only [specified section]"

**No new dependencies required.**

## Installation

```r
# New package for .bib parsing
install.packages("bib2df")

# Existing packages (already installed)
# readr — via tidyverse
# httr2 — already in DESCRIPTION
# DuckDB — already in DESCRIPTION
```

## Validation and Testing

**bib2df compatibility:**
- rOpenSci package, actively maintained
- Compatible with R >= 3.5.0
- No known conflicts with existing stack (Shiny, DuckDB, httr2)

**OpenAlex API batch limits:**
- Official limit: 100 DOIs per request (verified via [OpenAlex docs](https://docs.openalex.org/how-to-use-the-api/get-lists-of-entities/filter-entity-lists))
- Use `per-page=100` parameter to retrieve all results
- Pipe separator syntax: `doi:value1|value2|...|value100`

**DOI regex pattern:**
- Crossref standard: `/^10\.\d{4,9}/[-._;()/:A-Z0-9]+$/i`
- Matches 74.4M of 74.9M DOIs in Crossref database
- Source: [Crossref DOI regex blog](https://www.crossref.org/blog/dois-and-matching-regular-expressions/)

## Performance Considerations

**Batch DOI lookup:**
- 100 DOIs per API call vs 100 individual calls = 100x reduction in HTTP overhead
- Estimated time: ~1-2 seconds per 100 DOIs (network dependent)
- For 500 DOIs: 5 batches × 1.5s = ~7.5 seconds total

**CSV parsing with readr:**
- 10-100x faster than base R `read.csv()` on files >10K rows
- Negligible performance impact for typical DOI lists (<10K entries)

**BibTeX parsing with bib2df:**
- Typical .bib files: 10-1000 entries
- Parse time: <1 second for 1000 entries
- Bottleneck will be OpenAlex API batch requests, not parsing

## Sources

- [bib2df CRAN](https://cran.r-project.org/web/packages/bib2df/vignettes/bib2df.html) — Official vignette, version 1.1.2.0
- [bib2df GitHub (rOpenSci)](https://github.com/ropensci/bib2df) — Active maintenance, rOpenSci peer-reviewed
- [readr CRAN documentation](https://cran.r-project.org/web/packages/readr/readr.pdf) — Version 2.2.0, February 2026
- [OpenAlex API filter documentation](https://docs.openalex.org/how-to-use-the-api/get-lists-of-entities/filter-entity-lists) — Verified 100-value limit for pipe-separated filters
- [OpenAlex blog: Batch DOI requests](https://blog.openalex.org/fetch-multiple-dois-in-one-openalex-api-request/) — Official guide to batch lookup
- [Crossref DOI regex](https://www.crossref.org/blog/dois-and-matching-regular-expressions/) — Authoritative DOI validation pattern
- [RefManageR CRAN](https://cran.r-project.org/web/packages/RefManageR/RefManageR.pdf) — Version 1.4.0, considered but not recommended (overkill)
- [readr tidyverse documentation](https://readr.tidyverse.org/reference/read_delim.html) — Official API reference

---
*Stack research for: Serapeum v7.0 Citation Audit + Quick Wins*
*Researched: 2026-02-25*
