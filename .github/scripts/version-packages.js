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
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const ROOT_CL = path.join(ROOT, 'CHANGELOG.md');
const SRC_CL = path.join(ROOT, 'src', 'CHANGELOG.md');

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
const ignorePkg = ignoreIdx !== -1 ? process.argv[ignoreIdx + 1] : null;

if (ignorePkg) {
  console.log(`Selective release: ignoring ${ignorePkg}`);
}

// --- Pre-sync: copy root CHANGELOG into src/ so changeset version reads the latest ---
copyFile(ROOT_CL, SRC_CL);

// --- Run changeset version ---
const versionCmd = ignorePkg
  ? `npx changeset version --ignore ${ignorePkg}`
  : 'npx changeset version';

execOrDie(versionCmd);

// --- Post-sync: copy updated src/ CHANGELOG back to root, then back to src/ ---
// This mirrors the original shell one-liner behavior:
//   cp src/CHANGELOG.md CHANGELOG.md; cp CHANGELOG.md src/CHANGELOG.md
copyFile(SRC_CL, ROOT_CL);
copyFile(ROOT_CL, SRC_CL);
