import type { DeployFacetEntry } from "../deployGeneration/types";

export type DeployContract = {
  reference: string;
  sourcePath: string;
  contractName: string;
};

export type DeployProject = {
  projectRoot: string;
  composeJsonPath: string;
  framework: "foundry" | "hardhat";
  diamondName: string;
  diamond: DeployContract;
  facets: (DeployContract & { name: string; origin: DeployFacetEntry["origin"] })[];
  chain: { key: string; chainId: number };
};

/** Source-side deployment plan. This is not a receipt or proof of execution. */
export type DeployScriptArtifact = {
  kind: "deployment-script";
  outputPath: string;
  generatedAt: string;
  composeJsonPath: string;
  diamondName: string;
  diamond: DeployContract & { artifactReference: string };
  facets: (DeployContract & { name: string; artifactReference: string; expectedSelectors: string[] | null })[];
  chain: DeployProject["chain"];
  framework: DeployProject["framework"];
  toolbox: "ethers" | "viem" | null;
  selectorEvidence: "source-ast";
};
