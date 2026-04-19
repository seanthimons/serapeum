---
title: "Figure manifest: NA rendered as literal string in LLM prompt"
status: todo
type: task
priority: normal
tags:
  - pr-review
  - server
  - ui
created_at: 2026-03-21T21:46:05Z
updated_at: 2026-03-25T21:44:27Z
parent: sera-mgb9
---

## Context
Discovered during PR #163 round 3 review.

**File:** `R/slides.R:683`

## Problem
`fig$figure_label %||% "Untitled"` uses `%||%` which only handles NULL, not NA. When `figure_label` is `NA_character_`, it renders as the literal string `"NA"` in the LLM manifest prompt. Compare with the correct `!is.na()` check at line 692-694 for `presentation_hint`.

## Fix
Replace `fig$figure_label %||% "Untitled"` with `if (is.na(fig$figure_label)) "Untitled" else fig$figure_label`. Same for `fig$doc_name %||% "unknown"` at line 684.

## Severity
LOW — cosmetic impact on LLM prompt quality for figures without matched captions.

<!-- migrated from beads: `serapeum-1774459567634-194-198a1795` | github: https://github.com/seanthimons/serapeum/issues/224 -->
