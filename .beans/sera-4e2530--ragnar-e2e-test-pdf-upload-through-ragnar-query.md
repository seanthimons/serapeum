---
title: "ragnar: E2E test — PDF upload through ragnar query"
status: completed
type: task
priority: high
created_at: 2026-02-15T20:45:42Z
updated_at: 2026-02-18T17:08:14Z
---

## Context
Part of ragnar migration Phase 6 (parent: #77).

## Description
Create an end-to-end integration test that validates the full PDF pipeline through ragnar:

1. Upload a small test PDF
2. Verify chunks are created via `chunk_with_ragnar()`
3. Verify chunks are inserted into the ragnar store
4. Verify ragnar index is built
5. Query the ragnar store with a relevant question
6. Confirm results are returned with correct source attribution (doc_name, page_number)

## Notes
- Requires a small test PDF in `testdata/`
- Requires an API key for embedding (may need mock/fixture for CI)
- Should test both the happy path and fallback behavior

<!-- migrated from beads: `serapeum-1774459565013-78-4e253043` | github: https://github.com/seanthimons/serapeum/issues/95 -->
