---
# apj0
title: 'refiner: make temp embedding batch sizing model-aware and add live OpenRouter regression coverage'
status: todo
type: task
priority: normal
tags:
    - server
    - test
    - openrouter
created_at: 2026-04-21T03:39:41Z
updated_at: 2026-04-21T03:39:41Z
parent: sera-dast
---

Current refiner temp-store embedding now splits candidate abstracts into conservative fixed-size batches to avoid OpenRouter provider failures with large bulk requests. Follow up by deriving limits from model/provider capabilities when available and by adding a live or high-fidelity regression test for the OpenRouter Gemini embedding path so future batching changes do not regress this failure mode.
