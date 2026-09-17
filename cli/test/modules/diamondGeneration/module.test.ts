import fs from "node:fs/promises";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { ModuleState } from "../../../src/context/types";
import { BasesCatalog } from "../../../src/modules/config/types";
import { DiamondGenerationModule } from "../../../src/modules/diamondGeneration/module";
import { createDeployGenerationHarness } from "../deployGeneration/harness";

type DiamondGenerationResult = {
  outputPath: string;
  imports: string[];
  constructorEntries: unknown[];
};

/** Tests Diamond.sol generation from the full ERC-20 fixture selection. */
describe("DiamondGenerationModule", () => {
  it("generates Diamond.sol with selected facet imports and constructors", async () => {
    const harness = await createDeployGenerationHarness();
    const sourceRoot = path.join(harness.projectRoot, "src");
    const catalog = harness.ctx.config.bases as BasesCatalog;
    catalog.features.owner.required.OwnerDataFacet = {
      ...catalog.features.owner.required.OwnerDataFacet,
      mod: "@perfect-abstractions/compose/access/Owner/Data/OwnerDataMod.sol",
      constructor: [{
        comments: ["Set the initial contract owner."],
        code: "OwnerDataMod.setContractOwner(msg.sender);",
      }],
    };

    try {
      const result = await DiamondGenerationModule.generateDiamondContract(harness.ctx, sourceRoot);
      const state = result.state.generateDiamondContract as ModuleState<DiamondGenerationResult>;
      const source = await fs.readFile(path.join(sourceRoot, "Diamond.sol"), "utf8");

      expect(state.success).toBe(true);
      expect(state.result?.outputPath).toBe(path.join(sourceRoot, "Diamond.sol"));
      expect(state.result?.imports).toEqual(expect.arrayContaining([
        "@perfect-abstractions/compose/diamond/DiamondMod.sol",
        "@perfect-abstractions/compose/access/Owner/Data/OwnerDataMod.sol",
      ]));
      expect(state.result?.constructorEntries.length).toBeGreaterThan(0);
      expect(source).toContain("contract Diamond");
      expect(source).toContain("DiamondMod.addFacets(_facets);");
      expect(source).toContain("OwnerDataMod.setContractOwner(msg.sender);");
    } finally {
      await harness.cleanup();
    }
  });
});
