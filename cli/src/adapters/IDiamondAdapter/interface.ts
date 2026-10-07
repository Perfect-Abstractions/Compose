import type { Address, Hex } from "viem";

/** An entry returned by the shared ERC-8153/ERC-2535 diamond introspection ABI. */
export type DiamondFacet = {
  facet: Address;
  functionSelectors: Hex[];
};

/** Pin related introspection reads to the same chain state when needed. */
export type DiamondReadOptions = {
  blockNumber?: bigint;
};

/** Read-only diamond introspection boundary. */
export interface IDiamondAdapter {
  facets(diamond: Address, options?: DiamondReadOptions): Promise<DiamondFacet[]>;
  facetAddresses(diamond: Address, options?: DiamondReadOptions): Promise<Address[]>;
  facetFunctionSelectors(diamond: Address, facet: Address, options?: DiamondReadOptions): Promise<Hex[]>;
  facetAddress(diamond: Address, selector: Hex, options?: DiamondReadOptions): Promise<Address>;
}
