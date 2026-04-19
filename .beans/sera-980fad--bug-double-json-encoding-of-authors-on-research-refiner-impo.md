---
title: "bug: double JSON encoding of authors on Research Refiner import"
status: completed
type: bug
priority: high
tags:
  -  critical
created_at: 2026-03-19T20:13:58Z
updated_at: 2026-03-24T18:36:50Z
---

## Severity: Critical

## Description

In `R/mod_research_refiner.R`, the import handler passes `p$authors` (already a JSON string stored in `refiner_results`) to `create_abstract()`, which calls `jsonlite::toJSON()` again. This produces double-encoded JSON like `["[\"Smith\",\"Jones\"]"]`, corrupting author data in the target notebook.

## Steps to reproduce

1. Run a Research Refiner scoring pass
2. Accept one or more papers
3. Import accepted papers into a notebook
4. Check the imported paper's author field in the database

## Expected behavior

Authors stored as a properly encoded JSON array, e.g. `["Smith", "Jones"]`.

## Fix

Parse the JSON string back to a vector before passing to `create_abstract()`, e.g.:
```r
authors <- jsonlite::fromJSON(p$authors)
create_abstract(con, target, p$paper_id, p$title, authors, ...)
```

## Found in

PR #161 review

<!-- migrated from beads: `serapeum-1774459566527-148-980fadcc` | github: https://github.com/seanthimons/serapeum/issues/177 -->
