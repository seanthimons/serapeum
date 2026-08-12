---
# serapeum-0r3o
title: 'feat: add retry policy to provider embedding requests'
status: todo
type: feature
priority: normal
tags:
    - ragnar
    - embeddings
created_at: 2026-08-12T18:31:29Z
updated_at: 2026-08-12T18:31:29Z
---

## Problem

Ragnar 0.3.0 adds generalized retry behavior for its own embedding helpers, but Serapeum bypasses those helpers through `provider_get_embeddings()`. Embedding requests currently have no shared retry policy.

## Source

See `.planning/research/RAGNAR-0.3-NEWS-AUDIT.md`.

## Acceptance criteria

- Add provider-layer retry behavior for 429, retryable 5xx, and transient network failures.
- Respect `Retry-After`, bound attempts/time, and do not retry permanent 4xx failures.
- Preserve structured provider errors after exhaustion.
- Add deterministic tests for retry-then-success and exhausted/non-retryable failures.
