---
title: "tech-debt: section_hint not encoded in PDF ragnar origins"
status: completed
type: task
priority: high
tags:
  - tech-debt
created_at: 2026-02-18T17:08:28Z
updated_at: 2026-02-22T18:43:35Z
---

## Problem

When PDFs are chunked and inserted into ragnar stores, the `origin` field is set without `section_hint` metadata. Only abstracts encode `section_hint` (via `encode_origin_metadata(..., section_hint = "general")`). This means section-targeted synthesis filtering cannot work on PDF chunks.

## Context

Identified during v3.0 milestone audit (phase 20/22 integration check). `chunk_with_ragnar()` in `R/_ragnar.R` builds chunk data frames without calling `encode_origin_metadata()` for PDF origins.

## Fix

Update `chunk_with_ragnar()` to use `encode_origin_metadata()` for PDF chunk origins, encoding appropriate `section_hint` values (e.g., based on document structure detection or defaulting to "general").

## Files

- `R/_ragnar.R` — `chunk_with_ragnar()` function

<!-- migrated from beads: `serapeum-1774459565425-98-93b27158` | github: https://github.com/seanthimons/serapeum/issues/118 -->
