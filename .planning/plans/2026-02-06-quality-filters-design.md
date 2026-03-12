# Quality Filters Design

**Date:** 2026-02-06
**Status:** Draft
**Branch:** `feature/quality-filters`

## Overview

Add paper quality filtering to Search Notebooks to help users avoid retracted papers, predatory journals/publishers, and low-citation works.

## Problem

Researchers searching for papers may unknowingly include:
- **Retracted papers** - withdrawn due to errors, fraud, or ethical issues
- **Predatory journal papers** - from publishers with fake/minimal peer review
- **Low-impact papers** - works with few citations that may be less established

## Solution

Three quality filters integrated into the search modal:

| Filter | Behavior | Data Source |
|--------|----------|-------------|
| Exclude retracted papers | Hide completely | Retraction Watch (GitLab CSV) |
| Flag predatory journals/publishers | Show with warning icon | Google Sheets (predatoryjournals.org) |
| Minimum citations | Hide below threshold | OpenAlex API |

## Data Sources

### Retraction Watch
- **URL:** https://gitlab.com/crossref/retraction-watch-data/-/raw/main/retraction_watch.csv
- **Format:** CSV with DOI, title, retraction date, reason
- **Updates:** Daily (working days)
- **Size:** ~50k+ entries

### Predatory Publishers
- **URL:** https://docs.google.com/spreadsheets/d/1BHM4aJljhbOAzSpkX1kXDUEvy6vxREZu5WJaDH6M1Vk/export?format=csv&gid=0
- **Format:** CSV with publisher names
- **Source:** predatoryjournals.org (Beall's List derivative)
- **Size:** ~1,363 entries

### Predatory Journals
- **URL:** https://docs.google.com/spreadsheets/d/1Qa1lAlSbl7iiKddYINNsDB4wxI7uUA4IVseeLnCc5U4/export?format=csv&gid=0
- **Format:** CSV with journal names (some marked as hijacked)
- **Source:** predatoryjournals.org
- **Size:** ~1,866 entries

### Citations
- **Source:** OpenAlex API `cited_by_count` field
- **Filter:** `cited_by_count:>N` in API query

## Data Architecture

### New DuckDB Tables

```sql
CREATE TABLE predatory_publishers (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  name_normalized TEXT NOT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE predatory_journals (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  name_normalized TEXT NOT NULL,
  is_hijacked BOOLEAN DEFAULT FALSE,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE retracted_papers (
  doi TEXT PRIMARY KEY,
  title TEXT,
  retraction_date DATE,
  reason TEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE quality_cache_meta (
  source TEXT PRIMARY KEY,
  last_updated TIMESTAMP,
  record_count INTEGER
);
```

### Name Normalization

```r
normalize_name <- function(name) {
  name |>
    tolower() |>
    stringr::str_remove_all("[^a-z0-9 ]") |>
    stringr::str_squish()
}
```

Example:
- `"Journal of Advanced Research"` → `"journal of advanced research"`
- `"J. Adv. Res."` → `"j adv res"`

## Matching Logic

### Retraction Check
- Match paper DOI against `retracted_papers.doi`
- Exact match required
- Papers without DOI: skip check (can't verify)

### Predatory Check
- Match `primary_location.source.display_name` against `predatory_journals.name_normalized`
- Match `primary_location.source.host_organization_name` against `predatory_publishers.name_normalized`
- **Exact normalized match** (not partial/contains) to minimize false positives
- Papers without journal/publisher info: skip check (can't verify)

### Citation Check
- Applied at API level: `cited_by_count:>N`
- Empty input = no minimum

## UI Design

### Search Modal Addition

New "Quality Filters" section below existing filters:

```
┌─────────────────────────────────────────────┐
│ Quality Filters                             │
├─────────────────────────────────────────────┤
│ ☑ Exclude retracted papers                  │
│ ☑ Flag predatory journals/publishers        │
│ □ Minimum citations: [____]                 │
│                                             │
│ ⓘ Data last updated: 2026-02-05            │
│   [Refresh Quality Data]                    │
└─────────────────────────────────────────────┘
```

**Defaults:**
- Exclude retracted: checked
- Flag predatory: checked
- Minimum citations: empty (disabled)

### Paper List Warning Icon

Flagged papers show warning icon with tooltip:

```
┌──────────────────────────────────────────────────┐
│ ⚠️ Machine Learning Applications in Medicine     │
│    Journal of Advanced Scientific Research       │
│    2024 · 12 citations                          │
│    [Tooltip: "Flagged: Predatory publisher"]    │
└──────────────────────────────────────────────────┘
```

## Data Sync

### Initial Setup
1. App detects empty `quality_cache_meta` table
2. User clicks "Refresh Quality Data" or prompted on first search
3. Fetches from all sources, populates cache
4. Shows progress indicator

### Manual Refresh
- "Refresh Quality Data" button in search modal
- Progress: "Updating retraction data... (2/3)"
- Updates `quality_cache_meta.last_updated`

### Offline Behavior
- Fetch fails → use cached data with stale warning
- No cache exists → disable quality filters with message

## Files to Modify

| File | Changes |
|------|---------|
| `R/db.R` | New tables, migration, cache queries |
| `R/api_openalex.R` | Add `min_citations` parameter |
| `R/mod_search_notebook.R` | Search modal UI, filtering logic, warning icons |
| **New:** `R/quality_filter.R` | Fetch, parse, cache, and match functions |

## Implementation Steps

1. **Database schema** - Add tables to `R/db.R`
2. **Quality filter module** - Create `R/quality_filter.R` with:
   - `fetch_retraction_watch()`
   - `fetch_predatory_publishers()`
   - `fetch_predatory_journals()`
   - `refresh_quality_cache()`
   - `check_paper_quality()` - returns flags for a paper
   - `normalize_name()`
3. **API update** - Add `min_citations` to `search_papers()`
4. **UI: Search modal** - Add quality filter controls
5. **UI: Paper list** - Add warning icon rendering
6. **Testing** - Unit tests for matching logic

## Edge Cases

- Paper has no DOI → skip retraction check
- Paper has no journal/publisher info → skip predatory check
- Google Sheets URL changes → app shows fetch error, uses cache
- Retraction Watch CSV format changes → parse error handling

## Future Enhancements

- Add Kscien data (~3,500 entries) via scraping
- "Strict mode" that hides predatory papers instead of flagging
- Export quality report for a search
- Per-notebook quality preferences

## References

- [Retraction Watch GitLab](https://gitlab.com/crossref/retraction-watch-data)
- [Crossref Retraction Watch Docs](https://www.crossref.org/documentation/retrieve-metadata/retraction-watch/)
- [OpenAlex Filter Works](https://docs.openalex.org/api-entities/works/filter-works)
- [Kscien Predatory Publishing](https://kscien.org/predatory-publishing/)
