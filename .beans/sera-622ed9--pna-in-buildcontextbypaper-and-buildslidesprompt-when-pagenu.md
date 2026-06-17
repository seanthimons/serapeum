---
title: p.NA in build_context_by_paper() and build_slides_prompt() when page_number is NA
status: completed
type: task
priority: high
tags:
  - pr-review
  - pre-existing
created_at: 2026-03-22T03:13:34Z
updated_at: 2026-03-24T18:36:40Z
---

## Description

`build_context_by_paper()` at `R/rag.R:845` and `build_slides_prompt()` at `R/slides.R:56` use `sprintf("[p.%d, ...]", page_number)` without checking for `NA_integer_`. When `page_number` is `NA` (common for abstracts and papers without PDF extraction), the output includes literal `[p.NA, ...]` text that gets fed to the LLM, producing garbled citations.

This is the same class of bug fixed in `build_context()` at `R/rag.R:38` in PR #221, but in two other functions.

**Affected code paths:**
- `build_context_by_paper()` → used by deep presets: lit_review, methodology, gap_analysis
- `build_slides_prompt()` → used by slide generation

**Fix:** Add the same `!isTRUE(is.na(page_number))` guard used in `build_context()`, falling back to a format without page number.

Discovered during PR #221 review (round 2).

<!-- migrated from beads: `serapeum-1774459567758-199-622ed9e2` | github: https://github.com/seanthimons/serapeum/issues/229 -->
