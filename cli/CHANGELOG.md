# Changelog

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
