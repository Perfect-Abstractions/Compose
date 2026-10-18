import fs from "node:fs/promises";
import path from "node:path";

export type PackageFacetSearchOptions = {
  /** Skip unreadable search roots, as the info scanner historically does. */
  ignoreReadErrors?: boolean;
  /** Stop scanning as soon as the first matching source is found. */
  stopAfterFirstMatch?: boolean;
};

/** Finds matching Solidity source files in the project's Node and Foundry package roots. */
export async function findPackageFacetSourceMatches(
  projectRoot: string,
  packageName: string,
  facetName: string,
  options: PackageFacetSearchOptions = {},
): Promise<string[]> {
  const candidates = [
    path.join(projectRoot, "node_modules", packageName),
    path.join(projectRoot, "lib", "Compose", "src"),
  ];
  const matches: string[] = [];

  for (const candidate of candidates) {
    try {
      const entries = await fs.readdir(candidate, { recursive: true, withFileTypes: true });
      for (const entry of entries) {
        if (entry.isFile() && entry.name === `${facetName}.sol`) {
          matches.push(path.join(entry.parentPath ?? entry.path, entry.name));
          if (options.stopAfterFirstMatch) return matches;
        }
      }
    } catch (error) {
      if (
        options.ignoreReadErrors ||
        (error as NodeJS.ErrnoException).code === "ENOENT"
      ) {
        continue;
      }
      throw error;
    }
  }

  return matches;
}
