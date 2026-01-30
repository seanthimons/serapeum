# TODO

Future enhancements for the Research Notebook tool.

---

## 1. OpenRouter Cost Tracking

**Priority:** Medium

Track API costs from OpenRouter for transparency and budget management.

- [ ] Fetch model pricing from OpenRouter API
- [ ] Log token usage per request (prompt + completion tokens)
- [ ] Calculate cost per request based on model pricing
- [ ] Display running total in UI (Settings or dedicated page)
- [ ] Option to set budget alerts/limits

**Reference:** [OpenRouter API - Models](https://openrouter.ai/docs#models)

---

## 2. Expanded Model Selection

**Priority:** Medium

Add more high-quality models for chat and embeddings.

### Chat Models
- [ ] Fetch available models from OpenRouter dynamically
- [ ] Filter/categorize by capability (chat, code, etc.)

### Embedding Models
- [ ] Use top performers from MTEB leaderboard
- [ ] Reference: https://huggingface.co/spaces/mteb/leaderboard
- [ ] Consider adding:
  - [ ] Cohere embed-v3
  - [ ] Voyage AI models
  - [ ] BGE models (if available via OpenRouter)
- [ ] Allow custom embedding endpoint configuration

---

## 3. Semantic Scholar Integration

**Priority:** Low (OpenAlex works well)

Re-add Semantic Scholar as an alternative/additional paper source.

- [ ] Apply for API key: https://www.semanticscholar.org/product/api
- [ ] Implement endpoints following their strict specs
- [ ] Paper search endpoint
- [ ] Paper details endpoint
- [ ] Author search
- [ ] Citation/reference traversal
- [ ] Whole corpus download option (for offline/local search)
  - Reference: https://www.semanticscholar.org/product/api#datasets

**Note:** API approval process can be slow. Follow rate limits strictly.

---

## Completed

- [x] Basic document notebooks with PDF upload
- [x] Search notebooks via OpenAlex
- [x] RAG chat with citations
- [x] Preset generation (summary, key points, etc.)
- [x] Settings page with model configuration
