const { runCommand } = require("../utils/exec");
const { logger } = require("../utils/logger");

async function runUpdateCommand(packageName) {
  logger.info("Updating CLI to latest...");
  await runCommand("npm", ["install", "-g", `${packageName}@latest`], {
    cwd: process.cwd(),
  });
  logger.success("Update complete.");
}

module.exports = {
  runUpdateCommand,
};
