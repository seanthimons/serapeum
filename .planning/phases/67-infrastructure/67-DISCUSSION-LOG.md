# Phase 67: Infrastructure - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 67-infrastructure
**Areas discussed:** Audit Scope, Fresh-Install Strategy, Verification Bar, Cleanup Breadth

---

## Audit Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Audit migrations plus `R/db.R` overlap | Harden the real startup contract, including interactions between `init_schema()` and versioned migrations | ✓ |
| Audit migration SQL only | Keep fixes limited to `migrations/*.sql` even if startup overlap remains fragile | |

**User's choice:** Audit both `migrations/*.sql` and overlapping schema setup in `R/db.R`.
**Notes:** Fresh-install safety should be grounded in how startup actually works, not in an idealized migration-only model.

---

## Fresh-Install Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Keep current startup model | Preserve `init_schema()` followed by `run_pending_migrations()` and make it safe | ✓ |
| Start restructuring toward migration-only startup | Begin shifting ownership away from `init_schema()` in this phase | |

**User's choice:** Keep the current startup model and make migrations idempotent against it.
**Notes:** This phase should stay within hardening, not architecture replacement.

---

## Verification Bar

| Option | Description | Selected |
|--------|-------------|----------|
| Strong regression test | Add automated fresh-install and rerun verification against the real startup path | ✓ |
| Lighter audit-focused verification | Rely mainly on SQL audit and smaller migration tests | |

**User's choice:** Strong regression test.
**Notes:** Verification should prove first-run and rerun behavior, not only static SQL correctness.

---

## Cleanup Breadth

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal fixes only | Repair only the directly failing statements | |
| Broad cleanup within migration scope | Normalize migration/idempotency issues more broadly if they are part of the same domain | ✓ |

**User's choice:** Broad cleanup within the migration/idempotency boundary.
**Notes:** Broader cleanup is allowed, but broader database redesign remains out of scope.

---

## the agent's Discretion

- Exact split of cleanup work between SQL files and small startup/bootstrap adjustments
- Exact regression test structure

## Deferred Ideas

None
