/**
 * Post changeset reminder on PR when Changeset Required workflow fails.
 * Triggered by workflow_run (same pattern as coverage/gas comments) so
 * GITHUB_TOKEN can comment on PRs from forks.
 */

const {
  downloadArtifact,
  parsePRNumber,
  postOrUpdateComment,
} = require('./workflow-utils');

const COMMENT_MARKER = '## Changeset required';

module.exports = async ({ github, context }) => {
  const run = context.payload.workflow_run;

  const artifactFound = await downloadArtifact(
    github,
    context,
    'changeset-failure-data'
  );

  let prNumber = artifactFound ? parsePRNumber('changeset-data.txt') : null;

  if (!prNumber && run.pull_requests?.length) {
    prNumber = run.pull_requests[0].number;
  }

  if (!prNumber) {
    console.log('Could not determine PR number; skipping comment.');
    return;
  }

  const body = `${COMMENT_MARKER}

Publishable changes were detected under \`src/\` or \`cli/\`, but no **changeset** file was added.

- Run locally: \`npm run changeset\`, pick the package(s) and semver bump, then commit the generated \`.changeset/*.md\` with your PR.

Maintainers may add the **\`skip-changeset\`** label for internal-only edits (no release note).

<!-- changeset-required-bot -->
`;

  await postOrUpdateComment(
    github,
    context,
    prNumber,
    body,
    COMMENT_MARKER,
    'changeset required'
  );
};
