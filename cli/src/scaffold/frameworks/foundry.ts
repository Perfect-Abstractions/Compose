import fs from "fs-extra";
import path from "node:path";
import {
  copyTemplate,
  getTemplateDisplayName,
} from "../utils/fileManager.js";
import { runCommand } from "../../utils/exec.js";
import { logger } from "../../utils/logger.js";
import { COMPOSE_FOUNDRY_DEP } from "../../config/constants.js";

type ScaffoldOptions = {
  installDeps?: boolean;
};

type ScaffoldResult = {
  nextSteps: string[];
};

export async function scaffoldFoundry(
  projectName: string,
  templatePath: string,
  projectDir: string,
  options: ScaffoldOptions
): Promise<ScaffoldResult> {
  const shouldInstallDeps = Boolean(options.installDeps);

  logger.info(`Scaffolding Foundry project in "${projectDir}"…`);

  await fs.ensureDir(projectDir);

  await runCommand("forge", ["init", "."], { cwd: projectDir });

  if (shouldInstallDeps) {
    logger.info("Installing Compose dependencies with forge…");
    await runCommand("forge", ["install", COMPOSE_FOUNDRY_DEP], {
      cwd: projectDir,
    });
  } else {
    logger.info("Skipping dependency installation... ");
  }

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
