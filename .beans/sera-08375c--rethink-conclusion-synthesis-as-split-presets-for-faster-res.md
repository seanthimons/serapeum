---
title: Rethink conclusion synthesis as split presets for faster responses
status: completed
type: feature
priority: high
created_at: 2026-02-13T22:42:00Z
updated_at: 2026-03-06T21:14:41Z
---

## Description

Break the monolithic "Conclusions" preset into separate focused prompts (e.g., "Research Conclusions", "Agreements & Gaps", "Future Directions") each hitting a smaller context window for faster responses. Current single-prompt 3-section synthesis is too slow with 10 chunks of context.

## Context

Identified during v2.1 Phase 19 — the conclusion synthesis generates a 3-section structured output from 10 chunks, causing near-timeout responses. Splitting into individual presets would reduce per-request context and enable streaming per-section.

## Resolution

The original 3-section Conclusions preset was slimmed to 2 sections (Research Conclusions + Agreements & Disagreements). The "Research Gaps & Future Directions" section was removed since Gap Analysis (#101) now covers that in depth. Search queries were refocused on conclusions/findings rather than gaps. This, combined with the earlier split of Summary/Key Points into Overview (#98), completes the rethinking of conclusion synthesis.

<!-- migrated from beads: `serapeum-1774459564861-71-08375c95` | github: https://github.com/seanthimons/serapeum/issues/88 -->
