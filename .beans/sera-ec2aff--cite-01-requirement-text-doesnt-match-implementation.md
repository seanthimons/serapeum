---
title: "CITE-01 requirement text doesn't match implementation"
status: todo
type: task
priority: normal
tags:
  - pr-review
  - server
created_at: 2026-03-22T03:35:00Z
updated_at: 2026-03-25T21:44:28Z
---

**Source:** PR #221 review (round 1, item 6)

**File:** `.planning/REQUIREMENTS.md:36`

**Issue:** CITE-01 says `[Author, p.X]` but the implemented prompts use `(Author, Year, p.X)` for prose outputs and `^[Author et al., Year, p.X]` for slides. The requirement text should be updated to match the actual citation format.

**Fix:** Update line 36 to:
```
- [x] **CITE-01**: All AI preset system prompts instruct the LLM to cite with page numbers (prose: `(Author, Year, p.X)`; slides: `^[Author et al., Year, p.X]`)
```

<!-- migrated from beads: `serapeum-1774459567782-200-ec2aff8d` | github: https://github.com/seanthimons/serapeum/issues/230 -->
