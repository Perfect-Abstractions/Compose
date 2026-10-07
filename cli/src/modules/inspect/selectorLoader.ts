import path from "node:path";
import type { Address } from "viem";
import type { IDiamondAdapter } from "../../adapters/IDiamondAdapter/interface";
import type { ResolvedChainConfig } from "../../utils/chainConfig";
import { findFileAncestor } from "../../utils/files";
import { toFacetInfo } from "./facetFormatter";
import { mergeProjectSignatures } from "./selectorDecoder";
import type { FacetInfo, InspectResult } from "./types";

/** Loads and decodes a diamond's selectors for on-chain read commands. */
export async function loadDiamondSelectors(
  address: Address,
  diamond: IDiamondAdapter,
  chain: ResolvedChainConfig,
): Promise<InspectResult> {
  const rawFacets = await diamond.facets(address);
  const composePath = await findFileAncestor(process.cwd(), "compose.json");
  if (composePath) {
    await mergeProjectSignatures(path.dirname(composePath));
  }

  const facets: FacetInfo[] = rawFacets.map(toFacetInfo);
  return { diamond: address, chainKey: chain.chainKey, chainId: chain.chainId, facets };
}
