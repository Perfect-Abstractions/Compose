import type { Address } from "viem";

/** A single entry parsed from a contract ABI JSON array. */
export type AbiEntry = {
  type: string;
  name?: string;
  inputs?: { type: string }[];
};

/** A 4-byte selector paired with its decoded function signature. */
export type SelectorInfo = {
  selector: string;
  signature: string;
};

/** Information about a single facet registered on the Diamond. */
export type FacetInfo = {
  address: Address;
  index: number;
  selectors: SelectorInfo[];
};

/** The complete result of inspecting an on-chain Diamond. */
export type InspectResult = {
  diamond: Address;
  chainKey: string;
  chainId: number;
  facets: FacetInfo[];
};
