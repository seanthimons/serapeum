---
title: API key NA guard not applied to embedding provider check
status: completed
type: bug
priority: high
created_at: 2026-04-07T17:17:22Z
updated_at: 2026-04-08T16:22:20Z
---

R/mod_search_notebook.R:2875 still uses nchar(provider_or$api_key) == 0 without is.na() guard. Apply same fix as mod_query_builder.R:82. GitHub #282

## Resolution

Fixed in 248a55b

<!-- migrated from beads: `serapeum-brrm` -->
