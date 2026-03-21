---
date: 2026-03-20
topic: slide-image-layout-quality
---

# Slide Image Layout & Context-Aware Placement

## What We're Building

Three reinforcing changes to make figure injection into Quarto slides context-aware and layout-correct:

1. **Richer slide prompt** with concrete QMD examples for each layout pattern, including "hero image" slides and "explanation deferred to next slide"
2. **Recalibrated aspect ratio buckets** (5 classes instead of 3) to distinguish full-page captures from standard charts
3. **Vision model `presentation_hint`** field so the manifest tells the slide LLM whether a figure deserves its own slide, works alongside text, or is too dense

## Why This Approach

**Observed in Chemo_pic.qmd**: All 7 figures use identical `{width="90%"}` centered below bullet points. No column layouts, no hero slides, no height constraints. The LLM found one pattern and repeated it.

Root causes:
- Prompt gives abstract layout rules without concrete Quarto syntax examples
- Aspect ratio classification maps 1240x1630 full-page figures as "standard" (ratio 0.75), same bucket as actual standard charts
- Vision descriptions say *what* the figure shows but not *how* it should be used in a presentation
- No concept of "image-only slide" exists in the prompt

## Key Decisions

- **5 aspect ratio classes**: wide (>1.8), landscape (1.2-1.8), square (0.8-1.2), portrait (0.6-0.8), tall (<0.6)
- **Vision adds `presentation_hint`**: "hero" / "supporting" / "reference" — slide LLM uses this for placement
- **Hero slide pattern**: figure is the content, title + optional caption only, explanation deferred to next slide or speaker notes
- **Token cost accepted**: users informed; richer descriptions are worth it
- **`removeResourcePath` warning**: harmless (tryCatch on first run), not related to image issues

## Open Questions

- None — proceeding to plan

## Next Steps

-> `/workflows:plan` for implementation details
