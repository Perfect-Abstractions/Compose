import { ComposeContext } from "../../context/types";
import { BasesCatalog } from "../config/types";
import { cyan, dim, green, red, yellow } from "../../utils/terminal";
import { COMPOSE_HEADER, COMPOSE_DOCS_URL } from "../../utils/metadata";
import {
  getFacetScanState,
  getSelectorExportValidationState,
  getSelectorCollisionValidationState,
  getIdentifierCollisionValidationState,
} from "../validation/module";
import { FacetScanWarning } from "../validation/types";

/**
 * Terminal UI module for CLI output formatting.
 *
 * Provides methods for rendering the welcome header, help text, validation
 * reports, success messages, and validation output. All output is colorized
 * using the terminal utility helpers.
 */
export const TerminalOutputModule = {
  /**
   * Prints the Compose welcome banner and documentation URL.
   */
  showComposeHeader() {
    console.log(cyan(COMPOSE_HEADER));
    console.log(cyan("Scaffold your diamond smart contracts project with Compose"));
    console.log(cyan(`Explore our library: ${COMPOSE_DOCS_URL}\n`));
  },

  /**
   * Displays a dimmed list of dependencies that will be installed.
   *
   * @param deps - Array of dependency objects with name and version.
   * @param packageType - Label for the package type (e.g. "npm packages", "forge packages").
   */
  showDependencies(deps: { name: string; version: string }[], packageType: string): void {
    console.log(dim(`\nThe following ${packageType} will be installed:\n`));
    for (const dep of deps) {
      console.log(dim(`  ${dep.name}  ${dep.version}`));
    }
    console.log("");
  },



  /**
   * Renders validation warnings and fail-fast error reports.
   *
   * Displays facet scan warnings (yellow), then checks for selector export
   * issues, selector collisions, and identifier collisions in order. Each
   * failure is printed in red with details and the method returns early.
   *
   * @param ctx - The compose context with validation state populated.
   * @returns The context unchanged.
   */
  async showReport(ctx: ComposeContext): Promise<ComposeContext> {
    const facetScan = getFacetScanState(ctx);
    const scanWarnings = (facetScan?.result?.facets ?? [])
      .map((facet: FacetScanWarning) => facet)
      .filter((facet: FacetScanWarning) => facet.warnings.length > 0);

    if (scanWarnings.length > 0) {
      console.warn(yellow("\nValidation warnings"));
      for (const facet of scanWarnings) {
        console.warn(`\n${facet.facetName}`);
        console.warn(`  ${facet.path}`);
        for (const warning of facet.warnings) {
          console.warn(`  ${warning}`);
        }
      }
    }

    const selectorExportValidation = getSelectorExportValidationState(ctx);

    if (selectorExportValidation && !selectorExportValidation.success) {
      console.error(red("\nValidation failed"));
      console.error(red(selectorExportValidation.error?.message ?? "Validation failed."));

      for (const issue of selectorExportValidation.result?.issues ?? []) {
        console.error(`\n${issue.facetName}`);
        console.error(`  ${issue.path}`);

        if (issue.missingExports.length > 0) {
          console.error(`  Missing exports: ${issue.missingExports.join(", ")}`);
        }

        if (issue.extraExports.length > 0) {
          console.error(`  Extra exports: ${issue.extraExports.join(", ")}`);
        }
      }

      return ctx;
    }

    const selectorCollisionValidation = getSelectorCollisionValidationState(ctx);

    if (selectorCollisionValidation && !selectorCollisionValidation.success) {
      console.error(red("\nValidation failed"));
      console.error(red(selectorCollisionValidation.error?.message ?? "Validation failed."));

      for (const collision of selectorCollisionValidation.result?.collisions ?? []) {
        console.error(`\n${collision.selector}`);
        for (const owner of collision.owners) {
          console.error(`  ${owner.facetName}: ${owner.signature}`);
          console.error(`    ${owner.path}`);
        }
      }

      return ctx;
    }

    const identifierCollisionValidation = getIdentifierCollisionValidationState(ctx);

    if (identifierCollisionValidation && !identifierCollisionValidation.success) {
      console.error(red("\nValidation failed"));
      console.error(red(identifierCollisionValidation.error?.message ?? "Validation failed."));

      for (const collision of identifierCollisionValidation.result?.collisions ?? []) {
        console.error(`\n${collision.identifier}`);
        for (const owner of collision.owners) {
          console.error(`  ${owner.facetName}: [${owner.layout.join(", ")}]`);
          console.error(`    ${owner.path}`);
        }
      }
    }

    return ctx;
  },

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
  showSuccess(ctx: ComposeContext): void {
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
  },

  /**
   * Displays available Compose bases with their required and optional facets.
   *
   * Reads the bases catalog from `ctx.config.bases` and prints each feature
   * with its label, required facets, and optional facets.
   *
   * @param ctx - The compose context with the loaded bases catalog.
   */
  showTemplates(ctx: ComposeContext): void {
    const catalog = ctx.config.bases as BasesCatalog;
    const features = catalog.features;

    console.log("\nAvailable Compose bases:\n");

    Object.entries(features).forEach(([key, definition]) => {
      console.log(`${definition.label} (${key})`);
      console.log(`  Required: ${Object.keys(definition.required).join(", ") || "(none)"}`);
      if (Object.keys(definition.optional).length > 0) {
        console.log(`  Optional: ${Object.keys(definition.optional).join(", ")}`);
      }
      console.log("");
    });

    console.log("\nTo select a base for your project, use --base <base-id>\n");
  },
};