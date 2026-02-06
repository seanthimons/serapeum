# Document Type Filter Design

**Date:** 2026-02-06
**Branch:** `feature/document-type-filter`
**Status:** Ready for implementation

## Overview

Add document type filtering and display to the OpenAlex search feature. Users can filter by work type (article, review, preprint, etc.) and see the distribution of types in their search results.

## Data Model

### New Fields Extracted from OpenAlex

| Field | Source | Description |
|-------|--------|-------------|
| `work_type` | `work.type` | Simplified type: article, preprint, review, paratext, letter, editorial, erratum |
| `work_type_crossref` | `work.type_crossref` | Crossref type: journal-article, dissertation, book-chapter, etc. |

### Database Migration

```sql
ALTER TABLE abstracts ADD COLUMN work_type TEXT;
ALTER TABLE abstracts ADD COLUMN work_type_crossref TEXT;
```

## Backend Changes

### `R/api_openalex.R`

1. **`parse_openalex_work()`** - Extract new fields:
   ```r
   work_type = work$type %||% NA_character_
   work_type_crossref = work$type_crossref %||% NA_character_
   ```

2. **`search_papers()`** - Add `work_types` parameter:
   ```r
   # New parameter: work_types (character vector)
   # OpenAlex uses pipe for OR: type:article|review
   if (!is.null(work_types) && length(work_types) > 0) {
     filters <- c(filters, paste0("type:", paste(work_types, collapse = "|")))
   }
   ```

3. **`build_query_preview()`** - Include type filter in preview string.

### `R/db.R`

4. **`create_abstract()`** - Accept and store `work_type` and `work_type_crossref`.

5. **Database init** - Add migration for new columns.

## UI Changes

### Edit Search Modal (`R/mod_search_notebook.R`)

**New section after "Open Access Only" checkbox:**

```
Document Types
☑ Articles  ☑ Reviews  ☑ Preprints  ☑ Books  ☑ Dissertations  ☑ Other

▶ View distribution in current results
```

- All types checked by default (no default filtering)
- Collapsible distribution panel shows bar chart of types in current results

**Distribution panel (expanded):**

```
▼ View distribution in current results
  article      ████████████████████  142
  review       █████                  28
  preprint     ██                     12
  dissertation │                       3
```

- HTML/CSS bars using Bootstrap classes
- Computed client-side from loaded papers (no extra API call)
- Bars scale relative to max count

### Paper List

**Type badge next to title:**

| Type | Badge Style |
|------|-------------|
| article | muted gray (`.bg-secondary`) |
| review | blue (`.bg-info`) |
| preprint | orange (`.bg-warning`) |
| dissertation | purple (custom) |
| dataset | green (`.bg-success`) |
| other | light gray (`.bg-light`) |

### Paper Detail View

Show type badge in metadata section alongside year and venue.

## Implementation Order

1. Database migration (add columns)
2. API extraction (parse_openalex_work)
3. API filtering (search_papers + build_query_preview)
4. DB storage (create_abstract)
5. UI: Type filter checkboxes in modal
6. UI: Distribution panel in modal
7. UI: Type badges in paper list
8. UI: Type in detail view
9. Testing & cleanup

## Files to Modify

- `R/api_openalex.R` - Extract and filter by type
- `R/db.R` - Migration, create_abstract update
- `R/mod_search_notebook.R` - UI controls and display
- `tests/testthat/test-api-openalex.R` - Test new extraction

## References

- OpenAlex types: https://docs.openalex.org/api-entities/works/work-object#type
- Crossref types: https://api.crossref.org/types
