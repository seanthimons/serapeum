---
title: "Chat UX: busy spinners, progress messages, modal messaging for long operations"
status: todo
type: feature
priority: high
tags:
  - server
  - ui
created_at: 2026-02-13T22:41:56Z
updated_at: 2026-03-29T21:26:00Z
---

## Description

Replace grey-out processing state in chat windows with proper busy spinners (grey-out implies error). Add progress status messages for long LLM requests and modal messaging for synthesis operations.

## Context

Identified during v2.1 conclusion synthesis — the grey-out state during LLM processing looks like an error rather than a loading indicator. Long synthesis requests (10+ seconds) give no feedback.

## Proposed Changes

- Replace grey-out with animated busy spinners in chat windows
- Show progress status messages during long LLM requests
- Add modal messaging for synthesis operations
- Consider streaming responses for real-time feedback

<!-- migrated from beads: `serapeum-1774459564836-70-5f7b13c6` | github: https://github.com/seanthimons/serapeum/issues/87 -->
