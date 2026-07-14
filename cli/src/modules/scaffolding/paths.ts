import path from "node:path";
import { SelectedFacet } from "./types";

/**
 * Returns the target directory for a facet based on its source classification.
 * Diamond facets go to `diamond/`, library facets to `libraries/`, others to `facets/`.
 *
 * @param contractSourceRoot - The root directory for contract source files.
 * @param facet - The selected facet with source classification.
 * @returns The absolute target directory path.
 */
export function targetDirectoryForFacet(contractSourceRoot: string, facet: SelectedFacet): string {
  if (facet.source === "diamond-required" || facet.source === "diamond-optional") {
    return path.join(contractSourceRoot, "diamond");
  }

  if (facet.source === "library-required" || facet.source === "library-optional") {
    return path.join(contractSourceRoot, "libraries");
  }

  return path.join(contractSourceRoot, "facets");
}
