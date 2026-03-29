# Releasing Compose Packages

This repository publishes 2 npm packages:

- `@perfect-abstractions/compose` from `src/`
- `@perfect-abstractions/compose-cli` from `cli/`

Releases use [Changesets](https://github.com/changesets/changesets) and GitHub Actions.

## Changelogs

- **Library:** [CHANGELOG.md](CHANGELOG.md) at the repo root (also packed into the npm tarball via `src/` `prepack`). The `version-packages` script syncs Changesets output with this file.
- **CLI:** [cli/CHANGELOG.md](cli/CHANGELOG.md) only (not copied to the root).

## Release model

- **Branch:** `main` only for production releases.
- **Versioning:** independent per package.
- **Batching:** Multiple PRs can add `.changeset/*.md` files; one **version bump PR** (same PR updated) applies all pending bumps together.
- **Open/update the version PR:** Run the **Release** workflow manually (**Actions → Release → Run workflow**). It checks out `main`, runs checks, then [changesets/action](https://github.com/changesets/action) creates or updates the PR (branch is usually `changeset-release/main`).
- **Publish:** Runs automatically when that **version bump PR is merged** into `main` (workflow **Publish**). You can also run **Publish** manually (`workflow_dispatch`) to retry or publish without merging from that branch (e.g. hotfix).
- **Publish approval:** Jobs that publish to npm use GitHub Environment **`npm-publish`** (required reviewers) and secret **`NPM_TOKEN`**. Approval is requested when those jobs run, including after an automatic trigger.
- **Provenance:** `NPM_CONFIG_PROVENANCE=true` on publish (OIDC; requires `id-token: write` on publish jobs). Ensure the npm org is configured for trusted publishing from this repo if provenance fails.

## Contributor flow

1. Change code under `src/` and/or `cli/`.
2. **[changeset-bot](https://github.com/apps/changeset-bot)** comments on the PR when a release note may be needed. You can run `npm run changeset` locally, use the bot’s **add a changeset** link on GitHub, or leave it to maintainers before release.
3. Merge after required CI checks pass.

There is **no** failing CI check for missing changesets; maintainers batch or add `.changeset/*.md` when preparing releases as needed.

## Maintainer release flow

1. When you want a version bump PR, run **Release** manually on `main`.
2. Review and merge the **chore(release): bump npm versions & changelogs** PR (from `changeset-release/main` or the same prefix — automatic **Publish** only runs for merges from branches named `changeset-release/*`).
3. **Publish** starts automatically on that merge. Approve the **`npm-publish`** environment when GitHub prompts you.
4. The **plan** job fails if any real `.changeset/*.md` files remain (finish merging the version PR so only `.changeset/README.md` is left).
5. The **plan** job compares each package’s `package.json` version to npm (see [`.github/publish-packages.json`](.github/publish-packages.json)). If every configured package already matches npm, the publish job is skipped (nothing new to ship).
6. A single **publish** workflow job runs a **matrix**: one row per package that is ahead of npm. Rows run in parallel when several packages need a release. Each row publishes to npm, then creates a short git tag and GitHub Release:
   - Library tag: `compose@<version>` (e.g. `compose@0.2.0`)
   - CLI tag: `compose-cli@<version>` (e.g. `compose-cli@0.2.0`)
7. Confirm versions on npm and tags/releases on GitHub.

## Adding a publishable package

1. Add the workspace under the repo root [`package.json`](package.json) `workspaces` array and ensure the package has a proper `package.json` (name, version).
2. Register the package in [Changesets](https://github.com/changesets/changesets) (e.g. `.changeset/config.json` `ignore` / new package paths as needed).
3. Add a **new entry** to [`.github/publish-packages.json`](.github/publish-packages.json): `id`, `workspace` (npm name), `versionFile`, `tagPrefix`, `needsFoundry` (install Foundry before checks when the package needs Forge), and `check` (shell command, usually `npm run …` chains from the root `package.json`).
4. If you need new check scripts, add them to the root [`package.json`](package.json) `scripts` and reference them from the `check` field.

## Manual Publish only

Use **Actions → Publish → Run workflow** if you need to publish from `main` without a merge from `changeset-release/*`

## Rollback

Prefer a new **patch** release with a revert + changeset. Avoid unpublishing except for serious issues.
