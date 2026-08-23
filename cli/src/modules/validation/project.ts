import fs from "node:fs/promises";
import path from "node:path";
import { ComposeContext } from "../../context/types";
import { findFileAncestor } from "../../utils/files";
import { ResolvedFacetSource } from "./types";
import {
  ComposeProjectFacet,
  resolveComposeProjectFacetSources,
  resolveUserProjectFacetSources,
  UserProjectFacet,
} from "./projectSourceResolution";

type ComposeFacetDefinition = {
  contract?: unknown;
  package?: unknown;
  source?: unknown;
};

type ComposeDiamondDefinition = {
  contract?: unknown;
  facets?: Record<string, ComposeFacetDefinition>;
};

type ComposeProjectDefinition = {
  framework?: unknown;
  diamonds?: Record<string, ComposeDiamondDefinition>;
};

export type ValidationProject = {
  diamonds: ValidationDiamond[];
  diamondSourcePaths: string[];
  facetSources: ResolvedFacetSource[];
};

export type ValidationDiamond = {
  name: string;
  sourcePath: string;
  facets: ResolvedFacetSource[];
};

type PendingDiamond = Omit<ValidationDiamond, "facets"> & {
  facetIndexes: number[];
};

type PendingFacet = {
  kind: "compose" | "user";
  kindIndex: number;
};

/** Loads validation inputs from the nearest Compose project definition. */
export async function loadValidationProject(
  ctx: ComposeContext,
): Promise<ValidationProject> {
  const startDirectory = path.resolve(String(ctx.param.projectRoot ?? process.cwd()));
  const composeJsonPath = await findFileAncestor(startDirectory, "compose.json");
  if (!composeJsonPath) {
    throw new Error(
      "compose.json not found. Run 'compose init' first or navigate to a Compose project directory.",
    );
  }

  const composeJson = JSON.parse(
    await fs.readFile(composeJsonPath, "utf8"),
  ) as ComposeProjectDefinition;
  const projectRoot = path.dirname(composeJsonPath);
  const configuredFramework = String(composeJson.framework ?? "");
  const framework = String(ctx.param.framework ?? configuredFramework);
  if (framework !== "foundry" && framework !== "hardhat") {
    throw new Error(`Unsupported framework in compose.json: ${framework || "missing"}.`);
  }

  const diamondSourcePaths = new Set<string>();
  const pendingDiamonds: PendingDiamond[] = [];
  const pendingFacets: PendingFacet[] = [];
  const composeFacets: ComposeProjectFacet[] = [];
  const userFacets: UserProjectFacet[] = [];
  for (const [diamondName, diamond] of Object.entries(composeJson.diamonds ?? {})) {
    const diamondReference = typeof diamond.contract === "string" ? diamond.contract : "";
    const diamondSourcePath = diamondReference.split(":")[0];
    if (!diamondSourcePath) {
      throw new Error("Every diamond in compose.json must define its generated contract path.");
    }
    const resolvedDiamondSourcePath = path.resolve(projectRoot, diamondSourcePath);
    const diamondFacetIndexes: number[] = [];
    diamondSourcePaths.add(resolvedDiamondSourcePath);

    for (const [facetAlias, facet] of Object.entries(diamond.facets ?? {})) {
      const contractReference = typeof facet.contract === "string" ? facet.contract : "";
      const separatorIndex = contractReference.lastIndexOf(":");
      const contractName = separatorIndex >= 0
        ? contractReference.slice(separatorIndex + 1)
        : facetAlias;
      if (!contractName) continue;

      if (facet.source === "package") {
        const packageName = typeof facet.package === "string" ? facet.package : "";
        if (!packageName) {
          throw new Error(`Package facet ${contractName} is missing its package name.`);
        }
        diamondFacetIndexes.push(pendingFacets.length);
        pendingFacets.push({ kind: "compose", kindIndex: composeFacets.length });
        composeFacets.push({ contractName, packageName });
      } else {
        const contractPath = contractReference.split(":")[0];
        if (!contractPath) {
          throw new Error(`Local facet ${contractName} is missing its contract path.`);
        }
        diamondFacetIndexes.push(pendingFacets.length);
        pendingFacets.push({ kind: "user", kindIndex: userFacets.length });
        userFacets.push({ contractName, contractPath });
      }
    }

    pendingDiamonds.push({
      name: diamondName,
      sourcePath: resolvedDiamondSourcePath,
      facetIndexes: diamondFacetIndexes,
    });
  }
  if (pendingFacets.length === 0) {
    throw new Error("compose.json does not define any facets to validate.");
  }

  const composeFacetSources = await resolveComposeProjectFacetSources(projectRoot, composeFacets);
  const userFacetSources = resolveUserProjectFacetSources(projectRoot, userFacets);
  const resolvedFacets = pendingFacets.map((facet) => facet.kind === "compose"
    ? composeFacetSources[facet.kindIndex]
    : userFacetSources[facet.kindIndex]);
  const diamonds = pendingDiamonds.map((diamond) => ({
    name: diamond.name,
    sourcePath: diamond.sourcePath,
    facets: diamond.facetIndexes.map((index) => resolvedFacets[index]),
  }));
  const facetSources = [...new Map(
    resolvedFacets.map((facet) => [`${facet.sourcePath}:${facet.contractName}`, facet]),
  ).values()];

  ctx.param.projectRoot = projectRoot;
  ctx.param.framework = framework;
  ctx.config.composeJson = composeJson as Record<string, unknown>;
  ctx.state.validationProject = {
    success: true,
    result: {
      composeJsonPath,
      projectRoot,
      framework,
      diamonds,
      diamondSourcePaths: [...diamondSourcePaths],
      facetSources,
    },
    error: null,
  };

  return {
    diamonds,
    diamondSourcePaths: [...diamondSourcePaths],
    facetSources,
  };
}
