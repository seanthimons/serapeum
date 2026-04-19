---
title: "feat: Literature Review Table (structured comparison matrix)"
status: completed
type: task
priority: high
created_at: 2026-02-15T21:07:00Z
updated_at: 2026-02-22T18:43:13Z
---

## Summary

Add a new AI output preset that generates a **structured comparison table** extracting and comparing key attributes across papers: methodology, sample size, findings, limitations, geographic focus, etc.

## Why

Literature reviews are the most time-consuming part of research (often 30-50% of project time). Current outputs (summary, key points, conclusions) produce narrative text but don't provide the **structured comparison** needed for systematic reviews or meta-analyses. Researchers manually copy-paste into Excel/Word tables — this automates that pain point.

## How it differs from existing outputs

- **Conclusions Synthesis** = narrative text connecting findings
- **Summary** = high-level overview
- **Literature Review Table** = structured data extraction in tabular format with explicit comparison columns

## Implementation notes

- Generate Markdown table from LLM response with consistent columns (Method, N, Results, Limitations, Country, etc.)
- Export as CSV/Markdown
- Add "Lit Review Table" preset button to document notebook
- Low hallucination risk — extractive task grounded in document content

## Complexity/Impact

- **Complexity:** Medium
- **Impact:** Very High
- **Risk:** Low (extractive, not generative)
- **Workflow stage:** Synthesis & Writing

## Related

- Part of epic: AI Output Overhaul

<!-- migrated from beads: `serapeum-1774459565096-82-d517e16c` | github: https://github.com/seanthimons/serapeum/issues/99 -->
