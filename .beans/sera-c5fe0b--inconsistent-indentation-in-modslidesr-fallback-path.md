---
title: Inconsistent indentation in mod_slides.R fallback path
status: todo
type: task
priority: normal
tags:
  - pr-review
  - server
created_at: 2026-03-22T03:35:04Z
updated_at: 2026-03-25T21:44:29Z
---

**Source:** PR #221 review (round 1, item 7)

**File:** `R/mod_slides.R:1231`

**Issue:** `addResourcePath()` has 6 spaces of indentation while surrounding lines have 8. Not a parse error in R (braces-based language), but misleading to readers scanning the fallback healing path.

**Fix:** Align indentation to 8 spaces to match surrounding code.

<!-- migrated from beads: `serapeum-1774459567805-201-c5fe0b99` | github: https://github.com/seanthimons/serapeum/issues/231 -->
