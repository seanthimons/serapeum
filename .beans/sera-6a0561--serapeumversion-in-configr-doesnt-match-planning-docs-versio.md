---
title: "SERAPEUM_VERSION in config.R doesn't match planning docs version"
status: todo
type: task
priority: normal
tags:
  - pr-review
  - pre-existing
  - server
created_at: 2026-03-24T18:33:57Z
updated_at: 2026-03-25T21:44:37Z
---

**Source:** PR #253 review (round 1, Copilot finding)
**Severity:** LOW
**File:** `R/config.R:2`

`SERAPEUM_VERSION` is set to 18.0.0 but planning docs (`.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`) still reference v16.0. This could cause user-facing inconsistency (e.g., About page "What's New" section).

**Suggested fix:** Align the version across config and planning docs after the current milestone ships.

<!-- migrated from beads: `serapeum-1774459568365-225-6a05613a` | github: https://github.com/seanthimons/serapeum/issues/259 -->
