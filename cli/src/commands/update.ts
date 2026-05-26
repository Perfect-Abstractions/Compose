import { runCommand } from "../utils/exec.js";
import { logger } from "../utils/logger.js";

export async function runUpdateCommand(packageName: string): Promise<void> {
  logger.info("Updating CLI to latest...");
  await runCommand("npm", ["install", "-g", `${packageName}@latest`], {
    cwd: process.cwd(),
  });
  logger.success("Update complete.");
}
