# Phase 66: Error Handling - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 66-error-handling
**Areas discussed:** Error display strategy, Shared helper location, Modal dismissal on error
**Mode:** Auto (--auto flag)

---

## Error Display Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Toast notifications (show_error_toast) | Separate error UX from chat content, consistent with search notebook | ✓ |
| Inline chat messages | Current doc notebook pattern — error appears as assistant message | |
| Modal error panel | Show error within the synthesis modal itself | |

**User's choice:** [auto] Toast notifications via show_error_toast (recommended default)
**Notes:** Search notebook already uses this pattern consistently across 6+ handlers. Document notebook is the outlier returning errors as chat content.

---

## Shared Helper Location

| Option | Description | Selected |
|--------|-------------|----------|
| Move to shared utility file | Extract show_error_toast and classify_api_error to R/ utility | ✓ |
| Duplicate in both modules | Copy the functions into mod_document_notebook.R | |
| Keep in search notebook, import | Use source() or namespace to access from doc notebook | |

**User's choice:** [auto] Move to shared utility (recommended default)
**Notes:** Currently show_error_toast only exists in mod_search_notebook.R. Duplication violates DRY; Shiny module convention is shared utilities in R/ directory.

---

## Modal Dismissal on Error

| Option | Description | Selected |
|--------|-------------|----------|
| Dismiss modal first, then toast (Pattern D) | removeModal() before showNotification() | ✓ |
| CSS z-index override | Force notification panel above modal via z-index | |
| In-modal error display | Show error within the modal instead of as toast | |

**User's choice:** [auto] Pattern D — modal-then-notify (recommended default)
**Notes:** Documented in FEATURES.md Pattern D. CSS override rejected per PITFALLS.md — risks destabilizing Catppuccin theme z-index layering.

---

## Claude's Discretion

- Exact file location for shared error utilities
- Whether classify_api_error needs adaptation for document notebook context
- Whether to show a brief placeholder in chat alongside the error toast

## Deferred Ideas

None
