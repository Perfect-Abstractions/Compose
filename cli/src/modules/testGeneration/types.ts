import { DeployFacetGroup } from "../deployGeneration/types";

export type TestFacetEntry = {
  facetName: string;
  contractName: string;
  importPath: string;
  group: DeployFacetGroup;
};

export type TestGenerationModel = {
  outputPath: string;
  facets: TestFacetEntry[];
  facetCount: number;
};
