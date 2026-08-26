---
# serapeum-nvnv
title: 'fix: existing Ragnar store opens read-only during PDF embedding'
status: completed
type: bug
priority: high
tags:
    - embeddings
    - pdf
created_at: 2026-08-26T20:44:49Z
updated_at: 2026-08-26T20:46:42Z
---

Sequential PDF uploads save document rows, but uploads after the first fail during ragnar_store_insert because ragnar_store_connect() defaults to read_only = TRUE. Reopen existing stores with read_only = FALSE in write paths and cover with a regression test.



Verification: R/mod_document_notebook.R parses successfully; tests/testthat/test-ragnar.R passes 34 assertions (1 fixture-dependent skip, 2 package-build warnings). The index-status action now keeps rebuild available whenever indexed count is incomplete.
