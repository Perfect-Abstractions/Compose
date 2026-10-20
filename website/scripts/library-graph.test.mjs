import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { libraryGraph, constellationView, starDepthScale } from '../src/components/LibraryGraph/model.mjs';

const catalog = JSON.parse(await readFile(new URL('../src/data/libraryCatalog.json', import.meta.url), 'utf8'));

test('only actual Docusaurus routes become facet links, including custom slugs', () => {
  const graph = libraryGraph(catalog, [{ id: 'library/token/ERC20/Data/ERC20DataFacet', path: '/custom-data-route/' }]);
  assert.equal(graph.nodes.find((node) => node.name === 'ERC20DataFacet').href, '/custom-data-route/');
  assert.equal(graph.nodes.find((node) => node.name === 'ERC20TransferFacet').href, undefined);
  assert.ok(graph.nodes.filter((node) => node.kind === 'facet').every((node) => node.category !== 'interfaces'));
});

test('preset and search emphasis preserve complete membership and stable positions', () => {
  const full = libraryGraph(catalog);
  const filtered = libraryGraph(catalog, [], { preset: 'erc-20', query: 'Data' });
  assert.deepEqual(filtered.nodes.map((node) => [node.id, node.position]), full.nodes.map((node) => [node.id, node.position]));
  const matching = filtered.nodes.filter((node) => node.kind === 'facet' && node.matches);
  assert.deepEqual(matching.map((node) => node.name), ['ERC20DataFacet', 'ERC20MetadataFacet']);
  const ids = new Set(full.nodes.map((node) => node.id));
  assert.ok(full.links.every((link) => ids.has(link.source) && ids.has(link.target)));
});

test('CLI-local templates do not fabricate library facets', () => {
  const graph = libraryGraph(catalog, [], { preset: 'counter' });
  assert.equal(graph.nodes.filter((node) => node.matches).length, 0);
  assert.ok(graph.nodes.every((node) => !node.name.startsWith('Counter')));
});

test('constellations and their facets occupy depth rather than a common plane', () => {
  const graph = libraryGraph(catalog);
  const groups = graph.nodes.filter((node) => node.kind === 'group');
  const depth = groups.map((node) => node.position[2]);
  assert.ok(Math.max(...depth) - Math.min(...depth) > 10);
  const erc20 = graph.nodes.filter((node) => node.parentId === 'token/ERC20');
  const localDepth = erc20.map((node) => node.position[2]);
  assert.ok(Math.max(...localDepth) - Math.min(...localDepth) > 1.5);
  assert.ok(graph.links.some((edge) => edge.source === 'category:token' && edge.target === 'token/ERC20'));
});

test('centers from different categories form a volume and maintain near/far size cues', () => {
  const { nodes } = libraryGraph(catalog);
  const [a, b, c, d] = ['access/Owner', 'diamond/', 'interfaceDetection/ERC165', 'token/ERC1155']
    .map((id) => nodes.find((node) => node.id === id).position);
  const subtract = (p, q) => p.map((value, axis) => value - q[axis]);
  const ab = subtract(b, a), ac = subtract(c, a), ad = subtract(d, a);
  const cross = [ac[1] * ad[2] - ac[2] * ad[1], ac[2] * ad[0] - ac[0] * ad[2], ac[0] * ad[1] - ac[1] * ad[0]];
  const volume = Math.abs(ab.reduce((sum, value, axis) => sum + value * cross[axis], 0));
  assert.ok(volume / (Math.hypot(...ab) * Math.hypot(...ac) * Math.hypot(...ad)) > 0.2);
  assert.ok(starDepthScale(15, 25) > starDepthScale(35, 25));
  assert.ok(starDepthScale(100, 25) >= 0.72);
  assert.ok(starDepthScale(0, 25) <= 1.45);
});

test('oblique desktop and portrait cameras frame every node with label margins', () => {
  const { nodes } = libraryGraph(catalog);
  for (const aspect of [2.2, 1.5, 0.8, 0.6]) {
    const view = constellationView(nodes, aspect);
    assert.equal(view.positions.size, nodes.length);
    assert.ok(view.camera[1] < view.target[1]);
    for (const projected of view.projected.values()) {
      assert.ok(projected.every((value) => Number.isFinite(value) && Math.abs(value) < 0.9));
    }
  }
});
