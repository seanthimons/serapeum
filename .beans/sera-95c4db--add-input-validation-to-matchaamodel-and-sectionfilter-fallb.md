---
title: Add input validation to match_aa_model() and section_filter fallback
status: todo
type: task
priority: high
tags:
  - db
  - pr-review
  - server
created_at: 2026-03-20T17:40:28Z
updated_at: 2026-03-22T17:15:52Z
parent: sera-cpjh
---

**Source:** PR #162 review (round 1, items #10, #11, #13)

**Files:**
- `R/api_artificialanalysis.R:158` — `match_aa_model()` doesn't validate NULL/NA/empty input
- `R/db.R:1043` — Section filter silently eliminates all results when `section_hint` column is missing (assigns "general" but filter may not include it)
- `R/api_artificialanalysis.R:67-97` — `get_aa_models()` NULL safety on `raw$models` access

**Fix:**
- Add early guard in `match_aa_model()`: `if (is.null(openrouter_id) || !nzchar(openrouter_id)) return(NULL)`
- Skip section filter when column doesn't exist instead of assigning default
- Use `raw[["models"]]` for safer NULL access

<!-- migrated from beads: `serapeum-1774459567248-178-95c4dba2` | github: https://github.com/seanthimons/serapeum/issues/207 -->
