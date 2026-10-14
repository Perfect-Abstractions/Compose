import { parseAbi } from "viem";

/** ERC-8153's three facet changes and two optional upgrade records. */
export const historyEvents = parseAbi([
  "event FacetAdded(address indexed _facet)",
  "event FacetReplaced(address indexed _oldFacet, address indexed _newFacet)",
  "event FacetRemoved(address indexed _facet)",
  "event DiamondDelegateCall(address indexed _delegate, bytes _delegateCalldata)",
  "event DiamondMetadata(bytes32 indexed _tag, bytes _data)",
]);
