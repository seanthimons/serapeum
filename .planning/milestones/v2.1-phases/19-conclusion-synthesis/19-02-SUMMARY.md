---
phase: 19-conclusion-synthesis
plan: 02
subsystem: notebook-ui
tags: [ui, presets, disclaimers, synthesis, chat]

dependency_graph:
  requires: [19-01-section-metadata-backend, generate-conclusions-preset]
  provides: [conclusions-preset-button-document, conclusions-preset-button-search, ai-disclaimer-banner]
  affects: [mod-document-notebook, mod-search-notebook]

tech_stack:
  added: [conclusions-preset-ui, ai-disclaimer-rendering]
  patterns: [preset-type-tagging, conditional-disclaimer-rendering]

key_files:
  created: []
  modified:
    - R/mod_document_notebook.R
    - R/mod_search_notebook.R
    - R/rag.R

decisions:
  - id: direct-db-fallback-for-synthesis
    summary: "Add direct DB query fallback when hybrid search returns empty"
    rationale: "Hybrid search relies on ragnar + section_hint filtering which returns empty for pre-migration data"
    impact: "Conclusions work on existing notebooks without ragnar or section_hint data"

  - id: consistent-button-styling
    summary: "Use btn-outline-primary instead of btn-outline-success for conclusions button"
    rationale: "All other preset buttons use btn-outline-primary; green stood out inconsistently"
    impact: "Visual consistency across preset button group"

  - id: chunk-limit-10-fallback
    summary: "Limit direct DB fallback to 10 chunks with DESC ordering"
    rationale: "20 chunks caused LLM timeout; 10 chunks with chunk_index DESC prefers later document sections"
    impact: "Prevents 120s timeout while biasing toward conclusion-bearing content"

metrics:
  duration: ~600 seconds (including human verification)
  tasks_completed: 2
  files_modified: 3
  commits: 4
  bug_fixes: 3 (hybrid search fallback, timeout, button color)
  completed_date: 2026-02-13
---

# Phase 19 Plan 02: Conclusions Preset UI with AI Disclaimers Summary

**One-liner:** Conclusions preset buttons in both notebook types with AI disclaimer banners and robust fallback retrieval

## What Was Built

Added user-facing conclusion synthesis feature to both notebook modules with prominent AI-generated content disclaimers.

**Document Notebook:**
- "Conclusions" preset button (microscope icon, blue outline) in chat header alongside existing presets
- Handler calls `generate_conclusions_preset()` with `notebook_type = "document"`
- Synthesis responses tagged with `preset_type = "conclusions"` for disclaimer detection

**Search Notebook:**
- "Conclusions" preset button in offcanvas chat panel above messages area
- Handler calls `generate_conclusions_preset()` with `notebook_type = "search"`
- Uses search notebook error handling pattern (show_error_toast + classify_api_error)

**AI Disclaimer Banner:**
- Bootstrap `alert-warning` with triangle-exclamation icon
- Text: "AI-Generated Content - Verify all claims against original sources before use"
- Rendered above synthesis content, non-dismissible
- Only appears on synthesis responses (detected via `preset_type` field)
- Regular chat messages render normally without disclaimer

## Deviations from Plan

### Bug Fixes During Verification

**1. Hybrid search returning empty for pre-migration data**
- **Issue:** `search_chunks_hybrid` with section_filter returned 0 results (all chunks had `section_hint = 'general'`), and the fallback without filter also returned empty when ragnar unavailable
- **Fix:** Added direct DB query fallback matching `generate_preset` pattern
- **Commit:** eb1520d

**2. LLM request timeout with 20 chunks**
- **Issue:** 20 chunks in direct fallback produced too much context, causing 120s timeout
- **Fix:** Reduced to 10 chunks, ordered by `chunk_index DESC` to prefer later sections
- **Commit:** 5bb83b3

**3. Green button inconsistency**
- **Issue:** Plan specified `btn-outline-success` (green) but all other presets use `btn-outline-primary` (blue)
- **Fix:** Changed both modules to `btn-outline-primary`
- **Commit:** 78a8c45

## Verification Results

Human verification passed:
- ✅ Conclusions button visible in document notebook chat header
- ✅ Conclusions button visible in search notebook offcanvas chat
- ✅ Synthesis generates with research conclusions and future directions
- ✅ AI disclaimer banner appears above synthesis content
- ✅ Regular chat messages do not show disclaimer
- ✅ Cost logged for synthesis operations

## Known Issues (Added to TODO)

- Synthesis response is slow due to large context + complex 3-section output format
- TODO added: Rethink as split presets (separate Research Conclusions, Agreements & Gaps, Future Directions buttons)
- TODO added: Chat UX improvements (busy spinners, progress messages)

## Self-Check: PASSED

All artifacts verified present and functional.
