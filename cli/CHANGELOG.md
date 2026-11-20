# Changelog

## 0.4.0

### Minor Changes

- 20c3848: Add `compose deploy`: plan the diamond from `compose.json` and generate a reviewable managed deployment artifact. Foundry uses a Solidity script; Hardhat 3 uses a Hardhat Ignition module with an ignored transient runner. The default command prints the artifact path and review instructions without prompting or broadcasting; `--dry-run` simulates on a pinned chain fork, while `--broadcast` explicitly deploys, verifies the result on-chain, and records it in `compose.lock`. Hardhat deployment transaction hashes are read from the Ignition journal by future ID. Signing stays in the framework. Supports `--chain`, a per-deployment `--rpc-url` override, named Compose account aliases, `--instance`, `--redeploy`, and `--` passthrough for framework arguments. Add and list non-secret account aliases with `compose account`.
  
  Hardhat 3 initialization now uses Hardhat's official non-interactive Ethers/Mocha or Viem/Node test-runner template, overlays Compose project settings without discarding the official config, and requires Node.js 22.13 or newer.
- cafc10a: `compose init` no longer scaffolds a default deploy script; the first `compose deploy` generates the managed, reviewable script from `compose.json` instead.
- b0b9465: Scaffold immutable diamonds by default: `compose init` prompts for upgradeability, defaulting to Immutable, and non-interactive runs accept `--upgradeable` and `--immutable`. `--upgradeable` includes `DiamondUpgradeFacet` and couples the `owner` base when no ownership base is selected; an explicit `DiamondUpgradeFacet` in `--libraries` opts in for compatibility. Hardhat projects also scaffold a `local` network entry targeting the default Anvil RPC.
- e8fa69d: Nest `compose.lock` deployments by instance (`diamond → chain → instance → deployment`) and validate every recorded instance in `compose validate`.
- 30fa411: Generated Foundry and Hardhat projects now include a preconfigured `sepolia` chain. `compose.json` points Sepolia at `${SEPOLIA_RPC_URL}`, Foundry projects add a `sepolia` entry under `[rpc_endpoints]`, and Hardhat projects define a Sepolia HTTP network that reads `SEPOLIA_RPC_URL` and the `SEPOLIA_PRIVATE_KEY` signer. Generated projects also include a `.env.example` and README instructions for Sepolia deployments.

### Patch Changes

- 6cc3ac7: Add `compose test` to run a project's test suite through its detected framework (`forge test` or `npx hardhat test`), with `--` passthrough for framework filters and reporting flags.
- 08226b5: Preserve the relative folder structure of locally imported dependencies when copying catalog facets, so nested imports (for example `./libraries/LibFee.sol`) keep resolving after `compose install` and `compose init`.
- 69bcd13: Update the Compose library dependency to 0.0.7.
- 87920fd: Fix `compose install` of catalog package facets (e.g. `ERC20DataFacet`) in Hardhat projects: package-sourced facets are never copied into `contracts/`, and Hardhat only compiles npm Solidity files listed in `solidity.npmFilesToBuild`, so the install-time validation compile missed the facet and failed with "Facet contract not found in Solidity AST". Install now adds the batch's package facets to the Compose `composeNpmFilesToBuild` overlay in `hardhat.config.ts` before validating, and reverts the config when the transaction rolls back. Projects whose config no longer contains the generated overlay get an error naming the exact specifiers to add manually. Foundry is unaffected (its validation compile already receives the facet paths directly). Install/remove error messages now carry recovery hints (`compose remove <facet>`, `path.sol:ContractName` examples, available diamond lists).
- 21bb6c5: Move every Compose-owned Hardhat runtime file into the ignored `.compose/hardhat/` directory (`.compose/foundry/` is reserved for Foundry): the transient Ignition runner, the generated deploy result, and the account probe. The probe is now a deterministic rendered template rather than a per-run `scripts/compose-account-check-<uuid>.ts` file, so an interrupted run can no longer leave an untracked script in a tracked directory. `compose init` and every runtime write now ensure the project `.gitignore` contains `.compose/`; the nested `cache/compose/.gitignore` workaround is gone.
- 60ba0c8: Add a shared Diamond introspection adapter for ERC-8153 and ERC-2535, and use it for inspect and bytecode validation.
- 3436841: Add `compose install`/`i` and `compose remove`/`rm` commands for managing facet registrations in `compose.json`, including versioned batch manifests.
- 52ad0b0: Resolve package facets from the project framework's package root (Foundry `lib/Compose`, Hardhat `node_modules`), so a project that has both copies no longer fails with an ambiguous package source.
- c508a23: Resolve bare facet names in `compose install` by fuzzy-matching the project's Solidity sources, so a local `path.sol:ContractName` reference is only needed when several sources match; interactive runs pick the source from a list.
- abc15d1: Generated Foundry and Hardhat projects now expose native framework commands as `npm run build` and `npm test`, plus Compose workflows as `npm run validate` and `npm run deploy`. Foundry projects also include `npm run fmt`. The `compose build` and `compose test` commands remain available as convenience wrappers.
- 6743553: Raise the CLI's minimum Node.js version to 22 and check for Node.js 22.13+ before initializing a Hardhat project, so the engine requirement and the getting-started docs agree.
- 9ce8929: Mark selectors with unknown signatures in `compose inspect` output.
- 12dd70e: `compose init` now adds `@perfect-abstractions/compose-cli` to the generated project's `devDependencies` and installs it, so Compose commands run locally with `npx compose` without a global install. Foundry projects now include a `package.json` for this, and the tutorial and generated READMEs use the `npx compose` flow.
- 69bcd13: fix(cli): print correct init output path
- 0ffed76: fix(cli): defer build freshness to framework compiler
- f1a0616: Redact private keys, mnemonics, passwords, and secret-bearing RPC URLs from command failure errors and passthrough validation messages.
- c508a23: Accept `path.sol:ContractName` references in `compose remove`/`rm` and remove manifests, so they resolve to the registered facet name the way `compose install` does instead of being skipped as unregistered.

