import { describe, expect, it, vi } from "vitest";
import { showInspect } from "../../../src/modules/inspect/output";

describe("showInspect", () => {
  it("shows known signatures and marks unknown selectors", () => {
    const log = vi.spyOn(console, "log").mockImplementation(() => {});
    try {
      showInspect({
        diamond: "0x0000000000000000000000000000000000000001",
        chainKey: "local",
        chainId: 31337,
        facets: [{
          address: "0x0000000000000000000000000000000000000002",
          index: 0,
          selectors: [
            { selector: "0x7a0ed627", signature: "facets()" },
            { selector: "0xdeadbeef", signature: "0xdeadbeef" },
          ],
        }],
      });

      const output = log.mock.calls.map(([line]) => line).join("\n");
      expect(output).toContain("1 facets");
      expect(output).toContain("2 selectors");
      expect(output).toContain("facets()");
      expect(output).toContain("0xdeadbeef");
      expect(output).toContain("Unknown signature");
    } finally {
      log.mockRestore();
    }
  });
});
