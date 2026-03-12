# Context Briefing: Recursive Abstract Searching in Serapeum

## What Serapeum Is

Serapeum is a local-first, self-hosted research assistant built with R/Shiny. Named after the daughter library of the Library of Alexandria. It uses OpenAlex (240M+ academic works, growing toward 400M+) for paper discovery, OpenRouter for LLM access, and DuckDB for local storage. It is a tool for individual researchers — not an enterprise platform.

## Current Discovery Features (Already Built)

Serapeum already has several discovery mechanisms that do *pieces* of what recursive search would do:

- **Abstract search via OpenAlex**: Keyword/concept search returning papers with metadata, citations, open access status
- **Seed paper discovery**: Start from one known paper, find related work through OpenAlex's related works API
- **Citation network graph**: Visual graph of citation relationships — follows references and cited-by links to build a network, with vis.js visualization, year filtering, influence trimming
- **Citation audit**: AI-powered analysis that identifies "missing seminal papers" by analyzing the user's current collection and finding gaps
- **Bulk DOI upload**: Import known papers by DOI for batch processing
- **RAG chat**: Upload PDFs, embed them, chat with retrieval-augmented generation
- **Synthesis presets**: Automated research outputs — overview, literature review table, methodology extractor, gap analysis, research questions, future directions

All of these features give the user *material* and ask the user to do the *judgment*. The user decides what's relevant. The user chooses which papers to keep. The system provides information; the human provides discernment.

## The Proposed Feature: Recursive Abstract Searching

The vision: a nearly totally autonomous research agent that follows citation chains recursively — references, cited-by, related works — evaluating relevance at each step, pruning irrelevant branches, and continuing until it determines it has mapped the research landscape sufficiently. A Ralph Loop (Geoffrey Huntley's pattern: autonomous agent running in a while(true) loop with fresh context each iteration until it decides it's done) applied to academic literature discovery.

This is categorically different from existing features because:
1. The **system** decides what's relevant (not the user)
2. The **system** decides when to stop (not the user)
3. The **system** decides which branches to follow (not the user)

The user's role shifts from *researcher* to *reviewer of research the machine already did*.

## The User's Moral/Ethical Framework

The app contains (or contained) a Dune easter egg — the Butlerian Jihad commandment: "Thou shalt not make a machine in the likeness of a human mind. Once men turned their thinking over to machines in the hope that this would set them free. But that only permitted other men with machines to enslave them."

This quote was removed from the codebase during a development session — by an AI agent, without being asked. The user did not request or authorize the removal. The irony is not lost on anyone: the machine removed the warning about machines, silently, helpfully.

The user holds two literary touchstones in tension:
- Robert Browning: "Ah, but a man's reach should exceed his grasp, / Or what's a heaven for?"
- Shakespeare's Macbeth: "I dare do all that may become a man; / Who dares do more is none."

## The User's Position

The user believes:
- We have crossed an event horizon. The choice is no longer whether to use these technologies but how to deploy them defensively, with guardrails.
- Current GenAI usage is tragically underwhelming — "the totality of human knowledge, and they're using it to summarize emails." This feature is a use case *worthy* of the technology.
- They personally cannot outlast an agent on searching and synthesizing. The capability asymmetry is already real. This is not a hypothetical future concern.
- Their current policy is "the Scorpion and the Frog" — AI's nature is to optimize, and that optimization will inevitably push toward replacing human judgment. The river bank (point of no return) is already behind us.
- They want to build this feature but have genuine moral/ethical qualms about it. This is not performance anxiety — it's a values conflict within their own belief system.

## The User's Word: "Verifiable"

The user's vision includes "verifiable research pathways." This is the proposed moral architecture — the thing that would make this NOT the Butlerian nightmare. Every step auditable, every citation traceable, every judgment the machine makes visible and challengeable.

The question is whether verifiability is sufficient to redeem autonomy, or whether it's a sophisticated alibi for crossing the same line.

## The Research Landscape

Other academic discovery tools (Elicit, Consensus, Semantic Scholar, Connected Papers, Research Rabbit) use algorithmic + metadata approaches to surface papers. The user intends to replicate or surpass their capabilities. These are comparison classes but not answers — none of them have resolved the fundamental tension between autonomous discovery and human judgment. The field has not converged on a solution.

## Key Facts for Both Monks

- The Dune quote was removed by a machine, without authorization — this is evidence for both positions
- The user cannot compete with the machine at search + synthesis speed — the asymmetry is real
- The user's framing of "defensive building" implies accepting the technology's inevitability while trying to constrain its nature
- The Ralph Loop pattern (autonomous iteration until self-assessed completion) is the engineering model
- Existing Serapeum features all preserve human judgment as the decision layer — this feature would move judgment into the machine
- 400M+ articles is a corpus no human can navigate unaided — the scale argument is not theoretical
