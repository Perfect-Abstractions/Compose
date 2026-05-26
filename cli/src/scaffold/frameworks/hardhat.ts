import fs from "fs-extra";
import path from "node:path";
import {
  copyTemplate,
  readJson,
  writeJson,
} from "../utils/fileManager.js";
import { orderPackageJsonWithDepsBeforeDevDeps } from "../utils/packageOrderer.js";
import { runCommand } from "../../utils/exec.js";
import { logger } from "../../utils/logger.js";
import {
  COMPOSE_NPM_PACKAGE,
  COMPOSE_NPM_VERSION,
} from "../../config/constants.js";

type ScaffoldOptions = {
  installDeps?: boolean;
};

type ScaffoldResult = {
  nextSteps: string[];
};

export async function scaffoldHardhat(
  projectName: string,
  templatePath: string,
  projectDir: string,
  options: ScaffoldOptions
): Promise<ScaffoldResult> {
  await fs.ensureDir(projectDir);
  await copyTemplate(templatePath, projectDir);

  const shouldInstallDeps = Boolean(options.installDeps);

  const packageJsonPath = path.join(projectDir, "package.json");
  const packageJson = (await readJson(packageJsonPath)) as Record<
    string,
    unknown
  > & {
    name?: string;
    type?: string;
    scripts?: Record<string, string>;
    dependencies?: Record<string, string>;
    devDependencies?: Record<string, string>;
  };

  packageJson.name = projectName;
  packageJson.type = "module";

  packageJson.scripts = packageJson.scripts || {};
  packageJson.scripts.build = "npx hardhat compile";
  packageJson.scripts.test = "npx hardhat test";

  packageJson.devDependencies = packageJson.devDependencies || {};

  packageJson.dependencies = packageJson.dependencies || {};
  packageJson.dependencies[COMPOSE_NPM_PACKAGE] = COMPOSE_NPM_VERSION;

  const orderedPackageJson =
    orderPackageJsonWithDepsBeforeDevDeps(packageJson);
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
