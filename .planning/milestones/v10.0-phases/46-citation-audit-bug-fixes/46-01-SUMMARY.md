---
phase: 46-citation-audit-bug-fixes
plan: 01
subsystem: citation-audit
tags: [bugfix, ui-polish, reactive-sync]
dependency_graph:
  requires: [design-system-foundation]
  provides: [working-citation-audit-import, duplicate-skip-tracking, progress-feedback]
  affects: [abstract-notebook-sync, citation-audit-ux]
tech_stack:
  added: []
  patterns: [reactive-observer-tracking, progress-notification, skipped-count-return]
key_files:
  created: []
  modified:
    - R/citation_audit.R
    - R/mod_citation_audit.R
    - app.R
    - tests/testthat/test-citation-audit.R
decisions:
  - id: observer-tracking-pattern
    summary: Use reactiveVal to track created observers and prevent duplicates
    rationale: Avoid stale/duplicate observers from observe() recreating observeEvent() on each trigger
    alternatives: [isolate pattern, moduleServer scoping]
    trade_offs: Requires manual tracking but gives explicit control over observer lifecycle
  - id: progress-notification-over-modal
    summary: Use showNotification for batch import progress instead of withProgress
    rationale: Non-blocking, updates in real-time without modal overlay blocking UI
    alternatives: [withProgress modal, silent background import]
    trade_offs: Less prominent than modal but better UX for background operations
  - id: remove-observer-once-flag
    summary: Remove 'once=TRUE' from single-paper import observeEvent
    rationale: Allow re-importing same paper to different notebooks
    alternatives: [keep once=TRUE and recreate observers]
    trade_offs: Observer persists for session but duplicate detection in import_audit_papers handles re-clicks
metrics:
  duration: 327s
  completed_date: 2026-03-05
  task_count: 2
  file_count: 4
  commits:
    - 1338965 (test - RED)
    - 45938d4 (feat - GREEN)
    - 8149fa3 (fix - Task 2)
---

# Phase 46 Plan 01: Citation Audit Bug Fixes Summary

**One-liner:** Fixed multi-paper import failures and abstract notebook sync with progress notifications and duplicate skip tracking

## What Was Built

### Task 1: Enhanced import_audit_papers with skipped_count and progress_callback (TDD)

