/**
 * Post gas report comment workflow script
 * Downloads gas report artifact from a workflow run and posts/updates PR comment
 *
 * This script is designed to run in a workflow_run triggered workflow
 * with proper permissions to comment on PRs from forks.
 */

const {
  downloadArtifact,
  parsePRNumber,
  readReport,
  postOrUpdateComment
} = require('./workflow-utils');

module.exports = async ({ github, context }) => {
  // Download and extract artifact
  const artifactFound = await downloadArtifact(github, context, 'gas-report-data');
  if (!artifactFound) {
    return;
  }

  // Parse PR number from data file
  const prNumber = parsePRNumber('gas-report-data.txt');
  if (!prNumber) {
    return;
  }

  // Read gas report
  const body = readReport('gas-report.md');
  if (!body) {
    return;
  }

  // Post or update comment
  await postOrUpdateComment(
    github,
    context,
    prNumber,
    body,
    '## Gas Report',
    'gas report'
  );
};