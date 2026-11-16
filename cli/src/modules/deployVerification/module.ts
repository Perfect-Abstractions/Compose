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

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

/**
 * Rejects duplicate facet addresses and a facet that reuses the diamond address.
 *
 * @param facets - The reported facet names and addresses.
 * @param diamond - The deployed diamond address.
 */
function assertUniqueFacetAddresses(facets: Record<string, Hex>, diamond: Hex): void {
  const diamondAddress = diamond.toLowerCase();
  const namesByAddress = new Map<string, string>();

  for (const [name, address] of Object.entries(facets)) {
    const normalized = address.toLowerCase();
    if (normalized === diamondAddress) {
      throw new Error(
        `Facet '${name}' uses the diamond address ${address}; facets must be separate contracts.`,
      );
    }

    const existingName = namesByAddress.get(normalized);
    if (existingName) {
      throw new Error(
        `Facets '${existingName}' and '${name}' report the same address ${address}; facet addresses must be unique.`,
      );
    }
    namesByAddress.set(normalized, name);
  }
}

/**
 * Rejects duplicate or diamond-owned entries in the on-chain facet list.
 *
 * @param addresses - The facet addresses reported by the diamond.
 * @param diamond - The deployed diamond address.
 */
function assertValidOnChainFacetList(addresses: readonly Hex[], diamond: Hex): void {
  const diamondAddress = diamond.toLowerCase();
  const seen = new Set<string>();

  for (const address of addresses) {
    const normalized = address.toLowerCase();
    if (normalized === diamondAddress) {
      throw new Error(`The on-chain facet list contains the diamond address ${address}.`);
    }
    if (seen.has(normalized)) {
      throw new Error(`The on-chain facet list contains duplicate address ${address}.`);
    }
    seen.add(normalized);
  }
}

/**
 * Verifies that every selector exported by each facet routes back to that facet.
 *
 * `facetFunctionSelectors` derives its result from the facet's
 * `exportSelectors()`, so each selector must be checked with `facetAddress`;
 * this catches selectors that the facet exposes but the diamond does not route.
 *
 * @param diamond - The diamond introspection adapter.
 * @param diamondAddress - The deployed diamond address.
 * @param facets - The reported facet names and addresses.
 */
async function verifySelectorRouting(
  diamond: IDiamondAdapter,
  diamondAddress: Hex,
  facets: Record<string, Hex>,
): Promise<void> {
  for (const [name, address] of Object.entries(facets)) {
    const selectors = await diamond.facetFunctionSelectors(diamondAddress, address);
    if (selectors.length === 0) {
      throw new Error(
        `Facet '${name}' (${address}) exposes no selectors on the diamond; its first selector is not routed.`,
      );
    }

    for (const selector of selectors) {
      const routedTo = await diamond.facetAddress(diamondAddress, selector);
      const normalized = routedTo.toLowerCase();
      if (normalized === address.toLowerCase()) {
        continue;
      }
      if (normalized === ZERO_ADDRESS) {
        throw new Error(
          `Selector ${selector} from facet '${name}' (${address}) is not routed by the diamond.`,
        );
      }
      throw new Error(
        `Selector ${selector} from facet '${name}' (${address}) is routed to ${routedTo} instead.`,
      );
    }
  }
}

/**
 * Deploy verification module.
 *
 * Checks the deployed diamond against the chain before anything is
 * recorded in compose.lock: the diamond and every facet must have code,
 * facet addresses must be unique and distinct from the diamond, the diamond
 * registry must expose exactly the reported facet addresses, and every
 * selector exported by a facet must route back to that facet.
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

      assertUniqueFacetAddresses(execution.facets, execution.diamond);

      for (const [name, address] of Object.entries(execution.facets)) {
        const code = await dependencies.rpc.getCode(address);
        if (!code || code === "0x") {
          throw new Error(`No contract code found at facet '${name}' (${address}).`);
        }
      }

      const onChainAddresses = await dependencies.diamond.facetAddresses(execution.diamond);
      assertValidOnChainFacetList(onChainAddresses, execution.diamond);

      const reported = new Set(Object.values(execution.facets).map((address) => address.toLowerCase()));
      const observed = new Set(onChainAddresses.map((address) => address.toLowerCase()));
      const missing = [...reported].filter((address) => !observed.has(address));
      const unexpected = [...observed].filter((address) => !reported.has(address));
      if (missing.length > 0 || unexpected.length > 0) {
        throw new Error(
          `The on-chain facets do not match the deployment result (missing: ${missing.join(", ") || "none"}; unexpected: ${unexpected.join(", ") || "none"}).`,
        );
      }

      await verifySelectorRouting(dependencies.diamond, execution.diamond, execution.facets);

      const record: DiamondDeployment = {
        diamond: execution.diamond,
        facets: execution.facets,
        facetHash: LockFileModule.computeFacetHash(
          Object.values(execution.facets) as Hex[],
          dependencies.hashing,
        ),
        lastSync: new Date().toISOString(),
        txHash: execution.transactions.diamond,
        ...(execution.deployer ? { deployer: execution.deployer } : {}),
        ...(execution.ignitionDeploymentId ? { ignitionDeploymentId: execution.ignitionDeploymentId } : {}),
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
