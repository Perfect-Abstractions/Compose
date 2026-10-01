/**
 * ABI for the Diamond `facets()` introspection function.
 *
 * ERC-8153 and ERC-2535 expose the same response shape at this boundary.
 */
export const DIAMOND_INSPECT_ABI = [
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
