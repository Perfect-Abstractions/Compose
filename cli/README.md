# Compose CLI

Command-line toolkit for building, deploying, and managing diamond smart contracts using the Compose Library. Supports both [Foundry](https://book.getfoundry.sh/) and [Hardhat](https://hardhat.org/) frameworks.

## Quick Start

```bash
npx @perfect-abstractions/compose-cli init
```

This starts an interactive flow to scaffold a new diamond project with:
- Base preset selection (Counter, ERC-20, ERC-721, ERC-1155, ERC-6909)
- Extension facet selection
- Ownership and access control configuration
- Compose library facet selection
- Framework setup (Foundry or Hardhat)

## Usage

```bash
compose init [options]
compose info
compose validate
compose --version | -v
compose --help | -h
```

### `compose init`

Scaffold a new Compose diamond project.

**Options:**
- `--name <project-name>`: directory name for the new project
- `--framework <foundry|hardhat>`: target framework
- `--toolbox <ethers|viem>`: Hardhat toolbox (default: ethers)
- `--base <base-id>`: base preset (counter, erc-20, erc-721, erc-1155, erc-6909)
- `--ownership <none|owner|owner-two-step>`: ownership model
- `--access-control <facets...>`: access control facets to include
- `--libraries <facets...>`: Compose library facets to include
- `--extensions <facets...>`: extension facets to include
- `--examples`: include local example facets
- `--yes`: non-interactive mode with sensible defaults
- `--no-install-deps`: skip dependency installation

When `--yes` is not provided, `compose init` will prompt for any values you omit.

### `compose info`

Display a summary of the local project:
- All diamonds defined in the project
- Facets and their selectors
- Storage slot annotations
- Validation warnings

### `compose validate` (Coming Soon...)

Run static analysis on the local codebase:
- Storage layout validation
- Selector clash detection
- `exportSelectors` consistency checks
- Missing facet registration warnings

Exit code non-zero on failure (CI-friendly).

## Base Presets

Each base preset provides a starting point for common diamond patterns:

| Base | Description | Required Facets |
|------|-------------|-----------------|
| **Counter** (local) | Simple counter with increment/decrement | CounterDataFacet, CounterIncrementFacet, CounterDecrementFacet |
| **ERC-20** (package) | Fungible token standard | ERC20DataFacet, ERC20ApproveFacet, ERC20TransferFacet |
| **ERC-721** (package) | Non-fungible token standard | ERC721DataFacet, ERC721ApproveFacet, ERC721TransferFacet |
| **ERC-1155** (package) | Multi-token standard | ERC1155DataFacet, ERC1155ApproveFacet, ERC1155TransferFacet |
| **ERC-6909** (package) | Minimal multi-token standard | ERC6909DataFacet, ERC6909TransferFacet |

Each base has compatible extension facets that are filtered during interactive selection to prevent cross-standard conflicts.

## Examples

### Interactive mode

```bash
compose init
```

Follow the prompts to select framework, base, extensions, ownership, and access control.

### Non-interactive examples

```bash
# Foundry project with Counter base
compose init --name my-counter --framework foundry --base counter --ownership owner --yes

# Hardhat project with ERC-20 base and extensions
compose init --name my-token \
  --framework hardhat \
  --toolbox ethers \
  --base erc-20 \
  --ownership owner-two-step \
  --extensions ERC20BurnFacet,ERC20MintFacet \
  --libraries ERC165Facet \
  --yes

# Hardhat project with Viem toolbox
compose init --name my-nft \
  --framework hardhat \
  --toolbox viem \
  --base erc-721 \
  --ownership owner \
  --libraries DiamondUpgradeFacet,ERC165Facet \
  --yes
```

## Generated Project Structure

The CLI generates a project with the following structure:

```
my-diamond/
  src/
    diamond/
      Diamond.sol
    libraries/
      (Compose library facets)
    facets/
      (Custom and extension facets)
  test/
    Diamond.t.sol (Foundry) or Diamond.ts (Hardhat)
  script/
    Deploy.s.sol (Foundry) or deploy.ts (Hardhat)
  compose.json
  foundry.toml or hardhat.config.ts
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
