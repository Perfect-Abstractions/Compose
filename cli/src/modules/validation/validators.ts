import { IHashingAdapter } from "../../adapters/interface/IHashingAdapter";
import { isArrayPrefix } from "../../utils/arrays";
import {
  FacetScanResult,
  SelectorExportIssue,
  SelectorCollision,
  SelectorOwner,
  IdentifierCollision,
  IdentifierCollisionOwner,
} from "./types";

/**
 * Finds facets with missing or extra exported selectors compared to their functions.
 *
 * @param facets - Array of scanned facet results.
 * @returns Array of selector export issues (only facets with problems).
 */
export function findSelectorExportIssues(facets: FacetScanResult[]): SelectorExportIssue[] {
  return facets
    .map((facet) => ({
      facetName: facet.facetName,
      path: facet.path,
      missingExports: facet.missingExports,
      extraExports: facet.extraExports,
    }))
    .filter((issue) => issue.missingExports.length > 0 || issue.extraExports.length > 0);
}

/**
 * Detects duplicate 4-byte selectors across different facets.
 * Groups functions by their keccak256-derived selector and returns collisions
 * where the same selector appears in more than one facet.
 *
 * @param facets - Array of scanned facet results.
 * @param hashing - Hashing adapter for keccak256 computation.
 * @returns Array of selector collisions across facets.
 */
export function findSelectorCollisions(
  facets: FacetScanResult[],
  hashing: IHashingAdapter,
): SelectorCollision[] {
  const ownersBySelector = new Map<string, SelectorOwner[]>();

  for (const facet of facets) {
    const functionsBySignature = new Map(facet.functions.map((fn) => [fn.signature, fn]));

    for (const exportedSignature of facet.exportedSelectors) {
      const fn = functionsBySignature.get(exportedSignature);
      if (!fn) {
        continue;
      }

      const selector = hashing.keccak256(fn.signature).slice(0, 10);
      const owners = ownersBySelector.get(selector) ?? [];
      owners.push({
        facetName: facet.facetName,
        path: facet.path,
        functionName: fn.name,
        signature: fn.signature,
      });
      ownersBySelector.set(selector, owners);
    }
  }

  return [...ownersBySelector.entries()]
    .map(([selector, owners]) => ({ selector, owners }))
    .filter((collision) => new Set(collision.owners.map((owner) => owner.facetName)).size > 1);
}

/**
 * Detects incompatible storage layouts sharing the same storage slot identifier.
 * Layouts are compatible if they are prefix extensions of the shortest layout.
 *
 * @param facets - Array of scanned facet results.
 * @returns Array of identifier collisions with incompatible layouts.
 */
export function findIdentifierCollisions(facets: FacetScanResult[]): IdentifierCollision[] {
  const ownersByIdentifier = new Map<string, IdentifierCollisionOwner[]>();

  for (const facet of facets) {
    for (const storageLayout of facet.storageLayouts) {
      const identifier = storageLayout.slot;
      const owners = ownersByIdentifier.get(identifier) ?? [];
      owners.push({
        facetName: facet.facetName,
        path: facet.path,
        slot: storageLayout.slot,
        layout: storageLayout.layout,
        source: storageLayout.source,
        structName: storageLayout.structName,
      });
      ownersByIdentifier.set(identifier, owners);
    }
  }

  return [...ownersByIdentifier.entries()]
    .filter(([, owners]) => owners.length > 1)
    .filter(([, owners]) => !areLayoutsPrefixCompatible(owners.map((owner) => owner.layout)))
    .map(([identifier, owners]) => ({ identifier, owners }));
}

/**
 * Checks whether all layouts are prefix-compatible with the shortest layout.
 * A layout is prefix-compatible if all others extend it without conflicts.
 *
 * @param layouts - Array of layout arrays to check.
 * @returns True if all layouts are prefix-compatible.
 */
function areLayoutsPrefixCompatible(layouts: string[][]): boolean {
  if (layouts.length <= 1) {
    return true;
  }

  const sorted = [...layouts].sort((a, b) => a.length - b.length);
  const shortest = sorted[0];

  return sorted.every((layout) => isArrayPrefix(shortest, layout));
}
