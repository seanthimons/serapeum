---
title: Redundant role prefix in overview summary system prompt
status: todo
type: task
priority: normal
tags:
  - pr-review
  - server
created_at: 2026-03-22T15:32:34Z
updated_at: 2026-03-25T21:44:31Z
parent: sera-dv61
---

**Source:** PR #233 review (round 1)
**Severity:** LOW
**File:** `R/rag.R:727-728`

The sprintf format hardcodes "You are a research summarizer." before `get_effective_prompt(con, "summarize")`. If a user's custom prompt already includes a role declaration, the system prompt will have a redundant/conflicting role prefix.

**Suggested fix:** Let the effective prompt own the full system prompt content, or only add the role prefix when using the hardcoded default.

<!-- migrated from beads: `serapeum-1774459567898-205-9f7f9556` | github: https://github.com/seanthimons/serapeum/issues/236 -->
