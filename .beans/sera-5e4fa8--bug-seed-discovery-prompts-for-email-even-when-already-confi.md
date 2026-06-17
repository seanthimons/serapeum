---
title: "bug: Seed discovery prompts for email even when already configured"
status: completed
type: bug
priority: high
created_at: 2026-02-11T18:06:04Z
updated_at: 2026-02-11T18:10:45Z
---

## Description

The 'Discover from Paper' seed discovery flow prompts the user to enter their email address even when it's already configured in settings.

## Expected Behavior
If an email is already saved in config, the seed discovery flow should use it without prompting.

## Actual Behavior
User is prompted for email every time they use 'Discover from Paper', regardless of existing configuration.

## Context
Identified during v1.0 milestone completion. Tracked in `.planning/STATE.md` as a pending todo.

<!-- migrated from beads: `serapeum-1774459564258-44-5e4fa895` | github: https://github.com/seanthimons/serapeum/issues/57 -->
