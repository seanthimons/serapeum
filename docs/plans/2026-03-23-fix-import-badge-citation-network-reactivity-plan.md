---
title: "fix: Import badge doesn't update on citation network import"
type: fix
date: 2026-03-23
issue: "#154"
session: D
milestone: "v18: Bug Bash"
---

# fix: Import Badge Doesn't Update on Citation Network Import (#154)

## Overview

When importing papers from the "Missing Papers" tab in the citation network view, two things fail to update:

1. **The row-level badge** — the "Import" button doesn't change to "Imported"
2. **The `missing_count_badge`** — the tab count (e.g., "3 Missing") doesn't decrement

The citation audit view handles this correctly and serves as the reference implementation.

## Problem Statement

The `import_missing_paper` observer in `mod_citation_network.R:1380-1422` calls `create_abstract()` to import the paper, but **does not invalidate any reactive dependency**. The comment on line 1417 incorrectly claims `missing_papers_data` will "re-query automatically" — but since neither `current_network_data()` nor `source_notebook_id()` change after import, the reactive never re-fires.

### Reactive Chain (broken)

```
import_missing_paper observer (line 1380)
  └─ calls create_abstract()     ✅ writes to DB
  └─ shows notification           ✅ works
  └─ invalidates nothing          ❌ BUG

missing_papers_data (line 1279)
  ├─ depends on: current_network_data()   — unchanged after import
  └─ depends on: source_notebook_id()     — unchanged after import
  └─ RESULT: never re-executes

missing_count_badge (line 1312) ──depends on──▶ missing_papers_data() ── stale
missing_papers_content (line 1319) ──depends on──▶ missing_papers_data() ── stale
```

### Working Reference: Citation Audit

In `mod_citation_audit.R`, after importing (lines 693-718):
- Explicitly re-sets `audit_results()` with fresh data
- Calls `notebook_refresh(notebook_refresh() + 1)` to signal other modules
- Has `notebook_refresh` as a module parameter (line 66-68)

The citation network module does **none** of these things.

## Proposed Solution

Two fixes — one required, one recommended:

### Fix 1: Add Local Reactive Trigger (Required)

Add a `reactiveVal` trigger inside `mod_citation_network.R` that `missing_papers_data` depends on. Increment it after successful import.

```r
# R/mod_citation_network.R

# Near other reactiveVals (around line 240):
missing_refresh <- reactiveVal(0)

# In missing_papers_data reactive (line 1279), add dependency:
missing_papers_data <- reactive({
  missing_refresh()  # ← new reactive dependency
  net_data <- current_network_data()
  # ... rest unchanged ...
})

# In import_missing_paper observer (line 1422), after create_abstract():
missing_refresh(missing_refresh() + 1)
```

### Fix 2: Add Cross-Module Notification (Recommended)

Thread `notebook_refresh` into `mod_citation_network_server` so other modules (e.g., search notebook sidebar) know a paper was imported. This matches the pattern used by `mod_citation_audit_server`.

```r
# R/mod_citation_network.R line 185 — update signature:
mod_citation_network_server <- function(id, con_r, config_r, network_id_r, network_trigger, notebook_refresh = NULL)

# In import_missing_paper observer, after successful import:
if (!is.null(notebook_refresh)) {
  notebook_refresh(notebook_refresh() + 1)
}
```

```r
# app.R line ~1334 — update wiring:
mod_citation_network_server("citation_network", con_r, config_r, network_id_r, network_trigger, notebook_refresh)
```

## Technical Considerations

- **No new dependencies** — uses existing `reactiveVal` pattern already in use throughout the app
- **Performance** — `missing_papers_data` re-queries the DB on each invalidation, but this only fires on user-initiated import clicks (not continuous)
- **Backward compatibility** — `notebook_refresh = NULL` default means the signature change is non-breaking

## Acceptance Criteria

- [x] After importing a paper from "Missing Papers" tab, the "Import" button changes to "Imported" without page refresh
- [x] After importing, `missing_count_badge` decrements (e.g., "3 Missing" → "2 Missing")
- [x] Importing the last missing paper shows empty state or "0 Missing"
- [x] `notebook_refresh` is incremented after import (cross-module signal)
- [x] Existing citation audit import behavior is unchanged
- [x] Shiny smoke test passes (`runApp` starts without error)

## Files to Modify

| File | Change | Lines |
|------|--------|-------|
| `R/mod_citation_network.R` | Add `missing_refresh` reactiveVal | ~240 |
| `R/mod_citation_network.R` | Add `missing_refresh()` dependency to `missing_papers_data` | 1279 |
| `R/mod_citation_network.R` | Increment `missing_refresh` after import | 1422 |
| `R/mod_citation_network.R` | Add `notebook_refresh` param to server signature | 185 |
| `R/mod_citation_network.R` | Increment `notebook_refresh` after import | 1422 |
| `app.R` | Pass `notebook_refresh` to citation network module | ~1334 |

## Testing Strategy

**Unit test** (`tests/testthat/test-mod_citation_network_import_badge.R`):
- Use `testServer()` to instantiate `mod_citation_network_server`
- Mock DB with a paper in the network but not in the notebook
- Trigger `input$import_missing_paper`
- Assert `missing_refresh` was incremented
- Assert `notebook_refresh` was incremented

**Manual smoke test** (required — this is a reactive UI bug):
1. Start app with `shiny::runApp('app.R')`
2. Open a citation network with missing papers
3. Import a paper from "Missing Papers" tab
4. Verify badge updates without refresh
5. Import all remaining papers — verify empty state

## References

- Issue: [#154](https://github.com/seanthimons/serapeum/issues/154)
- Working reference: `R/mod_citation_audit.R:693-718` (correct import refresh pattern)
- Module wiring: `app.R:~1334` (citation network server call)
- Existing plan context: `docs/plans/2026-03-23-fix-v18-bug-bash-sessions-b-through-e-plan.md:164-192`