## 0.3.0

### Minor Changes

- 8aa339a: Validate deployed diamond facet bytecode against the source-derived virtual storage layout.

### Patch Changes

- 81b641f: Clarify CLI adapter and adapter test organization in the contributor documentation.
- 5b20797: Add automated CLI test coverage reporting to pull requests.
- 509cae0: Automatically sync the CLI's Compose dependency after a library release.
- 4862d57: Add compose init test coverage and reorganize adapters by interface.

## 0.2.1

### Patch Changes

- 92f92d6: Update the Compose CLI to use `@perfect-abstractions/compose` 0.0.6.

## 0.2.0

### Minor Changes

- cd8f28d: Add compiler AST support for Foundry and Hardhat, introduce Virtual Storage Layout compatibility checks, and add the standalone `compose validate` pipeline with traceable selector and storage diagnostics.

### Patch Changes

- 9ac686e: adds compose.lock support for tracking diamond deployment state across chains, and migrates the CLI package from CommonJS to ESM with tsup bundling and CI workflow fixes.
- e56eba6: add project build + auto detect project framework
- 9e5db52: remove temporal revoke facet in base
- 987e64c: Add CLI testing infrastructure, example tests, and contributor documentation for testing and code style.
- 787dab2: add rpc adapter using viem, add diamond inspect command querying deployed diamonds
- Updated dependencies [4909bb1]
- Updated dependencies [4909bb1]
- Updated dependencies [9e5db52]
  - @perfect-abstractions/compose@0.0.5

## 0.1.3

### Patch Changes

- 39c213a: fix cli rendering on windows

## 0.1.2

### Patch Changes

- 7984bcf: Refresh CLI dependency locks and fix interactive init prompts on Windows.
- fccdf34: fix: sync release lock for CLI prompt deps

## 0.1.1

### Patch Changes

- 0e83bb5: Build the CLI before publishing so the npm package includes dist output.

## 0.1.0

### Minor Changes

- 630dd70: Rewrite CLI from JavaScript to TypeScript with pipeline/context architecture, add `catalog` and `info` commands, bases catalog, validation, Solidity parsing, framework adapters, and scaffolding. Special thanks to @0x76agabond for his contributions on this.

## 0.0.5

### Patch Changes

- 404aafc: fix deployment setup on hardhat

## 0.0.4

### Patch Changes

- 84abb2d: add installation commands to docs & readme

## 0.0.3

### Patch Changes

- 33519f4: fix: compiler versions & imports
  docs: add local node command

## 0.0.2

### Patch Changes

- a9f32fb: first publised release: core facet library (@perfect-abstraction/compose) and CLI (@perfect-abstraction/compose-cli)

## 0.0.1

- Initial Compose CLI foundation.
- Added config-driven template registry with Foundry/Hardhat variants.
- Added scaffold engine, local facet source, and registry-mode stub.
- Added unit/integration tests, lint config, CI workflow, and release documentation.
