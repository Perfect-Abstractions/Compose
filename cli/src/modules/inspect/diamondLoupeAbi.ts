/**
 * ABI for the EIP-2535 Diamond Loupe `facets()` view function.
 *
 * Used to query on-chain diamonds for their registered facets and selectors.
 */
export const DIAMOND_LOUPE_ABI = [
  {
    name: "facets",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [
      {
        type: "tuple[]",
        components: [
          { name: "facet", type: "address" },
          { name: "functionSelectors", type: "bytes4[]" },
        ],
      },
    ],
  },
] as const;
