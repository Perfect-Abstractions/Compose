/** Test section group: base facets render before library facets. */
export type TestFacetGroup = "base" | "library";

export type TestFacetEntry = {
  facetName: string;
  contractName: string;
  importPath: string;
  group: TestFacetGroup;
};

export type TestGenerationModel = {
  outputPath: string;
  facets: TestFacetEntry[];
  facetCount: number;
};
