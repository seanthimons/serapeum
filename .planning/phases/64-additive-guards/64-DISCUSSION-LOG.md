# Phase 64: Additive Guards - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 64-additive-guards
**Mode:** --auto (all decisions auto-selected)
**Areas discussed:** req() placement, fig_refresh isolate scope, match_aa_model fallback, section_filter validation

---

## req() Guard Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Add req() before is.null check | Catches NULL provider/model before api_key check | ✓ |
| Replace is.null check with req() | Loses the user-friendly notification message | |
| Add req() at handler top | Too early — provider/model aren't resolved yet | |

**User's choice:** [auto] Add req(provider, model) after resolution, before is.null check
**Notes:** Preserves existing notification for missing API key while catching NULL provider

---

## fig_refresh isolate() Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Wrap all bare reads in isolate() | Only needed in observe(), not observeEvent() | |
| Audit and fix only observe() blocks | observeEvent auto-isolates; verify coverage | ✓ |
| Wrap all reads defensively | Over-isolation could kill intended triggers | |

**User's choice:** [auto] Audit-only approach — verify observe() blocks, leave observeEvent alone
**Notes:** Lines 790, 940, 948, 952 confirmed safe in observeEvent. Lines 1033, 1039, 1094 already correct.

---

## match_aa_model Fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Return NULL for NULL input | Consistent with existing contract | ✓ |
| Return default model row | Could cause unexpected behavior downstream | |
| Throw error | Would crash settings page | |

**User's choice:** [auto] Early return NULL — matches existing NULL return pattern
**Notes:** Callers already handle NULL returns from this function

---

## section_filter Validation

| Option | Description | Selected |
|--------|-------------|----------|
| Fall back to unfiltered retrieval | Matches three-level fallback pattern | ✓ |
| Throw error on invalid filter | Too aggressive for a defensive fix | |
| Log warning and skip | Loses data silently | |

**User's choice:** [auto] Defensive fallback to unfiltered retrieval
**Notes:** Currently hardcoded, so validation is purely forward-looking defense

---

## Claude's Discretion

- Exact placement of additional req() guards discovered during implementation
- Whether to add unit tests for guard paths
- Logging behavior for guard-triggered early returns

## Deferred Ideas

None — discussion stayed within phase scope.
