import path from "node:path";
import { findPackageFacetSourceMatches } from "../../utils/packageFacetSources";
import { ResolvedFacetSource } from "./types";

export type ComposeProjectFacet = {
  contractName: string;
  packageName: string;
};

export type UserProjectFacet = {
  contractName: string;
  contractPath: string;
};

/** Resolves package facets from installed Node or Foundry dependencies. */
export async function resolveComposeProjectFacetSources(
  projectRoot: string,
  facets: ComposeProjectFacet[],
): Promise<ResolvedFacetSource[]> {
  return Promise.all(
    facets.map(async (facet) => ({
      contractName: facet.contractName,
      sourcePath: await findPackageFacetSource(
        projectRoot,
        facet.packageName,
        facet.contractName,
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
    contractName: facet.contractName,
    sourcePath: path.resolve(projectRoot, facet.contractPath),
  }));
}

async function findPackageFacetSource(
  projectRoot: string,
  packageName: string,
  facetName: string,
): Promise<string> {
  const matches = await findPackageFacetSourceMatches(projectRoot, packageName, facetName);
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
