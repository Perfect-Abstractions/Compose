import { createHash } from 'node:crypto';
import { readdir, readFile, mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const defaultRoot = fileURLToPath(new URL('../../', import.meta.url));
const packagePrefix = '@perfect-abstractions/compose/';
const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;

async function filesUnder(root, directory, extension) {
  const entries = await readdir(path.join(root, directory), { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const relative = `${directory}/${entry.name}`;
    if (entry.isDirectory()) files.push(...await filesUnder(root, relative, extension));
    else if (entry.isFile() && entry.name.endsWith(extension)) files.push(relative);
  }
  return files.sort(compare);
}

/** Build a local source inventory with CLI preset membership as a separate overlay. */
export async function buildLibraryCatalog(root = defaultRoot) {
  const sourcePaths = await filesUnder(root, 'src', '.sol');
  const presetPaths = await filesUnder(root, 'cli/bases', '.json');
  const inputs = new Map();
  for (const relative of [...sourcePaths, ...presetPaths]) {
    inputs.set(relative, (await readFile(path.join(root, relative), 'utf8')).replace(/\r\n/g, '\n'));
  }
  const files = sourcePaths.map((relative) => {
    const name = path.posix.basename(relative, '.sol');
    const parts = relative.split('/');
    const kind = parts[1] === 'interfaces' ? 'interface'
      : name.endsWith('Facet') ? 'facet'
      : name.endsWith('Mod') ? 'module'
      : 'other';
    return {
      path: relative,
      name,
      kind,
      category: parts[1],
      family: parts.length > 3 ? parts[2] : null,
      sha256: createHash('sha256').update(inputs.get(relative)).digest('hex'),
      presets: [],
    };
  });
  const byPath = new Map(files.map((file) => [file.path, file]));
  const presets = [];
  const ids = new Set();

  for (const sourcePath of presetPaths) {
    const definitions = JSON.parse(inputs.get(sourcePath));
    if (!definitions || Array.isArray(definitions) || typeof definitions !== 'object') {
      throw new Error(`Expected preset definitions in ${sourcePath}`);
    }
    for (const id of Object.keys(definitions).sort(compare)) {
      if (ids.has(id)) throw new Error(`Duplicate preset ID: ${id}`);
      ids.add(id);
      const definition = definitions[id];
      if (!definition || typeof definition.label !== 'string') {
        throw new Error(`Missing preset label: ${sourcePath}#${id}`);
      }
      const references = [];
      // Preserve exact field paths, including mod and erc165 references, not just facets.
      function visit(value, fields = []) {
        if (typeof value === 'string' && value.endsWith('.sol')) {
          const field = fields.join('.');
          const libraryReference = value.startsWith(packagePrefix);
          const resolvedPath = libraryReference ? `src/${value.slice(packagePrefix.length)}` : null;
          const source = resolvedPath ? byPath.get(resolvedPath) : undefined;
          const status = source ? 'resolved' : libraryReference ? 'missing' : 'external';
          const role = ['required', 'optional'].includes(fields[0]) ? fields[0] : null;
          references.push({ field, declaredPath: value, path: source?.path ?? null, role, status });
          if (source) source.presets.push({ id, field, role });
        } else if (Array.isArray(value)) {
          value.forEach((child, index) => visit(child, [...fields, String(index)]));
        } else if (value && typeof value === 'object') {
          for (const key of Object.keys(value).sort(compare)) visit(value[key], [...fields, key]);
        }
      }
      visit(definition);
      presets.push({ id, sourcePath, definition, references });
    }
  }
  const hash = createHash('sha256');
  for (const [relative, contents] of inputs) {
    hash.update(JSON.stringify([relative, contents]));
  }
  return {
    schemaVersion: 1,
    source: { directories: ['src', 'cli/bases'], sha256: hash.digest('hex') },
    files,
    presets: presets.sort((a, b) => compare(a.id, b.id)),
  };
}

export async function generateLibraryCatalog({ root = defaultRoot, check = false } = {}) {
  const catalog = await buildLibraryCatalog(root);
  const missing = catalog.presets.flatMap((preset) => preset.references
    .filter((reference) => reference.status === 'missing')
    .map((reference) => `${preset.id}:${reference.field} -> ${reference.declaredPath}`));
  if (missing.length) throw new Error(`Unresolved Compose references:\n${missing.join('\n')}`);
  const output = path.join(root, 'website/src/data/libraryCatalog.json');
  const serialized = `${JSON.stringify(catalog, null, 2)}\n`;
  let current;
  try { current = await readFile(output, 'utf8'); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  if (check) {
    if (current?.replace(/\r\n/g, '\n') !== serialized) {
      throw new Error('Library catalog is stale. Run npm run catalog:generate in website.');
    }
  } else if (current?.replace(/\r\n/g, '\n') !== serialized) {
    await mkdir(path.dirname(output), { recursive: true });
    await writeFile(output, serialized);
  }
  return catalog;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const catalog = await generateLibraryCatalog({ check: process.argv.includes('--check') });
    console.log(`Library catalog: ${catalog.files.filter((file) => file.kind === 'facet').length} facets, ${catalog.presets.length} presets`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
