---
phase: 01-seed-paper-discovery
plan: 02
subsystem: discovery
tags: [openalex, doi, citations, shiny, producer-consumer]
dependency_graph:
  requires:
    - phase: 01-01
      provides: abstract-embedding-pipeline
  provides:
    - seed-paper-discovery-module
    - citation-api-functions
    - producer-consumer-pattern
  affects: [02-query-builder, 03-topic-explorer, mod_search_notebook]
tech_stack:
  added: []
  patterns: [producer-consumer, reactive-output-consumption]
key_files:
  created:
    - R/mod_seed_discovery.R
  modified:
    - R/api_openalex.R
    - app.R
key_decisions:
  - "Producer-consumer pattern: discovery module returns reactive request, app.R creates notebook"
  - "Citation API uses OpenAlex filters (cites:, cited_by:, related_to:) not paginated traversal"
  - "DOI normalization handles all common formats (plain, doi: prefix, URLs, OpenAlex IDs)"
  - "Discovery results populate search notebook without modifying mod_search_notebook.R"
patterns_established:
  - "Discovery modules are producers: return reactive request consumed by app.R"
  - "app.R is the orchestrator: creates notebooks, fetches data, wires module outputs"
  - "New features use new modules, not expansions to mod_search_notebook.R"
metrics:
  duration_minutes: 2
  tasks_completed: 3
  files_modified: 2
  files_created: 1
  completed_date: 2026-02-10
---

# Phase 01 Plan 02: Seed Paper Discovery

**DOI-based paper discovery with citation graph traversal (citing/cited-by/related) outputting to search notebooks via producer-consumer reactive pattern**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-10T19:30:44Z
- **Completed:** 2026-02-10T19:32:32Z
- **Tasks:** 3 (2 auto, 1 human-verify checkpoint)
- **Files modified:** 2
- **Files created:** 1

## Accomplishments

- Users can discover papers by entering a DOI or paper title
- Citation relationships (citing papers, cited papers, related papers) fetch via OpenAlex API
- Discovery results populate search notebooks where existing filtering, embedding, and RAG chat work
- Producer-consumer pattern validated: discovery module outputs request, app.R creates notebook

## Task Commits

Each task was committed atomically:

1. **Task 1: Add citation API functions and DOI normalization** - `b842e2b` (feat)
2. **Task 2: Create seed paper discovery module and wire into app** - `5d43561` (feat)
3. **Task 3: Verify complete seed paper discovery flow** - APPROVED (human verification checkpoint)

**Plan metadata:** (pending final commit)

## Files Created/Modified

### Created
- **R/mod_seed_discovery.R** (150 lines) - Seed paper discovery Shiny module with DOI input, paper preview, citation controls, and reactive discovery request output

### Modified
- **R/api_openalex.R** - Added `normalize_doi()`, `get_citing_papers()`, `get_cited_papers()`, `get_related_papers()`, and updated `get_paper()` to handle DOI URLs
- **app.R** - Added "Discover from Paper" sidebar button, discovery view routing, module server initialization, and producer-consumer wiring to create search notebooks from discovery requests

## What Was Built

### 1. Citation API Functions (R/api_openalex.R)

Added four new functions to extend OpenAlex integration:

**normalize_doi(input)**
- Accepts DOI in various formats: plain (`10.xxxx/yyyy`), with prefix (`doi:10.xxxx/yyyy`), HTTP/HTTPS URLs, or OpenAlex URLs
- Strips prefixes, normalizes URL schemes, validates format
- Returns consistent `https://doi.org/{doi}` format or NULL if invalid
- Also handles OpenAlex Work IDs (W-prefixed)

**get_citing_papers(paper_id, email, api_key, per_page = 25)**
- Fetches papers that cite the given work using OpenAlex `cites:{paper_id}` filter
- Returns list of parsed works with total count as attribute

**get_cited_papers(paper_id, email, api_key, per_page = 25)**
- Fetches papers cited BY the given work (outgoing references) using `cited_by:{paper_id}` filter

**get_related_papers(paper_id, email, api_key, per_page = 25)**
- Fetches algorithmically related works using `related_to:{paper_id}` filter

**Updated get_paper()**
- Now handles DOI URLs from `normalize_doi()` by using them as filter parameters instead of appending to base URL

### 2. Seed Discovery Module (R/mod_seed_discovery.R)

