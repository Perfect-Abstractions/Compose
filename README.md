# Compose

> **⚠️ Early Stage**: Compose is currently in development and only available to contributors. It is **NOT production ready**.


[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Discord](https://img.shields.io/badge/Discord-Join%20Chat-blue.svg)](https://discord.gg/DCBD2UKbxc)

**Forget everything you know about designing and organizing smart contracts**, because Compose is different.

We are building a high-quality smart contract library by **banning Solidity functionality** and consistently following conventions and design principles that are oriented to smart contracts. We are breaking existing software development rules in order to write good software specifically for smart contracts. This is **smart contract oriented programming (SCOP)**.

## Table of Contents

- [Quick Start](#quick-start)
- [What Makes Compose Different](#what-makes-compose-different)
- [Banned Solidity Features](#banned-solidity-features)
- [Design Principles](#design-principles)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)

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
```

## What Makes Compose Different

Compose is designed specifically for smart contracts with these unique characteristics:

- **Banned Solidity Features**: We intentionally restrict certain Solidity features to create simpler, more readable code
- **Diamond Contracts**: Built for [ERC-2535 diamond standard](https://eips.ethereum.org/EIPS/eip-2535) with modular, composable facets
- **Onchain Composition**: Favor composition over inheritance
- **Readable Code**: Code written to be read and understood
- **Smart Contract Oriented**: Design principles specifically for immutable, forever-running contracts

## Banned Solidity Features

Compose intentionally restricts certain Solidity features to create simpler, more readable code. Anyone submitting a pull request that uses banned features will be fined **$100 USDC**.

**Key Restrictions:**
- **No inheritance**: Use onchain composition instead
- **No constructors**: Use [diamond-based deployment](https://eip2535diamonds.substack.com/p/initializing-an-eip-2535-diamond) instead
- **No modifiers**: Use code written within functions instead
- **No visibility labels**: Use [diamond storage](https://eips.ethereum.org/EIPS/eip-8042) instead.
- **No private/public functions**: Use internal/external only
- **No external functions in libraries**: Use internal only
- **No `using for` directives**: Use internal functions instead
- **No `selfdestruct`**: Use safe contracts instead

[Endless discussion](https://discord.gg/DCBD2UKbxc) about what and why Solidity features should or shouldn't be allowed is *encouraged*.

> **Note**: The feature ban applies to the library itself, not to users of the library. Users can do what they want - it's our job to help them.

For complete details and examples, see [CONTRIBUTING.md](CONTRIBUTING.md#banned-solidity-features).

## Design Principles

Compose follows unique design principles specifically for smart contract development:

- **Read First**: Code written to be read and understood by present and future developers
- **Repeat Yourself**: Intentionally break DRY principle when it improves readability
- **Diamond Contracts**: Built for [ERC-2535 diamond standard](https://eips.ethereum.org/EIPS/eip-2535)
- **Onchain Composition**: Favor composition over inheritance
- **Compatibility**: Maintain compatibility with existing standards and systems

For detailed explanations and examples, see [CONTRIBUTING.md](CONTRIBUTING.md#design-principles).


## Reading a Facet

In Compose, each facet smart contract contains the storage variables and logic needed to implement its core functionality. The code in a facet is written to be easily read and understood from top to bottom—users can start at the first line and follow the logic sequentially to the end of the file without needing to jump to other sections or files.

Each facet includes the complete implementation of its main functionality. Facets do not rely on external contracts or Solidity libraries to implement their core behavior.

## The Use of Solidity Libraries

In Compose, it’s common for a facet to have a corresponding Solidity library. These libraries are designed to help developers integrate their custom facets with Compose’s built-in facets.

For example, Compose includes a facet called `ERC721Facet.sol` and a corresponding library called `LibERC721.sol`. The `ERC721Facet.sol` file contains the complete implementation of the ERC-721 functionality—it does not reference or depend on `LibERC721.sol`.

The `LibERC721.sol` library intentionally duplicates the storage variables and parts of the logic from `ERC721Facet.sol`. This allows developers creating their own custom facets to easily access and work with the `ERC-721` storage variables and functionality provided by Compose.

All Solidity libraries in Compose are prefixed with `Lib`.

## Contributing

We welcome contributions from everyone! 

Please see our [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

**Quick Start for Contributors:**
1. Choose an [issue](https://github.com/Perfect-Abstractions/Compose/issues) to work on
2. Look at [ERC20 and ERC721 implementations](./src/) for examples
3. Follow our [contribution guidelines](CONTRIBUTING.md)
4. Join our [discussions](https://github.com/Perfect-Abstractions/Compose/discussions)
4. Join our [discord](https://discord.gg/DCBD2UKbxc)

Browse our [issues](https://github.com/Perfect-Abstractions/Compose/issues) and [discussions](https://github.com/Perfect-Abstractions/Compose/discussions) to get familiar with the project and find ways to contribute.


## Usage

```bash
# Build the project
forge build

# Run tests
forge test

# Format code
forge fmt
```

For complete development commands and deployment instructions, see [CONTRIBUTING.md](CONTRIBUTING.md#available-commands).

## License

This project is licensed under the MIT License. See the [LICENSE.md](LICENSE.md) file for details.

---

<br>

**This is the beginning and we are still working out how this will all work. We are glad you are interested in this project and want to make something great with you.**

**-Nick**

