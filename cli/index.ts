#!/usr/bin/env node

import { Command } from "commander";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const require = createRequire(import.meta.url);

const pkg = require(resolve(__dirname, "package.json")) as {
  version: string;
  name: string;
};

import { runInitCommand } from "./src/commands/init.js";
import { runUpdateCommand } from "./src/commands/update.js";
import { runListTemplatesCommand } from "./src/commands/listTemplates.js";

const program = new Command();

program
  .name("compose")
  .description(
    "CLI for building, deploying, and managing diamond smart contracts",
  )
  .version(pkg.version, "-v, --version", "Print CLI version");

program
  .command("init")
  .description("Scaffold a new Compose diamond project")
  .option("-n, --name <name>", "Project name")
  .option("--template <id>", "Template ID")
  .option("--framework <framework>", "Project framework (foundry | hardhat)")
  .option(
    "--language <language>",
    "Project language (javascript | typescript)",
  )
  .option("--hardhat-project-type <type>", "Hardhat project type")
  .option("--install-deps", "Install dependencies")
  .option("--no-install-deps", "Skip dependency installation")
  .option("-y, --yes", "Skip prompts and use defaults")
  .action(async (options) => {
    await runInitCommand(options);
  });

program
  .command("templates")
  .description("List available templates")
  .action(async () => {
    await runListTemplatesCommand();
  });

program
  .command("update")
  .description("Update the CLI to the latest version")
  .action(async () => {
    await runUpdateCommand(pkg.name);
  });

export async function main(): Promise<void> {
  await program.parseAsync(process.argv);
}
