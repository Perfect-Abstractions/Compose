import { describe, expect, it, vi } from "vitest";
import { Context } from "../../../src/context/context";
import { showReport } from "../../../src/modules/validation/output";

describe("validation output", () => {
  it("reports selector and storage failures in the same run", async () => {
    const ctx = Context.create();
    ctx.state.validationSelectorCollisions = {
      success: false,
      result: { checkedFacets: 2, collisions: [] },
      error: {
        code: "SELECTOR_COLLISION_DETECTED",
        message: "selector failure",
        nativeError: null,
      },
    };
    ctx.state.validationVirtualStorageLayout = {
      success: false,
      result: { records: [], warnings: [], collisions: [] },
      error: {
        code: "VIRTUAL_STORAGE_COLLISION_DETECTED",
        message: "storage failure",
        nativeError: null,
      },
    };
    const output = vi.spyOn(console, "error").mockImplementation(() => undefined);

    try {
      await showReport(ctx);

      const messages = output.mock.calls.flat().map(String);
      expect(messages.some((message) => message.includes("selector failure"))).toBe(true);
      expect(messages.some((message) => message.includes("storage failure"))).toBe(true);
    } finally {
      output.mockRestore();
    }
  });

  it("reports only the conflicting virtual layout position", async () => {
    const ctx = Context.create();
    ctx.state.validationVirtualStorageLayout = {
      success: false,
      result: {
        records: [],
        warnings: [],
        collisions: [{
          id: "erc20",
          reason: "normal layout is not append-only compatible",
          records: [
            storageRecord("ERC20DataFacet", "ERC20DataFacet.sol", ["0xf1", "0x03"]),
            storageRecord("ERC20ApproveFacet", "ERC20ApproveFacet.sol", ["0xf1", "0x03"]),
            storageRecord("ERC20IdentifierCollisionError", "Collision.sol", ["0x2f", "0xf1"]),
          ],
        }],
      },
      error: {
        code: "VIRTUAL_STORAGE_COLLISION_DETECTED",
        message: "storage failure",
        nativeError: null,
      },
    };
    const output = vi.spyOn(console, "error").mockImplementation(() => undefined);

    try {
      await showReport(ctx);

      const messages = output.mock.calls.flat().map(String);
      expect(messages).toContain("\nerc20: layout position 0");
      expect(messages).toContain("  ERC20DataFacet: 0xf1");
      expect(messages).toContain("  ERC20IdentifierCollisionError: 0x2f");
      expect(messages.some((message) => message.includes("ERC20ApproveFacet"))).toBe(false);
      expect(messages.some((message) => message.includes("[0xf1"))).toBe(false);
    } finally {
      output.mockRestore();
    }
  });
});

function storageRecord(contractName: string, sourceName: string, layout: string[]) {
  return {
    id: "erc20",
    kind: "normal" as const,
    codeWidth: 1 as const,
    layout,
    serializedLayout: ["0x01", ...layout],
    slots: [],
    source: "slot-assignment" as const,
    sourceName,
    contractName,
    structName: "Data",
  };
}
