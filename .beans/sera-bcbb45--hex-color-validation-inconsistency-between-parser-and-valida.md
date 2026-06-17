---
title: Hex color validation inconsistency between parser and validator
status: todo
type: task
priority: normal
tags:
  - pr-review
  - ui
created_at: 2026-03-22T03:35:09Z
updated_at: 2026-03-25T21:44:30Z
---

**Source:** PR #221 review (round 1, item 8)

**File:** `R/themes.R:374` vs `R/themes.R:269`

**Issue:** `validate_theme_colors()` accepts only 6-digit hex (`#RRGGBB`) via `grepl("^#[0-9A-Fa-f]{6}$", v)`, but `parse_scss_colors_full()` regex accepts 6-8 digits (`#RRGGBBAA`). An 8-digit hex (with alpha channel) would parse successfully from an SCSS file but then fail validation, creating an inconsistency.

**Fix:** Either accept 8-digit hex in both places or reject it in both. Since CSS alpha hex is rarely used in slide themes, restricting the parser to 6 digits is the simpler fix.

<!-- migrated from beads: `serapeum-1774459567827-202-bcbb45aa` | github: https://github.com/seanthimons/serapeum/issues/232 -->
