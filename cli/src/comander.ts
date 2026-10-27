import { Command } from "commander";
import { VERSION } from "./utils/metadata";
import { formatCommandArgs } from "./utils/redaction";

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
    .option("--no-install-deps", "Skip dependency installation (Foundry only; Hardhat 3 init installs its template)")
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
    .command("account")
    .description("Set up, check, list, or remove non-secret deployment account aliases")
    .argument("<action>", "setup, check, list, or remove")
    .argument("[name]", "Account alias")
    .option("--address <address>", "Public address for the account")
    .option("--foundry-account <name>", "Existing Foundry keystore account name")
    .option("--chain <chain-key>", "Set this account as the chain's default signer")
    .option("--rpc-url <url>", "RPC endpoint override for account verification")
    .option("--project-root <dir>", "Compose project directory");

  program
    .command("deploy")
    .description("Deploy a diamond from compose.json and record it in compose.lock")
    .option("--diamond <name>", "Diamond name from compose.json")
    .option("--chain <chain-key>", "Chain key from compose.json", "local")
    .option("--account <alias>", "Compose account alias to use for deployment")
    .option("--instance <name>", "Deployment instance name", "default")
    .option("--project-root <dir>", "Compose project directory")
    .option("--broadcast", "Run the managed deploy script without asking")
    .option("--dry-run", "Print the plan and generated script without writing or deploying")
    .option("--redeploy", "Abandon the existing lock record and deploy fresh");

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
    .command("test")
    .description("Run the project's test suite through its framework")
    .option("--project-root <dir>", "Start searching for the project from this directory")

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
 * Everything from the first `--` (at or after the command) onward is
 * passthrough: it is split off before commander parses, so unknown options
 * before the separator are still rejected, and the tail is forwarded to the
 * framework by `compose deploy`.
 *
 * @param argv - The raw process.argv array (e.g. ["node", "cli.ts", "init", "--yes"])
 * @returns The parsed command name and flags object ready for ctx.param.
 */
export function parseArgs(argv: string[]): { command: string; flags: Record<string, unknown> } {
  const separatorIndex = argv.indexOf("--", 2);
  const cliArgv = separatorIndex === -1 ? argv : argv.slice(0, separatorIndex);
  const passthrough = separatorIndex === -1 ? [] : argv.slice(separatorIndex + 1);

  const program = buildProgram();
  program.parse(cliArgv);

  const invokedCommand = program.args[0] ?? "";
  const commandInstance = program.commands.find(
    (candidate) => candidate.name() === invokedCommand || candidate.aliases().includes(invokedCommand),
  );

  if (!commandInstance) {
    if (passthrough.length > 0) {
      throw new Error(
        `Unexpected arguments after '--': ${formatCommandArgs(passthrough)}. Only 'compose deploy' and 'compose test' accept passthrough arguments.`,
      );
    }
    return { command: invokedCommand, flags: {} };
  }

  const command = commandInstance.name();

  const opts = commandInstance.opts();
  const flags: Record<string, unknown> = { ...opts };

  if (flags.out !== undefined) {
    flags.outDir = flags.out;
    delete flags.out;
  }

  if (passthrough.length > 0) {
    if (command !== "deploy" && command !== "test") {
      throw new Error(
        `Unexpected arguments after '--': ${formatCommandArgs(passthrough)}. Only 'compose deploy' and 'compose test' accept passthrough arguments.`,
      );
    }
    flags.passthrough = passthrough;
  }

  const positionalArgs = commandInstance.args.filter((arg): arg is string => typeof arg === "string");
  if (command === "account") {
    if (positionalArgs[0]) flags.action = positionalArgs[0];
    if (positionalArgs[1]) flags.accountName = positionalArgs[1];
  } else if (command === "install" || command === "remove") {
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
