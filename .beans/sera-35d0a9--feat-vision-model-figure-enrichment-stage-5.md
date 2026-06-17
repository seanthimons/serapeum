---
title: "feat: Vision model figure enrichment (Stage 5)"
status: completed
type: task
priority: high
created_at: 2026-03-09T14:41:25Z
updated_at: 2026-03-22T16:54:21Z
parent: sera-mgb9
---

## Stage 5 of Epic #44: Vision Model Figure Enrichment (Optional)

### Problem

Heuristic caption extraction (Stage 3) achieves 40-60% recall. Figures without captions are less useful for slide generation because the LLM doesn't know what they depict. Additionally, even figures with captions benefit from richer descriptions that capture chart types, data patterns, and visual details.

### Approach: User-Triggered Vision Model Calls via OpenRouter

Same opt-in pattern as the existing "Embed Papers" button. User explicitly triggers this, sees a cost estimate, and can cancel.

**This stage is optional.** The pipeline works without it — figures just have less metadata, and the slide-generating LLM has less context for figure selection.

### Flow

1. User clicks "Describe Figures" in the figure review UI (Stage 6)
2. System counts un-described figures, estimates cost:
   - `N figures x ~300 input tokens (image) x model_price_per_token`
   - Display: "Describe 8 figures using google/gemini-2.0-flash. Estimated cost: $0.04"
3. User confirms
4. For each figure without `llm_description`:
   - Send image to multimodal model via existing OpenRouter `api_openrouter.R`
   - Prompt:
     ```
     Describe this academic figure in 2-3 sentences. Include:
     1. What type of visualization this is (bar chart, scatter plot, diagram, flowchart, etc.)
     2. What data or concepts it shows
     3. Key patterns or findings visible

     Also classify the image type as one of: chart, diagram, photo, table, equation, other

     Respond as JSON: {"description": "...", "image_type": "..."}
     ```
   - Parse response, store in `llm_description` and `image_type` columns
   - Log cost in existing `cost_log` table
5. Update UI with descriptions as they come in (progress indicator)

### Alternative: Full-Page Description

Instead of sending individual cropped figures, send the full rendered page and ask the model to describe all figures on that page. Trade-offs:

| Approach | Pros | Cons |
|----------|------|------|
| Individual figures | Focused descriptions, cleaner | More API calls, higher cost for many figures |
| Full page | Fewer calls, captures surrounding context | Less focused, model may miss small figures |

**Recommendation:** Start with individual figures. Revisit full-page if cost becomes an issue.

### Model Selection

Use whatever multimodal-capable model the user has configured for chat. Good defaults:
- `google/gemini-2.0-flash` — cheap, fast, good vision
- `anthropic/claude-sonnet-4-5-20250929` — higher quality descriptions
- Any OpenRouter model with vision capability

Should validate that the selected model supports image input before attempting. Show a clear error if not.

### Deliverables

- [ ] `describe_figure(con, figure_id, image_path, model)` — single figure -> OpenRouter vision call -> store result
- [ ] `describe_figures_batch(con, document_id, model)` — batch all un-described figures for a document
- [ ] Cost estimation function: `estimate_description_cost(n_figures, model)` using OpenRouter pricing
- [ ] Confirmation modal with cost estimate before processing
- [ ] Progress indicator (e.g., "Describing figure 3 of 8...")
- [ ] Cost logging in existing `cost_log` table
- [ ] Error handling: if a single figure fails, continue with remaining (don't abort batch)
- [ ] Validate model supports vision input before starting

### Depends On

- Stage 2 — needs stored figures to read images from
- Stage 4 — should run after filtering to avoid wasting API calls on junk images
- Existing `api_openrouter.R` — for multimodal API calls

### Part of

Epic #44 — PDF Image Pipeline (extraction -> slides)

<!-- migrated from beads: `serapeum-1774459566048-126-35d0a9ed` | github: https://github.com/seanthimons/serapeum/issues/148 -->