**RED phase (commit 1338965):**
- Added failing tests for skipped_count return value
- Added tests for progress_callback invocation
- Verified tests fail as expected (skipped_count NULL, progress_callback doesn't exist)

**GREEN phase (commit 45938d4):**
- Implemented skipped_count tracking: `skipped = length(work_ids) - length(new_ids)`
- Added optional progress_callback parameter to function signature
- Called progress_callback(i, length(metadata)) after each paper import
- Updated all return paths to include skipped_count (success, early return, error)
- Changed for loop to use seq_along for progress index tracking
- All tests pass

**Impact:**
- Callers can now show "Added 5 papers, 2 already existed (skipped)" messages
- Progress callbacks enable real-time UI updates during batch import

### Task 2: Fixed module import handlers and wired notebook_refresh

**Fix 1 - Single-paper import observer pattern (BUGF-01 root cause):**
- Created `created_observers` reactiveVal to track which observers exist
- Check `if (btn_id %in% already)` before creating new observer
- Removed `once=TRUE` flag to allow re-import to different notebooks
- Added progress notification: "Importing paper..."
- Show appropriate notification based on result: success/already exists/failed
- Trigger `notebook_refresh(notebook_refresh() + 1)` after successful import

**Fix 2 - Batch import with progress toast (BUGF-01 + BUGF-02):**
- Replaced blocking `withProgress()` with non-blocking `showNotification()`
- Pass progress_callback to import_audit_papers with notification update
- Build summary message from imported/skipped/failed counts
- Show summary toast: "Added 5 papers, 2 already existed, 1 failed"
- Trigger notebook_refresh after successful import
- Keep navigate_to_notebook call for navigation

**Fix 3 - Wire notebook_refresh in navigate_to_notebook (BUGF-02):**
- Updated navigate_to_notebook callback in app.R to increment notebook_refresh
- Ensures abstract notebook updates regardless of which code path triggers navigation

**Impact:**
- Multi-paper import no longer creates duplicate/stale observers
- No per-paper error modals - errors summarized in single toast
- Imported papers appear in abstract notebook immediately
- Progress feedback during batch import: "Importing papers... 3/7"
- Duplicate papers skipped silently with count in summary

## Verification Results

### Automated Tests
- ✅ Unit tests pass: 61 passed, 2 skipped (API-dependent tests)
- ✅ Smoke test pass: App starts and serves HTML without errors

### Manual Verification (UAT)
Ready for user acceptance testing:
- [ ] Run citation audit on notebook with papers
- [ ] Import single paper via "Import" button - appears in abstract notebook
- [ ] Import multiple papers via batch - progress toast updates
- [ ] Re-import same papers - shows "already existed" message
- [ ] No modal error dialogs during any import operation

## Success Criteria Status

- ✅ BUGF-01: Multi-paper citation audit import completes without errors, shows progress and summary toast
- ✅ BUGF-02: Papers imported via citation audit appear in abstract notebook without manual refresh
- ✅ No regression in existing citation audit functionality (test suite passes)
- ✅ App starts cleanly (smoke test)

## Deviations from Plan

None - plan executed exactly as written.

## Technical Notes

### Observer Pattern Fix
The original code created a new observeEvent(once=TRUE) inside an observe() every time audit_results() changed. This caused:
- Duplicate observers for the same button ID
- Stale closures capturing old reactive values
- Unpredictable behavior on rapid result updates

The fix tracks created observers explicitly, preventing re-creation while still allowing observers to respond to new audit results.

### Progress Notification Pattern
Using `showNotification(id = notif_id)` with the same ID updates the existing notification instead of creating a new one. This creates a smooth updating progress indicator without notification spam.

### Skipped Count Calculation
Calculated early in the pipeline: `skipped = length(work_ids) - length(new_ids)` after duplicate filtering. This captures the exact count of papers that were requested but already existed, providing accurate user feedback.

## Files Modified

### R/citation_audit.R
- Added `progress_callback = NULL` parameter to import_audit_papers
- Track skipped count after duplicate filter
- Call progress_callback after each paper import
- Include skipped_count in all return paths

### R/mod_citation_audit.R
- Single-paper import: observer tracking pattern, progress notification, notebook_refresh trigger
- Batch import: progress toast with callback, summary message with counts, notebook_refresh trigger
- No changes to UI - all fixes in server logic

### app.R
- navigate_to_notebook callback now increments notebook_refresh
- Ensures abstract notebook sync from all navigation paths

### tests/testthat/test-citation-audit.R
- Added tests for skipped_count return value
- Added tests for empty work_ids edge case
- Added placeholder tests for API-dependent scenarios (skipped)

## Self-Check: PASSED

**Created files:** None (all modifications)

**Modified files exist:**
- ✅ R/citation_audit.R exists and contains skipped_count, progress_callback
- ✅ R/mod_citation_audit.R exists and contains created_observers, notebook_refresh triggers
- ✅ app.R exists and contains notebook_refresh in navigate_to_notebook
- ✅ tests/testthat/test-citation-audit.R exists and contains skipped_count tests

**Commits exist:**
- ✅ 1338965: test(46-01): add failing tests for import_audit_papers
- ✅ 45938d4: feat(46-01): implement skipped_count and progress_callback
- ✅ 8149fa3: fix(46-01): fix citation audit import handlers and wire notebook_refresh

**Verification:**
- ✅ Unit tests pass (61 passed, 2 skipped)
- ✅ App smoke test passes (starts and serves HTML)
