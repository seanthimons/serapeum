# Phase 11 Plan 02: DOI Display UI Summary

**One-liner:** DOI displayed as clickable link in abstract preview with citation key fallback, plus backfill trigger in settings

---

## Metadata

```yaml
phase: 11-doi-storage-migration
plan: 02
subsystem: ["ui-abstracts", "settings-management"]
tags: ["doi", "ui", "backfill", "citations", "openalex"]
status: checkpoint-pending
completed: 2026-02-12

dependency_graph:
  requires: ["11-01"]  # DOI storage infrastructure
  provides: ["doi-ui-display", "doi-backfill-trigger"]
  affects: ["abstract-preview", "settings-page"]

tech_stack:
  added: []
  patterns: ["graceful-degradation", "batch-processing", "progress-indicator"]

key_files:
  created: []
  modified:
    - path: "R/mod_search_notebook.R"
      changes: "Added DOI display with clickable link or citation key fallback"
      lines_added: 23
    - path: "R/mod_settings.R"
      changes: "Added DOI Management section with backfill trigger and progress indicator"
      lines_added: 57

decisions:
  - name: "DOI link opens in new tab"
    rationale: "Follow standard practice for external links, avoid losing app state"
    alternatives: ["Same tab navigation"]
    impact: "Better UX, maintains app session"
  - name: "Citation key fallback for missing DOI"
    rationale: "Graceful degradation for legacy papers, provides usable reference ID"
    alternatives: ["Show nothing", "Show 'N/A'"]
    impact: "Users can still reference papers without DOI"
  - name: "Batch size 50 for backfill"
    rationale: "Balance between API efficiency and politeness to OpenAlex"
    alternatives: ["Batch size 100", "Single requests"]
    impact: "Reasonable backfill speed without overwhelming API"

metrics:
  duration_minutes: 1.5
  tasks_completed: 2
  files_modified: 2
  commits: 2
  lines_added: 80
```

---

## What Was Built

### Task 1: DOI Display in Abstract Preview ✅
**Commit:** `600b3ff`

Added DOI display to abstract detail view (after citation metrics, before hr separator):
- **Papers with DOI**: Display as clickable link opening `https://doi.org/{doi}` in new tab
- **Papers without DOI**: Show citation key generated from title+year with "(DOI unavailable)" message
- Uses `generate_citation_key()` from `utils_doi.R` for fallback
- Link attributes: `target="_blank"` and `rel="noopener noreferrer"` for security

**Files Modified:**
- `R/mod_search_notebook.R` (lines 795-796): Added DOI display block in abstract_detail renderUI

### Task 2: Backfill Trigger in Settings ✅
**Commit:** `3601e22`

Added "DOI Management" section to settings page:
- **Status display**: Shows badge counts for papers with/without DOI
- **Backfill button**: "Backfill Missing DOIs" with rotate icon
- **Progress indicator**: Uses `withProgress()` to show batch processing status
- **Batch processing**: Fetches DOIs from OpenAlex in batches of 50 with 0.5s delay
- **Email validation**: Checks OpenAlex email is configured before starting backfill
- **Status refresh**: Updates counts after backfill completes

**Files Modified:**
- `R/mod_settings.R` (UI lines 103-115, Server lines 421-467): Added DOI Management UI and backfill logic

### Task 3: Human Verification Checkpoint ⏸️
**Status:** Pending user verification

Verification steps to complete:
1. Start app, confirm migration 005 applied (doi column exists)
2. Search for papers and save to notebook
3. Click saved paper, verify DOI displays as clickable link
4. Click DOI link, confirm opens correct URL in new tab
5. For legacy papers (if any), verify citation key fallback displays
6. Go to Settings, verify DOI Management section shows counts
7. Click "Backfill Missing DOIs", verify progress bar and completion notification
8. Return to legacy paper, confirm DOI now displays instead of citation key

---

## Deviations from Plan

None - plan executed exactly as written.

All specified functionality implemented:
- DOI display with clickable link
- Citation key fallback for missing DOI
- Graceful degradation message
- Backfill trigger in settings
- Progress indicator for batch processing
- Status display with counts

---

## Integration Points

### Data Flow
1. **Abstract Preview → Database**: `list_abstracts()` uses `SELECT * FROM abstracts` which includes `doi` column
2. **Settings → Database**: `get_doi_backfill_status()` queries abstracts table for counts
3. **Backfill → OpenAlex**: `backfill_dois()` fetches DOIs via OpenAlex API using user's email
4. **Backfill → Database**: Updates `abstracts.doi` column with normalized DOI values

### Dependencies Used
- `R/utils_doi.R::generate_citation_key()` - Fallback citation key generation
- `R/utils_doi.R::normalize_doi_bare()` - DOI normalization in backfill
- `R/db.R::get_doi_backfill_status()` - Status counts for UI
- `R/db.R::backfill_dois()` - Batch DOI fetching from OpenAlex
- `R/db.R::get_db_setting()` - Get OpenAlex email for API calls

---

## Testing Notes

**Automated Tests:** None (UI-focused feature)

**Manual Verification Required:**
- Visual: DOI link appears in abstract preview
- Functional: DOI link opens correct URL
- Functional: Citation key fallback displays for papers without DOI
- Functional: Backfill button triggers batch processing
- Functional: Progress indicator displays during backfill
- Functional: Status counts update after backfill

**Edge Cases Handled:**
- NULL DOI field → shows citation key
- Empty string DOI → shows citation key
- NA DOI → shows citation key
- No OpenAlex email configured → error notification
- Batch has no papers to update → backfill stops gracefully

---

## Known Issues / Future Work

None identified.

**GitHub Issue:** Closes #66 (DOI on abstract preview) once verification passes.

---

## Self-Check: PASSED

**Created files exist:**
- N/A (no new files created)

**Modified files exist:**
```
FOUND: R/mod_search_notebook.R
FOUND: R/mod_settings.R
```

**Commits exist:**
```
FOUND: 600b3ff
FOUND: 3601e22
```

**Functions verified:**
- `generate_citation_key()` exists in `R/utils_doi.R` ✅
- `get_doi_backfill_status()` exists in `R/db.R` ✅
- `backfill_dois()` exists in `R/db.R` ✅

All implementation claims verified.

---

## Checkpoint Status

**Type:** human-verify
**Awaiting:** User verification of DOI display and backfill functionality
**Resume Signal:** User reports verification results (approved or issues found)

**Verification Instructions:** See Task 3 above for 8-step verification process.
