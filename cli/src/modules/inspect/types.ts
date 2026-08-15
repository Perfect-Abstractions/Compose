import type { Address } from "viem";

export type SelectorInfo = {
  selector: string;
  signature: string;
};

export type FacetInfo = {
  address: Address;
  index: number;
  selectors: SelectorInfo[];
};

export type InspectResult = {
  diamond: Address;
  chainKey: string;
  chainId: number;
  facets: FacetInfo[];
};
