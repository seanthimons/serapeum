---
title: "feat: Expanded progress modal for citation network building with stop button"
status: completed
type: feature
priority: high
created_at: 2026-02-12T19:43:10Z
updated_at: 2026-02-13T22:41:27Z
---

## Description

When building a citation network, the current progress indicator is a small spinner text near the Build button. For complex graphs (high node caps, multiple hops, both directions), the build process takes a long time with no visibility into what's happening.

## Requested Behavior

Replace the small spinner with a larger, central modal dialog that shows:
- **Detailed progress steps** (e.g., "Fetching seed paper...", "Hop 1: fetching citing papers for W123...", "Hop 2: expanding 25 frontier papers...", "Discovering cross-links...")
- **Progress bar** with current stage and paper count
- **Stop/Cancel button** to abort the build mid-process and keep partial results
- **Console-style log** showing individual API calls and timing for diagnosing slowdowns

## Technical Context

- `fetch_citation_network()` already accepts a `progress_callback` parameter
- The callback receives `(message, fraction)` but is currently only wired to `withProgress()`
- Shiny `modalDialog` with `renderUI` could show a live-updating log
- Need to support cancellation (e.g., via a reactive flag checked between API calls)

## Labels

- `enhancement`
- `ui`
- `citation-network`

<!-- migrated from beads: `serapeum-1774459564727-65-1c6b41cf` | github: https://github.com/seanthimons/serapeum/issues/80 -->
