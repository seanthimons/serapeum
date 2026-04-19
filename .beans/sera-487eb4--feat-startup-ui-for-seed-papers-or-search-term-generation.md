---
title: "feat: Startup UI for seed papers or search term generation"
status: completed
type: feature
priority: high
created_at: 2026-02-10T04:12:45Z
updated_at: 2026-02-11T18:06:01Z
---

## Description

Add a startup/onboarding UI that gives users two paths to begin their research:

1. **Seed Paper Mode** - Upload known papers (DOI, URL, or PDF) to find similar/related papers
2. **Search Term Mode** - Use a conversational prompt to generate optimal search terms

A toggle or tab switch allows users to choose their preferred approach.

## Related Issues
- Builds on #25 (seed paper for searching)
- Builds on #10 (meta-prompt for query building)

## Prospective Tasks

### UI/UX
- [ ] Design startup modal or landing page layout
- [ ] Create toggle/tab component for switching between modes
- [ ] Seed paper input: DOI field, URL field, or file upload
- [ ] Search term input: conversational prompt textarea
- [ ] Preview panel showing generated search terms or found seed paper metadata
- [ ] "Start Research" button to proceed to notebook creation

### Seed Paper Mode (#25 integration)
- [ ] Parse DOI/URL input and validate format
- [ ] Fetch paper metadata from OpenAlex
- [ ] Display seed paper details (title, authors, abstract preview)
- [ ] Extract keywords, topics, and cited-by/references for search expansion
- [ ] Generate initial search based on seed paper characteristics

### Search Term Mode (#10 integration)
- [ ] Conversational UI for describing research intent
- [ ] LLM generates OpenAlex-compatible search terms
- [ ] Display suggested terms with add/remove controls
- [ ] Show boolean logic (AND/OR) visualization
- [ ] Allow manual refinement before search execution

### Backend
- [ ] API endpoint or reactive logic for seed paper lookup
- [ ] Integration with existing OpenAlex search infrastructure
- [ ] Store user's starting context with notebook for reference

### Edge Cases
- [ ] Handle invalid DOIs gracefully
- [ ] Handle papers not in OpenAlex
- [ ] Fallback if LLM search term generation fails
- [ ] Remember user's preferred mode for next session

## Open Questions
- Should this replace the current "New Search Notebook" flow or be an optional enhanced mode?
- Should both modes be combinable (seed paper + additional prompt refinement)?

<!-- migrated from beads: `serapeum-1774459564003-33-487eb4f0` | github: https://github.com/seanthimons/serapeum/issues/43 -->
