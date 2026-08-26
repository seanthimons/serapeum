---
# serapeum-cqox
title: 'fix: preserve OpenRouter 404 response reason'
status: completed
type: bug
priority: normal
tags:
    - openrouter
    - errors
created_at: 2026-08-26T21:00:52Z
updated_at: 2026-08-26T21:00:52Z
---

OpenRouter 404 responses were collapsed into a misleading endpoint-changed message. Parse the httr2 response body and show the actual API error reason, with an actionable model/provider fallback when no JSON reason is present. Verification: test-search-consolidation.R passes 20 assertions; one package-build warning.
