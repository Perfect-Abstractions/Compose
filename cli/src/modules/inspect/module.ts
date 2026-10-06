import path from "node:path";
import { isAddress, type Address } from "viem";
import { ComposeContext } from "../../context/types";
import type { IDiamondAdapter } from "../../adapters/IDiamondAdapter/interface";
import type { ResolvedChainConfig } from "../../utils/chainConfig";
import { findFileAncestor } from "../../utils/files";
import { RPCAdapterError } from "../../adapters/IRPCAdapter/errors";
import { showInspect } from "./output";
import { toFacetInfo } from "./facetFormatter";
import { mergeProjectSignatures } from "./selectorDecoder";
import type { InspectResult, FacetInfo } from "./types";

/** Validate the command address before resolving chain dependencies. */
export function inspectAddress(value: unknown): Address {
  if (typeof value !== "string" || !isAddress(value, { strict: false })) {
    throw new RPCAdapterError(
      "RPC_INVALID_ADDRESS",
      `Invalid diamond address: ${String(value ?? "")}`,
      { operation: "inspect" },
    );
  }
  return value as Address;
}

export const InspectModule = {
  /**
   * Inspects an on-chain Diamond and displays its facets and selectors.
   *
   * Validates the diamond address, fetches facets via the resolved Diamond
   * adapter, and decodes each selector
   * using a combination of common signatures and project ABI files.
   *
   * @param ctx - The compose context with `address` and optional `chain` params.
   * @param diamond - Resolved Diamond adapter for the selected chain.
   * @param chain - Resolved chain identity for the result.
   * @returns The updated context with inspect result stored in
   *     `ctx.state.inspect` as {@link ModuleState}\<{@link InspectResult}\>.
   * @throws {RPCAdapterError} If the address is invalid or no contract code is
   *     found.
   */
  async inspect(ctx: ComposeContext, diamond: IDiamondAdapter, chain: ResolvedChainConfig): Promise<ComposeContext> {
    const diamondAddress = inspectAddress(ctx.param.address);
    const rawFacets = await diamond.facets(diamondAddress);

    const composePath = await findFileAncestor(process.cwd(), "compose.json");
    const projectRoot = composePath ? path.dirname(composePath) : null;
    if (projectRoot) {
      await mergeProjectSignatures(projectRoot);
    }

    const facets: FacetInfo[] = rawFacets.map(toFacetInfo);

    const result: InspectResult = {
      diamond: diamondAddress,
      chainKey: chain.chainKey,
      chainId: chain.chainId,
      facets,
    };

    ctx.state.inspect = { success: true, result, error: null };
    showInspect(result);
    return ctx;
  },
};
