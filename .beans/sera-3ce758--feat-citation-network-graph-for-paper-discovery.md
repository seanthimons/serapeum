---
title: "feat: Citation network graph for paper discovery"
status: completed
type: feature
priority: high
created_at: 2026-02-10T16:53:38Z
updated_at: 2026-02-13T22:41:35Z
---

## Description

Add an interactive citation network graph to search notebooks, allowing users to visualize relationships between papers in their current set, identify clusters, and spot outliers.

## Motivation

When working with a set of search results, it's hard to see the big picture:
- Which papers are central to the field (highly connected)?
- Which papers cite each other (forming research clusters)?
- Which papers are outliers with no citation overlap (possibly off-topic)?

A network graph makes these patterns immediately visible.

## Related Issues
- #25 (seed paper searching) - citation links are the graph edges
- #11 (recursive abstract searching) - graph reveals what to keep/discard
- #40 (Topics & Discovery) - topic clusters visible as graph communities

## Prospective Tasks

### Data Layer
- [ ] Fetch `referenced_works` for each paper in the notebook from OpenAlex
- [ ] Build adjacency list of citation relationships within the current paper set
- [ ] Calculate graph metrics: degree centrality, betweenness, connected components
- [ ] Identify outliers (papers with zero or very few connections to the set)

### Visualization
- [ ] Evaluate R graph libraries (`visNetwork`, `sigmajs`, `networkD3`) for Shiny compatibility
- [ ] Render interactive network graph (zoom, pan, hover for details)
- [ ] Node sizing by citation count or centrality
- [ ] Node coloring by topic, document type, or cluster membership
- [ ] Edge rendering for citation direction (A cites B)
- [ ] Cluster highlighting (co-citation groups)

### Interaction
- [ ] Click node to view paper details
- [ ] Select/highlight a cluster to filter the paper list
- [ ] Flag outlier nodes visually (disconnected or weakly connected)
- [ ] Option to remove outliers from the notebook
- [ ] Toggle between citation graph and topic similarity graph

### Integration
- [ ] Add graph tab/panel to search notebook UI
- [ ] Sync graph selection with paper list (click node → scroll to paper)
- [ ] Use graph insights to feed back into search refinement (#11)

## Open Questions
- Should edges represent direct citations only, or also co-citation (two papers cited by the same third paper)?
- Should the graph auto-layout or allow manual arrangement?
- Performance ceiling: how many papers before the graph becomes unusable? (50? 200?)

<!-- migrated from beads: `serapeum-1774459564190-41-3ce758ab` | github: https://github.com/seanthimons/serapeum/issues/53 -->
