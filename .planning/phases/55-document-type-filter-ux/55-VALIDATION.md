---
phase: 55
slug: document-type-filter-ux
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-11
---

# Phase 55 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | none — tests/testthat/ discovery-based |
| **Quick run command** | `testthat::test_file("tests/testthat/test-type-badge.R")` |
| **Full suite command** | `testthat::test_dir("tests/testthat")` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `testthat::test_file("tests/testthat/test-type-badge.R")`
- **After every plan wave:** Run `testthat::test_dir("tests/testthat")`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 55-01-01 | 01 | 1 | DTYPE-03 | unit | `testthat::test_file("tests/testthat/test-type-badge.R")` | ❌ W0 | ⬜ pending |
| 55-01-02 | 01 | 1 | DTYPE-01 | unit | `testthat::test_file("tests/testthat/test-type-filter-logic.R")` | ❌ W0 | ⬜ pending |
| 55-01-03 | 01 | 1 | DTYPE-01 | unit | `testthat::test_file("tests/testthat/test-type-filter-ui.R")` | ❌ W0 | ⬜ pending |
| 55-01-04 | 01 | 1 | DTYPE-02 | unit | `testthat::test_file("tests/testthat/test-type-distribution.R")` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-type-badge.R` — stubs for DTYPE-03 badge mapping
- [ ] `tests/testthat/test-type-filter-logic.R` — stubs for DTYPE-01 reactive state logic
- [ ] `tests/testthat/test-type-filter-ui.R` — stubs for DTYPE-01 chip rendering
- [ ] `tests/testthat/test-type-distribution.R` — stubs for DTYPE-02 distribution panel

*Existing infrastructure covers framework installation (testthat already present).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Type badges render consistently in search results and chips | DTYPE-03 | Visual consistency requires human eye | Compare badge colors in Edit Search modal chip toggles vs search result cards |
| Chip toggles are visually distinct ON vs OFF | DTYPE-01 | CSS visual confirmation | Toggle chips and verify ON = colored, OFF = muted/secondary |
| Distribution panel is above chip grid | DTYPE-02 | Layout positioning | Open Edit Search modal, verify distribution appears before chips |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
