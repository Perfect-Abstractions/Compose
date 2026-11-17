import fs from "node:fs/promises";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { ModuleState } from "../../../src/context/types";
import { TestGenerationModule } from "../../../src/modules/testGeneration/module";
import { createScaffoldHarness } from "../scaffoldHarness";

type TestGenerationResult = {
  outputPath: string;
  facetCount: number;
  framework: string;
};

/** Tests framework test generation from the scaffold map and selected facets. */
describe("TestGenerationModule", () => {
  it("generates a Foundry Diamond test for every selected facet", async () => {
    const harness = await createScaffoldHarness();
    const testRoot = path.join(harness.projectRoot, "test");

    try {
      const result = await TestGenerationModule.generateTestFile(harness.ctx, testRoot);
      const state = result.state.generateTestFile as ModuleState<TestGenerationResult>;
      const source = await fs.readFile(path.join(testRoot, "Diamond.t.sol"), "utf8");

      expect(state.success).toBe(true);
      expect(state.result).toEqual(expect.objectContaining({
        outputPath: path.join(testRoot, "Diamond.t.sol"),
        facetCount: 16,
        framework: "foundry",
      }));
      expect(source).toContain("contract DiamondTest is Test");
      expect(source).toContain("new ERC20DataFacet()");
      expect(source).toContain("new DiamondUpgradeFacet()");
    } finally {
      await harness.cleanup();
    }
  });
});
