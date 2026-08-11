import fs from "node:fs/promises";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { ModuleState } from "../../../src/context/types";
import { DeployGenerationModule } from "../../../src/modules/deployGeneration/module";
import { createDeployGenerationHarness } from "./harness";

type GeneratedDeployScriptState = {
  outputPath: string;
  facets: { facetName: string }[];
};

/**
 * Tests DeployGenerationModule against a full ERC-20 Foundry deploy script snapshot.
 *
 * It covers ERC-20 extensions, DiamondUpgrade, Owner with renounce, and
 * AccessControl with its batch grant and revoke extensions.
 */
describe("DeployGenerationModule", () => {
  it("generates a Foundry deploy script from selected facets", async () => {
    const harness = await createDeployGenerationHarness();

    try {
      const result = await DeployGenerationModule.generateDeployScript(harness.ctx, harness.scriptRoot);
      const outputPath = path.join(harness.scriptRoot, "Deploy.s.sol");
      const generated = await fs.readFile(outputPath, "utf8");
      const expected = await fs.readFile(path.join(__dirname, "fixtures", "expected", "Deploy.s.sol"), "utf8");
      const state = result.state.generateDeployScript as ModuleState<GeneratedDeployScriptState>;

      expect(state.success).toBe(true);
      expect(state.result?.outputPath).toBe(outputPath);
      expect(state.result?.facets.map((facet) => facet.facetName)).toEqual([
        "ERC20DataFacet",
        "ERC20ApproveFacet",
        "ERC20TransferFacet",
        "ERC20BurnFacet",
        "ERC20MetadataFacet",
        "ERC20PermitFacet",
        "DiamondInspectFacet",
        "OwnerDataFacet",
        "OwnerTransferFacet",
        "AccessControlDataFacet",
        "AccessControlGrantFacet",
        "AccessControlRevokeFacet",
        "DiamondUpgradeFacet",
        "OwnerRenounceFacet",
        "AccessControlGrantBatchFacet",
        "AccessControlRevokeBatchFacet",
      ]);
      expect(generated).toBe(expected);
    } finally {
      await harness.cleanup();
    }
  });
});
