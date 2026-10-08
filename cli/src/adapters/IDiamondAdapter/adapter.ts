import type { IRPCAdapter } from "../IRPCAdapter/interface";
import { DIAMOND_INSPECT_ABI } from "./abi";
import type { IDiamondAdapter } from "./interface";

/** Adapt generic RPC reads to the common diamond introspection interface. */
export function createDiamondAdapter(rpc: IRPCAdapter): IDiamondAdapter {
  return {
    facets: (diamond, options) => rpc.readContract({
      address: diamond,
      abi: DIAMOND_INSPECT_ABI,
      functionName: "facets",
      blockNumber: options?.blockNumber,
    }, { verifyCode: true }),
    facetAddresses: (diamond, options) => rpc.readContract({
      address: diamond,
      abi: DIAMOND_INSPECT_ABI,
      functionName: "facetAddresses",
      blockNumber: options?.blockNumber,
    }, { verifyCode: true }),
    facetFunctionSelectors: (diamond, facet, options) => rpc.readContract({
      address: diamond,
      abi: DIAMOND_INSPECT_ABI,
      functionName: "facetFunctionSelectors",
      args: [facet],
      blockNumber: options?.blockNumber,
    }, { verifyCode: true }),
    facetAddress: (diamond, selector, options) => rpc.readContract({
      address: diamond,
      abi: DIAMOND_INSPECT_ABI,
      functionName: "facetAddress",
      args: [selector],
      blockNumber: options?.blockNumber,
    }, { verifyCode: true }),
  };
}
