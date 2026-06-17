---
title: "feat: Gap Analysis Report preset"
status: completed
type: task
priority: high
created_at: 2026-02-15T21:07:14Z
updated_at: 2026-03-06T20:40:45Z
---

## Summary

Add a preset that systematically identifies underexplored areas, contradictory findings, and missing research dimensions across the paper collection. Output organized by category: methodological gaps, geographic gaps, population gaps, measurement gaps, theoretical gaps.

## Why

Finding research gaps is **critical for grant proposals, dissertations, and novel contributions**. The current Conclusions preset mentions future directions, but doesn't systematically analyze what's *missing* from the literature landscape.

**Pain points solved:**
- "What hasn't been studied yet?"
- "Where do findings contradict each other?"
- "Which populations/contexts are underrepresented?"

## How it differs

- **Conclusions Synthesis** → what authors say about future directions
- **Gap Analysis** → systematic identification of absences and contradictions across corpus

## Implementation notes

- Similar architecture to `generate_conclusions_preset()` with gap-focused prompt
- Query for limitation/discussion sections (already implemented in RAG)
- Requires inference about what's *not* there — slightly higher hallucination risk
- Should include AI warning banner (like Conclusions preset)

## Complexity/Impact

- **Complexity:** Medium
- **Impact:** High
- **Risk:** Medium (inferential, but cite contradictions from actual sources)
- **Workflow stage:** Synthesis & Writing

## Related

- Part of epic: AI Output Overhaul
- Natural extension of Conclusions Synthesis

<!-- migrated from beads: `serapeum-1774459565134-84-4909ee0d` | github: https://github.com/seanthimons/serapeum/issues/101 -->
