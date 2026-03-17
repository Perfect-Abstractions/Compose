# Compose CLI

`@perfect-abstractions/compose-cli` scaffolds diamond-based projects using the Compose Library.
Supports both Foundry and Hardhat.

## Install

```bash
npm install -g @perfect-abstractions/compose-cli
```

Requires Node.js >= 20.

## Usage

```bash
compose init [options]
compose templates
compose --version | -v
compose --help | -h
compose update
```

### Options

- `--name <project-name>`: directory / package name for the new project.
- `--template <template-id>`: template to use (see Template registry below).
- `--framework <foundry|hardhat>`: target framework.
- `--language <javascript|typescript>`: source language (Hardhat only; defaults to `typescript` when omitted).
- `--install-deps` / `--no-install-deps`: whether to install npm dependencies for Hardhat templates (defaults to `true` unless disabled or using `--yes` with an explicit value).
- `--yes`: non-interactive mode. Skips prompts and fills missing values with sensible defaults.
- `--help`: print CLI help text.

When `--yes` is not provided, `compose init` will prompt for any values you omit.

### Non-interactive examples

```bash
# Foundry default template
compose init --name my-foundry-app --template default --framework foundry --yes

# Hardhat minimal TypeScript template, skip dependency install
compose init --name my-hardhat-minimal \
  --template default \
  --framework hardhat \
  --language typescript \
  --install-deps=false \
  --yes

# Hardhat mocha-ethers TypeScript template
compose init --name my-hardhat-mocha-ethers \
  --template default \
  --framework hardhat \
  --language typescript \
  --yes
```


`compose templates` prints this information in a friendly format.

## Notes on `@perfect-abstractions/compose`

Hardhat scaffolds inject `@perfect-abstractions/compose` as the dependency name.  The current package isn't published yet.


## Development

From the `cli` directory:

```bash
npm install
npm run build:templates
npm run check
```

### Template registry generation

The template registry at `src/config/templates.json` is generated from per-template manifests under `src/templates/**/template.json`.

- To regenerate the registry after changing templates:

```bash
npm run build:templates
```

## Add a new template

To make a new template:

1. **Create the template folder**
   - Add a new directory under `src/templates/<template-id>`.
   - Example: `src/templates/erc721`.

2. **Add a `template.json` manifest**
   - Place it at `src/templates/<template-id>/template.json`.
   - Required fields:
     - `id`: the template id (must match `<template-id>`).
     - `name`: human‑readable name shown in `compose templates`.
     - `description`: short description.
     - `variants`: list of variant ids (see below).
     - `compatibility.frameworks`: array of supported frameworks, e.g. `["foundry"]` or `["foundry","hardhat"]`.
   - Example:
     ```json
     {
       "id": "erc721",
       "name": "ERC‑721 Diamond",
       "description": "Diamond project with an ERC‑721 facet",
       "variants": [
         "erc721-foundry",
         "erc721-hardhat-minimal"
       ],
       "compatibility": {
         "frameworks": ["foundry", "hardhat"]
       }
     }
     ```

3. **Add variant directories**
   - Variant ids follow the pattern: `<template-id>-<framework>[-<project-type>]`.
   - The generator maps variants to paths as follows:
     - **Foundry**: `templates/<template-id>/foundry`
       - Example variant id: `erc721-foundry` → `src/templates/erc721/foundry`
     - **Hardhat (no project type)**: `templates/<template-id>/hardhat`
       - Example variant id: `erc721-hardhat` → `src/templates/erc721/hardhat`
     - **Hardhat with project type (TypeScript/JS layout)**:
       - Path pattern: `templates/<template-id>/hardhat/ts/<project-type>`
       - Example variant id: `erc721-hardhat-minimal` → `src/templates/erc721/hardhat/ts/minimal`
   - Place the scaffolded project files (contracts, configs, tests, etc.) inside each variant directory.

4. **Language detection**
   - The CLI infers the language from the variant path:
     - Paths containing `/ts/` → `language: "typescript"`.
     - Paths containing `/js/` → `language: "javascript"`.
   - For Foundry templates, language is not set on the variant; the framework alone is enough.

5. **Regenerate the templates registry**
   - From the `cli` directory run:
     ```bash
     npm run build:templates
     ```
   - This rebuilds `src/config/templates.json` from all `template.json` manifests and validates the result.

6. **Verify your template is available**
   - Run:
     ```bash
     node index.js templates
     ```
   - Confirm your new template and variants appear in the list.

7. **Smoke‑test the template**
   - Use your new template to scaffold a project:
     ```bash
     node index.js init --name my-test-project --template <template-id> --framework <framework> --yes
     ```
   - Then run the framework’s own test / build commands in the generated project.

### Test the CLI locally

```bash
npm link
```

This will create a symlink to the CLI in your global `node_modules` directory.

You can then test the CLI by running:

```bash
compose --help
```
