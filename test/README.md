# Compose Test Suite

This directory contains the tests for the Compose library. The goal of this document is to give contributors a reference for how tests are organised, how we specify behaviour, and how to add or extend tests safely.

## Overview

- **Behaviour first (BTT)**: tests are driven from behaviour trees in `test/trees/*.tree`, not from implementation details.
- **Facet/mod oriented**: each facet or modifier module has a focused set of base fixtures and fuzz tests.
- **No test‑only code in `src`**: all test helpers live under `test/` (base contracts, defaults, storage utils).
- **Design‑constrained testing**: Compose bans some common Solidity patterns (e.g. inheritance‑heavy hierarchies, test‑only hooks in production code), so the suite relies on behaviour trees, shared fixtures, and storage utilities to keep `src/` clean while still achieving thorough coverage.
- **Consistent naming**: similar behaviours across standards (ERC‑20, ERC‑721, AccessControl, etc.) share naming and structure.

---

## Layout

```text
test/
├── README.md                 # this file
├── trees/                    # behaviour trees (specs)
│   ├── ERC20.tree
│   ├── ERC721.tree
│   ├── ERC1155.tree
│   ├── ERC165.tree
│   ├── AccessControl.tree
│   ├── Owner.tree
│   ├── Royalty.tree
│   └── NonReentrancy.tree
└── unit/                     # unit tests by domain
    ├── token/                # ERC-20/721/1155 + royalty facets/mods
    ├── access/               # Owner, AccessControl facets/mods
    └── interfaceDetection/   # ERC165 facets/mods
```

Within `unit/` you will generally see:

- **`*FacetBase.t.sol` / `*ModBase.t.sol`**: base fixtures for a facet or modifier (deploys contract, common setup).
- **`facet/fuzz/*.t.sol`**: fuzz tests that exercise a facet’s external API.
- **`mod/fuzz/*.t.sol`**: fuzz tests that exercise modifier‑style modules.

All tests share a small set of common utilities, described next.

---

## Common test utilities

- **`Base_Test`** (`test/Base.t.sol`):
  - Inherits `forge-std` utilities and internal helpers.
  - Creates labelled test users (`Users`) and funds them.
  - Instantiates `Defaults` and wires users into it.
  - Exposes helpers like `setMsgSender` (via `Utils`) to manage `msg.sender` during tests.

- **`Users`** (`test/utils/Types.sol`):
  - Typed bundle of common accounts: `alice`, `bob`, `charlee`, `admin`, `receiver`, `sender`.

- **`Constants`** (`test/utils/Constants.sol`):
  - Shared values (interface IDs, common roles, token metadata, URIs, fee denominators, etc.).

- **`Defaults`** (`test/utils/Defaults.sol`):
  - Holds default configuration for tests; receives `Users` from `Base_Test` and can be extended with more defaults over time.

- **`Modifiers`** (`test/utils/Modifiers.sol`):
  - Houses “given/when” style modifiers that mirror the behaviour tree wording.
  - `Base_Test` wires `Defaults` and `Users` into this layer so tests can depend on shared state.

- **Harnesses** (`test/utils/harnesses/**`):
  - Test-only contracts used to expose internal hooks or lifecycle entry points needed to exercise behaviour trees (e.g. ERC165, NonReentrancy).
  - Keep test-only logic out of `src/` while still allowing precise control in tests.

- **Storage utilities** (e.g. `test/utils/storage/AccessControlStorageUtils.sol`):
  - Libraries that use `vm.load` / `vm.store` to directly inspect and manipulate layout‑sensitive storage in tests (e.g. split AccessControl storage).
  - Allow verifying low‑level invariants without adding test‑only code to `src`.

Most unit tests import `Base_Test` and then add only the minimal extra setup they need, while a few low-level base tests (such as ERC165) extend `forge-std/Test` directly but follow the same patterns.

---

## Behaviour trees (`test/trees/*.tree`)

Each `.tree` file is a **behaviour tree specification** for a standard or module. For example, `test/trees/ERC20.tree` contains behaviours such as:

```text
Transfer
└── when the receiver is not the zero address
    └── given when the sender's balance is greater than, or equal to, the transfer amount
        └── when the amount is > 0
            ├── it should decrement the sender's balance by the transfer amount
            ├── it should increment the receiver's balance by the transfer amount
            ├── it should emit a {Transfer} event
            └── it should return true
```

These trees drive test design:

