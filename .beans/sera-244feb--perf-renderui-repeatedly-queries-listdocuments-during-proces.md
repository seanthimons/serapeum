---
title: "perf: renderUI repeatedly queries list_documents() during processing"
status: todo
type: task
priority: high
tags:
  - db
  - performance
  - ui
created_at: 2026-03-19T17:21:40Z
updated_at: 2026-03-22T17:15:52Z
parent: sera-cpjh
---

## Description

In `R/mod_document_notebook.R` (~line 589), `output$document_list <- renderUI(...)` calls `list_documents(con(), nb_id)` on every render cycle. During streaming/processing, this causes repeated DB queries.

## Current behavior

Each time `doc_refresh()` triggers a re-render (which happens during chat streaming), `list_documents()` hits the database again.

## Expected behavior

Cache the document list in a `reactiveVal` and only refresh it when documents are actually added/removed — not on every render cycle.

## Fix suggestion

```r
doc_list <- reactiveVal(data.frame())

observe({
  req(con(), current_nb_id())
  doc_list(list_documents(con(), current_nb_id()))
}) |> bindEvent(doc_refresh())

output$document_list <- renderUI({
  docs <- doc_list()
  # ... render using cached docs
})
```

## Context

Found during PR #156 review. Not a correctness issue — performance optimization for larger notebooks.

<!-- migrated from beads: `serapeum-1774459566327-139-244feb9a` | github: https://github.com/seanthimons/serapeum/issues/167 -->
