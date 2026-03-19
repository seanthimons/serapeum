---
phase: 58
slug: theme-infrastructure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-19
---

# Phase 58 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat (from project) |
| **Config file** | `tests/testthat.R` |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-slides.R')"` |
| **Full suite command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-slides.R')"`
- **After every plan wave:** Run `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 58-01-01 | 01 | 1 | THME-12 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-slides.R')"` | ✅ (append to existing) | ⬜ pending |
| 58-01-02 | 01 | 1 | THME-12 | unit | same | ✅ (existing covers scalar) | ⬜ pending |
| 58-01-03 | 01 | 1 | THME-12 | unit | same | ❌ W0 | ⬜ pending |
| 58-01-04 | 01 | 1 | THME-12 | unit | same | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-slides.R` — new test: `build_qmd_frontmatter with custom_scss emits array theme`
- [ ] `tests/testthat/test-slides.R` — new test: `build_qmd_frontmatter with custom_scss uses basename only`
- [ ] `tests/testthat/test-slides.R` — new test: `generate_slides copies scss to tempdir`

*Existing infrastructure covers scalar theme case; append new tests to existing file.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Quarto renders .qmd with array theme YAML without errors | THME-12 | Requires Quarto CLI + actual .scss file | Generate test slides with custom .scss, run `quarto render`, verify HTML output |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