New Shiny module following producer-consumer pattern:

**UI:**
- DOI input text field with placeholder examples
- "Look Up" button to fetch paper metadata
- Paper preview area showing title, authors, year, abstract snippet, venue
- Citation controls showing citation counts and radio buttons for citation direction
- "Create Notebook with Results" button to trigger discovery

**Server:**
- `seed_paper` reactiveVal stores looked-up paper
- `discovery_request` reactiveVal is the producer output
- Lookup flow: normalize DOI → fetch paper → display preview and citation controls
- Fetch flow: build discovery request with seed paper, citation type, and notebook name
- Returns `discovery_request` reactive for app.R to consume

### 3. App Wiring (app.R)

Added producer-consumer orchestration:

**UI:**
- "Discover from Paper" button in sidebar with seedling icon
- Discovery view routing in main content

**Server:**
- Module server initialization: `discovery_request <- mod_seed_discovery_server(...)`
- Consumer observer: watches `discovery_request()`, creates search notebook, fetches citation results, populates notebook with abstracts, navigates to new notebook
- Citation results flow through existing search notebook module for filtering, embedding, and RAG chat

## Decisions Made

1. **Producer-consumer pattern**: Discovery modules return reactive requests consumed by app.R to create notebooks. This keeps module responsibilities clean and allows app.R to orchestrate data flow.

2. **Citation API uses filters**: OpenAlex citation endpoints use filter parameters (`cites:`, `cited_by:`, `related_to:`) rather than paginated traversal. This matches OpenAlex's recommended approach.

3. **DOI normalization**: Handles all common DOI formats to reduce user friction. Users can paste from various sources without reformatting.

4. **No modification to mod_search_notebook.R**: Discovery results populate search notebooks without changing the 1,760-line search notebook module. This prevents module bloat and validates the producer-consumer architecture.

## Deviations from Plan

None - plan executed exactly as written. No bugs discovered, no architectural changes needed, no blocking issues encountered.

## Issues Encountered

None. The producer-consumer pattern worked as designed, OpenAlex API responded as expected, and all verification passed on first attempt.

## User Setup Required

None - no external service configuration required. Feature uses existing OpenAlex credentials from settings.

## Verification

User verified complete flow:
1. Clicked "Discover from Paper" in sidebar
2. Entered DOI `10.7717/peerj.4375` and clicked "Look Up"
3. Paper metadata displayed correctly (title, authors, year, abstract)
4. Citation counts shown
5. Selected "Papers citing this work" and clicked "Create Notebook with Results"
6. Search notebook created and opened with citing papers
7. Papers displayed with full metadata
8. "Embed Papers" embedded abstracts successfully
9. RAG chat returned relevant answers citing paper titles

All verification criteria met. Feature ready for use.

## Next Phase Readiness

**Ready for Phase 2 (Query Builder):**
- Producer-consumer pattern proven and documented
- Discovery modules output to search notebooks without expanding existing modules
- OpenAlex API integration extended with citation functions
- Pattern can be reused for query builder (Phase 2) and topic explorer (Phase 3)

**Concerns:**
- None. Phase 1 complete with no blockers.

## Self-Check: PASSED

**Created files exist:**
```
FOUND: R/mod_seed_discovery.R
```

**Modified files have expected content:**
```
FOUND: normalize_doi function in R/api_openalex.R
FOUND: get_citing_papers function in R/api_openalex.R
FOUND: get_cited_papers function in R/api_openalex.R
FOUND: get_related_papers function in R/api_openalex.R
FOUND: mod_seed_discovery_ui in R/mod_seed_discovery.R
FOUND: mod_seed_discovery_server in R/mod_seed_discovery.R
FOUND: discover_paper button in app.R
```

**Commits exist:**
```
FOUND: b842e2b (Task 1: citation API functions)
FOUND: 5d43561 (Task 2: seed discovery module and app wiring)
```

**Key functionality verified:**
- DOI normalization handles multiple formats
- Citation API functions fetch and parse papers correctly
- Discovery module displays paper preview and citation controls
- Producer-consumer pattern creates notebooks from discovery requests
- Discovery results populate search notebooks with full metadata
- Embedding and RAG chat work on discovered papers

---
*Phase: 01-seed-paper-discovery*
*Completed: 2026-02-10*
