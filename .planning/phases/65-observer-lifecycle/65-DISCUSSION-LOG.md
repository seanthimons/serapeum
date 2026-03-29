# Phase 65: Observer Lifecycle - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 65-observer-lifecycle
**Areas discussed:** Slide chip handler lifecycle, Figure action observer lifecycle, Document list renderUI efficiency, Module cleanup on close
**Mode:** --auto (all decisions auto-selected)

---

## Slide Chip Handler Lifecycle (LIFE-01)

| Option | Description | Selected |
|--------|-------------|----------|
| Pre-allocate fixed observer pool | Register 10 handlers once in module server, gate with reactiveVal | ✓ |
| Destroy-before-recreate per modal open | Store and destroy chip observers each time modal opens | |

**User's choice:** [auto] Pre-allocate fixed observer pool (recommended default)
**Notes:** Current code may already implement this correctly — verification needed before any code changes.

---

## Figure Action Observer Lifecycle (LIFE-02)

| Option | Description | Selected |
|--------|-------------|----------|
| Destroy-before-recreate pattern | Destroy old observers before registering new ones on re-extraction | ✓ |
| Once-only registration with ID guard | Register observers once per figure ID, never re-create | |

**User's choice:** [auto] Destroy-before-recreate pattern (recommended default)
**Notes:** Existing destroy loop at lines 931-938 provides partial implementation. Verify it covers all re-extraction paths.

---

## Document List RenderUI Efficiency (LIFE-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Reactive caching with separate data reactive | Move list_documents() into dedicated reactive() expression | ✓ |
| Debounce the refresh trigger | Rate-limit doc_refresh() to prevent rapid re-execution | |
| Keep as-is with documentation | Accept current behavior as non-harmful | |

**User's choice:** [auto] Reactive caching with separate data reactive (recommended default)
**Notes:** Benefits both document_list and index_action_ui renderUI blocks.

---

## Module Cleanup on Close (LIFE-04)

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit cleanup via session$onSessionEnded | Destroy stored observers on session end | ✓ |
| Scoped cleanup on modal dismiss | Tie cleanup to modal close events | |

**User's choice:** [auto] Explicit cleanup via session$onSessionEnded (recommended default)
**Notes:** Follow existing pattern from mod_citation_network.R line 1598.

---

## Claude's Discretion

- Whether SC-1 already passes (LIFE-01 may need no code changes)
- Reactive() expression granularity for list_documents caching
- Defensive tryCatch around $destroy() calls
- Development-only logging for observer lifecycle events

## Deferred Ideas

None — all decisions stayed within phase scope.
