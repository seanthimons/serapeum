---
title: "epic: AI Output Overhaul"
status: completed
type: epic
priority: high
tags:
  - epic
created_at: 2026-02-15T21:08:15Z
updated_at: 2026-03-06T21:19:24Z
---

## Overview

Comprehensive overhaul of Serapeum's AI-generated outputs based on structured debate analysis of the current preset system. The debate identified significant overlap between existing presets, a critical gap (no inline citations), and 8 high-value new outputs to add.

## Key findings from debate

1. **Summarize and Key Points overlap ~90%** — merge into a single "Overview" preset (high priority)
2. **Conclusions Synthesis is the crown jewel** — strongest implementation, keep and enhance
3. **Slideshow Generation is the key differentiator** — keep as-is
4. **No presets include inline citations** — the single most important cross-cutting improvement
5. **Missing outputs identified** — 8 new outputs ranked by researcher value

## Sub-issues

### High Priority — Fix existing outputs
- [x] #88 — Rethink conclusion synthesis as split presets for faster responses
- [ ] #98 — Merge Summarize + Key Points into unified Overview output

### New Output Presets (ranked by value)
- [ ] #99 — Literature Review Table (structured comparison matrix) — **Very High impact**
- [ ] #100 — Methodology Extractor — **High impact, reuses existing RAG**
- [ ] #101 — Gap Analysis Report — **High impact, extends Conclusions**
- [ ] #102 — Research Question Generator — **High impact**
- [ ] #103 — Citation Audit (no LLM, pure data) — **High impact, very low risk**
- [ ] #104 — Argument Map / Claims Network — **Medium impact, higher complexity**
- [ ] #105 — Annotated Bibliography export — **Medium impact**
- [ ] #106 — Teaching Materials Generator — **Medium impact**

## Suggested implementation order

1. **Quick wins:** #98 (merge presets), #103 (citation audit — no LLM needed)
2. **High value:** #99 (lit review table), #100 (methodology extractor)
3. **Extensions:** #101 (gap analysis), #102 (research questions)
4. **Lower priority:** #104 (argument map), #105 (annotated bib), #106 (teaching materials)

## Cross-cutting improvement

All presets should add **inline citations back to source documents/pages** — this was identified as the #1 gap across every existing output.

<!-- migrated from beads: `serapeum-1774459565258-90-afc091bf` | github: https://github.com/seanthimons/serapeum/issues/107 -->
