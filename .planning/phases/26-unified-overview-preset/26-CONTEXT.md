# Phase 26: Unified Overview Preset - Context

**Gathered:** 2026-02-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Merge the existing Summarize and Key Points presets into a single unified Overview output. The Overview button replaces both presets in the document notebook and search notebook preset panels. Users get a combined summary + key points response from one interaction.

</domain>

<decisions>
## Implementation Decisions

### Output structure
- Two-section format: Summary paragraph(s) first, then Key Points grouped by theme below
- Summary depth is user-selectable: Concise (1-2 paragraphs) or Detailed (3-4 paragraphs)
- Key Points are organized under thematic subheadings (e.g., Methodology, Findings, Gaps) — not a flat list

### Preset transition
- Remove both Summarize and Key Points buttons entirely — Overview fully replaces them
- Existing chat messages from old presets are left as-is in history (still render, just can't generate new ones)

### LLM call strategy
- User-selectable: "Quick" (single LLM call) vs "Thorough" (two separate calls for summary and key points)
- Framed as Speed vs Quality tradeoff in the UI

### Button & naming
- Label: "Overview"
- Click triggers a popover with two options: depth (Concise/Detailed) and quality (Quick/Thorough), then a "Generate" confirm button
- Popover always resets to defaults (Concise + Quick) — no persisted state
- Button placed in the same slot where Summarize/Key Points currently are, in both document and search notebook preset panels

### Content scope
- Overview covers ALL papers in the notebook (not RAG top-k retrieval)
- For large notebooks that exceed token limits: batch papers into groups, make parallel LLM calls to OpenRouter, then concatenate results
- Concatenation strategy for now (stitch batch results together); flag as future TODO if model compliance across batches diverges and a merge-pass LLM call becomes needed

### Claude's Discretion
- Exact prompt engineering for the Overview system/user prompts
- Batch size threshold (when to switch from single call to parallel batching)
- Popover styling and animation
- Icon choice for the Overview button
- Default ordering of thematic subheadings in Key Points section

</decisions>

<specifics>
## Specific Ideas

- Speed vs Quality framing for the single/two-call option — user explicitly chose this over "Draft vs Final"
- Popover UX pattern chosen over inline dropdowns — click Overview, see options, then confirm
- "Always reset" defaults chosen for predictability — no hidden state between uses

</specifics>

<deferred>
## Deferred Ideas

- Prompt inspection/editing UI — A control plane in Settings where users can view the prompt being sent to models (without data) and make one-off adjustments. Suggested as a debugging tool. — future phase

</deferred>

---

*Phase: 26-unified-overview-preset*
*Context gathered: 2026-02-19*
