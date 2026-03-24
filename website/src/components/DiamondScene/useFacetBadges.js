import { useState, useCallback } from 'react';

// Contract filenames mirrored from `src/**` and converted to display names.
const FACET_NAMES = [
  "DiamondInspectFacet",
  "DiamondUpgradeFacet",
  "ERC165Facet",
  "AccessControlDataFacet",
  "AccessControlGrantFacet",
  "AccessControlRevokeFacet",
  "OwnerDataFacet",
  "OwnerTransferFacet",
  "OwnerRenounceFacet",
  "ERC1155DataFacet",
  "ERC1155MintFacet",
  "ERC1155BurnFacet",
  "ERC20DataFacet",
  "ERC20MintFacet",
  "ERC20BurnFacet",
  "ERC20ApproveFacet",
  "ERC20TransferFacet",
  "ERC721DataFacet",
  "ERC721MintFacet",
  "ERC721BurnFacet",
  "ERC721ApproveFacet",
  "ERC721TransferFacet",
  "ERC721MetadataFacet",
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
