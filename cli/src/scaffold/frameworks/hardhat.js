const fs = require("fs-extra");
const path = require("node:path");
const { copyTemplate, readJson, writeJson } = require("../utils/fileManager");
const { orderPackageJsonWithDepsBeforeDevDeps } = require("../utils/packageOrderer");
const { runCommand } = require("../../utils/exec");
const { logger } = require("../../utils/logger");
const { COMPOSE_NPM_PACKAGE, COMPOSE_NPM_VERSION } = require("../../config/constants");

async function scaffoldHardhat(projectName, templatePath, projectDir, options) {
  await fs.ensureDir(projectDir);
  await copyTemplate(templatePath, projectDir);

  const shouldInstallDeps = Boolean(options.installDeps);

  const packageJsonPath = path.join(projectDir, "package.json");
  const packageJson = await readJson(packageJsonPath);

  packageJson.name = projectName;
  packageJson.type = "module";

  packageJson.scripts = packageJson.scripts || {};
  packageJson.scripts.build = "npx hardhat compile";
  packageJson.scripts.test = "npx hardhat test";

  packageJson.devDependencies = packageJson.devDependencies || {};

  packageJson.dependencies = packageJson.dependencies || {};
  packageJson.dependencies[COMPOSE_NPM_PACKAGE] = COMPOSE_NPM_VERSION;

  const orderedPackageJson = orderPackageJsonWithDepsBeforeDevDeps(packageJson);
  await writeJson(packageJsonPath, orderedPackageJson);

  if (shouldInstallDeps) {
    logger.info("Installing project dependencies…");
    await runCommand("npm", ["install"], { cwd: projectDir });
  } else {
    logger.info("Skipping dependency installation (installDeps=false).");
  }

  const nextSteps = shouldInstallDeps
    ? ["npx hardhat compile && npx hardhat test"]
    : ["npm install", "npx hardhat compile && npx hardhat test"];

  return { nextSteps };
}

module.exports = {
  scaffoldHardhat,
};

