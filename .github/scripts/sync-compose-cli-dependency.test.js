const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { syncDependency } = require('./sync-compose-cli-dependency');

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'compose-cli-sync-'));
  for (const directory of ['src', 'cli', '.changeset']) {
    fs.mkdirSync(path.join(root, directory));
  }
  fs.writeFileSync(path.join(root, 'src', 'package.json'), JSON.stringify({
    name: '@perfect-abstractions/compose', version: '0.0.7',
  }));
  fs.writeFileSync(path.join(root, 'cli', 'package.json'), JSON.stringify({
    name: '@perfect-abstractions/compose-cli',
    dependencies: { '@perfect-abstractions/compose': '0.0.6' },
  }));
  return root;
}

test('updates the CLI dependency and adds a patch changeset once', (t) => {
  const root = fixture();
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  assert.equal(syncDependency(root, '0.0.7'), true);
  const cli = JSON.parse(fs.readFileSync(path.join(root, 'cli', 'package.json'), 'utf8'));
  assert.equal(cli.dependencies['@perfect-abstractions/compose'], '0.0.7');
  const changeset = fs.readFileSync(path.join(root, '.changeset', 'compose-cli-dependency-0-0-7.md'), 'utf8');
  assert.match(changeset, /"@perfect-abstractions\/compose-cli": patch/);
  assert.equal(syncDependency(root, '0.0.7'), false);
});

test('rejects a version other than the library version on main', (t) => {
  const root = fixture();
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  assert.throws(() => syncDependency(root, '0.0.8'), /does not match/);
});
