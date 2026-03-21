---
date: 2026-03-13
topic: v12-ux-polish-onboarding
---

# V12.0: UX Polish & Onboarding

## What We're Building

Four parallel features that improve the new-user experience, provide feedback during long operations, expose LLM prompts for user control, and add version tracking.

## Feature 1: Onboarding & Notebook Descriptions (#150)

### What
- **Rework the welcome modal** to reflect the actual workflow order and current feature set
- **Rework the welcome landing page** to match the same workflow progression
- **Add contextual help text** on each sidebar section's landing/empty-state page explaining what it does and how to get started

### Current State
- **Welcome modal (wizard):** Shows 3 options — Start with a Paper, Build a Query, Browse Topics. Missing: Import, Citation Network, Citation Audit, and any mention of setup.
- **Welcome landing page:** Shows 3 cards — Search Papers, Upload Documents, Configure Settings. Different framing than the sidebar.
- **Sidebar:** 8 buttons — New Search Notebook, New Document Notebook, Import Papers, Discover from Paper, Explore Topics, Build a Query, Citation Network, Citation Audit.

### Workflow Order (Resolved)
The welcome modal and landing page should reflect this progression:
1. **Set up** — API keys, choose models, download/refresh metadata
2. **Find papers** — search, seed discovery, topics, query builder
3. **Collect** — import into notebooks, upload PDFs
4. **Analyze** — chat, synthesis presets, citation network
5. **Audit** — citation audit for gaps

### Why This Approach
No guided tour — tours are annoying and fragile. Instead, the welcome modal sets expectations upfront, and each section's landing page is self-documenting. Users discover features naturally as they navigate.

### Key Decisions
- Welcome modal content must match the 5-step workflow order above
- Welcome landing page reworked to match the same progression
- Each sidebar section gets a short description on its empty/landing state
- Setup/configuration is step 1 — remind users about API keys, models, and metadata

## Feature 2: Chat UX Progress Messaging (#87)

### What
- **Modal overlay with spinner + stop button** for heavy synthesis presets (literature review, gap analysis, methodology extractor, etc.)
- **Inline status text in the chat stream** for regular chat responses (e.g., "Analyzing 12 papers...")

### Modal Status Stages (Resolved)
Three stages, no progress bar — just a spinner with rotating status text:
1. "Sending request..."
2. "Waiting for response..."
3. "Building output..."

### Why This Approach
Two-tier approach matches user expectations: heavy operations that block the UI get a modal (consistent with the citation network progress modal pattern), while quick chat responses just get unobtrusive inline feedback. Spinners are already done (Phase 29) — this adds the informational layer on top. No progress bar because LLM synthesis has no granular progress signal.

### Key Decisions
- Modal for: synthesis presets (lit review, gap analysis, research questions, methodology extractor, overview, conclusions/future directions)
- Inline status for: regular RAG chat messages
- Reuse the existing modal pattern from citation network progress (#80)
- Three-stage status text, no estimated progress bar

## Feature 3: Prompt Transparency (#60)

### What
- **Editable prompt window for all LLM calls**, extending the existing slide generation prompt editing pattern to chat and synthesis operations
- **Verbose toggle in settings** for OpenAlex API call console logging

### Why This Approach
The slide generation workflow already has an editable prompt window — users see the prompt, can tweak it, then send. Extending this pattern to all LLM calls gives power users control without adding a new UI paradigm. OpenAlex queries are a simpler debugging need — a console toggle is sufficient.

### Key Decisions
- LLM prompts: opt-in editable window (collapsed by default, user expands to see/edit)
- OpenAlex: verbose toggle under settings → logs API URLs to browser console
- No need to expose embedding calls

## Feature 4: Versioning (#9)

### What
- **Version tag in the title bar** (e.g., "Serapeum v12.0")
- **"What's New" section** on the About page

### Why This Approach
Minimal ceremony — no GitHub Releases workflow needed for a local-first app. Version in the title bar is always visible, and a What's New section on the About page gives users context on recent changes without requiring them to check external sources.

### Key Decisions
- Version string lives in a single source of truth (config or dedicated version file)
- What's New content is maintained as a static list in the app (not pulled from GitHub)
- Title bar shows version at all times
- What's New lives on the About page

## Next Steps

→ `/workflows:plan` for implementation details on each feature
