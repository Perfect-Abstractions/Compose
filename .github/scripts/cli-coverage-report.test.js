const assert = require('node:assert/strict');
const test = require('node:test');
const { generateReport, MARKER } = require('./cli-coverage-report');

test('renders CLI coverage from LCOV totals', () => {
  const report = generateReport('LF:10\nLH:8\nFNF:5\nFNH:4\nBRF:2\nBRH:1\n', 'abcdef123456');
  assert.ok(report.startsWith(`${MARKER}\n## CLI Coverage`));
  assert.match(report, /\| Lines \| 80% \| 8\/10 \|/);
  assert.match(report, /\| Functions \| 80% \| 4\/5 \|/);
  assert.match(report, /\| Branches \| 50% \| 1\/2 \|/);
  assert.match(report, /Commit: `abcdef1`/);
});
