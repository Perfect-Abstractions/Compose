import type { DeployPlan } from "../deployPlan/types";
import { toProjectRelativePath } from "../../utils/files";
import { dim, green } from "../../utils/terminal";

/** Prints the result of a successful fork simulation. */
export function showDeploySimulationSuccess(
  plan: DeployPlan,
  scriptPath: string,
  forkBlockNumber: bigint,
): void {
  console.log();
  console.log(`${green("Simulation succeeded")} for '${plan.diamondName}' on ${plan.chain.chainKey}.`);
  console.log(`  Fork block: ${forkBlockNumber}`);
  console.log(`  Script:     ${toProjectRelativePath(plan.projectRoot, scriptPath)}`);
  console.log(dim("No transactions were broadcast. compose.lock was not changed."));
  console.log(dim("Review the script, then run 'compose deploy --broadcast' to deploy."));
  console.log();
}
