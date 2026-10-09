import { describe, expect, it, vi } from "vitest";
import { showSelectors } from "../../../src/modules/selectors/output";

describe("showSelectors", () => {
  it("groups signatures by facet and marks unknown selectors", () => {
    const log = vi.spyOn(console, "log").mockImplementation(() => {});
    try {
      showSelectors({
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
      expect(output).toContain("facets()");
      expect(output).toContain("Unknown signature");
      expect(output).toContain("0xdeadbeef");
    } finally {
      log.mockRestore();
    }
  });
});
