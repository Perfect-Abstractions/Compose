import fs from "node:fs/promises";
import path from "node:path";

export type PackageFacetSearchOptions = {
  /** Skip unreadable search roots, as the info scanner historically does. */
  ignoreReadErrors?: boolean;
  /** Stop scanning as soon as the first matching source is found. */
  stopAfterFirstMatch?: boolean;
  /** Framework whose installed package copy takes precedence when both exist. */
  framework?: string;
};

/**
 * Returns the package roots to search, most authoritative first.
 *
 * Foundry projects compile package facets from `lib/Compose`, while Hardhat
 * projects compile them from `node_modules`. When both copies exist (a Foundry
 * project also gets a `node_modules` copy through the Compose CLI's own
 * dependency tree), the framework's root must win to avoid false ambiguity.
 *
 * @param projectRoot - Absolute path of the Compose project.
 * @param packageName - Package that provides the facet.
 * @param framework - Project framework ("foundry" or "hardhat"), when known.
 * @returns Search roots ordered by precedence.
 */
function packageSearchRoots(
  projectRoot: string,
  packageName: string,
  framework?: string,
): string[] {
  const nodeModulesRoot = path.join(projectRoot, "node_modules", packageName);
  const foundryRoot = path.join(projectRoot, "lib", "Compose", "src");

  return framework === "foundry"
    ? [foundryRoot, nodeModulesRoot]
    : [nodeModulesRoot, foundryRoot];
}

/**
 * Finds matching Solidity sources inside one package root.
 *
 * @param root - Package root to scan.
 * @param facetName - Facet contract file name without the extension.
 * @param options - Search behavior options.
 * @returns Matching absolute paths, possibly empty.
 */
async function findMatchesInRoot(
  root: string,
  facetName: string,
  options: PackageFacetSearchOptions,
): Promise<string[]> {
  try {
    const entries = await fs.readdir(root, { recursive: true, withFileTypes: true });
    const matches: string[] = [];

    for (const entry of entries) {
      if (entry.isFile() && entry.name === `${facetName}.sol`) {
        matches.push(path.join(entry.parentPath ?? entry.path, entry.name));
        if (options.stopAfterFirstMatch) return matches;
      }
    }

    return matches;
  } catch (error) {
    if (
      options.ignoreReadErrors ||
      (error as NodeJS.ErrnoException).code === "ENOENT"
    ) {
      return [];
    }
    throw error;
  }
}

/**
 * Finds matching Solidity source files in the project's Node and Foundry
 * package roots, preferring the framework's own package installation.
 *
 * @param projectRoot - Absolute path of the Compose project.
 * @param packageName - Package that provides the facet.
 * @param facetName - Facet contract file name without the extension.
 * @param options - Search behavior options.
 * @returns Matches from the first root that contains the facet.
 */
export async function findPackageFacetSourceMatches(
  projectRoot: string,
  packageName: string,
  facetName: string,
  options: PackageFacetSearchOptions = {},
): Promise<string[]> {
  for (const root of packageSearchRoots(projectRoot, packageName, options.framework)) {
    const matches = await findMatchesInRoot(root, facetName, options);
    if (matches.length > 0) return matches;
  }

  return [];
}
