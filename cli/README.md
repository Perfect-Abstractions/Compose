# Compose CLI

`@perfect-abstractions/compose-cli` scaffolds diamond-based projects using the Compose Library.
Supports both Foundry and Hardhat.

## Install

```bash
npm install -g @perfect-abstractions/compose-cli
```

Requires Node.js >= 18.

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


`compose templates` prints this information in a CLI-friendly format.

## Notes on `@perfect-abstractions/compose`

Hardhat scaffolds inject `@perfect-abstractions/compose` as the dependency name.  The current package isn't published yet.


## Development

From the `cli` directory:

```bash
npm install
npm run build:templates
npm run check
```

To build or test the Foundry template (or any template that uses `lib/` submodules), init libs once:

```bash
npm run prepare:lib
```

Then from a template directory, for example `src/templates/default/foundry`:

```bash
forge build
forge test
```

New templates that need `forge-std` or Compose can add the same submodules under their own `lib/`; `prepare:lib` inits all submodules repo-wide.

### Template registry generation

The template registry at `src/config/templates.json` is generated from per-template manifests under `src/templates/**/template.json`.

- To regenerate the registry after changing templates:

```bash
npm run build:templates
```

The CLI loads the generated `templates.json` at runtime; editing `template.json` files alone is not enough unless you rebuild the registry.
