---
title: "Research Refiner: preset weights don't sum to 1.0"
status: completed
type: feature
priority: high
created_at: 2026-03-19T19:23:37Z
updated_at: 2026-03-19T19:47:51Z
---

In `utils_scoring.R`, the preset weights returned by `get_preset_weights()` don't sum to 1.0:

- **Discovery:** 0.25 + 0.30 + 0.20 + 0.15 + 0.30 + 0.30 = **1.50**
- **Comprehensive:** 0.30 + 0.10 + 0.20 + 0.30 + 0.05 + 0.25 = **1.20**
- **Emerging:** 0.10 + 0.15 + 0.40 + 0.25 + 0.20 + 0.20 = **1.30**

This is functionally fine because `compute_utility_score()` re-normalizes weights at runtime. However, it's confusing for users who toggle "Show Advanced Weights" and see slider values that don't add up to 1.0.

**Suggestion:** Either normalize presets to sum to 1.0, or show a "(weights are auto-normalized)" note next to the sliders.

<!-- migrated from beads: `serapeum-1774459566487-146-cc603ca1` | github: https://github.com/seanthimons/serapeum/issues/175 -->
