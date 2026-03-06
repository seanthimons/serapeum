---
phase: 46
slug: citation-audit-bug-fixes
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-05
---

# Phase 46 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat (current CRAN version) |
| **Config file** | tests/testthat.R |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-citation-audit.R')"` |
| **Full suite command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command (citation audit tests)
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 46-01-01 | 01 | 1 | BUGF-01 | integration | `Rscript -e "testthat::test_file('tests/testthat/test-citation-audit.R')"` | ✅ | ⬜ pending |
| 46-01-02 | 01 | 1 | BUGF-02 | manual + unit | Manual verification + unit test for reactive trigger | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Manual verification checklist for BUGF-02 (reactive sync)
- [ ] Optional: Integration test that simulates import + checks reactive trigger

*Existing infrastructure covers BUGF-01 — test-citation-audit.R has 44 tests.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Papers appear in abstract notebook after citation audit import | BUGF-02 | Requires Shiny reactive context — cannot unit test reactive invalidation | 1. Run citation audit on a seed paper 2. Select papers and click "Add to notebook" 3. Switch to abstract notebook tab 4. Verify new papers appear without manual refresh |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
