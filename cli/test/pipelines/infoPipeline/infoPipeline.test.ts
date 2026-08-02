import { describe, expect, it, vi } from "vitest";
import { ModuleState } from "../../../src/context/types";
import { ComposeProjectInfo } from "../../../src/modules/info/types";
import { InfoPipeline } from "../../../src/pipelines/infoPipeline";
import { createInfoPipelineHarness } from "./harness";

/**
 * Tests InfoPipeline with a local CounterFacet project built by its harness.
 *
 * CounterFacet exports getValue() and uses an ERC-8042 counter storage layout.
 */
describe("InfoPipeline", () => {
  it("loads, scans, and displays project information", async () => {
    const harness = await createInfoPipelineHarness();
    const output = vi.spyOn(console, "log");

    try {
      const result = await InfoPipeline.execute(harness.ctx);
      const state = result.state.infoProject as ModuleState<ComposeProjectInfo>;
      const project = state.result;
      const facet = project?.diamonds[0]?.facets[0];

      expect(result).toBe(harness.ctx);
      expect(state.success).toBe(true);
      expect(project?.project).toBe("info-example");
      expect(project?.framework).toBe("foundry");
      expect(project?.warnings).toEqual([]);
      expect(facet?.name).toBe("CounterFacet");
      expect(facet?.selectors).toEqual(["getValue()"]);
      expect(facet?.storageSlots).toEqual([
        {
          slot: "counter",
          layout: ["uint256"],
          source: "erc8042",
          structName: "CounterStorage",
        },
      ]);
      expect(output.mock.calls.flat().some((value) => String(value).includes("info-example"))).toBe(true);
    } finally {
      output.mockRestore();
      await harness.cleanup();
    }
  });
});
