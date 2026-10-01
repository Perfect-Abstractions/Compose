import { describe, expect, it, vi } from "vitest";
import type { Address, Hex } from "viem";
import { Context } from "../../../src/context/context";
import type { IBytecodeValidatorAdapter } from "../../../src/adapters/IBytecodeValidatorAdapter/interface";
import type { IRPCAdapter } from "../../../src/adapters/IRPCAdapter/interface";
import { BytecodeValidationModule } from "../../../src/modules/bytecodeValidation/module";

const diamond = "0x0000000000000000000000000000000000000001" as Address;
const facet = "0x0000000000000000000000000000000000000002" as Address;

function report(collisions: unknown[] = []) {
  return {
    collisions,
    validatedVariables: [],
    uncertainScopes: [],
    diagnostics: [],
    delegatecallWarnings: [],
  } as ReturnType<IBytecodeValidatorAdapter["validate"]>;
}

function setup() {
  const ctx = Context.create();
  ctx.param = {
    diamondName: "ExampleDiamond",
    chainKey: "local",
    diamondAddress: diamond,
    virtualStorageRecords: [],
  };
  const rpc: IRPCAdapter = {
    getBlockNumber: vi.fn().mockResolvedValue(100n),
    readContract: vi.fn().mockResolvedValue([{
      facet,
      functionSelectors: ["0x12345678"],
    }]),
    getCode: vi.fn().mockResolvedValue("0x6000" as Hex),
  };
  const validator: IBytecodeValidatorAdapter = {
    validate: vi.fn().mockReturnValue(report()),
  };
  return { ctx, rpc, validator };
}

describe("BytecodeValidationModule", () => {
  it("uses Diamond introspection and one pinned block", async () => {
    const { ctx, rpc, validator } = setup();
    const result = await BytecodeValidationModule.validateDeployment(ctx, { rpc, validator });

    expect(rpc.readContract).toHaveBeenCalledWith(expect.objectContaining({
      address: diamond,
      blockNumber: 100n,
      functionName: "facets",
    }), { verifyCode: true });
    expect(rpc.getCode).toHaveBeenCalledWith(facet, 100n);
    expect(validator.validate).toHaveBeenCalledOnce();
    expect(result.state.bytecodeDeploymentValidation.success).toBe(true);
  });

  it("reports introspection errors without blocking validation", async () => {
    const { ctx, rpc, validator } = setup();
    vi.mocked(rpc.readContract).mockRejectedValue(new Error("packed selectors are invalid"));

    const result = await BytecodeValidationModule.validateDeployment(ctx, { rpc, validator });
    const state = result.state.bytecodeDeploymentValidation;

    expect(state.success).toBe(true);
    expect(state.result).toMatchObject({
      complete: false,
      introspectionError: "packed selectors are invalid",
      facets: [],
    });
    expect(validator.validate).not.toHaveBeenCalled();
  });

  it("blocks only when the validator proves a collision", async () => {
    const { ctx, rpc, validator } = setup();
    ctx.param.virtualStorageRecords = [{
      id: "0x01",
      virtualPath: "example.storage",
      parentVirtualPath: null,
      kind: "normal",
      codeWidth: 1,
      layout: ["0x2f"],
      serializedLayout: ["0x01", "0x2f"],
      slots: [[256]],
      source: "erc8042",
      sourceName: "src/ExampleFacet.sol",
      contractName: "ExampleFacet",
      structName: "Storage",
    }];
    vi.mocked(validator.validate).mockReturnValue(report([{
      location: { slot: "0", offset: 0, selector: "12345678", symbolicPath: "slot(0)" },
      virtualPath: "example.storage",
      expectedType: "uint256",
      observedType: "address",
      reason: "type mismatch",
    }]));

    const result = await BytecodeValidationModule.validateDeployment(ctx, { rpc, validator });

    expect(result.state.bytecodeDeploymentValidation.success).toBe(false);
    expect(result.state.bytecodeDeploymentValidation.error?.code).toBe(
      "BYTECODE_STORAGE_COLLISION_DETECTED",
    );
    expect(result.state.bytecodeDeploymentValidation.result).toMatchObject({
      facets: [{ report: { collisions: [{ sourceNames: ["src/ExampleFacet.sol"] }] } }],
    });
  });

  it.each([
    ["an undefined response", undefined],
    ["empty runtime bytecode", "0x" as Hex],
  ])("marks validation incomplete without failing for %s", async (_case, bytecode) => {
    const { ctx, rpc, validator } = setup();
    vi.mocked(rpc.getCode).mockResolvedValue(bytecode);

    const result = await BytecodeValidationModule.validateDeployment(ctx, { rpc, validator });
    const state = result.state.bytecodeDeploymentValidation;

    expect(state.success).toBe(true);
    expect(state.result).toMatchObject({ complete: false });
    expect((state.result as { facets: Array<{ uncertain: string }> }).facets[0].uncertain)
      .toContain("this facet was not validated");
    expect(validator.validate).not.toHaveBeenCalled();
  });

  it("continues after an individual facet cannot be analyzed", async () => {
    const { ctx, rpc, validator } = setup();
    const secondFacet = "0x0000000000000000000000000000000000000003" as Address;
    vi.mocked(rpc.readContract).mockResolvedValue([
      { facet, functionSelectors: [] },
      { facet: secondFacet, functionSelectors: [] },
    ] as never);
    vi.mocked(rpc.getCode)
      .mockRejectedValueOnce(new Error("code unavailable"))
      .mockResolvedValueOnce("0x6000");

    const result = await BytecodeValidationModule.validateDeployment(ctx, { rpc, validator });
    const state = result.state.bytecodeDeploymentValidation;

    expect(state.success).toBe(false);
    expect((state.result as { facets: Array<{ error: string | null }> }).facets[0].error)
      .toBe("code unavailable");
    expect(validator.validate).toHaveBeenCalledOnce();
  });
});
