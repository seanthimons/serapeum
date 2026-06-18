---
# serapeum-fd1m
title: 'test: labeled RAG retrieval recall fixtures and UAT examples'
status: todo
type: task
priority: normal
created_at: 2026-06-18T21:02:36Z
updated_at: 2026-06-18T21:02:36Z
---

﻿Follow-up from PRD-rag-retrieval-precision.md implementation.

The retrieval/chunking/rerank plumbing is implemented and covered with unit/integration tests, but the PRD also calls for a labeled before/after retrieval-recall fixture set and qualitative UAT examples based on previously missed questions.

Acceptance criteria:
- Add deterministic fixture documents/questions with expected source document IDs and page-range evidence.
- Assert expected evidence appears in final context recall@12 after RRF plus rerank or fallback order.
- Capture at least a small qualitative UAT note comparing prior missed questions with revised retrieval.
