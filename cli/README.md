# Compose CLI

The Compose CLI is the fastest way to start a modular smart contract project. Scaffold a facet-based diamond, choose your building blocks, and develop with [Foundry](https://book.getfoundry.sh/) or [Hardhat](https://hardhat.org/).

## Quick Start

```bash
npx @perfect-abstractions/compose-cli init
```

This starts an interactive flow to scaffold a new diamond project with:
- Base preset selection (Counter, ERC-20, ERC-721, ERC-721 Enumerable, ERC-1155, ERC-6909)
- Upgradeability selection (immutable by default)
- Extension facet selection
- Ownership and access control configuration
- Compose library facet selection
- Framework setup (Foundry or Hardhat)

## Usage

```bash
compose init [options] [project-name]
compose install [facet-ref...] [options]
compose remove [facet-ref...] [options]
compose catalog
compose info
compose validate [options]
compose build
compose rpc [options]
compose inspect <address> [options]
compose deploy [options]
compose help [command]
compose --version | -V
compose --help | -h
```

### `compose init`

Scaffold a new Compose diamond project.

**Options:**
- `[project-name]`: directory name for the new project
- `--framework <foundry|hardhat>`: target framework (default: foundry)
- `--toolbox <ethers|viem>`: Hardhat toolbox (default: ethers)
- `--base <base-id>`: base preset — `counter`, `erc-20`, `erc-721`, `erc-721-enumerable`, `erc-1155`, `erc-6909`, or `none` for a blank project
- `--ownership <base>`: ownership base — `owner` or `owner-two-step`; omit the flag for no ownership (upgradeable projects without an ownership base default to `owner`)
- `--ownership-extensions <facets>`: comma-separated ownership extension facets
- `--access-control <bases>`: comma-separated access control bases (for example `access-control`)
- `--access-control-extensions <facets>`: comma-separated access control extension facets
- `--upgradeable`: include `DiamondUpgradeFacet` and the owner coupling
- `--immutable`: scaffold without the upgrade facet and owner coupling (default)
- `--libraries <facets>`: comma-separated Compose library facets
- `--extensions <facets>`: comma-separated extension facets
- `--out <dir>`: parent directory for the project (defaults to the current directory)
- `--yes`: non-interactive mode; requires `--base`
- `--install-deps` / `--no-install-deps`: install or skip framework dependencies

Selection flags apply to `--yes` runs. Without `--yes`, only `[project-name]` and `--out` are honored and `compose init` prompts for the framework, toolbox, base, upgradeability, extensions, libraries, ownership, access control, and dependency installation.

Immutable is the default. `--upgradeable` adds `DiamondUpgradeFacet` and, when no ownership base is chosen, Compose offers the `owner` base (interactive) or adds it with a note (non-interactive). An explicit `DiamondUpgradeFacet` in `--libraries` opts into upgradeability the same way for compatibility; combining it with `--immutable` is an error.

Hardhat projects scaffold a `local` network entry (`http://127.0.0.1:8545`, remote accounts) so deployments can target a locally running Anvil node.

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

# Register a local facet by contract name; the source file is located by fuzzy match
compose i FeeFacet --diamond my-token

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

Catalog facets backed by local Compose templates are copied into the framework's Solidity source tree. Local `path.sol:ContractName` references are registered in place. A bare name that is not in the catalog is fuzzy-matched against the project's Solidity sources (file name first, then declared contract names, then substring matches); several matches prompt interactively outside of `--yes`/non-interactive use. Package facets require their package source to be available in the project.

### `compose remove` / `compose rm`

Unregister facets from the desired composition. This does not delete Solidity files or package dependencies, and it does not modify an already deployed diamond.
The CLI keeps at least one facet registered per diamond so the project remains validatable.

```bash
compose remove FeeFacet --diamond my-token
compose rm --manifest remove-legacy
compose remove --create-manifest remove-legacy --diamond my-token
```

The options are the same as `compose install`. Facet arguments take the same forms as install — a catalog or project contract name, or a `path.sol:ContractName` reference — and both resolve to the registered facet name. In an interactive terminal, direct removals ask for confirmation. `--manifest` accepts a file path or a name under `compose/facet-batches/`.

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

Applying a batch validates the resulting source configuration before writing `compose.json`. It checks selector collisions and virtual storage layout compatibility. Install/remove commands do not update `compose.lock` or the managed deploy script; `compose deploy` consumes the configured facet set directly.

### `compose validate`

Run static analysis on the local codebase:
- Storage layout validation
- Selector clash detection
- `exportSelectors` consistency checks
- Missing facet registration warnings

**Options:**
- `--project-root <dir>`: start searching for the project from this directory

Exit code non-zero on failure (CI-friendly).

### `compose build`

Compile the project if artifacts are stale or missing.

### `compose rpc`

Check RPC connectivity and optionally inspect contract bytecode.

**Options:**
- `--chain <chain-key>`: chain key from `compose.json` (default: `local`)
- `--address <address>`: contract address to check or inspect

### `compose inspect`

Inspect a deployed diamond's facets and selectors.

**Arguments:**
- `<address>`: diamond contract address to inspect

**Options:**
- `--chain <chain-key>`: chain key from `compose.json` (default: `local`)

### `compose deploy`

Plan a diamond deployment, generate a reviewable framework script, execute it, verify the result on-chain, and record it in `compose.lock`.

**Options:**
- `--diamond <name>`: diamond definition to deploy (inferred when the project has one)
- `--chain <chain-key>`: chain key from `compose.json` (default: `local`)
- `--instance <name>`: deployment instance name (default: `default`)
- `--project-root <dir>`: start searching for the project from this directory
- `--dry-run`: print the plan and a script preview without writing anything
- `--broadcast`: execute the managed script, verify the deployment, and write `compose.lock`
- `--redeploy`: deploy a new diamond when a lock record already exists (the previous one is abandoned, not upgraded)
- `--`: everything after it is forwarded to the framework (`forge script` / `hardhat run`) — use it for signing options like `--private-key` or `--account`

Signing stays in the framework; the CLI never handles keys. A run without `--broadcast` writes `script/ComposeDeploy.s.sol` (Foundry) or `scripts/compose-deploy.ts` (Hardhat) for review. Interactive runs print the script path (relative to the project root) and ask whether to run it now; non-interactive runs stop with instructions to review and re-run with `--broadcast`. `--dry-run` prints the script source inline instead.

```bash
compose deploy                       # plan, write the script, review it
compose deploy --broadcast           # execute the reviewed script, verify, write compose.lock
compose deploy --broadcast -- --account deployer
```

A run reports `in sync` and stops when the recorded facet set already matches `compose.json`. When the composition changed, it prints the add/remove diff and exits non-zero (applying upgrades is a later milestone — `--redeploy` abandons the record and deploys fresh instead).

## Base Presets

Each base preset provides a starting point for common diamond patterns:

| Base | Description | Required Facets |
|------|-------------|-----------------|
| **Counter** (local) | Simple counter with increment/decrement | CounterDataFacet, CounterIncrementFacet |
| **ERC-20** (package) | Fungible token standard | ERC20DataFacet, ERC20ApproveFacet, ERC20TransferFacet |
| **ERC-721** (package) | Non-fungible token standard | ERC721DataFacet, ERC721ApproveFacet, ERC721TransferFacet |
| **ERC-721 Enumerable** (package) | ERC-721 with token enumeration | ERC721ApproveFacet, ERC721DataFacet, ERC721EnumerableDataFacet, ERC721EnumerableTransferFacet |
| **ERC-1155** (package) | Multi-token standard | ERC1155DataFacet, ERC1155ApproveFacet, ERC1155TransferFacet |
| **ERC-6909** (package) | Minimal multi-token standard | ERC6909DataFacet, ERC6909TransferFacet, ERC6909ApproveFacet, ERC6909OperatorFacet |

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
  --extensions ERC20BurnFacet,ERC20PermitFacet \
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
  compose.json
  foundry.toml or hardhat.config.ts
```

`compose deploy` generates a CLI-managed `script/ComposeDeploy.s.sol` (Foundry) or `scripts/compose-deploy.ts` (Hardhat) from `compose.json` and records verified deployments in `compose.lock`.

## Documentation

Please see our [documentation website](https://compose.diamonds/docs/) for full documentation.


## Contributing

We welcome contributions from everyone! Compose grows through community involvement.

Please see the [documentation for contributing](https://compose.diamonds/docs/contribution/how-to-contribute). 

---

<br>

**Start your next smart contract system with a structure you can understand and extend.**

**-The Compose Community**

<!-- automd:contributors github="Perfect-Abstractions/Compose" license="MIT" -->

### Made with 🩵 by the [Compose Community](https://github.com/Perfect-Abstractions/Compose/graphs/contributors)

<a href="https://github.com/Perfect-Abstractions/Compose/graphs/contributors">
<img src="https://contrib.rocks/image?repo=Perfect-Abstractions/Compose" />
</a>

<!-- /automd -->
