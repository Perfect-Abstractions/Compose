const fs = require('node:fs');
const path = require('node:path');
const { parseLcovContent, calculateCoverage } = require('./coverage-comment');

const MARKER = '<!-- compose-cli-coverage -->';

function generateReport(content, commit) {
  const metrics = parseLcovContent(content);
  const rows = [
    ['Lines', metrics.coveredLines, metrics.totalLines],
    ['Functions', metrics.coveredFunctions, metrics.totalFunctions],
    ['Branches', metrics.coveredBranches, metrics.totalBranches],
  ];
  const table = rows.map(([name, covered, total]) =>
    `| ${name} | ${calculateCoverage(covered, total)}% | ${covered}/${total} |`).join('\n');
  return `${MARKER}\n## CLI Coverage\n\n` +
    `Commit: \`${commit.slice(0, 7)}\`\n\n` +
    `| Metric | Coverage | Covered/Total |\n| --- | ---: | ---: |\n${table}\n`;
}

function main() {
  const lcovPath = path.join(process.cwd(), 'cli', 'coverage', 'lcov.info');
  const content = fs.readFileSync(lcovPath, 'utf8');
  const prNumber = Number(process.env.PR_NUMBER);
  const headSha = process.env.HEAD_SHA;
  const workflowSha = process.env.WORKFLOW_SHA;
  if (!Number.isSafeInteger(prNumber) || prNumber <= 0 || !headSha || !workflowSha) {
    throw new Error('CLI coverage requires PR_NUMBER, HEAD_SHA, and WORKFLOW_SHA');
  }
  fs.writeFileSync('cli-coverage-report.md', generateReport(content, headSha));
  fs.writeFileSync('cli-coverage-data.json', JSON.stringify({ prNumber, headSha, workflowSha }));
}

if (require.main === module) main();

module.exports = { generateReport, MARKER };
