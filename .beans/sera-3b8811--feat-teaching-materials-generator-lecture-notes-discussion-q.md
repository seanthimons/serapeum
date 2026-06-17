---
title: "feat: Teaching Materials Generator (lecture notes, discussion questions)"
status: completed
type: task
priority: high
created_at: 2026-02-15T21:07:57Z
updated_at: 2026-03-06T21:19:23Z
---

## Summary

Add a preset that converts the paper collection into **teaching materials**: lecture outline with learning objectives, key terms/definitions, discussion questions, real-world examples, and suggested in-class activities.

## Why

Professors teaching new courses spend enormous time converting research papers into lecture content. Graduate students use papers for seminar presentations. This automates the "research → pedagogy" transformation.

**Pain points solved:**
- "How do I teach this complex literature to undergrads?"
- "What discussion questions arise from these papers?"
- Converting expertise into curriculum materials

## How it differs

- **Study Guide** → student-focused exam prep
- **Teaching Materials** → instructor-focused (broader scope: learning objectives, activities, discussion prompts, real-world applications)

## Implementation notes

- Similar architecture to Study Guide preset, but instructor-oriented prompt
- Prompt sections: (1) outline with learning objectives, (2) key definitions, (3) 5-7 discussion questions, (4) real-world applications, (5) suggested in-class activity
- Export as Markdown → paste into LMS or feed into Slides preset
- Low-medium risk — discussion questions/activities are generative but instructor reviews before use

## Complexity/Impact

- **Complexity:** Low-Medium
- **Impact:** Medium
- **Risk:** Low-Medium
- **Workflow stage:** Communication & Teaching

## Related

- Part of epic: AI Output Overhaul
- Complements existing Study Guide and Slides presets

<!-- migrated from beads: `serapeum-1774459565236-89-3b88112d` | github: https://github.com/seanthimons/serapeum/issues/106 -->
