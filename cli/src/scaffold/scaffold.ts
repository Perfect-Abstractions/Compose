import fs from "fs-extra";
import {
  assertTargetDoesNotExist,
  assertDirectoryEmpty,
  resolveProjectDir,
  getProjectDisplayName,
} from "./utils/fileManager.js";
import { replaceTokensRecursively } from "./utils/tokenReplace.js";
import { scaffoldFoundry } from "./frameworks/foundry.js";
import { scaffoldHardhat } from "./frameworks/hardhat.js";

type ScaffoldOptions = {
  framework: string;
  language?: string;
  hardhatProjectType?: string;
  installDeps?: boolean;
};

type ScaffoldParams = {
  projectName: string;
  templatePath: string;
  options: ScaffoldOptions;
};

type ScaffoldResult = {
  projectDir: string;
  displayName: string;
  nextSteps: string[];
};

export async function scaffold(
  params: ScaffoldParams
): Promise<ScaffoldResult> {
  const { projectName, templatePath, options } = params;
  const projectDir = resolveProjectDir(projectName);
  if (projectName === ".") {
    await assertDirectoryEmpty(projectDir);
  } else {
    await assertTargetDoesNotExist(projectDir);
  }

  const displayName = getProjectDisplayName(projectName, projectDir);

  const templateExists = await fs.pathExists(templatePath);
  if (!templateExists) {
    throw new Error(`Template path does not exist: ${templatePath}`);
  }

  let frameworkResult;
  if (options.framework === "foundry") {
    frameworkResult = await scaffoldFoundry(
      displayName,
      templatePath,
      projectDir,
      options
    );
  } else if (options.framework === "hardhat") {
    frameworkResult = await scaffoldHardhat(
      displayName,
      templatePath,
      projectDir,
      options
    );
  } else {
    throw new Error(`Unknown framework: ${options.framework}`);
  }

  await replaceTokensRecursively(projectDir, {
    "{{projectName}}": displayName,
  });

  return {
    projectDir,
    displayName,
    nextSteps: frameworkResult?.nextSteps || [],
  };
}
