---
title: "feat: Expanded model selection"
status: completed
type: task
priority: high
created_at: 2026-02-06T20:52:36Z
updated_at: 2026-02-11T22:14:15Z
---

**Effort:** Medium | **Impact:** Medium

Add more high-quality models for chat and embeddings.

### Chat Models
- [ ] Fetch available models from OpenRouter dynamically
  - [ ] Need pricing! 
  - [ ] Models should get a price bin category based on SOTA, cost, etc. 
- [ ] Filter/categorize by capability (chat, code, etc.)

### Embedding Models
- [ ] Use top performers from MTEB leaderboard
- [ ] Reference: https://huggingface.co/spaces/mteb/leaderboard
- [ ] Consider adding:
  - [ ] Cohere embed-v3
  - [ ] Voyage AI models
  - [ ] BGE models (if available via OpenRouter)
- [ ] Allow custom embedding endpoint configuration

<!-- migrated from beads: `serapeum-1774459563566-14-c3444a5f` | github: https://github.com/seanthimons/serapeum/issues/20 -->
