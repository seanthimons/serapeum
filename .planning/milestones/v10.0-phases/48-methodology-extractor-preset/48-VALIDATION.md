---
phase: 48
slug: methodology-extractor-preset
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-05
---

# Phase 48 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | tests/testthat.R |
| **Quick run command** | `testthat::test_file("tests/testthat/test_methodology_extractor.R")` |
| **Full suite command** | `testthat::test_dir("tests/testthat")` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `testthat::test_file("tests/testthat/test_methodology_extractor.R")`
- **After every plan wave:** Run `testthat::test_dir("tests/testthat")`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 48-01-01 | 01 | 0 | METH-02 | unit | `testthat::test_file("tests/testthat/test_methodology_extractor.R")` | ❌ W0 | ⬜ pending |
| 48-01-02 | 01 | 1 | METH-02 | unit | `testthat::test_file("tests/testthat/test_methodology_extractor.R")` | ✅ W0 | ⬜ pending |
| 48-01-03 | 01 | 1 | METH-03 | unit | `testthat::test_file("tests/testthat/test_methodology_extractor.R")` | ✅ W0 | ⬜ pending |
| 48-01-04 | 01 | 1 | METH-04 | unit | `testthat::test_file("tests/testthat/test_methodology_extractor.R")` | ✅ W0 | ⬜ pending |
| 48-01-05 | 01 | 1 | METH-05 | unit | `testthat::test_file("tests/testthat/test_methodology_extractor.R")` | ✅ W0 | ⬜ pending |
| 48-01-06 | 01 | 2 | METH-01 | integration | Manual Shiny test | N/A | ⬜ pending |
| 48-01-07 | 01 | 2 | METH-01 | integration | Manual Shiny smoke test | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test_methodology_extractor.R` — stubs for METH-02, METH-03, METH-04, METH-05
  - Test generate_methodology_extractor() returns valid GFM table
  - Test section filter parameters passed correctly
  - Test 3-level fallback (mock failures)
  - Test DOI injection generates links
  - Test is_synthesis includes "methodology_extractor"

*Existing infrastructure covers test framework — only new test file needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Methods button triggers generation | METH-01 | Shiny UI interaction | Start app, open document notebook, click "Methods" button, verify table output |
| AI disclaimer banner shows | METH-05 | Visual UI check | After generating Methods output, verify yellow AI disclaimer banner at top |
| Two-row preset bar layout | N/A (UI) | Visual layout | Verify button bar has two rows: Quick (Overview, Study Guide, Outline) and Deep (Conclusions, Lit Review, Methods, Slides, Export) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
