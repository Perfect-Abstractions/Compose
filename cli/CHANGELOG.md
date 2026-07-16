# Changelog

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
