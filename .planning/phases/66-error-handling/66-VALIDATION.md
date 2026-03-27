---
phase: 66
slug: error-handling
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-27
---

# Phase 66 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | tests/testthat.R |
| **Quick run command** | `Rscript -e "testthat::test_dir('tests/testthat')"` |
| **Full suite command** | `Rscript -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `Rscript -e "testthat::test_dir('tests/testthat')"`
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 66-01-01 | 01 | 1 | ERRH-02 | unit | `grep -q "show_error_toast" R/utils_notifications.R` | ❌ W0 | ⬜ pending |
| 66-01-02 | 01 | 1 | ERRH-02 | unit | `grep -q "show_error_toast" R/mod_document_notebook.R` | ❌ W0 | ⬜ pending |
| 66-01-03 | 01 | 1 | ERRH-01 | unit | `grep -q "removeModal()" R/mod_document_notebook.R` | ❌ W0 | ⬜ pending |
| 66-01-04 | 01 | 1 | ERRH-01 | manual | Visual: error toast visible above modal | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- Existing infrastructure covers all phase requirements. No new test framework or fixtures needed.
- Validation is primarily structural (grep for function usage patterns) and manual (visual toast visibility).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Error toast appears above modal backdrop | ERRH-01 | Requires visual rendering context (Shiny app running with open modal) | 1. Open synthesis modal 2. Trigger a preset error (disconnect API) 3. Verify toast is visible, not behind modal |
| Same error format in both notebook types | ERRH-02 | Requires two separate notebook contexts side-by-side | 1. Trigger preset error in document notebook 2. Trigger same error in search notebook 3. Compare toast format |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
