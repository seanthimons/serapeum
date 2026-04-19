---
title: "Replace hardcoded \"OpenRouter\" error messages with provider-agnostic text"
status: todo
type: task
priority: normal
tags:
  - pr-review
  - server
created_at: 2026-03-20T17:40:12Z
updated_at: 2026-03-25T21:44:21Z
---

**Source:** PR #162 review (round 1, item #6)

**Files:** `R/rag.R` lines 201, 301, 395, 571

**Problem:** Error messages throughout the RAG pipeline still say "OpenRouter API key not configured" but the system now supports multiple providers (local, custom endpoints). Users on non-OpenRouter providers will see misleading errors.

**Fix:** Replace hardcoded provider name with the actual provider name from config, e.g.:
```r
provider_name <- provider$name %||% "API"
sprintf("Error: %s key not configured. Please set your key in Settings.", provider_name)
```

<!-- migrated from beads: `serapeum-1774459567151-174-3aa1acec` | github: https://github.com/seanthimons/serapeum/issues/203 -->
