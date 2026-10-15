import { describe, expect, it } from "vitest";
import {
  renderHardhatEthersTest,
  renderHardhatViemTest,
} from "../../../src/modules/testGeneration/renderers";
import type { TestGenerationModel } from "../../../src/modules/testGeneration/types";

const model: TestGenerationModel = {
  outputPath: "test/Diamond.ts",
  facetCount: 3,
  facets: [
    {
      facetName: "LibraryFirstFacet",
      contractName: "LibraryFirstFacet",
      importPath: "facets/LibraryFirstFacet.sol",
      group: "library",
    },
    {
      facetName: "BaseFirstFacet",
      contractName: "BaseFirstFacet",
      importPath: "facets/BaseFirstFacet.sol",
      group: "base",
    },
    {
      facetName: "BaseSecondFacet",
      contractName: "BaseSecondFacet",
      importPath: "facets/BaseSecondFacet.sol",
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

describe("Hardhat test renderers", () => {
  it("renders ethers setup with waits but without deploy-script logging", async () => {
    const source = await renderHardhatEthersTest(model);

    expectBaseSectionsBeforeLibraries(source);
    expect(source).toContain("await baseFirstFacet.waitForDeployment();");
    expect(source).toContain("facets.push(await baseFirstFacet.getAddress());");
    expect(source).not.toContain('console.log("BaseFirstFacet:");');
    expect(source).toContain("equal(3)");
  });

  it("renders viem setup with address access and no deployment wait", async () => {
    const source = await renderHardhatViemTest(model);

    expectBaseSectionsBeforeLibraries(source);
    expect(source).toContain("facets.push(baseFirstFacet.address);");
    expect(source).not.toContain("waitForDeployment");
    expect(source).toContain("strictEqual(addresses.length, 3)");
  });
});
