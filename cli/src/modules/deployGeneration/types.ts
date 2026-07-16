import { FacetOrigin, SelectedFacetSource } from "../scaffolding/types";

export type DeployFacetGroup = "base" | "library";

export type DeployFacetEntry = {
  facetName: string;
  contractName: string;
  importPath: string;
  source: SelectedFacetSource;
  origin: FacetOrigin;
  group: DeployFacetGroup;
};

export type DeployGenerationModel = {
  outputPath: string;
  facets: DeployFacetEntry[];
};
