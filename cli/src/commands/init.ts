import fs from "fs-extra";
import path from "node:path";
import { askInitPrompts } from "../prompts/initPrompts.js";
import { logger } from "../utils/logger.js";
import {
  COMPOSE_DOCS_URL,
  COMPOSE_REPO_URL,
} from "../config/constants.js";
import {
  loadTemplateConfig,
  pickVariant,
  resolveTemplatePath,
} from "../scaffold/utils/templateLoader.js";
import { scaffold } from "../scaffold/scaffold.js";
import { COMPOSE_HEADER } from "../utils/composeAsciiHeader.js";

type InitOptions = {
  projectName: string;
  template: string;
  framework: string;
  language?: string;
  hardhatProjectType?: string;
  installDeps?: boolean;
  yes: boolean;
};

export function normalizeInitOptions(argv: Record<string, unknown>): InitOptions {
  const options: InitOptions = {
    projectName: (argv.name as string) || "",
    template: (argv.template as string) || "",
    framework: (argv.framework as string) || "",
    language: argv.language as string | undefined,
    hardhatProjectType: argv.hardhatProjectType as string | undefined,
    installDeps: (argv.installDeps ?? argv["install-deps"]) as boolean | undefined,
    yes: Boolean(argv.yes),
  };

  return options;
}

async function ensureBinaryExists(binaryName: string): Promise<boolean> {
  const hasPath = process.env.PATH || "";
  const separator = process.platform === "win32" ? ";" : ":";
  const paths = hasPath.split(separator);
  const extensions =
    process.platform === "win32" ? [".exe", ".cmd", ".bat", ""] : [""];

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

async function preflightChecks(options: InitOptions): Promise<void> {
  if (options.framework === "foundry") {
    const forgeExists = await ensureBinaryExists("forge");
    if (!forgeExists) {
      throw new Error(
        "forge not found in PATH. Please install Foundry and try again."
      );
    }
  }

  if (options.framework === "hardhat" && options.installDeps !== false) {
    const npmExists = await ensureBinaryExists("npm");
    if (!npmExists) {
      throw new Error(
        "npm not found in PATH. Please install Node.js (with npm) and try again."
      );
    }
  }
}

async function collectInitOptions(
  argv: Record<string, unknown>
): Promise<InitOptions> {
  const normalized = normalizeInitOptions(argv);

  if (normalized.yes) {
    if (!normalized.projectName) {
      normalized.projectName = "my-diamond";
    }
    if (!normalized.template) {
      normalized.template = "default";
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
    normalized.language ||
    (framework === "hardhat" ? "typescript" : normalized.language);

  return {
    ...normalized,
    projectName: answers.name || normalized.projectName || "my-diamond",
    template: answers.template || normalized.template,
    framework,
    language,
    hardhatProjectType:
      answers.hardhatProjectType || normalized.hardhatProjectType,
    installDeps:
      typeof answers.installDeps === "boolean" ? answers.installDeps : true,
  };
}

function printInitHeader(): void {
  logger.info(COMPOSE_HEADER);
  logger.info("Scaffold your diamond smart contracts project with Compose");
  logger.info(`Explore our library: ${COMPOSE_DOCS_URL}\n`);
}

export async function runInitCommand(
  argv: Record<string, unknown>
): Promise<void> {
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
      hardhatProjectType:
        initOptions.hardhatProjectType || selectedVariant.projectType,
      installDeps: initOptions.installDeps,
    },
  });

  logger.success(`\nProject "${displayName}" scaffolded in "${projectDir}"`);
  logger.plain("Next steps:");
  let stepCount = 1;
  if (path.resolve(projectDir) !== process.cwd()) {
    logger.plain(`${stepCount}. cd ${displayName}`);
    stepCount++;
  }
  for (const step of nextSteps) {
    logger.plain(`${stepCount}. ${step}`);
    stepCount++;
  }

  logger.plain("");
  logger.info("You're all set. We hope you'll Compose something great!\n");
  logger.brightYellow(
    `If this helped you, please give us a star on GitHub:\n✨ ${COMPOSE_REPO_URL} ✨\n`
  );
  logger.warn(
    `Please report any issues or feedback:\n${COMPOSE_REPO_URL}/issues\n`
  );
}
