import { Command } from "commander";
import { VERSION } from "./utils/metadata";

/**
 * Defines the CLI program with per-command flags.
 *
 * Commander handles argument parsing, unknown flag rejection,
 * auto-generated --help per command, and --version.
 */
export function buildProgram(): Command {
  const program = new Command()
    .name("compose")
    .version(VERSION)
    .description("Multi-Facets Diamond project toolkit powered by Compose")
    .allowUnknownOption(false);

  program
    .command("init")
    .description("Scaffold a new Compose diamond project")
    .argument("[project-name]", "Project name")
    .option("--framework <foundry|hardhat>", "Framework to use", "foundry")
    .option("--base <base-id>", "Base preset (e.g. erc-20, counter)")
    .option("--libraries <facets>", "Comma-separated library facets")
    .option("--extensions <facets>", "Comma-separated extension facets")
    .option("--ownership <base>", "Ownership access base")
    .option("--ownership-extensions <facets>", "Ownership extension facets")
    .option("--access-control <bases>", "Comma-separated access control bases")
    .option("--access-control-extensions <facets>", "Access control extension facets")
    .option("--out <dir>", "Output directory")
    .option("--yes", "Non-interactive mode (requires --base)")
    .option("--install-deps", "Install dependencies (default)")
    .option("--no-install-deps", "Skip dependency installation")
    .option("--toolbox <ethers|viem>", "Hardhat toolbox", "ethers");

  program
    .command("validate")
    .description("Validate your project (Coming Soon...)")

  program
    .command("info")
    .description("Display a summary of the local project")

  program
    .command("catalog")
    .description("List all available bases in the Compose Catalog")

  return program;
}

/**
 * Parses CLI arguments using commander and returns a structured result.
 *
 * @param argv - The raw process.argv array (e.g. ["node", "cli.ts", "init", "--yes"])
 * @returns The parsed command name and flags object ready for ctx.param.
 */
export function parseArgs(argv: string[]): { command: string; flags: Record<string, unknown> } {
  const program = buildProgram();
  program.parse(argv);

  const command = program.args[0] ?? "";
  const commandInstance = program.commands.find((c) => c.name() === command);

  if (!commandInstance) {
    return { command, flags: {} };
  }

  const opts = commandInstance.opts();
  const flags: Record<string, unknown> = { ...opts };

  // Map the first positional argument to projectName if --name wasn't passed
  const positionalArgs = commandInstance.args.filter(
    (arg): arg is string => typeof arg === "string" && arg !== command,
  );
  if (positionalArgs.length > 0 && !flags.projectName) {
    flags.projectName = positionalArgs[0];
  }

  return { command, flags };
}
