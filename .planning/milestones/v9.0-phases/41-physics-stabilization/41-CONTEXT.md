# Phase 41: Physics Stabilization - Context

**Gathered:** 2026-03-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix two vis.js physics bugs in the citation network: (1) singularity collapse when toggling physics on/off after navigating away, and (2) missing ambient orbital rotation for small/single-seed networks after stabilization. No new features — purely fixing existing physics behavior.

</domain>

<decisions>
## Implementation Decisions

### Collapse fix behavior
- Toggle physics ON: resume from current node positions — physics re-engages gently, no jarring re-layout
- Prevent singularity proactively: ensure node positions are always valid before re-enabling physics (the collapse should never happen, not be recovered from)
- Toggle physics OFF: instant freeze — nodes stop immediately where they are
- Visual feedback: button state only — no toasts or additional indicators

### Orbital rotation feel
- Ambient motion style: gentle drift — nodes float slowly in a loose orbit, not uniform spin. Subtle, almost like breathing
- Speed: very slow, barely noticeable (~30-60s for a full orbit). Mark speed constants with `#NOTE` comment blocks flagging this as a tuneable area for future tweaking
- Interaction behavior: pause drift during user interaction (dragging, clicking), resume gently after interaction ends
- Size threshold: apply drift only to small networks (≤20 nodes). Larger networks stabilize and stay still

### Edge cases & guards
- Tab navigation: always reset to default state when returning to network tab (physics on, fresh layout)
- Rapid toggling: debounce physics toggle (~300ms) — only process the last toggle, prevents weird intermediate states
- Data changes while physics off: auto-enable physics when new data arrives (new seed added) to incorporate new nodes, then stabilize
- Stabilization timeout: no manual cap — rely on vis.js built-in stabilization. Research agent should verify vis.js stabilization behavior via Context7 docs and document whether a manual cap is needed

### Claude's Discretion
- Exact damping and gravitational constant values for ambient drift
- How to detect "interaction ended" for drift resume timing
- Internal implementation of position validation before physics re-enable
- Whether to use vis.js events or custom timers for drift mechanics

</decisions>

<specifics>
## Specific Ideas

- Speed constants for ambient drift should be marked with `#NOTE` comment blocks indicating they are tuneable for future adjustment
- Research should use Context7 to pull up-to-date vis.js documentation for `stabilizationIterationsDone`, `damping`, `gravitationalConstant`, and `visPhysics()` state management
- Issues #131 (singularity collapse) and #130 (missing rotation) are likely related — both involve vis.js physics behavior after stabilization

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 41-physics-stabilization*
*Context gathered: 2026-03-03*
