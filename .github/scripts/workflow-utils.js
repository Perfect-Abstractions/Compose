const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

/**
 * Download and extract workflow artifact
 * @param {object} github - GitHub API object
 * @param {object} context - GitHub Actions context
 * @param {string} artifactName - Name of the artifact to download
 * @returns {Promise<boolean>} True if artifact was found and extracted
 */
async function downloadArtifact(github, context, artifactName) {
  const artifacts = await github.rest.actions.listWorkflowRunArtifacts({
    owner: context.repo.owner,
    repo: context.repo.repo,
    run_id: context.payload.workflow_run.id,
  });

  const artifact = artifacts.data.artifacts.find(
    a => a.name === artifactName
  );

  if (!artifact) {
    return false;
  }

  const download = await github.rest.actions.downloadArtifact({
    owner: context.repo.owner,
    repo: context.repo.repo,
    artifact_id: artifact.id,
    archive_format: 'zip',
  });

  // Save and extract the artifact
  const artifactPath = path.join(process.env.GITHUB_WORKSPACE, `${artifactName}.zip`);
  fs.writeFileSync(artifactPath, Buffer.from(download.data));

  execSync(`unzip -o ${artifactPath} -d ${process.env.GITHUB_WORKSPACE}`);

  return true;
}

/**
 * Parse PR number from data file
 * @param {string} dataFileName - Name of the data file to parse
 * @returns {number|null} PR number or null if not found
 */
function parsePRNumber(dataFileName) {
  const dataPath = path.join(process.env.GITHUB_WORKSPACE, dataFileName);

  if (!fs.existsSync(dataPath)) {
    return null;
  }

  const dataContent = fs.readFileSync(dataPath, 'utf8');
  const prMatch = dataContent.match(/PR_NUMBER=(\d+)/);

  if (!prMatch) {
    return null;
  }

  return parseInt(prMatch[1]);
}

/**
 * Read report file
 * @param {string} reportFileName - Name of the report file
 * @returns {string|null} Report content or null if not found
 */
function readReport(reportFileName) {
  const reportPath = path.join(process.env.GITHUB_WORKSPACE, reportFileName);

  if (!fs.existsSync(reportPath)) {
    return null;
  }

  return fs.readFileSync(reportPath, 'utf8');
}

/**
 * Find existing bot comment on PR
 * @param {object} github - GitHub API object
 * @param {object} context - GitHub Actions context
 * @param {number} prNumber - PR number
 * @param {string} commentMarker - Unique string to identify the comment type
 * @returns {Promise<object|null>} Existing comment or null
 */
async function findBotComment(github, context, prNumber, commentMarker) {
  const { data: comments } = await github.rest.issues.listComments({
    owner: context.repo.owner,
    repo: context.repo.repo,
    issue_number: prNumber,
  });

  const botComment = comments.find(comment => 
    comment.user.type === 'Bot' && 
    comment.body.includes(commentMarker)
  );

  return botComment;
}

/**
 * Post or update PR comment
 * @param {object} github - GitHub API object
 * @param {object} context - GitHub Actions context
 * @param {number} prNumber - PR number
 * @param {string} body - Comment body
 * @param {string} commentMarker - Unique string to identify the comment type
 * @param {string} commentType - Type of comment (e.g., 'coverage', 'gas report')
 */
async function postOrUpdateComment(github, context, prNumber, body, commentMarker, commentType) {
  const existingComment = await findBotComment(github, context, prNumber, commentMarker);

  if (existingComment) {
    await github.rest.issues.updateComment({
      owner: context.repo.owner,
      repo: context.repo.repo,
      comment_id: existingComment.id,
      body: body
    });
  } else {
    await github.rest.issues.createComment({
      owner: context.repo.owner,
      repo: context.repo.repo,
      issue_number: prNumber,
      body: body
    });
  }
}

module.exports = {
  downloadArtifact,
  parsePRNumber,
  readReport,
  postOrUpdateComment
};