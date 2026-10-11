import { useState, useCallback, useRef } from 'react';
import { useHistory } from '@docusaurus/router';

// Facets that currently have documentation pages under `website/docs/library`.
// Keep this list in sync when library docs are added or removed.
export const FACETS = [
  { name: "DiamondInspectFacet", path: "/docs/library/diamond/DiamondInspectFacet" },
  { name: "DiamondUpgradeFacet", path: "/docs/library/diamond/DiamondUpgradeFacet" },
  { name: "OwnerDataFacet", path: "/docs/library/access/Owner/Data/OwnerDataFacet" },
  { name: "OwnerRenounceFacet", path: "/docs/library/access/Owner/Renounce/OwnerRenounceFacet" },
  { name: "OwnerTransferFacet", path: "/docs/library/access/Owner/Transfer/OwnerTransferFacet" },
  { name: "OwnerTwoStepDataFacet", path: "/docs/library/access/Owner/TwoSteps/Data/OwnerTwoStepDataFacet" },
  { name: "OwnerTwoStepRenounceFacet", path: "/docs/library/access/Owner/TwoSteps/Renounce/OwnerTwoStepRenounceFacet" },
  { name: "OwnerTwoStepTransferFacet", path: "/docs/library/access/Owner/TwoSteps/Transfer/OwnerTwoStepTransferFacet" },
  { name: "ERC20DataFacet", path: "/docs/library/token/ERC20/Data/ERC20DataFacet" },
  { name: "ERC20MetadataFacet", path: "/docs/library/token/ERC20/Metadata/ERC20MetadataFacet" },
  { name: "ERC20ApproveFacet", path: "/docs/library/token/ERC20/Approve/ERC20ApproveFacet" },
  { name: "ERC20TransferFacet", path: "/docs/library/token/ERC20/Transfer/ERC20TransferFacet" },
  { name: "ERC20BurnFacet", path: "/docs/library/token/ERC20/Burn/ERC20BurnFacet" },
  { name: "ERC20PermitFacet", path: "/docs/library/token/ERC20/Permit/ERC20PermitFacet" },
  { name: "ERC20BridgeableFacet", path: "/docs/library/token/ERC20/Bridgeable/ERC20BridgeableFacet" },
];

const HIDE_DELAY_MS = 400;

export function useFacetBadges() {
  const history = useHistory();
  const [activeFacet, setActiveFacet] = useState(null);
  const facetMapRef = useRef(new Map());
  const badgeHoveredRef = useRef(false);
  const hideTimerRef = useRef(null);

  const clearHideTimer = useCallback(() => {
    if (hideTimerRef.current) {
      clearTimeout(hideTimerRef.current);
      hideTimerRef.current = null;
    }
  }, []);

  const scheduleHide = useCallback(() => {
    clearHideTimer();
    hideTimerRef.current = setTimeout(() => {
      if (!badgeHoveredRef.current) setActiveFacet(null);
    }, HIDE_DELAY_MS);
  }, [clearHideTimer]);

  const handleHover = useCallback((facetId) => {
    if (facetId === -1) {
      scheduleHide();
      return;
    }

    clearHideTimer();

    // Assign a stable facet to each hovered geometry facet id
    if (!facetMapRef.current.has(facetId)) {
      const facet = FACETS[Math.floor(Math.random() * FACETS.length)];
      facetMapRef.current.set(facetId, facet);
    }

    setActiveFacet(facetMapRef.current.get(facetId));
  }, [clearHideTimer, scheduleHide]);

  // Keep the badge alive while the pointer is on it so the link is clickable
  const handleBadgeEnter = useCallback(() => {
    badgeHoveredRef.current = true;
    clearHideTimer();
  }, [clearHideTimer]);

  const handleBadgeLeave = useCallback(() => {
    badgeHoveredRef.current = false;
    setActiveFacet(null);
  }, []);

  // Clicking a hovered facet on the 3D diamond opens its docs page
  const handleFacetClick = useCallback((facetId) => {
    const facet = facetMapRef.current.get(facetId);
    if (facet) {
      history.push(facet.path);
    }
  }, [history]);

  return { activeFacet, handleHover, handleBadgeEnter, handleBadgeLeave, handleFacetClick };
}
