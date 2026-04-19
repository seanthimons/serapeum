---
title: Slides healing/theme generation bypasses resolve_model_for_operation()
status: todo
type: task
priority: critical
tags:
  - pr-review
  - pre-existing
  - server
  - ui
created_at: 2026-03-23T21:14:43Z
updated_at: 2026-03-25T21:44:04Z
parent: sera-dv61
---

**Source:** PR #241 review (round 2) — Codex cross-audit finding
**Severity:** HIGH (pre-existing, exposed by config rename)
**File:** `R/mod_slides.R:805, 950`

Two code paths in the slides module directly read `get_setting(cfg, "defaults", "chat_model")` instead of using `resolve_model_for_operation()`:

```r
# Line 805 (healing path):
model <- get_setting(cfg, "defaults", "chat_model") %||% "google/gemini-3.1-flash-lite-preview"

# Line 950 (theme generation):
model <- get_setting(cfg, "defaults", "chat_model") %||% "google/gemini-3.1-flash-lite-preview"
```

Since `effective_config()` now uses `quality_model` instead of `chat_model`, these paths silently fall back to the hardcoded Gemini default, ignoring the user's configured model.

Other slide paths (lines 626, 1293, 1403) correctly use `resolve_model_for_operation()`.

**Suggested fix:** Replace both lines with:
```r
model <- resolve_model_for_operation(cfg, "slide_healing")  # or "slide_generation"
```

<!-- migrated from beads: `serapeum-1774459568221-219-1cff4b8c` | github: https://github.com/seanthimons/serapeum/issues/252 -->
