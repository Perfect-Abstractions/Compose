import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, readFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { buildLibraryCatalog, generateLibraryCatalog } from './generate-library-catalog.mjs';

async function fixture(t) {
  const root = await mkdtemp(path.join(os.tmpdir(), 'compose-catalog-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const sources = {
    'src/token/Example/Data/ExampleDataFacet.sol': 'contract ExampleDataFacet {}\n',
    'src/token/Example/Data/ExampleDataMod.sol': 'library ExampleDataMod {}\n',
    'src/token/Example/Burn/ExampleBurnFacet.sol': 'contract ExampleBurnFacet {}\n',
    'src/interfaces/IExample.sol': 'interface IExample {}\n',
    'src/interfaces/IFacet.sol': 'interface IFacet {}\n',
  };
  for (const [relative, contents] of Object.entries(sources)) {
    await mkdir(path.dirname(path.join(root, relative)), { recursive: true });
    await writeFile(path.join(root, relative), contents);
  }
  const definitions = {
    example: {
      label: 'Example',
      erc165: { path: '@perfect-abstractions/compose/interfaces/IExample.sol' },
      required: {
        ExampleDataFacet: {
          path: '@perfect-abstractions/compose/token/Example/Data/ExampleDataFacet.sol',
          mod: '@perfect-abstractions/compose/token/Example/Data/ExampleDataMod.sol',
        },
      },
      optional: { LocalFacet: { path: './src/templates/LocalFacet.sol' } },
    },
  };
  await mkdir(path.join(root, 'cli/bases'), { recursive: true });
  const presetFile = path.join(root, 'cli/bases/example.json');
  await writeFile(presetFile, JSON.stringify(definitions));
  return { root, definitions, presetFile, sources };
}

test('inventories facets outside presets and preserves exact preset references', async (t) => {
  const { root, definitions } = await fixture(t);
  const catalog = await buildLibraryCatalog(root);
  assert.equal(catalog.files.filter((file) => file.kind === 'facet').length, 2);
  assert.equal(catalog.files.find((file) => file.name === 'IFacet').kind, 'interface');
  const data = catalog.files.find((file) => file.name === 'ExampleDataFacet');
  assert.equal(data.category, 'token');
  assert.equal(data.family, 'Example');
  assert.deepEqual(data.presets, [{ id: 'example', field: 'required.ExampleDataFacet.path', role: 'required' }]);
  assert.deepEqual(catalog.files.find((file) => file.name === 'ExampleBurnFacet').presets, []);
  assert.deepEqual(catalog.presets[0].definition, definitions.example);
  assert.equal(catalog.presets[0].references.find((ref) => ref.field.endsWith('.mod')).status, 'resolved');
  assert.equal(catalog.presets[0].references.find((ref) => ref.field === 'erc165.path').role, null);
  const external = catalog.presets[0].references.find((ref) => ref.status === 'external');
  assert.equal(external.path, null);
  assert.equal(external.declaredPath, './src/templates/LocalFacet.sol');
});

test('generation is deterministic across line endings and detects stale inputs', async (t) => {
  const { root, sources } = await fixture(t);
  const first = await generateLibraryCatalog({ root });
  for (const [relative, contents] of Object.entries(sources)) {
    await writeFile(path.join(root, relative), contents.replace(/\n/g, '\r\n'));
  }
  assert.deepEqual(await generateLibraryCatalog({ root, check: true }), first);
  const output = path.join(root, 'website/src/data/libraryCatalog.json');
  const before = await readFile(output, 'utf8');
  await generateLibraryCatalog({ root });
  assert.equal(await readFile(output, 'utf8'), before);
  await writeFile(path.join(root, Object.keys(sources)[0]), 'contract ChangedFacet {}\n');
  await assert.rejects(generateLibraryCatalog({ root, check: true }), /stale/);
});

test('missing package sources fail generation instead of inventing library nodes', async (t) => {
  const { root, definitions, presetFile } = await fixture(t);
  definitions.example.required.ExampleDataFacet.path = '@perfect-abstractions/compose/MissingFacet.sol';
  await writeFile(presetFile, JSON.stringify(definitions));
  await assert.rejects(generateLibraryCatalog({ root }), /Unresolved Compose references/);
});

test('duplicate preset IDs are rejected', async (t) => {
  const { root, definitions } = await fixture(t);
  await writeFile(path.join(root, 'cli/bases/duplicate.json'), JSON.stringify(definitions));
  await assert.rejects(buildLibraryCatalog(root), /Duplicate preset ID/);
});
