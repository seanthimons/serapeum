---
title: "feat: Argument Map / Claims Network preset"
status: completed
type: task
priority: high
created_at: 2026-02-15T21:07:38Z
updated_at: 2026-03-06T21:19:21Z
---

## Summary

Add a preset that extracts the **main claims/arguments** from each paper and maps relationships between them (supports, contradicts, extends). Formatted as a hierarchical outline with citations to source.

## Why

Understanding **argumentative structure** across papers is key for writing literature reviews and identifying theoretical debates. Current outputs summarize content but don't map **relationships between arguments**.

**Pain points solved:**
- "Which authors agree/disagree on this claim?"
- "How do these theories relate?"
- Structuring lit review by argument threads (not just topics)

## How it differs

- **Conclusions Synthesis** → summarizes findings as narrative
- **Argument Map** → extracts explicit claims and shows support/contradiction links per source

## Implementation notes

- Prompt: "For each source, extract 2-3 main claims. Then identify which claims from different sources support, contradict, or extend each other."
- Output: Hierarchical Markdown (Claim → Supporting evidence [Source A], Contradictory evidence [Source B])
- Higher complexity — requires multi-step reasoning from LLM
- Should include AI warning banner and explicit quotations for each claim

## Complexity/Impact

- **Complexity:** High
- **Impact:** Medium
- **Risk:** Medium-High (requires interpretation of argumentative relationships)
- **Workflow stage:** Synthesis

## Related

- Part of epic: AI Output Overhaul
- Benefits from higher-quality models (Claude Opus / similar)

<!-- migrated from beads: `serapeum-1774459565195-87-01c65a2c` | github: https://github.com/seanthimons/serapeum/issues/104 -->
