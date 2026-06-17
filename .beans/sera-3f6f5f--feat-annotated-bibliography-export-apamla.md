---
title: "feat: Annotated Bibliography export (APA/MLA)"
status: completed
type: task
priority: high
created_at: 2026-02-15T21:07:49Z
updated_at: 2026-03-06T21:19:22Z
---

## Summary

Add an export option that generates a formatted annotated bibliography: each entry includes a proper citation (APA/MLA/Chicago), a 150-200 word summary, and a critical evaluation (strengths, limitations, relevance).

## Why

Annotated bibliographies are **required assignments** in many graduate programs and common in grant proposals. Currently users can export BibTeX/CSV (citations only), but annotations require manual writing for each paper.

**Pain points solved:**
- "I need an annotated bib for my qualifying exam/grant/literature review"
- Manual summarization of 20+ papers is tedious
- Formatting consistency across entries

## How it differs

- **BibTeX export** → citations only, no annotations
- **Summary preset** → single synthesis across all papers, not per-paper
- **Annotated Bib** → individual entry per paper with citation + summary + evaluation

## Implementation notes

- Data flow:
  1. Iterate over papers in notebook
  2. Generate citation via existing `format_bibtex_entry()` or adapt for APA/MLA
  3. LLM summarizes each paper + evaluates (prompt: "Summarize in 150 words. Note 2 strengths, 2 limitations.")
  4. Combine into formatted document
- Export as Markdown/HTML (or Pandoc → Word/PDF if available)
- Add export option to Search Notebook ("Export as Annotated Bibliography")
- Add disclaimer: "AI-generated annotations — verify before submission"

## Complexity/Impact

- **Complexity:** Medium
- **Impact:** Medium
- **Risk:** Low (citations factual, summaries grounded in abstracts, evaluations low-stakes)
- **Workflow stage:** Writing & Production

## Related

- Part of epic: AI Output Overhaul
- Leverages existing citation export infrastructure (`utils_citation.R`)

<!-- migrated from beads: `serapeum-1774459565216-88-3f6f5fea` | github: https://github.com/seanthimons/serapeum/issues/105 -->
