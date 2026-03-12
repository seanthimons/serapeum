# Design: OA Status & Citations (#4 Phase 2)

**Date:** 2026-02-06
**Status:** Ready for implementation
**Effort:** Low-Medium | **Impact:** High

## Overview

Extend paper metadata to include Open Access status and citation metrics, displaying them as compact badges and icons in the paper list.

## Current State

The abstracts table stores basic metadata (title, authors, year, venue) plus:
- `work_type` / `work_type_crossref` - Document type badges (Phase 1: done)
- `keywords` - Paper keywords from OpenAlex
- `pdf_url` - Direct PDF link if available

**Missing for Phase 2:**
- Open Access status and type
- Citation impact metrics

## New Fields

### Database Schema Additions

```sql
-- OA Status
oa_status VARCHAR      -- 'diamond', 'gold', 'green', 'hybrid', 'bronze', 'closed'
is_oa BOOLEAN          -- true if freely readable

-- Citation Metrics
cited_by_count INTEGER -- Incoming citations (how many papers cite this one)
referenced_works_count INTEGER  -- Outgoing citations (how many papers this cites)
fwci DOUBLE            -- Field-weighted citation impact (may be NULL for recent papers)
```

### OpenAlex Fields Mapping

| OpenAlex Field | Database Column |
|----------------|-----------------|
| `open_access.oa_status` | `oa_status` |
| `open_access.is_oa` | `is_oa` |
| `cited_by_count` | `cited_by_count` |
| `referenced_works_count` | `referenced_works_count` |
| `fwci` | `fwci` |

## UI Design

### OA Status Badge

Display next to the existing type badge in the paper list row.

| Status | Badge Class | Icon | Tooltip |
|--------|-------------|------|---------|
| Diamond | `bg-info` | `gem` | "Diamond OA: Free to read & publish" |
| Gold | `bg-warning text-dark` | `unlock` | "Gold OA: Open access journal" |
| Green | `bg-success` | `leaf` | "Green OA: Repository copy" |
| Hybrid | `bg-primary` | `code-branch` | "Hybrid OA: Open in toll-access journal" |
| Bronze | `bg-secondary` | `lock-open` | "Bronze OA: Free but no license" |
| Closed | `bg-dark` | `lock` | "Closed access" |

### Citation Metrics

Compact icon format below author/year line:

```
📥142  ⚖️2.4  📤45
```

- `📥` (or Font Awesome `arrow-down`) = Cited by count
- `⚖️` (or Font Awesome `scale-balanced`) = FWCI
- `📤` (or Font Awesome `arrow-up`) = Referenced works count

Each icon has a tooltip explaining the metric.

**Special cases:**
- FWCI may be `NULL` for recent papers - hide the metric in this case
- Zero values still shown (0 citations is useful information)

### Paper List Row Layout

```
┌─────────────────────────────────────────────────────────────────┐
│ ☐ ⚠️ Machine Learning in Healthcare                        [X] │
│    Smith et al. - 2023  [article] [🔓 gold]                 📄  │
│    Nature Medicine                                              │
│    📥142  ⚖️2.4  📤45                                          │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation

### 1. Database Migration (db.R)

```r
# Migration: Add OA and citation columns (Phase 2)
tryCatch({
  dbExecute(con, "ALTER TABLE abstracts ADD COLUMN oa_status VARCHAR")
}, error = function(e) {})

tryCatch({
  dbExecute(con, "ALTER TABLE abstracts ADD COLUMN is_oa BOOLEAN")
}, error = function(e) {})

tryCatch({
  dbExecute(con, "ALTER TABLE abstracts ADD COLUMN cited_by_count INTEGER DEFAULT 0")
}, error = function(e) {})

tryCatch({
  dbExecute(con, "ALTER TABLE abstracts ADD COLUMN referenced_works_count INTEGER DEFAULT 0")
}, error = function(e) {})

tryCatch({
  dbExecute(con, "ALTER TABLE abstracts ADD COLUMN fwci DOUBLE")
}, error = function(e) {})
```

### 2. API Extraction (api_openalex.R)

Update `parse_openalex_work()`:

```r
# OA Status
oa_status <- NA_character_
is_oa <- FALSE
if (!is.null(work$open_access)) {
  oa_status <- work$open_access$oa_status %||% NA_character_
  is_oa <- isTRUE(work$open_access$is_oa)
}

