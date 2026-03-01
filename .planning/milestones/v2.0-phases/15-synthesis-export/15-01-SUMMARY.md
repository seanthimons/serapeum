---
phase: 15-synthesis-export
plan: 01
subsystem: synthesis-export
tags: [export, chat, markdown, html, ui]
dependency_graph:
  requires: []
  provides: [chat-export-markdown, chat-export-html]
  affects: [document-notebook, search-notebook]
tech_stack:
  added: [commonmark]
  patterns: [download-handlers, export-formatters, utf8-bom]
key_files:
  created:
    - path: R/utils_export.R
      purpose: Chat export formatters for Markdown and HTML
      exports: [format_chat_as_markdown, format_chat_as_html]
  modified:
    - path: R/mod_document_notebook.R
      changes: Added timestamp to messages, export dropdown UI, download handlers
    - path: R/mod_search_notebook.R
      changes: Added timestamp to messages, export dropdown UI, download handlers
decisions:
  - summary: "Add timestamp field to all messages for export metadata"
    rationale: "Timestamps provide context and traceability for exported conversations"
  - summary: "Use writeBin with UTF-8 BOM for HTML, plain UTF-8 for Markdown"
    rationale: "BOM ensures browser compatibility for HTML; Markdown editors handle UTF-8 natively"
  - summary: "Embed CSS in HTML export (no external dependencies)"
    rationale: "Standalone HTML files work in any browser without network access"
  - summary: "Use commonmark library for Markdown to HTML conversion"
    rationale: "Reliable, well-maintained, supports extensions and smart typography"
metrics:
  duration_minutes: 3
  tasks_completed: 2
  files_created: 1
  files_modified: 2
  commits: 2
  completed_at: "2026-02-12"
---

# Phase 15 Plan 01: Chat Export to Markdown and HTML Summary

**One-liner:** Users can export chat conversations as Markdown or HTML files with timestamps and role labels from both document and search notebooks.

## What Was Built

Added chat export functionality to both document and search notebooks, enabling users to download their AI assistant conversations in two formats:

1. **Markdown Export (.md)**: Clean text format with headers, timestamps, and message content
2. **HTML Export (.html)**: Standalone browser-viewable file with embedded CSS styling

Both formats include:
- Export timestamp
- User/Assistant role labels
- Message timestamps (when available)
- Full conversation content
- Graceful handling of empty conversations

## Implementation Details

### Export Formatters (R/utils_export.R)

Created two exported functions:

**format_chat_as_markdown(messages, notebook_name = NULL)**
- Accepts list of message objects with role, content, timestamp fields
- Generates clean Markdown with headers, timestamps, and content
- Handles missing timestamps gracefully (older messages without timestamp field)
- Returns "No messages" placeholder for empty conversations

**format_chat_as_html(messages, notebook_name = NULL)**
- Calls format_chat_as_markdown() then converts to HTML using commonmark library
- Wraps in standalone HTML document with embedded CSS
- System font stack, max-width 800px, light background
- No external dependencies (works offline in any browser)

### Message Timestamps

Added `timestamp = Sys.time()` to all message creation points:
- Document notebook: send handler and preset handler
- Search notebook: send handler

Existing message rendering code only reads $role and $content, so adding $timestamp doesn't break rendering (R lists ignore extra fields).

### UI Changes

**Document Notebook:**
- Added Export dropdown in chat card header (next to preset buttons)
- Dropdown contains Markdown and HTML download links
- Uses btn-group-sm for consistent sizing

**Search Notebook:**
- Added Export dropdown in offcanvas chat header (before close button)
- Wrapped header elements in flex container for proper alignment
- dropdown-menu-end ensures dropdown opens left-aligned

### Download Handlers

Both modules implement identical downloadHandler patterns:
- Markdown: Uses writeBin with charToRaw for reliable UTF-8 on Windows
- HTML: Adds UTF-8 BOM (\xEF\xBB\xBF) for browser compatibility
- Filenames: chat-YYYY-MM-DD.md / chat-YYYY-MM-DD.html

## Deviations from Plan

None - plan executed exactly as written.

## Testing Results

1. App loads without errors
2. Export formatters produce correct Markdown and HTML output
3. Timestamps appear on all newly created messages
4. Download handlers ready for manual testing (requires running app)

## Success Criteria Verification

- [x] R/utils_export.R exists with format_chat_as_markdown() and format_chat_as_html()
- [x] Both functions are callable and handle empty messages
- [x] Document notebook chat header shows Export dropdown with two options
- [x] Search notebook offcanvas header shows Export dropdown with two options
- [x] Timestamps added to all message creation in both modules
- [x] HTML export includes DOCTYPE, embedded CSS, UTF-8 meta tag
- [x] Markdown export format includes headers, timestamps, role labels
- [x] App loads successfully without errors

## Key Decisions

1. **Timestamp field addition**: Added to all messages as optional metadata (doesn't break existing rendering)
2. **UTF-8 encoding strategy**: BOM for HTML (browser compatibility), plain UTF-8 for Markdown (editor native support)
3. **Standalone HTML**: Embedded CSS ensures files work offline in any browser
4. **Export filename format**: Date-based (chat-YYYY-MM-DD.ext) for clarity and sorting

## Files Changed

**Created:**
- R/utils_export.R (147 lines) - Export formatters

**Modified:**
- R/mod_document_notebook.R - Export UI + handlers + timestamps
- R/mod_search_notebook.R - Export UI + handlers + timestamps

## Commits

- 55e51ae: feat(15-01): add chat export formatters and timestamps
- 37034e5: feat(15-01): add chat export UI and download handlers

## Self-Check: PASSED

**Created files:**
```
FOUND: R/utils_export.R
```

**Commits:**
```
FOUND: 55e51ae
FOUND: 37034e5
```

All artifacts verified.
