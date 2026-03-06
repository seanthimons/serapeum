---
phase: 49
slug: gap-analysis-report-preset
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-06
---

# Phase 49 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | tests/testthat.R |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-gap-analysis.R')"` |
| **Full suite command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 49-01-01 | 01 | 1 | GAPS-01 | integration | `test_file('tests/testthat/test-gap-analysis.R', filter='button_handler')` | ❌ W0 | ⬜ pending |
| 49-01-02 | 01 | 1 | GAPS-02 | unit | `test_file('tests/testthat/test-gap-analysis.R', filter='gap_categories')` | ❌ W0 | ⬜ pending |
| 49-01-03 | 01 | 1 | GAPS-03 | unit | `test_file('tests/testthat/test-gap-analysis.R', filter='contradictions')` | ❌ W0 | ⬜ pending |
| 49-01-04 | 01 | 1 | GAPS-04 | unit | `test_file('tests/testthat/test-gap-analysis.R', filter='section_targeting')` | ❌ W0 | ⬜ pending |
| 49-01-05 | 01 | 1 | GAPS-05 | unit | `test_file('tests/testthat/test-gap-analysis.R', filter='disclaimer')` | ❌ W0 | ⬜ pending |
| 49-01-06 | 01 | 1 | GAPS-06 | unit | `test_file('tests/testthat/test-gap-analysis.R', filter='threshold')` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-gap-analysis.R` — stubs for GAPS-01 through GAPS-06
  - test_that("button_handler triggers generate_gap_analysis", ...)
  - test_that("gap_categories all 5 headings present in output", ...)
  - test_that("contradictions formatted with bold prefix", ...)
  - test_that("section_targeting filters discussion/limitations/future_work", ...)
  - test_that("disclaimer is_synthesis includes gap_analysis", ...)
  - test_that("threshold blocks < 3 papers with toast", ...)

*Existing test infrastructure (testthat 3.x) covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Button appears in Deep presets row | GAPS-01 | Visual UI placement | Open document notebook → verify "Research Gaps" button in Deep row after Methods |
| Narrative reads naturally | GAPS-02 | Subjective quality | Generate report with 5+ papers → read output for coherent prose |
| AI disclaimer banner visible | GAPS-05 | Visual rendering | Generate gap analysis → verify yellow disclaimer banner appears |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
