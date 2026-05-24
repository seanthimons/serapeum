---
# serapeum-521b
title: Evaluate Ragnar database backend support
status: todo
type: task
priority: deferred
tags:
    - ragnar
    - database
    - architecture
    - investigation
created_at: 2026-05-24T17:19:32Z
updated_at: 2026-05-24T17:19:32Z
parent: serapeum-9vzz
---

## Context

Serapeum is currently built around local DuckDB persistence. Ragnar may have assumptions or extension points around storage/vector stores that could affect whether Serapeum should keep DuckDB as the canonical store, add another backend, or only use Ragnar for model/RAG orchestration.

## Research questions

- What database, vector store, or document-store backends does Ragnar support today?
- Does Ragnar expose backend abstractions that Serapeum can plug into, or is backend choice fixed by Ragnar internals?
- Can Ragnar operate with DuckDB as the durable local store, either directly or through an adapter layer?
- If alternate backends are supported, what are the tradeoffs for local-first use, reproducibility, installation burden, and federal/locked-down environments?
- Which Serapeum data boundaries must remain stable regardless of Ragnar backend support?

## Acceptance criteria

- Produce a short backend capability matrix covering Ragnar-supported persistence/vector backends and DuckDB compatibility.
- Recommend one of:
  1. Keep DuckDB canonical and use Ragnar only above the persistence layer.
  2. Add a Ragnar-compatible adapter while retaining DuckDB as the source of truth.
  3. Plan a broader backend abstraction if Ragnar support makes that worthwhile.
- File any implementation issues that follow from the recommendation.

## Guardrail

Do not assume Ragnar supports arbitrary database backends. Verify from package docs/source before designing around it.
