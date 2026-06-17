---
title: Allow for export from network graph to abstract search + export from abstract to network
status: todo
type: feature
priority: normal
tags:
  - ui
created_at: 2026-02-12T22:05:03Z
updated_at: 2026-03-29T21:26:00Z
parent: sera-c879
---

## Feature Description

UI to convert a network graph to an abstract notebook, and an abstract notebook to a network graph. 

## Use Case

Users may want to see how their papers are organized + allow for more narrow filtering before promoting to a document notebook

## Proposed Solution

UI for abstract -> network can build off the current export options to save space. 
UI for network to abstract should indicated this is a one-way trip. 
 - Question: how does the existing filters affect this? If I have a filter that remove no citation works or preprints, when does that kick in to remove papers? Do we need to trigger the modal first and then import?

<!-- migrated from beads: `serapeum-1774459564770-67-cb042ca2` | github: https://github.com/seanthimons/serapeum/issues/84 -->
