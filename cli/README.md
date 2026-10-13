# Compose CLI

The Compose CLI is the fastest way to start a modular smart contract project. Scaffold a facet-based diamond, choose your building blocks, and develop with [Foundry](https://book.getfoundry.sh/) or [Hardhat](https://hardhat.org/).

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
compose install [facet-ref...] [options]
compose remove [facet-name...] [options]
compose catalog
compose info
compose validate
compose build
compose rpc [options]
compose inspect <address> [options]
compose --version | -v
compose --help | -h
```

`compose install` also has the short alias `compose i`. `compose remove` also has the alias `compose rm`.

### `compose init`

Scaffold a new Compose diamond project.

**Options:**
- `[project-name]`: directory name for the new project
- `--framework <foundry|hardhat>`: target framework
- `--toolbox <ethers|viem>`: Hardhat toolbox (default: ethers)
- `--base <base-id>`: base preset (counter, erc-20, erc-721, erc-1155, erc-6909)
- `--ownership <none|owner|owner-two-step>`: ownership model
- `--access-control <facets...>`: access control facets to include
- `--libraries <facets...>`: Compose library facets to include
- `--extensions <facets...>`: extension facets to include
- `--out <dir>`: parent directory for the project (defaults to the current directory)
- `--yes`: non-interactive mode with sensible defaults
- `--install-deps` / `--no-install-deps`: install or skip framework dependencies

When `--yes` is not provided, `compose init` will prompt for any values you omit.

### `compose catalog`

List all available bases for init. Displays bases grouped by type (Features, Access Control) with their required and optional facet counts.

### `compose info`

Display a summary of the local project:
- All diamonds defined in the project
- Facets and their selectors
- Storage slot annotations
- Validation warnings

### `compose install` / `compose i`

Register facets in the desired composition for a diamond in `compose.json`.
This edits project configuration only; it does not deploy facets or change a deployed diamond.

```bash
# Register Compose catalog facets
compose install ERC20BurnFacet DiamondUpgradeFacet --diamond my-token

# Register a local facet (the source file must already be in the project)
compose i src/facets/FeeFacet.sol:FeeFacet --diamond my-token

# Create a reviewable batch file without applying it
compose install --create-manifest add-fees --diamond my-token

# Apply a batch file from compose/facet-batches/add-fees.json
compose install --manifest add-fees
```

**Options:**
- `--diamond <name>`: target diamond; inferred when the project defines one diamond, otherwise prompted interactively or required in non-interactive use
- `--project-root <dir>`: start searching for the project from this directory
- `--manifest <path-or-name>`: apply an install manifest; a simple name resolves under `compose/facet-batches/`
- `--create-manifest <name>`: create a manifest in `compose/facet-batches/` without changing `compose.json`
- `--yes`: skip interactive confirmation prompts

Catalog facets backed by local Compose templates are copied into the framework's Solidity source tree. Local `path.sol:ContractName` references are registered in place. Package facets require their package source to be available in the project.

### `compose remove` / `compose rm`

Unregister facets from the desired composition. This does not delete Solidity files or package dependencies, and it does not modify an already deployed diamond.
The CLI keeps at least one facet registered per diamond so the project remains validatable.

```bash
compose remove FeeFacet --diamond my-token
compose rm --manifest remove-legacy
compose remove --create-manifest remove-legacy --diamond my-token
```

The options are the same as `compose install`. In an interactive terminal, direct removals ask for confirmation. `--manifest` accepts a file path or a name under `compose/facet-batches/`.

### Facet batch manifests

Manifests are versioned JSON files and can be reviewed or edited before applying. Install manifests accept catalog names or explicit local/package references:

```json
{
  "version": 1,
  "operation": "install",
  "diamonds": {
    "my-token": [
      { "name": "ERC20BurnFacet" },
      {
        "name": "FeeFacet",
        "source": "local",
        "contract": "src/facets/FeeFacet.sol:FeeFacet"
      }
    ]
  }
}
```

Remove manifests list registered facet names:

```json
{
  "version": 1,
  "operation": "remove",
  "diamonds": { "my-token": ["LegacyFacet"] }
}
```

Applying a batch validates the resulting source configuration before writing `compose.json`. It checks selector collisions and virtual storage layout compatibility. Install/remove commands do not update `compose.lock` or refresh the deploy script generated by `init`; deployment tooling will consume the configured facet set in a later workflow.

### `compose validate`

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
compose init my-counter --framework foundry --base counter --ownership owner --yes

# Hardhat project with ERC-20 base and extensions
compose init my-token \
  --framework hardhat \
  --toolbox ethers \
  --base erc-20 \
  --ownership owner-two-step \
  --extensions ERC20BurnFacet,ERC20MintFacet \
  --libraries ERC165Facet \
  --yes

# Hardhat project with Viem toolbox
compose init my-nft \
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

**Start your next smart contract system with a structure you can understand and extend.**

**-Nick & The Compose Community**

<!-- automd:contributors github="Perfect-Abstractions/Compose" license="MIT" -->

### Made with 🩵 by the [Compose Community](https://github.com/Perfect-Abstractions/Compose/graphs/contributors)

<a href="https://github.com/Perfect-Abstractions/Compose/graphs/contributors">
<img src="https://contrib.rocks/image?repo=Perfect-Abstractions/Compose" />
</a>

<!-- /automd -->
