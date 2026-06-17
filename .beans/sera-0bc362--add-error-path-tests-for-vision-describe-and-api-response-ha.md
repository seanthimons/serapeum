---
title: Add error path tests for vision describe and API response handling
status: todo
type: task
priority: normal
tags:
  - pr-review
  - server
  - test
created_at: 2026-03-21T00:48:49Z
updated_at: 2026-03-25T21:44:26Z
---

From PR #163 review (round 1), items #14-15:

- **Missing error path tests** (`tests/testthat/test-vision-describe.R`) — Only happy-path tests for `parse_vision_response()`. No tests for malformed JSON, empty responses, or invalid image data.
- **API response bounds check** (`R/api_openrouter.R:60-67`) — `resp_body$choices[[1]]$message` accessed without checking `choices` is non-empty. Add validation and corresponding test.

<!-- migrated from beads: `serapeum-1774459567560-191-0bc36291` | github: https://github.com/seanthimons/serapeum/issues/220 -->
