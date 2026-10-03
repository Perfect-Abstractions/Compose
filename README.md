![Compose](./assets/compose-logo.png)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT) [![Discord](https://img.shields.io/badge/Discord-Join%20Chat-blue.svg)](https://discord.gg/DCBD2UKbxc)

> **⚠️ Early Stage**: Compose is currently in development and only available to contributors and early adopters. It is **NOT production ready**.

## What is Compose?

A smart contract development framework for building modular systems with [ERC-8153 Diamonds](https://eips.ethereum.org/EIPS/eip-2535).

Compose gives you a clear way to split contract functionality into focused facets, reuse proven building blocks, and evolve your onchain application with ease.

**The framework includes:**

- A Solidity library of reusable facets and modules
- A CLI toolkit for projects with Foundry or Hardhat
- Design patterns for combining Compose components with custom logic
- Documentation for building, extending, and testing diamond systems

The project actively evolves based on community input—[tell us](https://github.com/Perfect-Abstractions/Compose/discussions/108) what you'd like Compose to do for you.


## Why Compose is Different

Smart contracts are hard enough to audit and maintain. Compose keeps each piece small, explicit, and easy to read.

We use <a href="https://compose.diamonds/docs/design/banned-solidity-features">**intentional Solidity constraints**</a> and conventions designed specifically for smart contracts. This is **Smart Contract Oriented Programming (SCOP)**.

### Core Philosophy

- **Read First**: Code written to be understood, not just executed
- **Diamond-Native**: Built specifically for ERC-2535 / ERC-8153 diamond contracts
- **Composition Over Inheritance**: Combine facets instead of inheriting contracts
- **Intentional Simplicity**: Banned features lead to clearer, safer code

## Quick Start

## Create a new project with Compose CLI

```bash
npx @perfect-abstractions/compose-cli init
```

## Add Compose to an existing project (Manual Installation)

### Foundry

```bash
forge install Perfect-Abstractions/Compose@tag=compose@0.0.6
```

### Hardhat / NPM

```bash
npm install @perfect-abstractions/compose
```

Packages: [`@perfect-abstractions/compose`](https://www.npmjs.com/package/@perfect-abstractions/compose) · [`@perfect-abstractions/compose-cli`](https://www.npmjs.com/package/@perfect-abstractions/compose-cli). More detail: [Installation](https://compose.diamonds/docs/getting-started/installation).



## Documentation

Please see our [documentation website](https://compose.diamonds/docs/) for full documentation.


## Contributing

We welcome contributions from everyone! Compose grows through community involvement.

Please see the [documentation for contributing](https://compose.diamonds/docs/contribution/how-to-contribute). 

---

<br>

<!-- automd:contributors github="Perfect-Abstractions/Compose" license="MIT" -->

### Made with more than 🩵 by the [Compose Community](https://github.com/Perfect-Abstractions/Compose/graphs/contributors)

<a href="https://github.com/Perfect-Abstractions/Compose/graphs/contributors">
<img src="https://contrib.rocks/image?repo=Perfect-Abstractions/Compose" />
</a>

<!-- /automd -->
