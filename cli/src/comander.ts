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
    .option("--upgradeable", "Include the upgrade facet and owner coupling")
    .option("--immutable", "Deploy without the upgrade facet (default)")
    .option("--out <dir>", "Output directory")
    .option("--yes", "Non-interactive mode (requires --base)")
    .option("--install-deps", "Install dependencies (default)")
    .option("--no-install-deps", "Skip dependency installation")
    .option("--toolbox <ethers|viem>", "Hardhat toolbox", "ethers");

  program
    .command("install")
    .alias("i")
    .description("Register facets in compose.json without deploying them")
    .argument("[facets...]", "Catalog facet names, project contract names, or local path:Contract references")
    .option("--diamond <name>", "Diamond name from compose.json")
    .option("--project-root <dir>", "Compose project directory")
    .option("--manifest <path-or-name>", "Apply an install batch manifest")
    .option("--create-manifest <name>", "Create an install batch manifest without applying it")
    .option("--yes", "Skip confirmation prompts")

  program
    .command("remove")
    .alias("rm")
    .description("Unregister facets from compose.json without changing a deployment")
    .argument("[facets...]", "Facet names or local path:Contract references to unregister")
    .option("--diamond <name>", "Diamond name from compose.json")
    .option("--project-root <dir>", "Compose project directory")
    .option("--manifest <path-or-name>", "Apply a remove batch manifest")
    .option("--create-manifest <name>", "Create a remove batch manifest without applying it")
    .option("--yes", "Skip confirmation prompts");

  program
    .command("validate")
    .description("Validate selectors and virtual storage layouts")
    .option("--project-root <dir>", "Compose project directory")

  program
    .command("info")
    .description("Display a summary of the local project")

  program
    .command("catalog")
    .description("List all available bases in the Compose Catalog")

  program
    .command("build")
    .description("Compile the project if artifacts are stale or missing")

  program
    .command("rpc")
    .description("Check RPC connectivity and optionally inspect contract bytecode")
    .option("--chain <chain-key>", "Chain key from compose.json", "local")
    .option("--address <address>", "Contract address to check or inspect")

  program
    .command("inspect")
    .description("Inspect a deployed diamond's facets and selectors")
    .argument("<address>", "Diamond contract address")
    .option("--chain <chain-key>", "Chain key from compose.json", "local")

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

  const invokedCommand = program.args[0] ?? "";
  const commandInstance = program.commands.find(
    (candidate) => candidate.name() === invokedCommand || candidate.aliases().includes(invokedCommand),
  );

  if (!commandInstance) {
    return { command: invokedCommand, flags: {} };
  }

  const command = commandInstance.name();

  const opts = commandInstance.opts();
  const flags: Record<string, unknown> = { ...opts };

  if (flags.out !== undefined) {
    flags.outDir = flags.out;
    delete flags.out;
  }

  const positionalArgs = commandInstance.args.filter((arg): arg is string => typeof arg === "string");
  if (command === "install" || command === "remove") {
    if (positionalArgs.length > 0) flags.facets = positionalArgs;
  } else if (positionalArgs.length > 0) {
    if (command === "inspect" && !flags.address) {
      flags.address = positionalArgs[0];
    } else if (!flags.projectName) {
      flags.projectName = positionalArgs[0];
    }
  }

  return { command, flags };
}
