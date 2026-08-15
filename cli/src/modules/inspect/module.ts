import path from "node:path";
import { isAddress, type Address, type Hex } from "viem";
import { ComposeContext } from "../../context/types";
import { DependencyKey } from "../../resolver/dependencyKey";
import { DependencyResolver } from "../../resolver/dependencyResolver";
import { resolveChainConfig } from "../../utils/chainConfig";
import { findFileAncestor } from "../../utils/files";
import { RPCAdapterError } from "../../adapters/rpc/errors";
import { showInspect } from "./output";
import { DIAMOND_LOUPE_ABI } from "./diamondLoupeAbi";
import { toFacetInfo } from "./facetFormatter";
import { mergeProjectSignatures } from "./selectorDecoder";
import type { InspectResult, FacetInfo } from "./types";

export const InspectModule = {
  /**
   * Inspects an on-chain Diamond and displays its facets and selectors.
   *
   * Validates the diamond address, resolves the RPC adapter for the target
   * chain, fetches facets via the Diamond Loupe, and decodes each selector
   * using a combination of common signatures and project ABI files.
   *
   * @param ctx - The compose context with `address` and optional `chain` params.
   * @returns The updated context with inspect result stored in
   *     `ctx.state.inspect` as {@link ModuleState}\<{@link InspectResult}\>.
   * @throws {RPCAdapterError} If the address is invalid or no contract code is
   *     found.
   */
  async inspect(ctx: ComposeContext): Promise<ComposeContext> {
    const addressValue = ctx.param.address;
    if (typeof addressValue !== "string" || !isAddress(addressValue, { strict: false })) {
      throw new RPCAdapterError(
        "RPC_INVALID_ADDRESS",
        `Invalid diamond address: ${String(addressValue ?? "")}`,
        { operation: "inspect" },
      );
    }
    const diamondAddress = addressValue as Address;

    const chainKey = typeof ctx.param.chain === "string" ? ctx.param.chain : "local";
    const configuredChain = await resolveChainConfig({ chainKey });

    const dependencies = await DependencyResolver.resolve([{
      key: DependencyKey.RPC,
      params: { chainKey: configuredChain.chainKey },
    }]);
    const rpc = dependencies[DependencyKey.RPC];
    if (!rpc) throw new Error("RPC dependency was not resolved");

    const code = await rpc.getCode(diamondAddress);
    if (!code || code === "0x") {
      throw new RPCAdapterError(
        "RPC_CONTRACT_NOT_FOUND",
        `No contract code found at ${diamondAddress}`,
        { operation: "inspect", chainId: configuredChain.chainId },
      );
    }

    const rawFacets = await rpc.readContract<
      { facet: Address; functionSelectors: Hex[] }[]
    >({
      address: diamondAddress,
      abi: DIAMOND_LOUPE_ABI,
      functionName: "facets",
    });

    const composePath = await findFileAncestor(process.cwd(), "compose.json");
    const projectRoot = composePath ? path.dirname(composePath) : null;
    if (projectRoot) {
      await mergeProjectSignatures(projectRoot);
    }

    const facets: FacetInfo[] = rawFacets.map(toFacetInfo);

    const result: InspectResult = {
      diamond: diamondAddress,
      chainKey: configuredChain.chainKey,
      chainId: configuredChain.chainId,
      facets,
    };

    ctx.state.inspect = { success: true, result, error: null };
    showInspect(result);
    return ctx;
  },
};
