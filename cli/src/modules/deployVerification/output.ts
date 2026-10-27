import { toProjectRelativePath } from "../../utils/files";
import { dim, green, red } from "../../utils/terminal";
import type { DeployPlan } from "../deployPlan/types";
import type { DeployExecutionResult } from "../deployExecution/types";
import type { DiamondDeployment } from "../lockFile/types";

/**
 * Prints a verification failure report with the captured addresses.
 *
 * @param plan - The resolved deployment plan.
 * @param execution - The normalized execution result.
 * @param error - The underlying verification error.
 */
export function showVerificationFailure(
  plan: DeployPlan,
  execution: DeployExecutionResult,
  error: unknown,
): void {
  console.error();
  console.error(red("On-chain verification failed; compose.lock was not changed."));
  console.error(`  Diamond: ${execution.diamond}`);
  console.error("  Result facets:");
  for (const [name, address] of Object.entries(execution.facets)) {
    console.error(`    - ${name}: ${address}`);
  }
  console.error(`  ${error instanceof Error ? error.message : String(error)}`);
  console.error(dim("Inspect the addresses above on the chain, then retry or use --redeploy."));
  console.error();
}

/**
 * Prints the successful deployment summary and the lock record location
 * (relative to the project root).
 *
 * @param plan - The resolved deployment plan.
 * @param record - The verified lock record.
 * @param lockPath - Absolute path of the written compose.lock.
 */
export function showDeploySuccess(
  plan: DeployPlan,
  record: DiamondDeployment,
  lockPath: string,
): void {
  console.log();
  console.log(
    `${green("Deployed")} '${plan.diamondName}' on ${plan.chain.chainKey} (instance '${plan.instance}').`,
  );
  console.log(`  Diamond: ${record.diamond}`);
  if (record.deployer) console.log(`  Deployer: ${record.deployer}`);
  console.log(`  Facets:  ${Object.keys(record.facets).length}`);
  console.log(`  Tx:      ${record.txHash}`);
  console.log(`  Lock:    ${toProjectRelativePath(plan.projectRoot, lockPath)}`);
  console.log();
}
