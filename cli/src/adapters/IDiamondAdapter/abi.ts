/** The four introspection functions shared by ERC-8153 and ERC-2535 diamonds. */
export const DIAMOND_INSPECT_ABI = [
  {
    name: "facets",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{
      type: "tuple[]",
      components: [
        { name: "facet", type: "address" },
        { name: "functionSelectors", type: "bytes4[]" },
      ],
    }],
  },
  {
    name: "facetAddresses",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "address[]" }],
  },
  {
    name: "facetFunctionSelectors",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "facet", type: "address" }],
    outputs: [{ type: "bytes4[]" }],
  },
  {
    name: "facetAddress",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "selector", type: "bytes4" }],
    outputs: [{ type: "address" }],
  },
] as const;
