#!/usr/bin/env node

/**
 * Wrapper around `changeset version` that supports --ignore for selective
 * package releases. Also syncs the root CHANGELOG.md with src/CHANGELOG.md
 * before and after versioning (the dual-CHANGELOG pattern).
 *
 * Usage:
 *   node .github/scripts/version-packages.js
 *   node .github/scripts/version-packages.js --ignore @perfect-abstractions/compose-cli
 *   node .github/scripts/version-packages.js --ignore @perfect-abstractions/compose
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

// --- Parse --ignore flag ---
const ignoreIdx = process.argv.indexOf('--ignore');
const selectiveIgnore = ignoreIdx !== -1 ? process.argv[ignoreIdx + 1] : null;

const allIgnore = [...PERMANENT_IGNORE];
if (selectiveIgnore) {
  allIgnore.push(selectiveIgnore);
  console.log(`Selective release: ignoring ${selectiveIgnore}`);
}

// --- Pre-sync: copy root CHANGELOG into src/ so changeset version reads the latest ---
copyFile(ROOT_CL, SRC_CL);

// --- Run changeset version ---
const ignoreArg = allIgnore.length > 0 ? ` --ignore ${allIgnore.join(',')}` : '';
execOrDie(`npx changeset version${ignoreArg}`);

// --- Post-sync: copy updated src/ CHANGELOG back to root, then back to src/ ---
copyFile(SRC_CL, ROOT_CL);
copyFile(ROOT_CL, SRC_CL);
