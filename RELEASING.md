# Releasing Compose Packages

This repository publishes 2 npm packages:

- `@perfect-abstractions/compose` from `src/`
- `@perfect-abstractions/compose-cli` from `cli/`

Releases use [Changesets](https://github.com/changesets/changesets) and run in GitHub Actions.

## Release model

- **Branch:** `main` only for production releases.
- **Versioning:** independent per package.
- **Batching:** Multiple PRs can add `.changeset/*.md` files; one **version bump PR** (same PR updated) applies all pending bumps together.
- **Publish approval:** manual via GitHub Environment `npm-publish` and secret `NPM_TOKEN`.
- **Provenance:** `NPM_CONFIG_PROVENANCE=true` on publish (OIDC; requires `id-token: write` on the publish job).

## Contributor flow

1. Change code under `src/` and/or `cli/`.
2. **[changeset-bot](https://github.com/apps/changeset-bot)** comments on the PR when a release note may be needed. You can run `npm run changeset` locally, use the bot’s **add a changeset** link on GitHub, or leave it to maintainers before release.
3. Merge after required CI checks pass.

There is **no** failing CI check for missing changesets; maintainers batch or add `.changeset/*.md` when preparing releases as needed.

## First release checklist

1. Confirm `src/package.json` and `cli/package.json` names and versions.
2. Install **[changeset-bot](https://github.com/apps/changeset-bot)** on the org/repo (optional but recommended for PR reminders).
3. Add at least one `.changeset/*.md` on `main` (feature PR or maintainer commit), then merge the generated **chore(release): bump npm versions & changelogs** PR when ready (bot branch is usually `changeset-release/main`; [changesets/action](https://github.com/changesets/action) updates that PR as new changesets land).
4. Approve the **Publish** workflow deployment for `npm-publish`.
5. Confirm versions on npm and tags/releases on GitHub.

## Rollback

Prefer a new **patch** release with a revert + changeset. Avoid unpublishing except for serious issues.
