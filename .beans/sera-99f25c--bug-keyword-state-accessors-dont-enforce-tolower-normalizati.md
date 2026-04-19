---
title: "bug: keyword state accessors don't enforce tolower() normalization"
status: todo
type: bug
priority: normal
tags:
  -  low
  - server
created_at: 2026-03-19T20:14:01Z
updated_at: 2026-03-25T21:44:16Z
---

## Severity: Low

## Description

In `R/mod_keyword_filter.R`, `set_keyword_state()` and `get_keyword_state()` do not enforce `tolower()` on the keyword argument. While keyword parsing normalizes to lowercase, an external caller passing mixed-case keywords could create duplicate state entries.

## Fix

Add `keyword <- tolower(keyword)` at the top of both `set_keyword_state` and `get_keyword_state`.

## Found in

PR #161 review (unresolved Copilot comment #1)

<!-- migrated from beads: `serapeum-1774459566554-149-99f25cb5` | github: https://github.com/seanthimons/serapeum/issues/178 -->
