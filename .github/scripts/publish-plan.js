/**
 * Reads .github/publish-packages.json, compares each package version to npm,
 * and writes matrix JSON + has_publish to GITHUB_OUTPUT for publish.yml.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const CONFIG_PATH = path.join(process.cwd(), '.github/publish-packages.json');

function npmViewVersion(packageName) {
  try {
    return execSync(`npm view ${JSON.stringify(packageName)} version`, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return '';
  }
}

function readLocalVersion(versionFile) {
  const abs = path.join(process.cwd(), versionFile);
  const raw = fs.readFileSync(abs, 'utf8');
  const pkg = JSON.parse(raw);
  if (typeof pkg.version !== 'string' || !pkg.version) {
    throw new Error(`Invalid or missing version in ${versionFile}`);
  }
  return pkg.version;
}

function loadConfig() {
  const raw = fs.readFileSync(CONFIG_PATH, 'utf8');
  const config = JSON.parse(raw);
  if (!config.packages || !Array.isArray(config.packages)) {
    throw new Error('publish-packages.json must contain a "packages" array');
  }
  return config.packages;
}

function validateEntries(packages) {
  const ids = new Set();
  const workspaces = new Set();
  const required = ['id', 'workspace', 'versionFile', 'tagPrefix', 'check', 'needsFoundry'];

  for (const p of packages) {
    for (const key of required) {
      if (!(key in p)) {
        throw new Error(`Package entry missing required field "${key}": ${JSON.stringify(p)}`);
      }
    }
    if (typeof p.needsFoundry !== 'boolean') {
      throw new Error(`needsFoundry must be boolean for id "${p.id}"`);
    }
    if (ids.has(p.id)) {
      throw new Error(`Duplicate id: ${p.id}`);
    }
    ids.add(p.id);
    if (workspaces.has(p.workspace)) {
      throw new Error(`Duplicate workspace: ${p.workspace}`);
    }
    workspaces.add(p.workspace);
  }
}

function main() {
  const packages = loadConfig();
  validateEntries(packages);

  const include = [];
  const out = process.env.GITHUB_OUTPUT;
  if (!out) {
    throw new Error('GITHUB_OUTPUT is not set');
  }

  for (const p of packages) {
    const localVer = readLocalVersion(p.versionFile);
    const npmVer = npmViewVersion(p.workspace);
    const needsPublish = !npmVer || localVer !== npmVer;

    console.log(`${p.id}: package.json=${localVer} npm=${npmVer || '<not published>'}`);

    if (needsPublish) {
      include.push({
        id: p.id,
        workspace: p.workspace,
        versionFile: p.versionFile,
        tagPrefix: p.tagPrefix,
        needsFoundry: p.needsFoundry,
        check: p.check,
      });
    }
  }

  const hasPublish = include.length > 0;
  fs.appendFileSync(out, `has_publish=${hasPublish ? 'true' : 'false'}\n`);

  const matrixJson = JSON.stringify(include);
  const delim = 'PUBLISH_MATRIX_JSON';
  fs.appendFileSync(out, `matrix<<${delim}\n${matrixJson}\n${delim}\n`);

  if (hasPublish) {
    console.log('Publish matrix will run for packages ahead of npm.');
  } else {
    console.log('Nothing to publish — versions on main already match npm for all configured packages.');
  }
}

main();
