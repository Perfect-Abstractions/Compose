const fs = require("fs-extra");
const path = require("path");
const { copyTemplate, getTemplateDisplayName } = require("../utils/fileManager");
const { runCommand } = require("../../utils/exec");
const { logger } = require("../../utils/logger");
const { COMPOSE_FOUNDRY_DEP } = require("../../config/constants");

async function scaffoldFoundry(projectName, templatePath, projectDir, options) {
  const shouldInstallDeps = Boolean(options.installDeps);

  logger.info(`Scaffolding Foundry project in "${projectDir}"…`);

  await fs.ensureDir(projectDir);

  await runCommand("forge", ["init", "."], { cwd: projectDir });

  if (shouldInstallDeps) {
    logger.info("Installing Compose dependencies with forge…");
    await runCommand("forge", ["install", COMPOSE_FOUNDRY_DEP], { cwd: projectDir });
  } else {
    logger.info("Skipping dependency installation... ");
  }

  // Remove default Forge starter contracts/scripts/tests for replacement with our template.
  await Promise.all([
    fs.remove(path.join(projectDir, "src")),
    fs.remove(path.join(projectDir, "test")),
    fs.remove(path.join(projectDir, "script")),
  ]);

  const templateName = getTemplateDisplayName(templatePath);
  logger.info(`Applying template "${templateName}"`);

  await copyTemplate(templatePath, projectDir);

  const nextSteps = shouldInstallDeps
    ? ["forge build && forge test"]
    : [`forge install ${COMPOSE_FOUNDRY_DEP}`, "forge build && forge test"];

  return { nextSteps };
}

module.exports = {
  scaffoldFoundry,
};

