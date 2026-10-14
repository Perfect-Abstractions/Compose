import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { Context } from "../../../src/context/context";
import type { ModuleState } from "../../../src/context/types";
import { ComposeProjectInfo } from "../../../src/modules/info/types";
import { scanFacets } from "../../../src/modules/info/scanner";

describe("info package facet scanning", () => {
  it("uses the first package source match", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-info-package-facet-"));

    try {
      const nodeSource = path.join(projectRoot, "node_modules", "example-package", "PackageFacet.sol");
      const foundrySource = path.join(projectRoot, "lib", "Compose", "src", "PackageFacet.sol");
      await fs.mkdir(path.dirname(nodeSource), { recursive: true });
      await fs.mkdir(path.dirname(foundrySource), { recursive: true });
      await fs.writeFile(nodeSource, `
        contract PackageFacet {
          function fromNodeModules() external {}
          function exportSelectors() external pure returns (bytes memory) {
            return bytes.concat(this.fromNodeModules.selector);
          }
        }
      `, "utf8");
      await fs.writeFile(foundrySource, `
        contract PackageFacet {
          function fromFoundryLib() external {}
          function exportSelectors() external pure returns (bytes memory) {
            return bytes.concat(this.fromFoundryLib.selector);
          }
        }
      `, "utf8");

      const ctx = Context.create();
      const projectInfo: ComposeProjectInfo = {
        project: "example",
        composeVersion: "0.1.0",
        framework: "foundry",
        diamonds: [{
          name: "ExampleDiamond",
          contract: "src/Diamond.sol:Diamond",
          facets: [{
            name: "PackageFacet",
            source: "package",
            contract: "PackageFacet",
            package: "example-package",
            selectors: [],
            storageSlots: [],
          }],
        }],
        warnings: [],
      };
      ctx.state.infoProject = { success: true, result: projectInfo, error: null };
      ctx.state.infoLoader = {
        success: true,
        result: { composeJsonPath: path.join(projectRoot, "compose.json") },
        error: null,
      };

      await scanFacets(ctx);

      const state = ctx.state.infoProject as ModuleState<ComposeProjectInfo>;
      expect(state.result?.diamonds[0].facets[0].selectors).toEqual(["fromNodeModules()"]);
    } finally {
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });
});
