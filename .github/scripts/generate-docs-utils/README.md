## Documentation Generator

This directory contains the utilities used by the GitHub Actions workflow to generate the Markdown/MDX documentation for the Solidity contracts and the docs site.

- **Entry script**: `../../generate-docs.js`
- **Templates**: `templates/`
- **Core logic**: `core/`, `parsing/`, `category/`, `utils/`, `ai/`

Use this README as a reference for running the same process **locally**.

---

## Prerequisites

- Node.js 20.x
- `forge` (Foundry) installed and available on your `PATH`
- From the repo root, run once (or whenever dependencies change):

```bash
cd .github/scripts/generate-docs-utils/templates
npm install
cd ../../../..
```

---

## Basic local workflow

All commands below are run from the **repo root**.

### 1. Generate base forge docs

```bash
forge doc
```

This produces the raw contract documentation that the generator consumes.

### 2. Run the docs generator

#### Process all Solidity files

```bash
node .github/scripts/generate-docs.js --all
```

#### Process specific Solidity files

Create a text file with one Solidity path per line (relative to the repo root, usually under `src/`), for example:

```bash
printf "src/access/AccessControl/Batch/Revoke/AccessControlRevokeBatchFacet.sol\n" > /tmp/changed_sol_files.txt
```

Then run:

```bash
node .github/scripts/generate-docs.js /tmp/changed_sol_files.txt
```

---

## AI enhancement controls

By default, the generator can call an AI provider to enhance descriptions. In CI, this is controlled by the `SKIP_ENHANCEMENT` input on the workflow. Locally, you can control this via an environment variable:

- **Disable AI enhancement**:

```bash
SKIP_ENHANCEMENT=true node .github/scripts/generate-docs.js --all
```

- **Enable AI enhancement** (requires a valid provider key, see `.github/scripts/ai-provider/README.md`):

```bash
GITHUB_TOKEN=<your_github_token> \
GOOGLE_AI_API_KEY=<optional_gemini_key> \
node .github/scripts/generate-docs.js --all
```

If no valid provider/key is available, the generator falls back to non‑AI content.

---

## Verifying the docs site build

After generating docs, you can ensure the documentation site still builds:

```bash
cd website
npm ci
npm run build
```

New or updated pages should appear under `website/docs/library`.

