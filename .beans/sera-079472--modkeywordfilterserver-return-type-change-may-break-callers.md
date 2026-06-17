---
title: mod_keyword_filter_server return type change may break callers
status: completed
type: task
priority: high
tags:
  - pr-review
  - pre-existing
  - server
created_at: 2026-03-24T18:33:47Z
updated_at: 2026-04-07T16:49:56Z
---

**Source:** PR #253 review (round 1, Copilot finding)
**Severity:** MEDIUM
**File:** `R/mod_keyword_filter.R:321`

The module's return type changed from a single reactive to a list. Any existing callers that do `filtered <- mod_keyword_filter_server(...); filtered()` will break.

**Suggested fix:** Verify all call sites are updated. If backward compatibility is needed, consider returning the original reactive as the primary return value with accessors via attributes, or add a parameter defaulting to the previous behavior.

## Resolution

Already correct. The only caller (mod_search_notebook.R:979) destructures the list properly: $filtered_papers, $get_keyword_state, $set_keyword_state.

<!-- migrated from beads: `serapeum-1774459568268-221-079472cc` | github: https://github.com/seanthimons/serapeum/issues/255 -->
