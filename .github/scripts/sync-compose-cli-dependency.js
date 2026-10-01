const fs = require('node:fs');
const path = require('node:path');

const LIBRARY_NAME = '@perfect-abstractions/compose';

function readPackage(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function syncDependency(root, publishedVersion) {
  const library = readPackage(path.join(root, 'src', 'package.json'));
  if (library.name !== LIBRARY_NAME || library.version !== publishedVersion) {
    throw new Error(`Published Compose version ${publishedVersion} does not match src/package.json`);
  }

  const cliPath = path.join(root, 'cli', 'package.json');
  const cli = readPackage(cliPath);
  if (cli.dependencies?.[LIBRARY_NAME] === publishedVersion) return false;

  cli.dependencies[LIBRARY_NAME] = publishedVersion;
  fs.writeFileSync(cliPath, `${JSON.stringify(cli, null, 2)}\n`);

  const suffix = publishedVersion.replace(/[^a-zA-Z0-9-]/g, '-');
  const changesetPath = path.join(root, '.changeset', `compose-cli-dependency-${suffix}.md`);
  fs.writeFileSync(changesetPath,
    `---\n"@perfect-abstractions/compose-cli": patch\n---\n\nUpdate the Compose library dependency to ${publishedVersion}.\n`);
  return true;
}

function main() {
  const publishedVersion = process.argv[2];
  if (!publishedVersion) throw new Error('Published Compose version is required');
  const changed = syncDependency(process.cwd(), publishedVersion);
  console.log(changed ? `CLI dependency updated to ${publishedVersion}` : 'CLI dependency is already current');
  if (process.env.GITHUB_OUTPUT) {
    fs.appendFileSync(process.env.GITHUB_OUTPUT, `changed=${changed}\n`);
  }
}

if (require.main === module) main();

module.exports = { syncDependency };
