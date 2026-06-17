---
title: "feat: Methodology Extractor preset"
status: completed
type: task
priority: high
created_at: 2026-02-15T21:07:06Z
updated_at: 2026-03-06T20:40:44Z
---

## Summary

Add a preset that isolates and extracts research methods from PDFs: study design, data sources, sample characteristics, statistical methods, and tools/instruments used. Formatted as a structured report with citations.

## Why

When planning research design, scholars need to understand **how** previous studies were conducted, not just **what** they found. Current presets focus on findings/conclusions. Methodology details are buried in full text and hard to extract manually.

**Pain points solved:**
- "What methods did similar studies use?"
- "What sample sizes are typical in this field?"
- "Which statistical tests are standard for this research question?"

## Implementation notes

- Leverage existing `section_hint` filtering (already used for Conclusions preset) to target Methods sections
- Structured breakdown: Study Design | Sample | Measures | Analysis
- Add "Extract Methods" button to document notebook
- Low hallucination risk — methods sections are factual and explicitly stated

## Complexity/Impact

- **Complexity:** Medium
- **Impact:** High
- **Risk:** Low
- **Workflow stage:** Reading & Research Design

## Related

- Part of epic: AI Output Overhaul
- Reuses section-aware RAG from Conclusions preset

<!-- migrated from beads: `serapeum-1774459565113-83-00fe1139` | github: https://github.com/seanthimons/serapeum/issues/100 -->
