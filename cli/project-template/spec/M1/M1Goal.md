# Development Commands

## `compose init`

Scaffold a new Compose diamond project.

`compose init` creates a new local project, generates the initial `compose.json`, and prepares the project file structure.

`compose init` should build a diamond configuration from available Compose library facets, starter patterns, local example facets, and framework-specific project setup.

- Supports interactive prompts or flag-driven usage.
- Generates `compose.json` during scaffolding.
- Supports Foundry and Hardhat project setup.
- Supports starter presets such as bare diamond, Counter, ERC-20, ERC-721, and future examples.
- Allows the developer to select, add, or remove available Compose library facets before generation.
- Optionally generates local starter facets and tests.
- Recomputes the diamond surface as facets are added or removed.
- Resolves selected facets into a selector ownership table before writing the project.
- Detects selector collisions during project building.
- Shows collision details during interactive facet selection.
- Allows the developer to resolve collisions by choosing an owner, excluding selectors, or removing one of the colliding facets.
- Writes explicit selector export rules when a collision is resolved intentionally.
- Fails safely in non-interactive mode if required choices or selector collisions cannot be resolved automatically.

Interactive flow:

```shell
Select project framework:
> Foundry
  Hardhat

# A base is a standard that consists of multiple facets.
Select base:
  Bare diamond
> ERC-20
  ERC-721

# Libraries are facets for cross-cutting concerns.
Select Compose library facets:
[x] DiamondInspectFacet
[x] ERC165Facet
[ ] OwnershipFacet
...

# Extensions are facets that support optional features of a standard.
Select extension facets:
[ ] ERC20BurnFacet
[ ] ERC20MintFacet
[ ] ERC20MetadataFacet
[ ] ERC20PermitFacet

Select local example facets:
[x] CounterFacet
[ ] None

# Run internal validation here.

> Yes
```

**Example non-interactive usage:**

```shell
compose init my-diamond \
  --framework foundry \
  --base ERC20 \
  --library AccessControlAdminFacet,AccessControlGrantFacet \
  --extension ERC20MetadataFacet \
  --yes
```

Non-interactive mode must only succeed when the selected preset fully resolves the project shape, including selector ownership. If unresolved selector collisions are found, the command must fail with a clear error instead of guessing.

The builder must never rely on facet order, implicit priority, or last-write-wins behavior to resolve selector ownership. Every imported selector in the generated diamond must have exactly one owner.

### Metadata

This metadata is owned by Compose CLI and lives under the Compose root directory, not inside the user project directory.
It acts as an internal catalog for `compose init` to decide which diamond facets, library facets, base facets, and extension facets are available for selection.

The source of truth is the Compose-owned `bases` directory. `diamond.json` and `libraries.json` are special global catalogs. Every other JSON file is a selectable base. Each base has two parts:

- `required`: facets that are always included when that base is selected.
- `optional`: extension facets shown after the user selects that base.

For `diamond.json` and `libraries.json`, required facets are included for every generated diamond. Optional facets are shown in the Compose library selection unless they are already required by the selected base.

Example:

```json
{
  "diamond.json": {
    "diamond": {
      "label": "Diamond",
      "required": {
        "DiamondInspectFacet": {
          "path": "./src/templates/diamond/DiamondInspectFacet.sol"
        }
      },
      "optional": {
        "DiamondUpgradeFacet": {
          "path": "./src/templates/diamond/DiamondUpgradeFacet.sol"
        }
      }
    }
  },
  "libraries.json": {
    "libraries": {
      "label": "Libraries",
      "required": {},
      "optional": {
        "ERC165Facet": {
          "path": "./src/templates/interfaceDetection/ERC165/ERC165Facet.sol"
        }
      }
    }
  },
  "erc20.json": {
    "erc-20": {
      "label": "ERC-20",
      "required": {
        "ERC20DataFacet": {
          "path": "./src/templates/token/ERC20/Data/ERC20DataFacet.sol"
        },
        "ERC20ApproveFacet": {
          "path": "./src/templates/token/ERC20/Approve/ERC20ApproveFacet.sol"
        },
        "ERC20TransferFacet": {
          "path": "./src/templates/token/ERC20/Transfer/ERC20TransferFacet.sol"
        }
      },
      "optional": {
        "ERC20BurnFacet": {
          "path": "./src/templates/token/ERC20/Burn/ERC20BurnFacet.sol"
        },
        "ERC20MetadataFacet": {
          "path": "./src/templates/token/ERC20/Metadata/ERC20MetadataFacet.sol"
        },
        "ERC20PermitFacet": {
          "path": "./src/templates/token/ERC20/Permit/ERC20PermitFacet.sol"
        },
        "ERC20BridgeableFacet": {
          "path": "./src/templates/token/ERC20/Bridgeable/ERC20BridgeableFacet.sol"
        }
      }
    }
  },
  "erc721.json": "...",
  "erc1155.json": "..."
}
```

