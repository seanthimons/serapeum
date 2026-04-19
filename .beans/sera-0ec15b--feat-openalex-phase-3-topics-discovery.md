---
title: "feat: OpenAlex Phase 3 - Topics & Discovery"
status: completed
type: feature
priority: high
created_at: 2026-02-10T04:06:26Z
updated_at: 2026-02-11T18:05:58Z
---

## Description
Extract and display topic hierarchy from OpenAlex for better paper discovery and search suggestions.

## Tasks
- [ ] Extract `primary_topic` hierarchy (domain → field → subfield → topic)
- [ ] Display topic info in paper detail view
- [ ] Topic-based search suggestions (feeds into #10 meta-prompt)

## Context
This is Phase 3 of the Enhanced OpenAlex Search Filters feature (#4). Phase 1 (document types) and Phase 2 (OA status & citations) are complete.

## Reference
- https://docs.openalex.org/api-entities/works/filter-works

<!-- migrated from beads: `serapeum-1774459563919-30-0ec15b00` | github: https://github.com/seanthimons/serapeum/issues/40 -->
