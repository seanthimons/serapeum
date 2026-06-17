---
title: "feat: recursive abstract searching"
status: completed
type: task
priority: high
created_at: 2026-02-05T00:14:37Z
updated_at: 2026-03-17T19:40:52Z
---

Sometimes, the search query isn't perfect. Need a way of kicking abstracts out until the "perfect" set of abstracts is available. 

Ideal implementation would be embedding to check closeness with desired search query, remove abstract until {k} number of abstracts is found. 

Need to assess embedding costs per abstract vs bulk; would require many large request to OpenAlex to achieve large number of {k} abstracts.

<!-- migrated from beads: `serapeum-1774459563446-8-0d1fcaf8` | github: https://github.com/seanthimons/serapeum/issues/11 -->
