const { downloadArtifact, readReport } = require('./workflow-utils');
const { MARKER } = require('./cli-coverage-report');

module.exports = async ({ github, context }, helpers = {}) => {
  const download = helpers.downloadArtifact ?? downloadArtifact;
  const read = helpers.readReport ?? readReport;
  if (!await download(github, context, 'cli-coverage-data')) return;

  const metadataText = read('cli-coverage-data.json');
  if (!metadataText) throw new Error('CLI coverage metadata is missing');
  const metadata = JSON.parse(metadataText);
  const { prNumber, headSha, workflowSha } = metadata;
  if (!Number.isSafeInteger(prNumber) || prNumber <= 0 || workflowSha !== context.payload.workflow_run.head_sha) {
    throw new Error('CLI coverage artifact does not match its workflow run');
  }

  const { owner, repo } = context.repo;
  const { data: pr } = await github.rest.pulls.get({ owner, repo, pull_number: prNumber });
  if (pr.head.sha !== headSha || pr.base.repo.full_name !== `${owner}/${repo}`) {
    console.log('Skipping coverage from an outdated or unrelated PR run');
    return;
  }

  const body = read('cli-coverage-report.md');
  if (!body?.startsWith(MARKER)) throw new Error('CLI coverage report is missing its marker');
  const comments = await github.paginate(github.rest.issues.listComments, {
    owner, repo, issue_number: prNumber, per_page: 100,
  });
  const existing = comments.find((comment) => comment.user?.type === 'Bot' && comment.body?.includes(MARKER));
  if (existing) {
    await github.rest.issues.updateComment({ owner, repo, comment_id: existing.id, body });
  } else {
    await github.rest.issues.createComment({ owner, repo, issue_number: prNumber, body });
  }
};
