import { bytesToHex, hexToBytes, parseAbi, type Address, type Hex } from "viem";
import type { IRPCAdapter } from "../../adapters/IRPCAdapter/interface";
import type { HistoryEvent } from "./types";

const exportSelectorsAbi = parseAbi(["function exportSelectors() pure returns (bytes)"]);
const facetParameters = new Set(["_facet", "_oldFacet", "_newFacet"]);

async function readFacetSelectors(rpc: IRPCAdapter, facet: Address): Promise<Hex[] | null> {
  try {
    const packed = await rpc.readContract<Hex>({ address: facet, abi: exportSelectorsAbi, functionName: "exportSelectors" });
    const bytes = hexToBytes(packed);
    if (bytes.length % 4 !== 0) return null;
    const selectors: Hex[] = [];
    for (let offset = 0; offset < bytes.length; offset += 4) {
      selectors.push(bytesToHex(bytes.subarray(offset, offset + 4)));
    }
    return selectors;
  } catch {
    return null;
  }
}

/** Enrich facet events from their direct, pure exportSelectors() calls. */
export async function loadHistorySelectors(rpc: IRPCAdapter, events: HistoryEvent[]): Promise<void> {
  const selectorsByFacet = new Map<Address, Promise<Hex[] | null>>();
  await Promise.all(events.flatMap((event) => event.parameters
    .filter((parameter) => event.name.startsWith("Facet") && facetParameters.has(parameter.name))
    .map(async (parameter) => {
      const facet = parameter.value as Address;
      let selectors = selectorsByFacet.get(facet);
      if (!selectors) {
        selectors = readFacetSelectors(rpc, facet);
        selectorsByFacet.set(facet, selectors);
      }
      parameter.selectors = await selectors;
    })));
}
