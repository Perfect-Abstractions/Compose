import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const script = fileURLToPath(new URL('../../website/netlify-ignore.sh', import.meta.url)).replaceAll('\\', '/');
const shell = process.env.NETLIFY_IGNORE_TEST_SHELL || 'bash';

test('Netlify rebuilds for docs inputs and skips unrelated changes', async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'compose-netlify-ignore-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', ['-C', root, ...args], { encoding: 'utf8', windowsHide: true }).trim();
  await mkdir(path.join(root, 'website'), { recursive: true });
  await writeFile(path.join(root, 'website/index.mdx'), '# Library\n');
  git('init', '--quiet');
  function commit() {
    git('add', '.');
    git('-c', 'user.name=Docs Test', '-c', 'user.email=docs-test@example.invalid', '-c', 'commit.gpgsign=false', 'commit', '--quiet', '-m', 'Test fixture');
    return git('rev-parse', 'HEAD');
  }
  let previous = commit();
  function check(cached, current) {
    const result = spawnSync(shell, [script], {
      cwd: path.join(root, 'website'),
      env: { ...process.env, CACHED_COMMIT_REF: cached, COMMIT_REF: current },
      encoding: 'utf8',
      windowsHide: true,
    });
    if (result.error) throw result.error;
    assert.equal(result.stderr, '');
    return result.status;
  }
  for (const [file, expected] of [
    ['website/index.mdx', 1],
    ['cli/bases/example.json', 1],
    ['cli/src/example.ts', 1],
    ['src/ExampleFacet.sol', 1],
    ['src/token/example/ExampleFacet.sol', 1],
    ['src/README.md', 0],
    ['README.md', 0],
  ]) {
    await t.test(file, async () => {
      await mkdir(path.dirname(path.join(root, file)), { recursive: true });
      await writeFile(path.join(root, file), `Changed ${file}\n`);
      const current = commit();
      assert.equal(check(previous, current), expected);
      previous = current;
    });
  }
  await t.test('missing or untrustworthy baseline always builds', () => {
    assert.equal(check('', previous), 1);
    assert.equal(check(previous, ''), 1);
    assert.equal(check(previous, previous), 1);
    assert.equal(check('nonexistent-ref', previous), 1);
  });
});
