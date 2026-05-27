#!/usr/bin/env node

import { readFileSync, existsSync } from "node:fs";
import { Command } from "commander";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __filename = fileURLToPath(import.meta.url);

function findPackageJson(startDir: string): { version: string; name: string } {
  let dir = startDir;
  while (true) {
    const candidate = resolve(dir, "package.json");
    if (existsSync(candidate)) {
      return JSON.parse(readFileSync(candidate, "utf-8"));
    }
    const parent = dirname(dir);
    if (parent === dir) throw new Error("Could not find package.json");
    dir = parent;
  }
}

const pkg = findPackageJson(dirname(__filename));

import { runInitCommand } from "./src/commands/init.ts";
import { runUpdateCommand } from "./src/commands/update.ts";
import { runListTemplatesCommand } from "./src/commands/listTemplates.ts";

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
