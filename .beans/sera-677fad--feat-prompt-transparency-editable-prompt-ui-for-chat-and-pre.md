---
title: "feat: prompt transparency / editable prompt UI for chat and presets"
status: todo
type: task
priority: high
tags:
  - server
  - ui
created_at: 2026-03-19T15:53:04Z
updated_at: 2026-03-22T17:16:10Z
---

## Context

PR #156 included a first pass at a collapsible prompt editor in both the document notebook and search notebook modules. The implementation was incomplete and has been removed to keep the PR clean. This issue tracks the feature properly.

## Problem

Users have no visibility into what prompts are being sent to the LLM — neither for freeform chat (RAG queries) nor for synthesis presets. This makes it hard to understand, debug, or refine the AI's behavior.

## Proposed Feature

A collapsible "View/Edit Prompt" section in the chat input area that:

1. **Shows the assembled prompt** (system prompt + context + user question) before sending
2. **Allows editing** so users can refine instructions before execution
3. **Works for both chat and presets** — clicking a preset populates the editor with the preset instruction; clicking Send executes it through the correct pipeline

## Design Considerations

From the removed V1 implementation, key issues to solve:

- **Routing:** Edited presets must go through `generate_preset()`, not `rag_query()`. Store a `pending_preset` reactiveVal so Send knows which pipeline to use.
- **Retrieval quality:** Don't mix system prompt text into the retrieval query. Keep system prompt and user question as separate fields in the editor, or only expose the user-editable portion.
- **Both modules:** Wire up both `mod_document_notebook` and `mod_search_notebook` — the V1 had UI in search notebook but zero server logic.
- **JS handlers:** `populatePromptEditor` handler needs to be global (in `app.R`) or registered in both module UIs.

## References

- Removed in PR #156 (post-mortem item #6)
- Related to #60 (API query transparency — that issue covers verbose logging, this covers LLM prompt transparency)

<!-- migrated from beads: `serapeum-1774459566260-136-677fadcb` | github: https://github.com/seanthimons/serapeum/issues/164 -->
