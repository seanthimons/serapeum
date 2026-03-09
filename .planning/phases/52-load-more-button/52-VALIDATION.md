---
phase: 52
slug: load-more-button
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-09
---

# Phase 52 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat (R standard testing framework) |
| **Config file** | None — tests auto-discovered in tests/testthat/ |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-load-more.R')"` |
| **Full suite command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command for modified test files
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 52-01-01 | 01 | 1 | PAGE-02 | unit | `testthat::test_file('tests/testthat/test-load-more.R')` | ❌ W0 | ⬜ pending |
| 52-01-02 | 01 | 1 | PAGE-03 | manual | Visual inspection in running app | N/A | ⬜ pending |
| 52-01-03 | 01 | 1 | PAGE-04 | unit | `testthat::test_file('tests/testthat/test-load-more.R')` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-load-more.R` — stubs for PAGE-02, PAGE-04
- [ ] `R/theme_catppuccin.R` — add `icon_angles_down()` wrapper

*Existing test infrastructure (testthat, test helpers) covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Button styled with sapphire color, icon+text | PAGE-03 | CSS styling requires visual verification | 1. Start app 2. Run a search 3. Verify Load More button appears with sapphire outline and angles-down icon |
| Button disappears when no more results | PAGE-04 | Shiny reactive UI visibility requires running app | 1. Search for topic with few results 2. Click Load More until exhausted 3. Verify button disappears |
| Appended papers persist until Refresh | PAGE-02 | Full reactive flow requires running app context | 1. Search 2. Click Load More 3. Verify papers appended 4. Click Refresh 5. Verify list resets |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
