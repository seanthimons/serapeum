---
title: "feat: Research Question Generator preset"
status: completed
type: task
priority: high
created_at: 2026-02-15T21:07:20Z
updated_at: 2026-02-22T18:43:17Z
---

## Summary

Add a preset that generates **testable research questions** derived from the literature, organized by type (descriptive, comparative, causal, exploratory). Each question includes brief rationale tied to gaps/findings in the corpus.

## Why

Early-stage researchers (PhD students, new faculty) struggle to formulate **focused, answerable research questions**. This bridges the gap between "I read papers" and "I have a study to propose."

**Pain points solved:**
- "What should I research next?"
- "How do I turn these findings into a research design?"
- Creative block after literature review

## Implementation notes

- Best implemented after Gap Analysis — converts identified gaps into concrete questions
- Prompt: generate 8-10 specific, testable questions with type classification, rationale, and feasibility notes
- Medium hallucination risk — generative but grounded in real source gaps
- Could be a sub-option after Gap Analysis or standalone preset

## Complexity/Impact

- **Complexity:** Medium
- **Impact:** High
- **Risk:** Medium (generative but grounded in gaps from real sources)
- **Workflow stage:** Discovery & Research Design

## Related

- Part of epic: AI Output Overhaul
- Depends on or benefits from Gap Analysis Report

<!-- migrated from beads: `serapeum-1774459565155-85-cd1c0ea9` | github: https://github.com/seanthimons/serapeum/issues/102 -->
