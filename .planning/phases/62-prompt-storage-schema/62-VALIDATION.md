---
phase: 62
slug: prompt-storage-schema
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 62 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat (R) |
| **Config file** | `tests/testthat.R` |
| **Quick run command** | `Rscript -e "testthat::test_file('tests/testthat/test-db-migrations.R')"` |
| **Full suite command** | `Rscript -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~5 seconds (migration test only) |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 62-01-01 | 01 | 1 | PRMT-04 | integration | `Rscript -e "testthat::test_file('tests/testthat/test-db-migrations.R')"` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements — migration test file already exists.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Migration auto-runs on startup | PRMT-04 | Requires app startup | Start app, check `[migration] Applied migration 11` in console |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
