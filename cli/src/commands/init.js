const fs = require("fs-extra");
const path = require("node:path");
const { askInitPrompts } = require("../prompts/initPrompts");
const { logger } = require("../utils/logger");
const { COMPOSE_DOCS_URL, COMPOSE_REPO_URL } = require("../config/constants");
const { loadTemplateConfig, pickVariant, resolveTemplatePath } = require("../scaffold/utils/templateLoader");
const { scaffold } = require("../scaffold/scaffold");
const { COMPOSE_HEADER } = require("../utils/composeAsciiHeader");

function normalizeInitOptions(argv) {
  const options = {
    projectName: argv.name || "",
    template: argv.template || "",
    framework: argv.framework || "",
    language: argv.language,
    hardhatProjectType: argv.hardhatProjectType,
    installDeps: argv["install-deps"],
    yes: Boolean(argv.yes),
  };

  return options;
}

async function ensureBinaryExists(binaryName) {
  const hasPath = process.env.PATH || "";
  const separator = process.platform === "win32" ? ";" : ":";
  const paths = hasPath.split(separator);
  const extensions = process.platform === "win32" ? [".exe", ".cmd", ".bat", ""] : [""];

  for (const currentPath of paths) {
    for (const extension of extensions) {
      const candidate = path.join(currentPath, `${binaryName}${extension}`);
      if (await fs.pathExists(candidate)) {
        return true;
      }
    }
  }

  return false;
}

async function preflightChecks(options) {
  if (options.framework === "foundry") {
    const forgeExists = await ensureBinaryExists("forge");
    if (!forgeExists) {
      throw new Error(
        "forge not found in PATH. Please install Foundry and try again.",
      );
    }
  }

  if (options.framework === "hardhat" && options.installDeps !== false) {
    const npmExists = await ensureBinaryExists("npm");
    if (!npmExists) {
      throw new Error("npm not found in PATH. Please install Node.js (with npm) and try again.");
    }
  }
}

async function collectInitOptions(argv) {
  const normalized = normalizeInitOptions(argv);

  if (normalized.yes) {
    if (!normalized.projectName) {
      normalized.projectName = "my-diamond";
    }
    if (typeof normalized.installDeps !== "boolean") {
      normalized.installDeps = true;
    }
    return normalized;
  }

  const answers = await askInitPrompts({
    name: normalized.projectName || undefined,
    template: normalized.template || undefined,
    framework: normalized.framework || undefined,
    hardhatProjectType: normalized.hardhatProjectType,
    installDeps: normalized.installDeps,
  });

  const framework = answers.framework || normalized.framework;
  const language =
    normalized.language || (framework === "hardhat" ? "typescript" : normalized.language);

  return {
    ...normalized,
    projectName: answers.name || normalized.projectName || "my-diamond",
    template: answers.template || normalized.template,
    framework,
    language,
    hardhatProjectType: answers.hardhatProjectType || normalized.hardhatProjectType,
    installDeps: typeof answers.installDeps === "boolean" ? answers.installDeps : true,
  };
}

function printInitHeader() {
  logger.info(COMPOSE_HEADER);
  logger.info("Scaffold your diamond smart contracts project with Compose");
  logger.info(`Explore our library: ${COMPOSE_DOCS_URL}\n`);
}

async function runInitCommand(argv) {
  printInitHeader();
  const initOptions = await collectInitOptions(argv);
  await preflightChecks(initOptions);

  const templateConfig = await loadTemplateConfig();
  const selectedVariant = pickVariant(templateConfig, {
    template: initOptions.template,
    framework: initOptions.framework,
    language: initOptions.language,
    projectType: initOptions.hardhatProjectType,
  });

  const templatePath = resolveTemplatePath(selectedVariant);


  const { projectDir, displayName, nextSteps } = await scaffold({
    projectName: initOptions.projectName,
    templatePath,
    options: {
      framework: selectedVariant.framework,
      language: selectedVariant.language,
      hardhatProjectType: initOptions.hardhatProjectType || selectedVariant.projectType,
      installDeps: initOptions.installDeps,
    },
  });

  logger.success(`\nProject "${displayName}" scaffolded in "${projectDir}"`);
  logger.plain("Next steps:");
  let stepCount = 1;
  if (path.resolve(projectDir) !== process.cwd()) {
    logger.plain(`${stepCount}. cd ${displayName}`);
  }
  for (const step of nextSteps) {
    logger.plain(`${stepCount}. ${step}`);
    stepCount++;
  }

  logger.plain("");
  logger.info("You're all set. We hope you'll Compose something great!\n");
  logger.warn(`If this helped you, please give us a star on GitHub:\n${COMPOSE_REPO_URL}\n`);
}

module.exports = {
  runInitCommand,
  normalizeInitOptions,
};
