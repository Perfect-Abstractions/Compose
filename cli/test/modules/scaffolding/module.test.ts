import fs from "node:fs/promises";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { ScaffoldingModule } from "../../../src/modules/scaffolding/module";
import { createDeployGenerationHarness } from "../deployGeneration/harness";

/** Tests compose.json assembly and persistence from a prepared scaffold map. */
describe("ScaffoldingModule", () => {
  it("writes selected package facets to compose.json", async () => {
    const harness = await createDeployGenerationHarness();
    const contractSourceRoot = path.join(harness.projectRoot, "src");

    try {
      ScaffoldingModule.buildComposeJson(harness.ctx, contractSourceRoot);
      await ScaffoldingModule.validateLocalFacetFiles(harness.ctx);
      await ScaffoldingModule.writeComposeConfig(harness.ctx);

      const composeJson = JSON.parse(
        await fs.readFile(path.join(harness.projectRoot, "compose.json"), "utf8"),
      ) as {
        project: string;
        framework: string;
        diamonds: Record<string, {
          contract: string;
          facets: Record<string, { source: string; contract: string; package?: string }>;
        }>;
      };
      const diamond = composeJson.diamonds["my-diamond"];

      expect(composeJson.project).toBe("my-diamond");
      expect(composeJson.framework).toBe("foundry");
      expect(diamond.contract).toBe("src/Diamond.sol:Diamond");
      expect(Object.keys(diamond.facets)).toHaveLength(16);
      expect(diamond.facets.ERC20DataFacet).toEqual({
        source: "package",
        contract: "ERC20DataFacet",
        package: "@perfect-abstractions/compose",
      });
      expect(harness.ctx.state.facetFileValidation?.success).toBe(true);
    } finally {
      await harness.cleanup();
    }
  });
});
