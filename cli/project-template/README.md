# Compose CLI Project Template

This directory is the current Compose CLI implementation template. It is a Node.js/TypeScript CLI that scaffolds a Diamond-based Foundry project from Compose-owned metadata under `bases/`.

## Current Behavior

- `compose` with no command prints help.
- `compose init` starts the interactive init flow.
- Interactive init asks for framework, base, Compose library facets, extension facets, and local example facets.
- Foundry init validates selected facets before writing files.
- Generated Foundry files are written into the current Foundry project when `foundry.toml` exists, otherwise into `my-diamond/`.
- `compose validate` and `compose inspect` are routed placeholders only.

## Commands

From this directory:

```sh
npm install
npm run build
node dist/index.js
node dist/index.js init
```

For development:

```sh
npm run dev -- init
```

## Structure

- `bases/`: Compose-owned metadata for standards, diamond facets, library facets, and local examples.
- `src/index.ts`: CLI entrypoint.
- `src/context`: Shared context types and factory.
- `src/pipelines`: Top-level and command pipelines.
- `src/modules`: Feature logic for entry UI, config loading, validation, scaffolding, routing, and Foundry project detection.
- `src/adapters`: External library adapters, currently hashing through `viem`.
- `src/resolver`: Dependency keys, registry, and resolver.
- `src/utils`: Generic reusable helpers for files, regex, terminal output, and Solidity text parsing.
- `src/templates`: Solidity template assets copied into generated projects.
- `spec/`: M1 design notes and architecture documentation.
- `skills/`: Local Codex architecture skill used while developing this template.

## Metadata

`bases/` is the source of truth for interactive init options.

- `diamond.json`: Diamond facets.
- `libraries.json`: Compose library facets.
- `examples.json`: Local example facets used for validation testing.
- Other JSON files define selectable bases such as ERC-20, ERC-721, ERC-1155, ERC-6909, AccessControl, and Owner.

Each base has:

- `required`: Facets always included for that base.
- `optional`: Extension facets shown after the base is selected.

## Validation

Foundry init currently validates:

- Selector exports: every selected facet must export all intended external/public functions.
- Selector collisions: selected facets must not introduce duplicate function selectors.
- Identifier collisions: selected facets must not use incompatible storage layouts for the same storage identifier.

Validation is fail-fast. `EntryModule.showReport` prints the error report and stops the flow before scaffolding continues.

## Generated Output

Generated files are organized by meaning:

```txt
src/
  diamond/
  libraries/
  facets/
```

The CLI also writes a generated `compose.json` into the target project. `compose.lock` is not part of the current M1 implementation.

## Local Artifacts

The local `.gitignore` excludes generated or machine-local files:

```gitignore
node_modules/
dist/
my-diamond/
*.tsbuildinfo
.vscode/
```