# Citation metrics
referenced_works_count <- 0
if (!is.null(work$referenced_works_count)) {
  referenced_works_count <- work$referenced_works_count
}

fwci <- NA_real_
if (!is.null(work$fwci)) {
  fwci <- work$fwci
}

# Add to return list
list(
  # ... existing fields ...
  oa_status = oa_status,
  is_oa = is_oa,
  cited_by_count = cited_by_count,  # Already extracted
  referenced_works_count = referenced_works_count,
  fwci = fwci
)
```

### 3. Save Abstract (db.R)

Update `save_abstract()` to include new columns in INSERT statement.

### 4. UI Helpers (mod_search_notebook.R)

```r
# Helper: Get OA status badge info
get_oa_badge <- function(oa_status) {
  if (is.null(oa_status) || is.na(oa_status) || oa_status == "") {
    return(NULL)  # Don't show badge if unknown
  }
  switch(oa_status,
    "diamond" = list(class = "bg-info", icon = "gem", tooltip = "Diamond OA: Free to read & publish"),
    "gold" = list(class = "bg-warning text-dark", icon = "unlock", tooltip = "Gold OA: Open access journal"),
    "green" = list(class = "bg-success", icon = "leaf", tooltip = "Green OA: Repository copy"),
    "hybrid" = list(class = "bg-primary", icon = "code-branch", tooltip = "Hybrid OA: Open in toll-access journal"),
    "bronze" = list(class = "bg-secondary", icon = "lock-open", tooltip = "Bronze OA: Free but no license"),
    "closed" = list(class = "bg-dark", icon = "lock", tooltip = "Closed access"),
    NULL
  )
}

# Helper: Format citation metrics row
format_citation_metrics <- function(cited_by, fwci, refs) {
  metrics <- list()

  # Cited by (always show)
  metrics <- c(metrics, list(
    span(
      class = "text-muted",
      title = "Cited by count",
      icon("arrow-down", class = "small"),
      format(cited_by %||% 0, big.mark = ",")
    )
  ))

  # FWCI (only if available)
  if (!is.null(fwci) && !is.na(fwci)) {
    fwci_class <- if (fwci >= 1.0) "text-success" else "text-muted"
    metrics <- c(metrics, list(
      span(
        class = fwci_class,
        title = "Field-weighted citation impact (>1.0 = above average)",
        icon("scale-balanced", class = "small"),
        sprintf("%.1f", fwci)
      )
    ))
  }

  # Referenced works (always show)
  metrics <- c(metrics, list(
    span(
      class = "text-muted",
      title = "References (outgoing citations)",
      icon("arrow-up", class = "small"),
      format(refs %||% 0, big.mark = ",")
    )
  ))

  div(
    class = "small d-flex gap-2",
    metrics
  )
}
```

### 5. Paper List Rendering

Add OA badge after type badge, and citation metrics as new row:

```r
# After type badge
oa_badge <- get_oa_badge(paper$oa_status)
if (!is.null(oa_badge)) {
  span(
    class = paste("badge", oa_badge$class, "ms-1"),
    title = oa_badge$tooltip,
    icon(oa_badge$icon, class = "small")
  )
}

# New row for citation metrics
format_citation_metrics(paper$cited_by_count, paper$fwci, paper$referenced_works_count)
```

## File Changes Summary

| File | Changes |
|------|---------|
| `R/db.R` | Add 5 new columns via migration, update `save_abstract()` |
| `R/api_openalex.R` | Extract new fields in `parse_openalex_work()` |
| `R/mod_search_notebook.R` | Add `get_oa_badge()`, `format_citation_metrics()`, update paper list rendering |

## Filtering (Future Phase 3)

This phase focuses on **display only**. Filtering by OA status (e.g., "show only Gold OA papers") is deferred to Phase 3 as noted in TODO.md:

> Phase 2: OA Status & Citations
> - Granular OA status filter (`oa_status`: gold, green, hybrid, bronze, closed) | Pending
> - Display OA status badges in paper list | **This design**

## Testing

- [ ] New papers display OA badge with correct color/icon
- [ ] Existing papers (without OA data) don't show OA badge
- [ ] Citation metrics display correctly with tooltips
- [ ] FWCI hidden when NULL
- [ ] Large citation counts formatted with commas
- [ ] FWCI >= 1.0 shows green text
- [ ] Database migration runs without error on existing DB
