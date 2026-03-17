const fs = require("fs-extra");
const path = require("node:path");

async function assertTargetDoesNotExist(projectDir) {
  const exists = await fs.pathExists(projectDir);
  if (exists) {
    throw new Error(`Target directory already exists: ${projectDir}`);
  }
}

async function copyTemplate(templateDir, projectDir) {
  await fs.copy(templateDir, projectDir);
}

async function readJson(filePath) {
  return fs.readJson(filePath);
}

async function writeJson(filePath, data) {
  await fs.writeJson(filePath, data, { spaces: 2 });
}

async function appendLineIfMissing(filePath, line) {
  const exists = await fs.pathExists(filePath);
  if (!exists) {
    await fs.outputFile(filePath, `${line}\n`);
    return;
  }

  const content = await fs.readFile(filePath, "utf8");
  if (!content.includes(line)) {
    await fs.writeFile(filePath, `${content.trimEnd()}\n${line}\n`);
  }
}

async function assertDirectoryEmpty(projectDir) {
  const entries = await fs.readdir(projectDir);
  const ignoredEntries = [".git"];
  const nonIgnored = entries.filter((entry) => !ignoredEntries.includes(entry));
  if (nonIgnored.length > 0) {
    throw new Error(`Target directory is not empty: ${projectDir}`);
  }
}

function resolveProjectDir(projectName) {
  return path.join(process.cwd(), projectName);
}

function getProjectDisplayName(projectName, projectDir) {
  if (projectName === ".") {
    return path.basename(projectDir);
  }
  return projectName;
}

function getTemplateDisplayName(templatePath) {
  const templatesRoot = path.join(__dirname, "..", "..", "templates");
  let templateName = path.relative(templatesRoot, templatePath).replace(/\\/g, "/");
  if (templateName.startsWith("..")) {
    templateName = path.basename(templatePath);
  }
  return templateName;
}

module.exports = {
  assertTargetDoesNotExist,
  assertDirectoryEmpty,
  copyTemplate,
  readJson,
  writeJson,
  appendLineIfMissing,
  resolveProjectDir,
  getProjectDisplayName,
  getTemplateDisplayName,
};
