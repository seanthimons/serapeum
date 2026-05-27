---
# serapeum-9vzz
title: Plan Ragnar-native Bedrock adoption
status: todo
type: milestone
priority: deferred
tags:
    - ragnar
    - bedrock
    - llm
    - future-milestone
created_at: 2026-05-24T17:19:32Z
updated_at: 2026-05-24T17:19:32Z
---

## Context

Ragnar can natively use AWS Bedrock-hosted models. Serapeum currently has OpenRouter-oriented LLM access, so Bedrock support should be planned as a future milestone rather than bolted on ad hoc.

## Outcome

Create a defensible integration plan for using Ragnar-native Bedrock models inside Serapeum while preserving local-first behavior, reproducibility, and clear separation between retrieval, model routing, and persistence.

## Scope

- Inventory Ragnar's current model-provider APIs for Bedrock chat/completion and embedding workflows.
- Crosswalk Ragnar's Bedrock support against Serapeum's existing OpenRouter client boundaries.
- Decide whether Bedrock is a parallel provider option, a Ragnar-backed replacement path, or a feature-gated experimental backend.
- Identify credential/configuration requirements and avoid storing secrets in project files.
- Define test strategy with mocks or dry-run provider probes so this remains deterministic in CI/local development.
- Document required changes in `docs/plans/` before implementation.

## Acceptance criteria

- A short design note exists describing the recommended Ragnar/Bedrock architecture.
- The plan identifies which Serapeum modules/functions would change and which should stay provider-agnostic.
- Credential handling is specified without committing secrets.
- Follow-up implementation issues are created if the plan recommends proceeding.

## Notes

This is intentionally a future milestone. Do not implement provider changes until the design questions are answered.
