import fs from "node:fs/promises";
import path from "node:path";
import { ResolvedFacetSource } from "./types";

export type ComposeProjectFacet = {
  facetName: string;
  packageName: string;
};

export type UserProjectFacet = {
  facetName: string;
  contractPath: string;
};

/** Resolves package facets from installed Node or Foundry dependencies. */
export async function resolveComposeProjectFacetSources(
  projectRoot: string,
  facets: ComposeProjectFacet[],
): Promise<ResolvedFacetSource[]> {
  return Promise.all(
    facets.map(async (facet) => ({
      facetName: facet.facetName,
      sourcePath: await findPackageFacetSource(
        projectRoot,
        facet.packageName,
        facet.facetName,
      ),
    })),
  );
}

/** Resolves user-specific facets from compose.json contract references. */
export function resolveUserProjectFacetSources(
  projectRoot: string,
  facets: UserProjectFacet[],
): ResolvedFacetSource[] {
  return facets.map((facet) => ({
    facetName: facet.facetName,
    sourcePath: path.resolve(projectRoot, facet.contractPath),
  }));
}

async function findPackageFacetSource(
  projectRoot: string,
  packageName: string,
  facetName: string,
): Promise<string> {
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
          matches.push(path.join(entry.parentPath, entry.name));
        }
      }
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
  }

  const uniqueMatches = [...new Set(matches.map((match) => path.resolve(match)))];
  if (uniqueMatches.length === 0) {
    throw new Error(`Package facet source not found: ${packageName}/${facetName}.sol`);
  }
  if (uniqueMatches.length > 1) {
    throw new Error(
      `Package facet source is ambiguous: ${packageName}/${facetName}.sol\n${uniqueMatches.join("\n")}`,
    );
  }

  return uniqueMatches[0];
}
