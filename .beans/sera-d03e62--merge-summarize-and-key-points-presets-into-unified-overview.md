---
title: Merge Summarize and Key Points presets into unified Overview output
status: completed
type: task
priority: high
created_at: 2026-02-15T21:06:50Z
updated_at: 2026-02-22T18:43:11Z
---

## Problem

The Summarize and Key Points presets have significant overlap — both target "the most important content" from documents, differing only in output format (prose vs. bullets). This creates:

- **Decision paralysis** for users ("which button do I click?")
- **Maintenance burden** (two prompts to tune, two features to document)
- **No unique value** — summarization is the most commodified AI capability; every competing tool offers it

### Evidence from debate analysis

| Preset | Prompt Target | Format |
|--------|--------------|--------|
| Summarize | "main themes, key findings, important conclusions" | Prose paragraphs |
| Key Points | "most important facts, findings, arguments, conclusions" | Bulleted list |

The semantic overlap is ~90%. The only meaningful difference is output format.

## Proposal

Merge into a single **"Overview"** preset that produces:
1. A brief narrative summary (2-3 paragraphs)
2. Followed by structured key points (bulleted)
3. With **inline citations** back to source documents/pages

This gives users the best of both formats in one click, eliminates redundancy, and adds the most-requested missing feature (source attribution).

## Priority

**High** — reduces UI clutter, improves output quality, and addresses the #1 gap across all presets (lack of citations).

## Related

- Part of epic: AI Output Overhaul
- #88 (Rethink conclusion synthesis)

<!-- migrated from beads: `serapeum-1774459565077-81-d03e6244` | github: https://github.com/seanthimons/serapeum/issues/98 -->
