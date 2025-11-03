/**
 * Gas Report Script for GitHub Actions
 * Handles forge snapshot diffs and generates formatted reports
 *
 * Usage:
 * - node gas-report.js generate - Read gas-diff.txt and create gas-report.md
 * - Called from gas-report.yml workflow to generate report for artifact upload
 */

const fs = require('fs');
const path = require('path');

/**
 * Parse gas diff output into structured data
 */
function parseGasDiff(diffOutput) {
  const lines = diffOutput.split('\n').filter(line => line.trim());
  const changes = [];

  for (const line of lines) {
    // Skip lines until we find the actual diff output
    // Look for lines like: test_FunctionName() (gas: -123 (-1.23%))
    // or: testFuzz_Name(params) (gas: 456 (4.56%))
    const trimmedLine = line.trim();

    // Match function name followed by (gas: change (percentage))
    const changeMatch = trimmedLine.match(/^([\w_]+)\([^)]*\)\s+\(gas:\s*([-+]?\d+)\s+\([^)]+\)\)/);

    if (changeMatch) {
      const [, funcName, gasChangeStr] = changeMatch;
      const gasChange = parseInt(gasChangeStr);

      // Skip zero changes
      if (gasChange === 0) continue;

      changes.push({
        type: gasChange < 0 ? 'improvement' : 'regression',
        contract: 'Test', // We don't have contract names in this format
        function: funcName,
        oldGas: null, // We don't have old value
        newGas: null, // We don't have new value
        gasChange: gasChange
      });
    }
  }

  return changes;
}

/**
 * Format large numbers with commas
 */
