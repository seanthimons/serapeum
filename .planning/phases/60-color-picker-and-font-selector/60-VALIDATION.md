---
phase: 60
slug: color-picker-and-font-selector
status: draft
nyquist_compliant: true
wave_0_complete: true
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
| **Quick run command** | `Rscript -e "testthat::test_file('tests/testthat/test-themes.R')"` |
| **Full suite command** | `Rscript -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command (theme helper tests)
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 60-01-01 | 01 | 1 | THME-08, THME-11 | unit (TDD) | `Rscript -e "testthat::test_file('tests/testthat/test-themes.R')"` | ⬜ pending |
| 60-02-01 | 02 | 2 | THME-08, THME-11 | structural (grep) | `grep -q 'id = ns("customize_panel")' R/mod_slides.R && grep -q 'type = "color"' R/mod_slides.R && grep -q 'textInput(ns("bg_hex")' R/mod_slides.R && grep -q 'selectInput(ns("font")' R/mod_slides.R` | ⬜ pending |
| 60-02-02 | 02 | 2 | THME-08, THME-10 | structural (grep) | `grep -q 'observeEvent(input\$theme,' R/mod_slides.R && grep -q 'parse_scss_colors_full' R/mod_slides.R && grep -q 'generate_custom_scss(' R/mod_slides.R && grep -q 'sendCustomMessage' R/mod_slides.R` | ⬜ pending |
| 60-02-03 | 02 | 2 | THME-08 | manual | Human verification of full picker flow (checkpoint) | ⬜ pending |

*Status: ⬜ pending / ✅ green / ❌ red / ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `tests/testthat/test-themes.R` — stubs for parse_scss_colors_full, generate_custom_scss, CURATED_FONTS (created as part of Plan 01 TDD task)

Note: Shiny server-rendered modal panels cannot be unit-tested with testthat for UI element presence. Plan 02 uses grep-based structural checks against R/mod_slides.R source code as the automated verification approach. Visual/functional verification is covered by the human checkpoint.

*Existing testthat infrastructure covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Color picker swatch visually updates on selection | THME-08 | Requires browser rendering | Open modal -> expand panel -> change color -> verify swatch dot updates |
| Native color input <-> hex text field sync | THME-08 | Requires JS event handling in browser | Click color swatch -> verify hex field updates; type hex -> verify swatch updates |
| Font dropdown grouped by category | THME-11 | Visual layout verification | Open font selector -> verify serif/sans-serif/mono groups appear |
| Collapsible panel expand/collapse | THME-08 | UI interaction | Click "Customize colors & font" -> verify panel toggles |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or structural grep checks
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (Plan 01 TDD creates test-themes.R stubs; Plan 02 uses grep checks)
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Reminder:** After human verification checkpoint passes, confirm `nyquist_compliant: true` remains set and update status to `complete`.

**Approval:** approved (revised 2026-03-20)
