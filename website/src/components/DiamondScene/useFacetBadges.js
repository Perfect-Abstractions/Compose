import { useState, useCallback } from 'react';

// A list of realistic facet names related to EIP-2535 Diamond Standard
const FACET_NAMES = [
  "DiamondUpgradeFacet",
  "DiamondInspectFacet",
  "OwnerFacet",
  "AccessControlFacet",
  "ERC20DataFacet",
  "ERC20MetadataFacet",
  "ERC20MintFacet",
  "ERC721DataFacet",
  "ERC721MetadataFacet",
  "ERC721EnumerableFacet",
  "ERC165Facet",
  "RoyaltyFacet",
];

export function useFacetBadges() {
  const [activeFacetName, setActiveFacetName] = useState(null);
  
  // Map random names to IDs to keep them consistent during a session if we wanted,
  // but for now we just pick a random one on hover entry if it's not already set.
  const [facetMap] = useState(() => new Map());

  const handleHover = useCallback((facetId) => {
    if (facetId === -1) {
      setActiveFacetName(null);
      return;
    }

    // If we haven't assigned a name to this ID yet, pick one randomly
    if (!facetMap.has(facetId)) {
      const randomName = FACET_NAMES[Math.floor(Math.random() * FACET_NAMES.length)];
      facetMap.set(facetId, randomName);
    }

    setActiveFacetName(facetMap.get(facetId));
  }, [facetMap]);

  return { activeFacetName, handleHover };
}
