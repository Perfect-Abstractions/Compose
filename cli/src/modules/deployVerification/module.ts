import type { Hex } from "viem";
import type { ComposeContext } from "../../context/types";
import type { IRPCAdapter } from "../../adapters/IRPCAdapter/interface";
import type { IDiamondAdapter } from "../../adapters/IDiamondAdapter/interface";
import type { IHashingAdapter } from "../../adapters/IHashingAdapter/interface";
import { LockFileModule } from "../lockFile/module";
import type { DiamondDeployment } from "../lockFile/types";
import type { DeployPlan } from "../deployPlan/types";
import type { DeployExecutionResult } from "../deployExecution/types";
import { showVerificationFailure } from "./output";

/**
 * Deploy verification module.
 *
 * Checks the deployed diamond against the chain before anything is
 * recorded in compose.lock: the diamond and every facet must have code, and
 * the diamond registry must expose exactly the reported facet addresses.
 */
export const DeployVerificationModule = {
  /**
   * Verifies a deployment result against chain state and builds the lock record.
   *
   * Stores the record in `ctx.state.deployVerification` on success; records a
   * failure state and prints a report on failure. Failure leaves compose.lock
   * untouched.
   *
   * @param ctx - The compose context.
   * @param plan - The resolved deployment plan.
   * @param execution - The normalized execution result.
   * @param dependencies - RPC, diamond, and hashing adapters.
   * @returns The context with `state.deployVerification` populated.
   */
  async verify(
    ctx: ComposeContext,
    plan: DeployPlan,
    execution: DeployExecutionResult,
    dependencies: { rpc: IRPCAdapter; diamond: IDiamondAdapter; hashing: IHashingAdapter },
  ): Promise<ComposeContext> {
    try {
      const diamondCode = await dependencies.rpc.getCode(execution.diamond);
      if (!diamondCode || diamondCode === "0x") {
        throw new Error(`No contract code found at the diamond address ${execution.diamond}.`);
      }

      for (const [name, address] of Object.entries(execution.facets)) {
        const code = await dependencies.rpc.getCode(address);
        if (!code || code === "0x") {
          throw new Error(`No contract code found at facet '${name}' (${address}).`);
        }
      }

      const onChainAddresses = await dependencies.diamond.facetAddresses(execution.diamond);
      const reported = new Set(Object.values(execution.facets).map((address) => address.toLowerCase()));
      const observed = new Set(onChainAddresses.map((address) => address.toLowerCase()));
      const missing = [...reported].filter((address) => !observed.has(address));
      const unexpected = [...observed].filter((address) => !reported.has(address));
      if (missing.length > 0 || unexpected.length > 0) {
        throw new Error(
          `The on-chain facets do not match the deployment result (missing: ${missing.join(", ") || "none"}; unexpected: ${unexpected.join(", ") || "none"}).`,
        );
      }

      const record: DiamondDeployment = {
        diamond: execution.diamond,
        facets: execution.facets,
        facetHash: LockFileModule.computeFacetHash(
          Object.values(execution.facets) as Hex[],
          dependencies.hashing,
        ),
        lastSync: new Date().toISOString(),
        txHash: execution.transactions.diamond,
      };

      ctx.state.deployVerification = { success: true, result: record, error: null };
    } catch (error) {
      ctx.state.deployVerification = {
        success: false,
        result: null,
        error: {
          code: "DEPLOY_VERIFICATION_FAILED",
          message: error instanceof Error ? error.message : "Verification failed.",
          nativeError: error,
        },
      };
      showVerificationFailure(plan, execution, error);
    }

    return ctx;
  },
};
