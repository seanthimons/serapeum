---
title: Heal flow sends base64-inlined QMD to LLM on second attempt
status: todo
type: task
priority: high
tags:
  - pr-review
  - server
created_at: 2026-03-21T21:45:59Z
updated_at: 2026-03-22T17:15:56Z
parent: sera-mgb9
---

## Context
Discovered during PR #163 round 3 review.

**File:** `R/mod_slides.R:609,678`

## Problem
After healing, `generation_state$qmd_content` is set to the post-processed text which includes base64 data URIs from `inline_figure_data_uris()` (line 678). If the user triggers a second heal attempt, line 609 sends this bloated string as `previous_qmd` to the LLM.

This wastes tokens/money and could exceed model context limits on presentations with many figures.

## Fix
Store a separate `qmd_content_raw` (pre-inline) for LLM round-trips. Only use the inlined version for rendering and download.

## Severity
MEDIUM — only affects second heal attempt (edge case). First generation and first heal both send clean QMD.

<!-- migrated from beads: `serapeum-1774459567583-192-4352f83f` | github: https://github.com/seanthimons/serapeum/issues/222 -->
