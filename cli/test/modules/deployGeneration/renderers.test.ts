import { describe, expect, it } from "vitest";
import {
  renderHardhatEthersDeployScript,
  renderHardhatViemDeployScript,
} from "../../../src/modules/deployGeneration/renderers";
import type { DeployGenerationModel } from "../../../src/modules/deployGeneration/types";

const model: DeployGenerationModel = {
  outputPath: "scripts/deploy.ts",
  projectRoot: ".",
  diamond: {
    contractName: "Diamond",
    importPath: "src/Diamond.sol",
    deploymentReference: "src/Diamond.sol:Diamond",
  },
  facets: [
    {
      facetName: "LibraryFirstFacet",
      contractName: "LibraryFirstFacet",
      importPath: "facets/LibraryFirstFacet.sol",
      source: "library-required",
      origin: "local",
      group: "library",
    },
    {
      facetName: "BaseFirstFacet",
      contractName: "BaseFirstFacet",
      importPath: "facets/BaseFirstFacet.sol",
      source: "base-required",
      origin: "local",
      group: "base",
    },
    {
      facetName: "BaseSecondFacet",
      contractName: "BaseSecondFacet",
      importPath: "facets/BaseSecondFacet.sol",
      source: "extension",
      origin: "local",
      group: "base",
    },
  ],
};

function expectBaseSectionsBeforeLibraries(source: string): void {
  const baseFirst = source.indexOf("const baseFirstFacet =");
  const baseSecond = source.indexOf("const baseSecondFacet =");
  const library = source.indexOf("const libraryFirstFacet =");

  expect(baseFirst).toBeGreaterThanOrEqual(0);
  expect(baseSecond).toBeGreaterThan(baseFirst);
  expect(library).toBeGreaterThan(baseSecond);
}

describe("Hardhat deploy renderers", () => {
  it("renders ethers deployment and logging after grouping base facets first", async () => {
    const source = await renderHardhatEthersDeployScript(model);

    expectBaseSectionsBeforeLibraries(source);
    expect(source).toContain("await baseFirstFacet.waitForDeployment();");
    expect(source).toContain('console.log("BaseFirstFacet:", await baseFirstFacet.getAddress());');
    expect(source).toContain("facets.push(await baseFirstFacet.getAddress());");
  });

  it("renders viem deployment and address access after grouping base facets first", async () => {
    const source = await renderHardhatViemDeployScript(model);

    expectBaseSectionsBeforeLibraries(source);
    expect(source).toContain('console.log("BaseFirstFacet:", baseFirstFacet.address);');
    expect(source).toContain("facets.push(baseFirstFacet.address);");
    expect(source).not.toContain("waitForDeployment");
  });
});
