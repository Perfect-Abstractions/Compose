const fs = require('fs');

// Configuration thresholds
const THRESHOLDS = {
  good: 80,
  needsImprovement: 60,
  poor: 40
};

/**
 * Parse lcov.info file and extract coverage metrics
 * @param {string} content - The lcov.info file content
 * @returns {object} Coverage metrics
 */
function parseLcovContent(content) {
  const lines = content.split('\n');
  let totalLines = 0;
  let coveredLines = 0;
  let totalFunctions = 0;
  let coveredFunctions = 0;
  let totalBranches = 0;
  let coveredBranches = 0;

  // LF:, LH:, FNF:, FNH:, BRF:, BRH: are on separate lines
  // We need to track them separately and sum them up
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();

    // Lines Found and Lines Hit
    if (line.startsWith('LF:')) {
      totalLines += parseInt(line.substring(3)) || 0;
    }
    if (line.startsWith('LH:')) {
      coveredLines += parseInt(line.substring(3)) || 0;
    }

    // Functions Found and Functions Hit
    if (line.startsWith('FNF:')) {
      totalFunctions += parseInt(line.substring(4)) || 0;
    }
    if (line.startsWith('FNH:')) {
      coveredFunctions += parseInt(line.substring(4)) || 0;
    }

    // Branches Found and Branches Hit
    if (line.startsWith('BRF:')) {
      totalBranches += parseInt(line.substring(4)) || 0;
    }
    if (line.startsWith('BRH:')) {
      coveredBranches += parseInt(line.substring(4)) || 0;
    }
  }

  return {
    totalLines,
    coveredLines,
    totalFunctions,
    coveredFunctions,
    totalBranches,
    coveredBranches
  };
}

/**
 * Calculate coverage percentage
 * @param {number} covered - Number of covered items
 * @param {number} total - Total number of items
 * @returns {number} Coverage percentage
 */
function calculateCoverage(covered, total) {
  return total > 0 ? Math.round((covered / total) * 100) : 0;
}

/**
 * Get badge color based on coverage percentage
 * @param {number} coverage - Coverage percentage
 * @returns {string} Badge color
 */
function getBadgeColor(coverage) {
  if (coverage >= THRESHOLDS.good) return 'brightgreen';
  if (coverage >= THRESHOLDS.needsImprovement) return 'yellow';
  if (coverage >= THRESHOLDS.poor) return 'orange';
  return 'red';
}

/**
 * Generate coverage report comment body
 * @param {object} metrics - Coverage metrics
 * @param {object} commitInfo - Optional commit information
 * @returns {string} Markdown formatted comment body
 */
function generateCoverageReport(metrics, commitInfo = {}) {
  const lineCoverage = calculateCoverage(metrics.coveredLines, metrics.totalLines);
  const functionCoverage = calculateCoverage(metrics.coveredFunctions, metrics.totalFunctions);
  const branchCoverage = calculateCoverage(metrics.coveredBranches, metrics.totalBranches);

  const badgeColor = getBadgeColor(lineCoverage);
  const badge = `![Coverage](https://img.shields.io/badge/coverage-${lineCoverage}%25-${badgeColor})`;
  
  // Generate timestamp
  const timestamp = new Date().toUTCString();
  
  // Build commit link if info is available
  let commitLink = '';
  if (commitInfo.sha && commitInfo.owner && commitInfo.repo) {
    const shortSha = commitInfo.sha.substring(0, 7);
    commitLink = ` for commit [\`${shortSha}\`](https://github.com/${commitInfo.owner}/${commitInfo.repo}/commit/${commitInfo.sha})`;
  }

  return `## Coverage Report\n` +
    `${badge}\n\n` +
    `| Metric | Coverage | Details |\n` +
    `|--------|----------|----------|\n` +
    `| **Lines** | ${lineCoverage}% | ${metrics.coveredLines}/${metrics.totalLines} lines |\n` +
    `| **Functions** | ${functionCoverage}% | ${metrics.coveredFunctions}/${metrics.totalFunctions} functions |\n` +
    `| **Branches** | ${branchCoverage}% | ${metrics.coveredBranches}/${metrics.totalBranches} branches |\n\n` +
    `*Last updated: ${timestamp}*${commitLink}\n`;
}

/**
 * Generate coverage report and save to file (for workflow artifacts)
 */
function generateCoverageFile() {
  const file = 'lcov.info';

  if (!fs.existsSync(file)) {
    return;
  }

  const content = fs.readFileSync(file, 'utf8');
  const metrics = parseLcovContent(content);

  // Get commit info from environment variables
  const commitInfo = {
    sha: process.env.COMMIT_SHA,
    owner: process.env.REPO_OWNER,
    repo: process.env.REPO_NAME
  };

  const body = generateCoverageReport(metrics, commitInfo);
  fs.writeFileSync('coverage-report.md', body);
}

// If run directly (not as module), generate the file
if (require.main === module) {
  generateCoverageFile();
}
