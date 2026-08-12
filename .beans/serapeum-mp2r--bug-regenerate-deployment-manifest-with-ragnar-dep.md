---
# serapeum-mp2r
title: 'bug: regenerate deployment manifest with Ragnar dependencies'
status: todo
type: bug
priority: high
tags:
    - ragnar
    - deployment
created_at: 2026-08-12T18:31:28Z
updated_at: 2026-08-12T18:31:28Z
---

## Problem

The tracked `manifest.json` has 74 package entries but no entries for the runtime dependencies `ragnar` or `mirai`. `renv.lock` and the local project library are already on ragnar 0.3.0 and mirai 2.6.0. If deployment consumes the manifest, the deployed app can omit required packages.

## Source

See `.planning/research/RAGNAR-0.3-NEWS-AUDIT.md`.

## Acceptance criteria

- Confirm which deployment workflow consumes `manifest.json`.
- Regenerate the manifest with project deployment tooling; do not hand-edit package records.
- Verify `ragnar` and `mirai` are package entries with versions compatible with `renv.lock`.
- Run deployment/package restoration validation and the relevant Ragnar integration tests.
