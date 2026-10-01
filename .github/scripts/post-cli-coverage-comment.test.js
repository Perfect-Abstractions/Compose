const assert = require('node:assert/strict');
const test = require('node:test');
const post = require('./post-cli-coverage-comment');

function setup(prSha = 'head-sha') {
  const calls = { created: [], updated: [] };
  const github = {
    rest: {
      pulls: { get: async () => ({ data: {
        head: { sha: prSha },
        base: { repo: { full_name: 'owner/repo' } },
      } }) },
      issues: {
        listComments: async () => {},
        createComment: async (args) => { calls.created.push(args); },
        updateComment: async (args) => { calls.updated.push(args); },
      },
    },
    paginate: async () => [{
      id: 42,
      user: { type: 'Bot' },
      body: '<!-- compose-cli-coverage -->\nOld report',
    }],
  };
  const context = {
    repo: { owner: 'owner', repo: 'repo' },
    payload: { workflow_run: { head_sha: 'head-sha' } },
  };
  const helpers = {
    downloadArtifact: async () => true,
    readReport: (name) => name.endsWith('.json')
      ? JSON.stringify({ prNumber: 17, headSha: 'head-sha', workflowSha: 'head-sha' })
      : '<!-- compose-cli-coverage -->\nNew report',
  };
  return { calls, github, context, helpers };
}

test('updates the existing CLI coverage comment', async () => {
  const { calls, github, context, helpers } = setup();
  await post({ github, context }, helpers);
  assert.equal(calls.created.length, 0);
  assert.deepEqual(calls.updated, [{
    owner: 'owner', repo: 'repo', comment_id: 42,
    body: '<!-- compose-cli-coverage -->\nNew report',
  }]);
});

test('ignores coverage from an older PR commit', async () => {
  const { calls, github, context, helpers } = setup('newer-head-sha');
  await post({ github, context }, helpers);
  assert.equal(calls.created.length, 0);
  assert.equal(calls.updated.length, 0);
});
