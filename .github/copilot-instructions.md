# Copilot Instructions for Serapeum

## Project Overview

Serapeum is a local-first research assistant built with R/Shiny. It uses bslib for the web interface, DuckDB for storage, OpenRouter for LLM access, and OpenAlex for academic paper search.

## Issue Triage

When reviewing a new issue, perform the following:

### 1. Label Classification

Apply labels from each category based on the issue content:

**Complexity** (effort required):
- `complexity:low` — Quick fix, < 1 hour of work
- `complexity:medium` — Half day to full day
- `complexity:high` — Multiple days or significant refactoring

**Impact** (value delivered):
- `impact:low` — Nice to have, minor improvement
- `impact:medium` — Improves workflow or fixes notable issue
- `impact:high` — Critical feature or blocking issue

**Priority** (derived from complexity + impact):
- `priority:high` — High impact + Low/Medium complexity (quick wins, critical fixes)
- `priority:medium` — Medium impact, or High impact + High complexity
- `priority:low` — Low impact items

**Type labels** (should already be set by template, but verify):
- `bug` — Something is broken
- `enhancement` — New feature or improvement
- `question` — Discussion or question
- `tech-debt` — Internal cleanup, refactoring
- `documentation` — Docs-only changes

### 2. Milestone Assignment

Assign to the most appropriate milestone based on the issue's domain:

| Milestone | Domain | Key Signals |
|-----------|--------|-------------|
| **v12.0: UX Polish & Onboarding** | UI improvements, tooltips, descriptions, onboarding, versioning | Quick UX wins, user-facing polish |
| **v13.0: Search & Discovery** | Search filters, keyword behavior, recursive search, follow-up research | How users find and filter papers |
| **v14.0: Citation Network Evolution** | Network graph, citation audit, visualization modes, BFS graph, export graph↔search | Network graph features |
| **v15.0: AI Infrastructure** | Model routing, retrieval pipeline, reranking, local models, RAG controls | AI/ML pipeline work |
| **v16.0: Content & Output Quality** | Slides, prompts, exports, audio overview, Quarto citations | Generated content quality |
| **v17.0: PDF Image Pipeline** | PDF extraction, figure storage, captions, filtering, vision models, figure UI, slide injection | PDF image processing (sequential stages) |

If an issue doesn't clearly fit any milestone, leave it unassigned and add a comment explaining why.

### 3. Triage Comment

After labeling and assigning, leave a brief comment summarizing your triage reasoning:
- Why you chose those labels
- Why you assigned that milestone (or why you didn't)
- Any dependencies or related issues you noticed
- Flag if the issue duplicates or overlaps with an existing issue

### 4. Special Cases

- **Issues labeled `copilot`**: This label means the issue was created via a template and needs triage. Remove the `copilot` label after completing triage.
- **Moonshot/parking lot items**: If an issue is very ambitious or low priority with no clear milestone fit, mention that it may belong in the parking lot (unslotted in TODO.md).
- **Duplicate detection**: Check if a similar issue already exists before completing triage. If so, link the duplicate and suggest closing one.
