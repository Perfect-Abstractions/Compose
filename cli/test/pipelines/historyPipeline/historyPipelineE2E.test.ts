import { describe, expect, it, vi } from "vitest";
import { keccak256, stringToHex } from "viem";
import { Context } from "../../../src/context/context";
import type { HistoryResult } from "../../../src/modules/history/types";
import { HistoryPipeline } from "../../../src/pipelines/historyPipeline";
import { createHistoryHarness } from "./harness";

describe("compose history over Anvil", () => {
  it("reads all five ERC-8153 events from a real diamond across separate upgrade blocks", async () => {
    const harness = await createHistoryHarness();
    const previousDirectory = process.cwd();
    const printed = vi.spyOn(console, "log").mockImplementation(() => undefined);

    try {
      process.chdir(harness.projectRoot);
      const ctx = Context.create();
      ctx.param = { address: harness.diamond, chain: "local" };
      const result = await HistoryPipeline.execute(ctx);
      const state = result.state.history;
      expect(state).toMatchObject({ success: true });
      if (!state || !("result" in state) || !state.result) throw new Error("Missing history result");
      const history = state.result as HistoryResult;

      expect(history.events.map((event) => event.name)).toEqual([
        "DiamondDelegateCall",
        "DiamondMetadata",
        "FacetRemoved",
        "FacetReplaced",
        "FacetAdded",
        "FacetAdded",
        "FacetAdded",
        "FacetAdded",
      ]);
      expect(history.events.slice(0, 7).map((event) => event.blockNumber)).toEqual([...harness.upgradeBlocks].reverse());
      expect(history.events[7].blockNumber).toBeLessThan(harness.upgradeBlocks[0]);

      const parameterValues = (index: number) => history.events[index].parameters.map((parameter) => parameter.value);
      expect(parameterValues(0)[0]).toBe(harness.facetAddresses.HistoryInitializer);
      expect(parameterValues(0)[1]).toMatch(/^0x[0-9a-f]{8}$/);
      expect(parameterValues(1)[1]).toBe("0x1234");
      expect(parameterValues(2)).toEqual([harness.facetAddresses.HistoryFacetC]);
      expect(parameterValues(3)).toEqual([
        harness.facetAddresses.HistoryFacetB,
        harness.facetAddresses.HistoryFacetB2,
      ]);
      expect(history.events.slice(4, 7).map((event) => event.parameters[0].value)).toEqual([
        harness.facetAddresses.HistoryFacetC,
        harness.facetAddresses.HistoryFacetB,
        harness.facetAddresses.HistoryFacetA,
      ]);
      expect(parameterValues(7)).toEqual([harness.facetAddresses.DiamondUpgradeFacet]);

      const marker = keccak256(stringToHex("history.initialized"));
      const value = await harness.rpc("eth_getStorageAt", [harness.diamond, marker, "latest"]);
      expect(BigInt(value as string)).toBe(1n);

      const output = printed.mock.calls.map(([line]) => String(line)).join("\n");
      for (const name of ["FacetAdded", "FacetReplaced", "FacetRemoved", "DiamondMetadata", "DiamondDelegateCall"]) {
        expect(output).toContain(`Event: ${name}`);
      }
      expect(output).toContain("Data: 0x1234");
      expect(output).toContain("Selectors: 0x");
      expect(output).not.toContain("Selectors: unavailable");

      const cliOutput = await harness.runHistory();
      expect((cliOutput.match(/Event: FacetAdded/g) ?? []).length).toBe(4);
      for (const name of ["FacetReplaced", "FacetRemoved", "DiamondMetadata", "DiamondDelegateCall"]) {
        expect(cliOutput).toContain(`Event: ${name}`);
      }
      expect(cliOutput).toContain("Selectors: 0x");
    } finally {
      process.chdir(previousDirectory);
      printed.mockRestore();
      await harness.cleanup();
    }
  }, 60_000);
});
