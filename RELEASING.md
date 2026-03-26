# Releasing Compose Packages

This repository publishes two npm packages:

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
2. Run `npm run changeset`, pick package(s) and semver bump (`patch` / `minor` / `major`), write a short note.
3. Commit the generated `.changeset/*.md` with your PR.
4. Merge after required CI checks pass.

**Internal-only changes** (no user-facing release note): a maintainer may add the PR label **`skip-changeset`** so the changeset guard passes without a new changeset file. Use sparingly.

## First release checklist

1. Confirm `src/package.json` and `cli/package.json` names and versions.
2. Add at least one changeset on a feature PR and merge to `main`.
3. Merge the generated **chore(release): bump npm versions & changelogs** PR when ready (bot branch is usually `changeset-release/main`; the bot updates that PR as new changesets land).
4. Approve the **Publish** workflow deployment for `npm-publish`.
5. Confirm versions on npm and tags/releases on GitHub.

## Rollback

Prefer a new **patch** release with a revert + changeset. Avoid unpublishing except for serious issues.
