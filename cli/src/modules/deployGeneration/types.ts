import { FacetOrigin } from "../scaffolding/types";

export type DeployFacetGroup = "base" | "library";

export type DeployFacetEntry = {
  facetName: string;
  contractName: string;
  importPath: string;
  origin: FacetOrigin;
  group: DeployFacetGroup;
  deploymentReference?: string;
};

export type DeployGenerationModel = {
  outputPath: string;
  projectRoot: string;
  diamond: { contractName: string; importPath: string; deploymentReference?: string };
  facets: DeployFacetEntry[];
};
