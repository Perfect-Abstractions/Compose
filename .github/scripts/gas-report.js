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
    // Parse lines that look like:
    // +ContractName:testFunctionName() (gas: 12345)
    // -ContractName:testFunctionName() (gas: 12345)
    const changeMatch = line.match(/^([+-])([^:]+):([^(]+)\(\).*?(\d+)\s*$/);
    if (changeMatch) {
      const [, sign, contract, func, newGas] = changeMatch;

      // Try to extract the old gas value from the context
      const oldGasMatch = line.match(/(\d+)\s*->\s*(\d+)/);
      let oldGas = null;
      if (oldGasMatch) {
        oldGas = oldGasMatch[1];
      }

      changes.push({
        type: sign === '+' ? 'regression' : 'improvement',
        contract: contract.trim(),
        function: func.trim(),
        oldGas: oldGas ? parseInt(oldGas) : null,
        newGas: parseInt(newGas),
        gasChange: oldGas ? parseInt(newGas) - parseInt(oldGas) : parseInt(newGas)
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
 * Calculate percentage change
 */
function calculatePercentageChange(oldVal, newVal) {
  if (!oldVal || oldVal === 0) return 'N/A';
  const change = ((newVal - oldVal) / oldVal) * 100;
  return change.toFixed(2) + '%';
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
    const before = change.oldGas ? formatGasValue(change.oldGas) : 'New';
    const after = formatGasValue(change.newGas);
    const diff = `${icon} ${sign}${formatGasValue(change.gasChange)}`;
    const percentage = change.oldGas ? ` (${calculatePercentageChange(change.oldGas, change.newGas)})` : '';

    table += `| ${change.contract} | ${change.function}() | ${before} | ${after} | ${diff}${percentage} |\n`;
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
 * Generate the full markdown report
 */
function generateFullReport(diffOutput, prInfo = {}) {
  const baseBranch = prInfo.baseBranch || 'base';
  const headBranch = prInfo.headBranch || 'head';
  const commitSha = prInfo.commitSha ? ` (${prInfo.commitSha.substring(0, 7)})` : '';

  // Handle case with no changes
  if (!diffOutput || diffOutput.trim().length === 0) {
    return `## 📊 Gas Report

No gas usage changes detected between \`${baseBranch}\` and \`${headBranch}\`${commitSha}.

All functions maintain the same gas costs. ✅`;
  }

  // Parse and analyze changes
  const changes = parseGasDiff(diffOutput);

  // If no changes were parsed but there was diff output, it might be an error or unrecognized format
  if (changes.length === 0) {
    return `## 📊 Gas Report

No gas usage changes detected between \`${baseBranch}\` and \`${headBranch}\`${commitSha}.

All functions maintain the same gas costs. ✅`;
  }

  const summary = generateSummary(changes);
  const table = generateMarkdownTable(changes);

  return `## 📊 Gas Report

Comparing gas usage between \`${baseBranch}\` and \`${headBranch}\`${commitSha}

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

<details>
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

  console.log('Gas report generated successfully: gas-report.md');
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

// Export functions for testing or other uses
module.exports = {
  parseGasDiff,
  generateMarkdownTable,
  generateSummary,
  generateFullReport,
  formatGasValue,
  calculatePercentageChange
};