# Compose

> **⚠️ Early Stage**: Compose is currently in development and only available to contributors. It is **NOT production ready**.

## What is Compose?

Compose is a smart contract library that helps developers create smart contract systems using [ERC-2535 Diamonds](https://eips.ethereum.org/EIPS/eip-2535).

**Compose provides:**

- An on-chain standard library of facets (modular smart contracts)
- Building blocks for diamond-based smart contract systems
- Patterns and libraries to combine Compose facets with your custom logic

The project actively evolves based on community input—[tell us](https://github.com/Perfect-Abstractions/Compose/discussions/108) what you'd like Compose to do for you.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Discord](https://img.shields.io/badge/Discord-Join%20Chat-blue.svg)](https://discord.gg/DCBD2UKbxc)

## Why Compose is Different

**Forget traditional smart contract design patterns**—Compose takes a radically different approach.

We build high-quality smart contracts by <a href="https://compose.diamonds/docs/design/banned-solidity-features">**intentionally restricting Solidity features**</a> and following conventions designed specifically for smart contracts. This is **Smart Contract Oriented Programming (SCOP)**.

### Core Philosophy

- **Read First**: Code written to be understood, not just executed
- **Diamond-Native**: Built specifically for ERC-2535 diamond contracts
- **Composition Over Inheritance**: Combine facets instead of inheriting contracts
- **Intentional Simplicity**: Banned features lead to clearer, safer code

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Perfect-Abstractions/Compose.git
cd Compose

# Install dependencies
forge install

# Build the project
forge build

# Run tests
forge test

# For test documentation, see test/README.md
```
## Documentation

Please see our [documentation website](https://compose.diamonds/docs/) for full documentation.


## Contributing

We welcome contributions from everyone! Compose grows through community involvement.

Please see the [documentation for contributing](https://compose.diamonds/docs/contribution/how-to-contribute). 

---

<br>

**Compose is evolving with your help. Join us in building the future of smart contract development.**

**-Nick & The Compose Community**

<!-- automd:contributors github="Perfect-Abstractions/Compose" license="MIT" -->

### Made with 🩵 by the [Compose Community](https://github.com/Perfect-Abstractions/Compose/graphs/contributors)

<a href="https://github.com/Perfect-Abstractions/Compose/graphs/contributors">
<img src="https://contrib.rocks/image?repo=Perfect-Abstractions/Compose" />
</a>

<!-- /automd -->
