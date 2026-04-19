---
title: Malformed JSON test assertion too permissive in test-rag-citations.R
status: todo
type: task
priority: normal
tags:
  - pr-review
  - server
  - test
created_at: 2026-03-23T18:59:38Z
updated_at: 2026-03-25T21:44:32Z
parent: sera-dv61
---

**Source:** PR #241 review (round 1)
**Severity:** MEDIUM
**File:** `tests/testthat/test-rag-citations.R:71-76`

Test expects `result %in% c("Unknown (2023)", "Fallback")` for malformed JSON input. This accepts two completely different behaviors without distinguishing which is correct.

**Suggested fix:** Pin to the actual expected output for malformed JSON.

<!-- migrated from beads: `serapeum-1774459568081-213-d1160ef3` | github: https://github.com/seanthimons/serapeum/issues/246 -->
