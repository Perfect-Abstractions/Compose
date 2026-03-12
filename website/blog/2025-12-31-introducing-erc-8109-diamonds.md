---
slug: introducing-erc-8109-diamonds
title: Introducing ERC-8109 Diamonds, a Standard for Simpler Diamond Contracts
authors: [mudgen]
tags: [architecture, standards]
---

> This post is adapted from an article originally [published on my Substack](https://eip2535diamonds.substack.com/p/introducing-erc-8109-diamonds-simplified), and is reposted here because ERC-8109 directly informs the architecture and goals of Compose.

While working on Compose, I decided to revisit parts of [ERC-2535 Diamonds](https://eips.ethereum.org/EIPS/eip-2535) to see how the standard could be improved. Initially, I thought this would be limited to terminology changes, which led to my post [Revising ERC-2535 Diamonds to Simplify and Improve the Terminology](https://ethereum-magicians.org/t/revising-erc-2535-diamonds-to-simplify-and-improve-the-terminology/26973).

However, that effort revealed deeper opportunities for improvement — enough that I ultimately decided to propose a new standard for diamond contracts.

<!-- truncate -->

## A Flawed Narrative

The primary issue I wanted to address is complexity.

Too many articles and discussions imply that diamonds are inherently complex, or that they should only be used when building complicated systems. That narrative is backwards.

Diamonds should be used when you want to build **large systems that remain simple** — systems that are easy to understand, reason about, test, audit, and evolve.

Any powerful tool can be used well or poorly. Diamonds can reduce complexity, or they can increase it if misapplied.

Let’s do this right.

## How Diamonds Reduce Complexity

Diamonds reduce complexity in two fundamental ways:

1. A single contract address
   A diamond exposes a large surface area of functionality through one address, simplifying deployment, integration, tooling, and user interfaces.

2. Decomposition into focused facets
   Large contracts are broken into small, purpose-built facets. Each facet is independently testable and understandable. The diamond then wires these facets together in a systematic, efficient, and documented manner.

The benefits of modularity are well understood in software engineering — and diamonds bring those benefits on-chain.

## ERC-8109: Diamonds, Simplified

The new standard, [ERC-8109: Diamonds, Simplified](https://eips.ethereum.org/EIPS/eip-8109), focuses on reducing complexity while preserving the full power of diamond contracts. It does so by:

### 1. Simplifying terminology
   - “loupe” → introspection
   - “cut” → upgrade

### 2. Simplifying introspection

Only two introspection functions are required:

- facetAddress(selector) — returns the facet address for a given function selector
- functionFacetPairs() — returns all (selector, facet) pairs

### 3. Standardizing simpler events

Replaces the monolithic DiamondCut event with per-function events:

- DiamondFunctionAdded
- DiamondFunctionReplaced
- DiamondFunctionRemoved

These events simplify the implementation of functions that add/replace/remove functions and are easier for block explorers, indexers, and other tooling to consume.

### 4. Defining an optional upgrade function

An explicitly specified, optional, upgrade function, including metadata support, to ensure consistent behavior across tooling.

### 5. Providing an optional upgrade path

Existing ERC-2535 diamonds can adopt the new standard.

## Compose

Compose goes beyond standards and documentation. Compose is the practical application of the ideas behind ERC-8109.

Together with [maxnorm](https://github.com/maxnorm) and others, I’m building Compose to help developers use ERC-8109 Diamonds to construct modular smart-contract systems. Compose will provide:

- A library of reusable, on-chain facets.
- Tooling for deploying, testing, and working with diamonds.

Compose is intended to make the *right* way to build diamond systems the *easy* way.

## Call to Action

Please read the new standard here:
[ERC-8109: Diamonds, Simplified](https://eips.ethereum.org/EIPS/eip-8109)

Share your feedback here:
[Feedback for ERC-8109: Diamonds, Simplified](https://ethereum-magicians.org/t/erc-8109-diamonds-simplified/27119)

If you care about building large smart contract systems that remain simple, understandable, and robust, I invite your collaboration.