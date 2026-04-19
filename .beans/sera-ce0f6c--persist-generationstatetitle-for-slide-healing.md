---
title: Persist generation_state$title for slide healing
status: todo
type: task
priority: critical
tags:
  - pr-review
  - server
created_at: 2026-03-21T00:48:40Z
updated_at: 2026-03-25T21:44:00Z
parent: sera-yn90
---

From PR #163 review (round 1), item #8:

The healing path in `R/mod_slides.R:659` falls back to `generation_state$title` but this field is never set during initial generation. Healed presentations always default to "Presentation" if the LLM omits a title, losing the original user-specified title.

Fix: Store `generation_state$title <- title` after initial slide generation.

<!-- migrated from beads: `serapeum-1774459567488-188-ce0f6ce0` | github: https://github.com/seanthimons/serapeum/issues/217 -->
