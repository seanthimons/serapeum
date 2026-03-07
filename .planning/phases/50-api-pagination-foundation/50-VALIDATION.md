---
phase: 50
slug: api-pagination-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-07
---

# Phase 50 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat |
| **Config file** | None — tests run via `testthat::test_dir("tests/testthat")` |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-api-openalex.R')"` |
| **Full suite command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command (test-api-openalex.R)
- **After every plan wave:** Run full test suite
- **Before `/gsd:verify-work`:** Full suite must be green + Shiny smoke test
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 50-01-01 | 01 | 1 | PAGE-06 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-api-openalex.R')"` | ✅ extend | ⬜ pending |
| 50-01-02 | 01 | 1 | PAGE-06 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-api-openalex.R')"` | ✅ extend | ⬜ pending |
| 50-01-03 | 01 | 1 | PAGE-06 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-api-openalex.R')"` | ✅ extend | ⬜ pending |
| 50-01-04 | 01 | 1 | PAGE-06 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-api-openalex.R')"` | ✅ extend | ⬜ pending |
| 50-01-05 | 01 | 1 | PAGE-06 | smoke | Shiny smoke test | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Extend `tests/testthat/test-api-openalex.R` with test stubs:
  - `test_that("search_papers returns list with papers, next_cursor, count")`
  - `test_that("search_papers accepts cursor parameter")`
  - `test_that("search_papers accepts sort parameter")`
  - `test_that("search_papers throws on missing meta field")`
  - `test_that("search_papers throws on missing results field")`
  - `test_that("search_papers returns empty structure when no results")`

*Existing infrastructure covers framework — only new test cases needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Caller update in mod_search_notebook.R | PAGE-06 | Shiny reactive context | Run Shiny smoke test per CLAUDE.md protocol |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
