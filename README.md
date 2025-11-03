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

We build high-quality smart contracts by **intentionally restricting Solidity features** and following conventions designed specifically for smart contracts. This is **Smart Contract Oriented Programming (SCOP)**.

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

## Understanding Facets and Libraries

Compose uses two complementary patterns for smart contract development:

### Facets (Complete Implementations)

**Facets** are standalone contracts that contain all the logic needed to implement specific functionality. They're designed to be:

- **Self-contained**: All code needed for the feature is in one file
- **Readable top-to-bottom**: No jumping between files (or within the same file) to understand the logic
- **Deployed once**: Reused across multiple diamonds on-chain
- **Deployed everywhere**: Our facets will be deployed on many blockchains at the same addresses

**Example**: `ERC20Facet.sol` contains the complete ERC-20 token implementation.

### Libraries (Helper Functions)

**Libraries** (prefixed with `Lib`) help developers integrate their custom facets with Compose's facets. They:

- **Provide helper functions**: Reusable internal functions for custom facets
- **Access shared storage**: Work with the same storage layout as their corresponding facet
- **Enable composition**: Allow custom facets to interact with Compose functionality

**Example**: `LibERC20.sol` provides helper functions to interact with ERC-20 storage from custom facets.

### The Key Insight: Shared Storage

**Both facets and libraries access the SAME storage in your diamond.** When `ERC721Facet` and `LibERC721` both define identical storage at `keccak256("compose.erc721")`, they're reading and writing the same data. This is how your custom facets can extend Compose functionality without inheritance.

### When to Use Each

**Use a Facet when you want:**

- The complete, standard implementation (e.g., full ERC-20 functionality)
- To reuse it (onchain) across multiple diamonds
- A verified, audited implementation

**Use a Library when you're:**

- Building a custom facet that needs to interact with Compose features
- Extending standard functionality with custom logic

### Practical Example

```solidity
// Scenario: Building an NFT game with custom minting logic

// 1. Your custom facet uses LibERC721 to access NFT storage
import {LibERC721} from "compose/LibERC721.sol";

contract GameNFTFacet {
    function mintWithGameLogic(address player, uint256 tokenId) external {
        // Your custom game logic here
        require(playerHasEnoughPoints(player), "Not enough points");

        // Use LibERC721 to mint - this modifies the SAME storage
        // that ERC721Facet uses for balanceOf(), ownerOf(), etc.
        LibERC721.mint(player, tokenId);

        // Now the player owns this NFT and can transfer it
        // using the standard ERC721Facet.transferFrom() function!

        // More custom logic
        updatePlayerStats(player);
    }
}

// 2. Deploy your diamond with BOTH facets:
//    - ERC721Facet provides: transfer(), approve(), ownerOf(), etc.
//    - GameNFTFacet provides: mintWithGameLogic()
//    Both facets operate on the SAME NFT collection!
```

## Available Facets & Libraries

Look in the [src directory](https://github.com/Perfect-Abstractions/Compose/tree/main/src) to see the currently provided functionality, facets and libraries.

### Diamond Infrastructure

- **DiamondCutFacet**: Diamond upgrade functionality

Each facet has a corresponding library (`LibOwner`, `LibERC20`, `LibERC721`, etc.) for integration with custom facets.

## Design Principles

Compose follows specific design principles that make it unique:

1. **Understanding First**: Code clarity is the top priority
2. **Repeat Yourself**: We intentionally break DRY when it improves readability
3. **Diamond-Native**: Designed specifically for ERC-2535 diamonds
4. **Onchain Composition**: Combine deployed facets instead of inheriting
5. **Standards Compliance**: Full compatibility with existing ERC standards

For detailed explanations and the complete list of banned Solidity features, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Usage

### Basic Commands

```bash
# Build contracts
forge build

# Run tests
forge test

# Format code
forge fmt

# Gas snapshots
forge snapshot
```

### Creating Your Diamond

Currently, you can use Compose facets by:

1. Deploying the facets you need (or using already-deployed instances when available)
2. Creating your diamond contract following ERC-2535
3. Adding Compose facets alongside your custom facets

_Note: Automated deployment tools and an on-chain diamond factory are planned future features._

## Contributing

We welcome contributions from everyone! Compose grows through community involvement.

**Quick Start for Contributors:**

1. Browse [open issues](https://github.com/Perfect-Abstractions/Compose/issues)
2. Join the [discussion](https://github.com/Perfect-Abstractions/Compose/discussions)
3. Review [contribution guidelines](CONTRIBUTING.md)
4. Join our [Discord](https://discord.gg/DCBD2UKbxc)

See [CONTRIBUTING.md](CONTRIBUTING.md) for:

- Complete setup instructions
- Banned Solidity features list
- Design principles in detail
- Testing requirements
- Code standards

## License

This project is licensed under the MIT License. See the [LICENSE.md](LICENSE.md) file for details.

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
