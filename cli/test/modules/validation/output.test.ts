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
      result: { records: [], warnings: [], collisions: [], unsupported: [] },
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

  it("reports conflicting storage variables without exposing virtual type codes", async () => {
    const ctx = Context.create();
    ctx.state.validationVirtualStorageLayout = {
      success: false,
      result: {
        records: [],
        warnings: [],
        unsupported: [],
        collisions: [{
          id: "0x5a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc9",
          virtualPath: "erc20",
          reason: "normal layout is not append-only compatible",
          mismatches: [{
            position: 0,
            left: {
              contractName: "ERC20DataFacet",
              structName: "ERC20Storage",
              variableName: "balanceOf",
              typeName: "mapping(address => uint256)",
              storagePath: "ERC20Storage.balanceOf",
              sourceName: "ERC20DataFacet.sol",
            },
            right: {
              contractName: "ERC20IdentifierCollisionError",
              structName: "Data",
              variableName: "value",
              typeName: "uint256",
              storagePath: "Data.value",
              sourceName: "Collision.sol",
            },
          }],
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
      expect(messages).toContain("\nerc20");
      expect(messages).toContain("  ERC20DataFacet: ERC20Storage.balanceOf");
      expect(messages).toContain("      Type: mapping(address => uint256)");
      expect(messages).toContain("      Storage path: ERC20Storage.balanceOf");
      expect(messages).toContain("  ERC20IdentifierCollisionError: Data.value");
      expect(messages).toContain("      Type: uint256");
      expect(messages.some((message) => message.includes("0xf1"))).toBe(false);
      expect(messages.some((message) => message.includes("0x2f"))).toBe(false);
    } finally {
      output.mockRestore();
    }
  });

  it("reports unknown storage compatibility as incomplete instead of passed or collided", async () => {
    const ctx = Context.create();
    const records = [
      storageRecord("KnownFacet", "KnownFacet.sol", ["0x2f", "0x03"]),
      storageRecord("UnknownFacet", "UnknownFacet.sol", ["0x2f", "0xfe"]),
    ];
    ctx.state.validationVirtualStorageLayout = {
      success: false,
      result: {
        records,
        warnings: [],
        collisions: [],
        unsupported: [{
          id: records[0].id,
          virtualPath: "erc20",
          reason: "layout contains an unknown storage type",
          records,
          variables: [{
            contractName: "UnknownFacet",
            structName: "Data",
            variableName: "value",
            typeName: "unknown",
            storagePath: "Data.value",
            sourceName: "UnknownFacet.sol",
          }],
        }],
      },
      error: {
        code: "VIRTUAL_STORAGE_LAYOUT_UNSUPPORTED",
        message: "Storage layout compatibility could not be proven.",
        nativeError: null,
      },
    };
    const warnings = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const errors = vi.spyOn(console, "error").mockImplementation(() => undefined);

    try {
      await showReport(ctx);

      const messages = warnings.mock.calls.flat().map(String);
      expect(messages.some((message) => message.includes("Validation incomplete"))).toBe(true);
      expect(messages.some(
        (message) => message.includes("Storage layout compatibility could not be proven."),
      )).toBe(true);
      expect(messages.some((message) => message.includes("UnknownFacet: Data.value"))).toBe(true);
      expect(messages.some((message) => message.includes("Storage path: Data.value"))).toBe(true);
      expect(errors).not.toHaveBeenCalled();
    } finally {
      warnings.mockRestore();
      errors.mockRestore();
    }
  });

  it("reports collisions and uncertain storage in the same run", async () => {
    const ctx = Context.create();
    const records = [
      storageRecord("KnownFacet", "KnownFacet.sol", ["0x2f", "0x03"]),
      storageRecord("UnknownFacet", "UnknownFacet.sol", ["0x2f", "0xfe"]),
    ];
    ctx.state.validationVirtualStorageLayout = {
      success: false,
      result: {
        records,
        warnings: [],
        collisions: [{
          id: records[0].id,
          virtualPath: "erc20",
          reason: "normal layout is not append-only compatible",
          records,
          mismatches: [],
        }],
        unsupported: [{
          id: records[0].id,
          virtualPath: "erc20",
          reason: "layout contains an unknown storage type",
          records,
          variables: [],
        }],
      },
      error: {
        code: "VIRTUAL_STORAGE_COLLISION_DETECTED",
        message: "Selected facets declare incompatible storage layouts.",
        nativeError: null,
      },
    };
    const warnings = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const errors = vi.spyOn(console, "error").mockImplementation(() => undefined);

    try {
      await showReport(ctx);

      expect(errors.mock.calls.flat().map(String).some(
        (message) => message.includes("Validation failed"),
      )).toBe(true);
      expect(warnings.mock.calls.flat().map(String).some(
        (message) => message.includes("Validation incomplete"),
      )).toBe(true);
    } finally {
      warnings.mockRestore();
      errors.mockRestore();
    }
  });
});

function storageRecord(contractName: string, sourceName: string, layout: string[]) {
  return {
    id: "0x5a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc9",
    virtualPath: "erc20",
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
