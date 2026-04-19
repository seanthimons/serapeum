---
title: Refiner API error-path tests are placeholders with dead mock code
status: todo
type: task
priority: high
tags:
  - pr-review
  - server
  - test
created_at: 2026-03-23T18:59:36Z
updated_at: 2026-03-23T19:01:28Z
parent: sera-dv61
---

**Source:** PR #241 review (round 1)
**Severity:** MEDIUM
**File:** `tests/testthat/test-refiner.R:156-182`

Mock functions at lines 158-166 are assigned to local variables but never wired into the test. Tests only validate return structure with empty seeds, not actual error accumulation on API failure.

**Suggested fix:** Either properly mock with `local_mocked_bindings()` to test error paths, or rename tests to "return structure with empty seeds" to avoid false confidence.

<!-- migrated from beads: `serapeum-1774459568059-212-2b0bd8b8` | github: https://github.com/seanthimons/serapeum/issues/245 -->