- **Each “it should …” leaf maps to one or more test functions** in the relevant facet or mod fuzz file.
- **Intermediate “given/when …” nodes** often map to shared modifiers or setup helpers.
- Tests should be easy to trace back to the tree:
  - Files usually carry a short note like `@dev BTT spec: test/trees/ERC20.tree`.
  - Function names and test groupings follow the wording of the tree as closely as practical.

When you add new behaviour, update the corresponding `.tree` file first, then add or extend tests to cover the new leaves.

---

## Writing tests for a facet or module

The typical pattern for a new facet test looks like:

1. **Extend a domain-specific `*Base_Test` and override `setUp` there**:
   - Each facet or mod usually has a base test (e.g. `ERC20TransferFacet_Base_Test`, `AccessControlAdmin_Base_Test`) that itself extends `Base_Test`.
   - In that base, call `Base_Test.setUp()` (or `super.setUp()` if there are multiple layers) first.
   - Deploy the facet or module under test in the base and label it with `vm.label` for clear traces and logs.
2. **Align with the behaviour tree**:
   - Identify which `.tree` file the facet belongs to (e.g. `ERC20.tree`, `AccessControl.tree`).
   - Group tests by the same high‑level branches (e.g. `Transfer`, `Approve`, `ExportSelectors`).
3. **Write fuzz tests in the appropriate folder**:
   - Use `facet/fuzz/*.t.sol` for facet APIs.
   - Use `mod/fuzz/*.t.sol` for modifier‑style modules.

As an example, a simple unit test following this pattern is (taken from the AccessControl admin facet and its base test):

```solidity
/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract ExportSelectors_AccessControlAdminFacet_Unit_Test is AccessControlAdmin_Base_Test {
    using AccessControlStorageUtils for address;

    AccessControlAdminFacet internal facet;

    function setUp() public override {
        super.setUp();
        facet = new AccessControlAdminFacet();
        vm.label(address(facet), "AccessControlAdminFacet");
        seedDefaultAdmin(address(facet));
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(AccessControlAdminFacet.setRoleAdmin.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
```

This contract:

- Reuses the common user/defaults setup from `Base_Test`.
- Targets one leaf in the `AccessControl.tree` (the `ExportSelectors` behaviour).
- Uses clear, behaviour‑oriented naming for the test function.

---

## Naming and structure conventions

- **Behaviour‑oriented naming**:
  - `test_FunctionName_Scenario()` for happy‑path and scenario tests.
  - `test_RevertWhen_Condition()` for revert paths.
  - `testFuzz_FunctionName_Scenario()` for fuzz/property tests.
- **Arrange–Act–Assert**:
  - Make the phases obvious with whitespace and, if helpful, short comments.
- **Mirror the trees**:
  - Use the same terminology as the `.tree` files where possible (e.g. “given when balance < amount”).
- **Scope and isolation**:
  - Prefer small, focused test contracts rather than monolithic files.
  - Use storage utilities instead of adding debug getters to `src`.

---

## Running tests

- **Run all tests**:

```bash
forge test
```

- **Run tests for a specific area** (example: ERC‑20 token module):

```bash
forge test --match-path "test/unit/token/ERC20/**"
```

- **Run a specific fuzz file**:

```bash
forge test --match-path "test/unit/token/ERC20/Transfer/facet/fuzz/transfer.t.sol"
```

- **Run a specific test by name**:

```bash
forge test --match-test "test_RevertWhen_TransferInsufficientBalance"
```

- **Generate a gas report**:

```bash
forge test --gas-report
```

You can combine `--match-path` and `--match-test` to narrow the scope as needed.

---

## Contributing to tests

When you add or change behaviour in Compose:

- **Update or add the relevant behaviour tree** in `test/trees/*.tree` to reflect the new or changed behaviour.
- **Add or extend unit tests** under `test/unit/**` that:
  - Use `Base_Test` and the shared utilities.
  - Clearly map back to specific leaves in the tree.
  - Include both success paths and revert paths.
- **Prefer fuzz tests** for anything with numeric parameters or interesting state spaces.
- **Run `forge test` locally** before opening a PR and ensure the new tests are stable (no flakiness).

If you are unsure how to structure tests for a new module, start by:

- Reading the relevant `.tree` file in `test/trees/`.
- Looking at existing tests for a similar standard (e.g. ERC‑20 vs ERC‑721 transfer behaviour).
- Following the same patterns for layout, naming, and use of shared utilities.
