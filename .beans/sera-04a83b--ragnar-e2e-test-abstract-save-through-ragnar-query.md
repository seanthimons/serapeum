---
title: "ragnar: E2E test — abstract save through ragnar query"
status: completed
type: task
priority: high
created_at: 2026-02-15T20:45:46Z
updated_at: 2026-02-18T17:08:18Z
---

## Context
Part of ragnar migration Phase 6 (parent: #77).

## Description
Create an end-to-end integration test that validates the abstract pipeline through ragnar:

1. Save an abstract to a notebook
2. Verify it is inserted into the ragnar store with `abstract:{id}` origin
3. Verify ragnar index is built
4. Query the ragnar store with a relevant question
5. Confirm results are returned with correct abstract title (not "[Abstract]")
6. Confirm notebook-scoped filtering works (results only from the target notebook)

## Notes
- Test notebook-scoped filtering specifically — this is the weakest part of the current implementation (over-fetch + post-filter in `search_chunks_hybrid`)
- Should verify that abstract IDs match correctly across the main DB and ragnar store

<!-- migrated from beads: `serapeum-1774459565034-79-04a83b9c` | github: https://github.com/seanthimons/serapeum/issues/96 -->
