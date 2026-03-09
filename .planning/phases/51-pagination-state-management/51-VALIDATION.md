---
phase: 51
slug: pagination-state-management
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-09
---

# Phase 51 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat (latest stable) |
| **Config file** | None — tests in `tests/testthat/` directory |
| **Quick run command** | `testthat::test_file("tests/testthat/test-pagination-state.R")` |
| **Full suite command** | `testthat::test_dir("tests/testthat")` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `testthat::test_file("tests/testthat/test-pagination-state.R")`
- **After every plan wave:** Run `testthat::test_dir("tests/testthat")`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 51-01-01 | 01 | 1 | PAGE-01 | unit | `testthat::test_file("tests/testthat/test-pagination-state.R")` | ❌ W0 | ⬜ pending |
| 51-01-02 | 01 | 1 | PAGE-05 | integration | `testthat::test_file("tests/testthat/test-pagination-state.R")` | ❌ W0 | ⬜ pending |
| 51-01-03 | 01 | 1 | N/A | unit | `testthat::test_file("tests/testthat/test-pagination-state.R")` | ❌ W0 | ⬜ pending |
| 51-01-04 | 01 | 1 | N/A | unit | `testthat::test_file("tests/testthat/test-pagination-state.R")` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-pagination-state.R` — stubs for PAGE-01, PAGE-05, reactiveValues initialization, state sync
- [ ] Shiny `testServer()` setup pattern (if not already in existing tests)

*Note: Shiny reactive contexts require `shiny::testServer()` for testing observers and reactiveValues. Standard unit tests can verify helper functions only.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Refresh replaces results visually | PAGE-01 | UI rendering requires browser | 1. Search papers, 2. Click Refresh, 3. Verify table replaces (not appends) |
| Cursor resets on Edit Search changes | PAGE-05 | Multi-step UI interaction | 1. Search, 2. Load More, 3. Change year filter, 4. Verify results start from page 1 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
