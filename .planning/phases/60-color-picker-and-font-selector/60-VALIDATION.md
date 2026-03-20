---
phase: 60
slug: color-picker-and-font-selector
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 60 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | `tests/testthat.R` |
| **Quick run command** | `Rscript -e "testthat::test_file('tests/testthat/test-mod_slides.R')"` |
| **Full suite command** | `Rscript -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command (mod_slides tests)
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 60-01-01 | 01 | 1 | THME-08 | unit | `grep -q 'colorPickerPanel' R/mod_slides.R` | ❌ W0 | ⬜ pending |
| 60-01-02 | 01 | 1 | THME-11 | unit | `grep -q 'font_choices' R/mod_slides.R` | ❌ W0 | ⬜ pending |
| 60-01-03 | 01 | 1 | THME-08 | unit | `grep -q 'parse_scss_colors_full' R/themes.R` | ❌ W0 | ⬜ pending |
| 60-01-04 | 01 | 1 | THME-08 | unit | `grep -q 'generate_custom_scss' R/themes.R` | ❌ W0 | ⬜ pending |
| 60-01-05 | 01 | 1 | THME-10 | integration | `grep -q 'updateTextInput.*color_bg' R/mod_slides.R` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-themes.R` — stubs for parse_scss_colors_full and generate_custom_scss
- [ ] `tests/testthat/test-mod_slides.R` — stubs for color picker UI and font selector rendering

*Existing testthat infrastructure covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Color picker swatch visually updates on selection | THME-08 | Requires browser rendering | Open modal → expand panel → change color → verify swatch dot updates |
| Native color input ↔ hex text field sync | THME-08 | Requires JS event handling in browser | Click color swatch → verify hex field updates; type hex → verify swatch updates |
| Font dropdown grouped by category | THME-11 | Visual layout verification | Open font selector → verify serif/sans-serif/mono groups appear |
| Collapsible panel expand/collapse | THME-08 | UI interaction | Click "Customize colors & font" → verify panel toggles |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