#### Target project layout

```txt
root
`-- src
    |-- diamond
    |   `-- diamond facets
    |-- libraries
    |   `-- shared project libraries
    `-- facets
        |-- base
        |   `-- base facets
        `-- extensions
            `-- extension facets
```

## `compose validate`

### Definition

Static analysis on the local codebase before deployment.

- **Auto-compilation**: Detects the project framework (Foundry or Hardhat) and runs `forge build` or `hardhat compile` under the hood if compiled artifacts are stale or missing. Skips compilation if artifacts are already fresh.
- **Storage layout validation**: When multiple facets share a namespaced storage slot, validates that structs are safely extended. New fields may be appended (e.g. `{a, b}` to `{a, b, c}`), but fields must not be reordered or inserted (e.g. `{a, b}` to `{a, c, b}` is invalid). One struct must be a prefix of the other. Storage slot detection uses a fallback chain:
  1. **ERC-8042 annotation** (`@custom:storage-location erc8042:<namespace>`): preferred, parsed directly from source.
  2. **`.slot :=` pattern**: if the annotation is missing, the CLI scans the source for any assembly block containing a `.slot :=` assignment, regardless of whether it occurs in a dedicated accessor function or inline. From each match, it traces backward to resolve: (a) the `keccak256("namespace")` constant that feeds the slot, and (b) the struct type of the storage variable being assigned. This produces the same namespace-to-struct mapping as the annotation. A warning is raised: *"Missing `@custom:storage-location` annotation -- storage slot inferred from `.slot :=` pattern. Add the annotation for reliable detection."*
  3. **Neither detected**: the storage check is skipped for that facet with a warning: *"Cannot determine storage layout -- no ERC-8042 annotation or recognized storage pattern found."*
- **Selector clash detection**: Flags two different functions that hash to the same 4-byte selector across all facets in the diamond.
- **`exportSelectors()` consistency**: Verifies every facet's `exportSelectors()` return value matches its actual external functions.
- **Missing facet registration**: Warns about facets in the codebase not referenced in `compose.json`.
- Exit code non-zero on failure (CI-friendly).

### Validation types

#### Selector collision

Compute each selected function's 4-byte selector and detect duplicates.
This can be handled using `exportSelectors()` on each facet.

#### Storage collision

Storage collision happens when two different layouts point to the same storage slot.

There are three main kinds of storage collision:

- Two different storage layouts point to the same identifier.
- Variables are placed outside the diamond storage struct.
- Storage changes during an update, such as a new variable placed in the middle of a struct.

Across this project, some storage layouts may have a different number of elements while still preserving the same field order.
Those implementations are valid.

#### Example

```solidity
// Valid
// ERC20Mint
bytes32 constant STORAGE_POSITION = keccak256("erc20");
struct ERC20Storage {
    mapping(address owner => uint256 balance) balanceOf;
    uint256 totalSupply;
}

// ERC20Transfer
bytes32 constant STORAGE_POSITION = keccak256("erc20");
struct ERC20Storage {
    mapping(address owner => uint256 balance) balanceOf;
    uint256 totalSupply;
    mapping(address owner => mapping(address spender => uint256 allowance)) allowance;
}

// ============================
// Invalid
// ERC20Mint
bytes32 constant STORAGE_POSITION = keccak256("erc20");
struct ERC20Storage {
    uint256 totalSupply;
    mapping(address owner => uint256 balance) balanceOf;
}

// ERC20Transfer
bytes32 constant STORAGE_POSITION = keccak256("erc20");
struct ERC20Storage {
    mapping(address owner => uint256 balance) balanceOf;
    uint256 totalSupply;
}
```

## Libraries

```shell
commander   # parse commands such as: compose init --framework foundry
inquirer    # ask users to choose options, checkboxes, and confirmations
picocolors  # color terminal output
fs-extra    # copy templates, write files, and ensure directories exist
```
