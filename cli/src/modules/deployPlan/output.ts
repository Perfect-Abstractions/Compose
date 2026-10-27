import { dim, green, yellow } from "../../utils/terminal";
import { safeRpcEndpoint } from "../../adapters/IRPCAdapter/utils";
import type { DeployPlan } from "./types";

/**
 * Prints the fresh/redeploy plan summary.
 *
 * @param plan - The resolved deployment plan.
 */
export function showDeployPlan(plan: DeployPlan): void {
  console.log();
  console.log(`${green("Deploy plan")} ${dim(`(${plan.mode === "redeploy" ? "redeploy" : "fresh"})`)}`);
  console.log(`  Diamond:  ${plan.diamondName} (${plan.diamond.contractName})`);
  const rpcEndpoint = safeRpcEndpoint(plan.chain.rpcUrl) ?? "[invalid endpoint]";
  const rpcSource = plan.rpcUrlOverridden ? "CLI override" : "compose.json";
  console.log(`  Chain:    ${plan.chain.chainKey} (chain id ${plan.chain.chainId})`);
  console.log(`  RPC:      ${rpcEndpoint} (${rpcSource}; credentials and path redacted)`);
  console.log(plan.account
    ? `  Signer:   ${plan.account.alias} (${plan.account.address})`
    : "  Signer:   framework default");
  console.log(`  Instance: ${plan.instance}`);
  console.log(`  Facets (${plan.facets.length}):`);
  for (const facet of plan.facets) {
    console.log(`    - ${facet.name} ${dim(`(${facet.importSpec})`)}`);
  }
  console.log(
    `  Upgradeability: ${plan.upgradeable ? "upgradeable (DiamondUpgradeFacet present)" : "immutable (no upgrade facet)"}`,
  );
  if (plan.mode === "redeploy" && plan.existing) {
    console.log(
      yellow(`  Redeploy: the lock record at ${plan.existing.diamond} will be abandoned and replaced.`),
    );
  }
  console.log(dim(`  Plan hash: ${plan.planHash}`));
  console.log();
}

/**
 * Prints the in-sync summary when nothing needs to happen.
 *
 * @param plan - The resolved deployment plan with mode `in-sync`.
 */
export function showInSync(plan: DeployPlan): void {
  console.log(
    `${green("In sync")}: '${plan.diamondName}' on ${plan.chain.chainKey} (instance '${plan.instance}') matches compose.json.`,
  );
  if (plan.existing) {
    console.log(dim(`  Diamond: ${plan.existing.diamond} (${Object.keys(plan.existing.facets).length} facets)`));
  }
  console.log(dim("Nothing to do. Use --redeploy to replace the deployment with a fresh one."));
}

/**
 * Prints the composition diff and stops.
 *
 * Applying upgrades is a separate milestone; until then `compose deploy`
 * reports drift and exits non-zero so CI catches it.
 *
 * @param plan - The resolved deployment plan with mode `diff`.
 */
export function showDiffStopped(plan: DeployPlan): void {
  console.log();
  console.log(
    `The deployment of '${plan.diamondName}' on ${plan.chain.chainKey} (instance '${plan.instance}') differs from compose.json:`,
  );
  if (plan.existing) {
    console.log(dim(`  On-chain diamond: ${plan.existing.diamond}`));
  }
  if (plan.diff?.added.length) {
    console.log(`  Facets to add:    ${plan.diff.added.join(", ")}`);
  }
  if (plan.diff?.removed.length) {
    console.log(`  Facets to remove: ${plan.diff.removed.join(", ")}`);
  }
  console.log();
  console.log("Nothing was changed. Use --redeploy to abandon this deployment and deploy fresh,");
  console.log("or restore compose.json to match the recorded deployment.");
  console.log();
}
