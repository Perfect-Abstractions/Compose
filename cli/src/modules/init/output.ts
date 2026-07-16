import { ComposeContext } from "../../context/types";
import { cyan, dim, green, yellow } from "../../utils/terminal";
import { COMPOSE_HEADER, COMPOSE_DOCS_URL } from "../../utils/metadata";

/**
 * Prints the Compose welcome banner and documentation URL.
 */
export function showComposeHeader(): void {
  console.log(cyan(COMPOSE_HEADER));
  console.log(cyan("Scaffold your diamond smart contracts project with Compose"));
  console.log(cyan(`Explore our library: ${COMPOSE_DOCS_URL}\n`));
}

/**
 * Displays a dimmed list of dependencies that will be installed.
 *
 * @param deps - Array of dependency objects with name and version.
 * @param packageType - Label for the package type (e.g. "npm packages", "forge packages").
 */
export function showDependencies(deps: { name: string; version: string }[], packageType: string): void {
  console.log(dim(`\nThe following ${packageType} will be installed:\n`));
  for (const dep of deps) {
    console.log(dim(`  ${dep.name}  ${dep.version}`));
  }
  console.log("");
}

/**
 * Prints the success message with framework-specific next steps.
 *
 * Displays the project name, scaffolded path, and a numbered list of
 * next-step commands (e.g. `forge build && forge test` for Foundry,
 * `npx hardhat compile && npx hardhat test` for Hardhat). Adjusts steps
 * based on whether `installDeps` is enabled.
 *
 * @param ctx - The compose context with `param.projectName`, `param.projectRoot`, and `param.framework`.
 */
export function showSuccess(ctx: ComposeContext): void {
  const projectName = String(ctx.param.projectName ?? "my-diamond");
  const projectRoot = String(ctx.param.projectRoot ?? "");

  console.log(green(`\n✔`) + ` Project "${projectName}" scaffolded in "${projectRoot}"\n`);
  console.log(green("Next steps:"));

  let stepCount = 1;
  if (projectRoot !== process.cwd()) {
    console.log(green(`${stepCount}.`) + ` cd ${projectName}`);
    stepCount++;
  }

  const framework = String(ctx.param.framework ?? "foundry");
  if (framework === "foundry") {
    const installDeps = ctx.param.installDeps !== false;
    if (installDeps) {
      console.log(green(`${stepCount}.`) + ` forge build && forge test`);
    } else {
      console.log(green(`${stepCount}.`) + ` forge install Perfect-Abstractions/Compose`);
      console.log(green(`${stepCount + 1}.`) + ` forge build && forge test`);
    }
  } else if (framework === "hardhat") {
    const installDeps = ctx.param.installDeps !== false;
    if (installDeps) {
      console.log(green(`${stepCount}.`) + ` npx hardhat compile && npx hardhat test`);
    } else {
      console.log(green(`${stepCount}.`) + ` npm install`);
      console.log(green(`${stepCount + 1}.`) + ` npx hardhat compile && npx hardhat test`);
    }
  }

  console.log("");
  console.log(green("You're all set. We hope you'll Compose something great!\n"));
  console.log(yellow(`If this helped you, please give us a star on GitHub\n`) + `✨ https://github.com/Perfect-Abstractions/Compose ✨\n`);
  console.log(`Please report any issues or feedback:\nhttps://github.com/Perfect-Abstractions/Compose/issues\n`);
}
