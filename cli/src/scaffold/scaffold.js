const fs = require("fs-extra");
const {
  assertTargetDoesNotExist,
  assertDirectoryEmpty,
  resolveProjectDir,
  getProjectDisplayName,
} = require("./utils/fileManager");
const { replaceTokensRecursively } = require("./utils/tokenReplace");
const { scaffoldFoundry } = require("./frameworks/foundry");
const { scaffoldHardhat } = require("./frameworks/hardhat");

async function scaffold({ projectName, templatePath, options }) {
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
    frameworkResult = await scaffoldFoundry(displayName, templatePath, projectDir, options);
  } else if (options.framework === "hardhat") {
    frameworkResult = await scaffoldHardhat(displayName, templatePath, projectDir, options);
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

module.exports = {
  scaffold,
};
