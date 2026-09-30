import { describe, expect, it } from "vitest";
import {
  BytecodeValidatorAdapter,
  formatSymbolicStoragePath,
} from "../../../src/adapters/IBytecodeValidatorAdapter/adapter";

describe("BytecodeValidatorAdapter", () => {
  it("runs the packaged WASM validator through the CLI boundary", () => {
    const report = BytecodeValidatorAdapter.validate({
      bytecode: "0x6000600055",
      virtualStorageLayout: { records: [] },
    });

    expect(report).toEqual({
      collisions: expect.any(Array),
      validatedVariables: expect.any(Array),
      uncertainScopes: expect.any(Array),
      diagnostics: expect.any(Array),
      delegatecallWarnings: expect.any(Array),
    });
  });

  it("formats plain byte-array slots as readable hex", () => {
    expect(formatSymbolicStoragePath(
      "Plain([208, 192, 207, 159, 68, 4, 30, 38, 148, 81, 176, 16, 155, 218, 207, 239, 134, 70, 39, 202, 210, 195, 121, 156, 43, 94, 12, 108, 34, 175, 0, 119])",
    )).toBe("Plain(0xd0c0cf9f44041e269451b0109bdacfef864627cad2c3799c2b5e0c6c22af0077)");
  });

  it("preserves other symbolic paths", () => {
    expect(formatSymbolicStoragePath("Plain([1, 2, 3]) + keccak(key)"))
      .toBe("Plain([1, 2, 3]) + keccak(key)");
    expect(formatSymbolicStoragePath("Plain([256, 0])"))
      .toBe("Plain([256, 0])");
  });
});
