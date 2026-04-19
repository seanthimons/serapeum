---
title: Slide preview does not reflect selected theme
status: todo
type: bug
priority: high
tags:
  - slides
  - ui
created_at: 2026-03-19T19:02:14Z
updated_at: 2026-03-22T17:15:59Z
parent: sera-yn90
---

## Summary

When generating slides with a selected theme (built-in or custom), the preview pane in the results modal does not visually reflect the chosen theme. The theme is correctly applied to the final generated output, but the in-modal preview renders with default styling.

## Context

Discovered during Phase 59 (Theme Swatches, Upload, and Management) UAT. Phase 59 wires theme selection into the `custom_scss` generation pipeline but does not address live preview theming.

## Expected Behavior

The slide preview shown in the results modal should render with the selected theme's styling applied.

## Actual Behavior

Preview renders with default theme regardless of selection. Generated output has correct theme.

## Investigation Needed

- Trace how the preview iframe sources its HTML — does it use the Quarto-rendered temp file (which should have theme applied), or a separate render path?
- If preview is a separate render, it may need the same `custom_scss` / theme parameter passed through

<!-- migrated from beads: `serapeum-1774459566397-142-ab2efdd3` | github: https://github.com/seanthimons/serapeum/issues/171 -->
