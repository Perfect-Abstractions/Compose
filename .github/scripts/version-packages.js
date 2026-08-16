#!/usr/bin/env node

/**
 * Wrapper around `changeset version` that supports --ignore for selective
 * package releases. Also syncs the root CHANGELOG.md with src/CHANGELOG.md
 * before and after versioning (the dual-CHANGELOG pattern).
 *
 * Usage:
 *   node .github/scripts/version-packages.js
 *   node .github/scripts/version-packages.js --ignore @perfect-abstractions/compose-cli
 *   node .github/scripts/version-packages.js --ignore @perfect-abstractions/compose --ignore @perfect-abstractions/compose-cli
 *
 * Permanent ignores (e.g. private packages) are always included.
 * The --ignore flag is additive with the permanent list.
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const ROOT_CL = path.join(ROOT, 'CHANGELOG.md');
const SRC_CL = path.join(ROOT, 'src', 'CHANGELOG.md');

// Packages that should never be versioned (private / non-publishable)
const PERMANENT_IGNORE = ['compose-documentation'];

function copyFile(src, dest) {
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, dest);
  }
}

function execOrDie(cmd) {
  console.log(`> ${cmd}`);
  execSync(cmd, { stdio: 'inherit', cwd: ROOT });
}

// --- Parse --ignore flags (supports multiple --ignore and comma-separated values) ---
const allIgnore = [...PERMANENT_IGNORE];
const ignoredPkgs = [];
for (let i = 2; i < process.argv.length; i++) {
  if (process.argv[i] === '--ignore' && i + 1 < process.argv.length) {
    ignoredPkgs.push(...process.argv[i + 1].split(',').map(s => s.trim()));
    i++; // skip the value
  }
}

if (ignoredPkgs.length > 0) {
  allIgnore.push(...ignoredPkgs);

  // Auto-include dependents of ignored packages
  const workspaceDirs = ['src', 'cli', 'website'];
  for (const dir of workspaceDirs) {
    const pkgPath = path.join(ROOT, dir, 'package.json');
    if (!fs.existsSync(pkgPath)) continue;
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
    const deps = { ...pkg.dependencies, ...pkg.devDependencies };
    for (const dep of Object.keys(deps)) {
      if (ignoredPkgs.includes(dep) && !allIgnore.includes(pkg.name)) {
        allIgnore.push(pkg.name);
        console.log(`Auto-ignoring dependent: ${pkg.name}`);
      }
    }
  }

  console.log(`Selective release: ignoring ${allIgnore.join(', ')}`);
}

// --- Pre-sync: copy root CHANGELOG into src/ so changeset version reads the latest ---
copyFile(ROOT_CL, SRC_CL);

// --- Run changeset version ---
const ignoreArg = allIgnore.map(pkg => ` --ignore ${pkg}`).join('');
execOrDie(`npx changeset version${ignoreArg}`);

// --- Post-sync: copy updated src/ CHANGELOG back to root, then back to src/ ---
copyFile(SRC_CL, ROOT_CL);
copyFile(ROOT_CL, SRC_CL);
