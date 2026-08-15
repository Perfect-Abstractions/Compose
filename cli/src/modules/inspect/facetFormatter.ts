import { type Address, type Hex } from "viem";
import { decodeSelector } from "./selectorDecoder";
import type { FacetInfo } from "./types";

/**
 * Converts raw on-chain facet data into a {@link FacetInfo} object with decoded
 * selector signatures.
 *
 * @param raw - The raw facet returned by the Diamond Loupe.
 * @param raw.facet - The facet contract address.
 * @param raw.functionSelectors - The 4-byte selectors registered on the facet.
 * @param index - The zero-based index of the facet in the Loupe response.
 * @returns The facet info with decoded selectors.
 */
export function toFacetInfo(raw: { facet: Address; functionSelectors: Hex[] }, index: number): FacetInfo {
  return {
    address: raw.facet,
    index,
    selectors: raw.functionSelectors.map((sel) => ({
      selector: sel,
      signature: decodeSelector(sel),
    })),
  };
}