function formatGasValue(value) {
  return value.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

/**
 * Generate markdown table from changes
 */
function generateMarkdownTable(changes, limit = 20) {
  if (changes.length === 0) {
    return 'No gas changes detected in individual functions.';
  }

  // Sort by absolute gas change (biggest changes first)
  changes.sort((a, b) => Math.abs(b.gasChange) - Math.abs(a.gasChange));

  let table = `| Contract | Function | Before | After | Change |
|----------|----------|--------|-------|--------|
`;

  const displayChanges = changes.slice(0, limit);

  for (const change of displayChanges) {
    const icon = change.type === 'improvement' ? '🟢' : '🔴';
    const sign = change.gasChange > 0 ? '+' : '';
    const diff = `${icon} ${sign}${formatGasValue(change.gasChange)}`;
    // Since we don't have old/new values in the new format, show N/A
    const before = change.oldGas ? formatGasValue(change.oldGas) : 'N/A';
    const after = change.newGas ? formatGasValue(change.newGas) : 'N/A';

    table += `| ${change.contract} | ${change.function}() | ${before} | ${after} | ${diff} |\n`;
  }

  if (changes.length > limit) {
    table += `\n*Showing top ${limit} changes out of ${changes.length} total.*`;
  }

  return table;
}

/**
 * Generate summary statistics
 */
function generateSummary(changes) {
  const improvements = changes.filter(c => c.type === 'improvement');
  const regressions = changes.filter(c => c.type === 'regression');

  const totalImprovement = improvements.reduce((sum, c) => sum + Math.abs(c.gasChange), 0);
  const totalRegression = regressions.reduce((sum, c) => sum + Math.abs(c.gasChange), 0);
  const netChange = totalRegression - totalImprovement;

  let netIcon = '⚪';
  let netText = 'No change';

  if (netChange > 0) {
    netIcon = '🔴';
    netText = `+${formatGasValue(netChange)} gas`;
  } else if (netChange < 0) {
    netIcon = '🟢';
    netText = `${formatGasValue(netChange)} gas`;
  }

  return {
    improvements: improvements.length,
    regressions: regressions.length,
    totalImprovement,
    totalRegression,
    netChange,
    netIcon,
    netText
  };
}

/**
 * Generate timestamp footer for reports
 */
function generateFooter(shortSha, fullCommitSha) {
  const timestamp = new Date().toUTCString();
  const repo = process.env.GITHUB_REPOSITORY || 'owner/repo';
  const commitLink = `[\`${shortSha || 'unknown'}\`](https://github.com/${repo}/commit/${fullCommitSha})`;
  return `*Last updated: ${timestamp}* for commit ${commitLink}`;
}

/**
 * Generate "no changes" report
 */
function generateNoChangesReport(baseBranch, headBranch, shortSha, fullCommitSha) {
  return `## Gas Report

No gas usage changes detected between \`${baseBranch}\` and \`${headBranch}\`.

All functions maintain the same gas costs. ✅

${generateFooter(shortSha, fullCommitSha)}`;
}

/**
 * Generate about section
 */
function generateAboutSection() {
  return `<details>
<summary>ℹ️ About this report</summary>

This report compares gas usage between the base branch and this PR using \`forge snapshot\`.
- 🟢 indicates a gas improvement (reduction)
- 🔴 indicates a gas regression (increase)
- Functions not shown have unchanged gas costs

To run this locally:
\`\`\`bash
# Generate snapshot for current branch
forge snapshot

# Compare with another branch
git checkout main
forge snapshot --diff .gas-snapshot
\`\`\`

</details>`;
}

/**
 * Generate the full markdown report
 */
function generateFullReport(diffOutput, prInfo = {}) {
  const baseBranch = prInfo.baseBranch || 'base';
  const headBranch = prInfo.headBranch || 'head';
  const fullCommitSha = prInfo.commitSha || '';
  const shortSha = fullCommitSha ? fullCommitSha.substring(0, 7) : '';

  // Handle case with no changes
  if (!diffOutput || diffOutput.trim().length === 0) {
    return generateNoChangesReport(baseBranch, headBranch, shortSha, fullCommitSha);
  }

  // Parse and analyze changes
  const changes = parseGasDiff(diffOutput);

  // If no changes were parsed but there was diff output, it might be an error or unrecognized format
  if (changes.length === 0) {
    return generateNoChangesReport(baseBranch, headBranch, shortSha, fullCommitSha);
  }

  const summary = generateSummary(changes);
  const table = generateMarkdownTable(changes);

  return `## Gas Report

Comparing gas usage between \`${baseBranch}\` and \`${headBranch}\`

### Summary
- **Optimized:** ${summary.improvements} functions (🟢 -${formatGasValue(summary.totalImprovement)} gas)
- **Increased:** ${summary.regressions} functions (🔴 +${formatGasValue(summary.totalRegression)} gas)
- **Net Change:** ${summary.netIcon} ${summary.netText}

### Details

${table}

${changes.length > 20 ? `
<details>
<summary>View all ${changes.length} changes</summary>

${generateMarkdownTable(changes, changes.length)}

</details>
` : ''}

${generateAboutSection()}

${generateFooter(shortSha, fullCommitSha)}`;
}

/**
 * Main function for CLI usage
 * Reads gas-diff.txt and generates gas-report.md
 */
function generateReportFromFile() {
  // Read the diff output
  const diffPath = path.join(process.cwd(), 'gas-diff.txt');
  if (!fs.existsSync(diffPath)) {
    console.error('Error: gas-diff.txt not found');
    process.exit(1);
  }

  const diffOutput = fs.readFileSync(diffPath, 'utf8');

  // Get PR info from environment
  const prInfo = {
    baseBranch: process.env.BASE_BRANCH || 'main',
    headBranch: process.env.HEAD_BRANCH || 'feature',
    commitSha: process.env.HEAD_SHA
  };

  // Generate the report
  const report = generateFullReport(diffOutput, prInfo);

  // Save the report
  const reportPath = path.join(process.cwd(), 'gas-report.md');
  fs.writeFileSync(reportPath, report, 'utf8');
}

// CLI handling
if (require.main === module) {
  const command = process.argv[2];

  if (command === 'generate') {
    generateReportFromFile();
  } else {
    console.error('Usage: node gas-report.js generate');
    process.exit(1);
  }
}
