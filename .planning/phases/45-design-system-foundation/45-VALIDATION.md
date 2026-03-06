---
phase: 45
slug: design-system-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-04
---

# Phase 45 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | tests/testthat.R |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |
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
| 45-01-01 | 01 | 1 | DSGN-01 | manual | Visual inspection of theme_catppuccin.R comments | N/A | ⬜ pending |
| 45-01-02 | 01 | 1 | DSGN-02 | unit | `test_file("tests/testthat/test-icon-wrappers.R")` | ❌ W0 | ⬜ pending |
| 45-01-03 | 01 | 1 | DSGN-01 | manual | Open swatch.html in browser, verify both themes | N/A | ⬜ pending |
| 45-01-04 | 01 | 1 | DSGN-01, DSGN-02 | manual | User validates swatch sheet | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-icon-wrappers.R` — stubs for icon wrapper function tests

*Existing infrastructure covers most phase requirements. This phase is primarily documentation and visual validation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Color policy documentation completeness | DSGN-01 | Documentation quality requires human judgment | Review structured comments in theme_catppuccin.R |
| Swatch sheet visual accuracy | DSGN-01 | Visual rendering requires browser inspection | Open www/swatch.html, compare Latte vs Mocha side-by-side |
| User validates swatch before code changes | DSGN-01, DSGN-02 | Requires user approval | Present swatch sheet to user for sign-off |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
