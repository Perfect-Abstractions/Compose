import fs from "node:fs/promises";
import path from "node:path";
import { describe, expect, it, vi } from "vitest";
import { ValidatePipeline } from "../../../src/pipelines/validatePipeline";
import { findVirtualStorageLayoutCollisions } from "../../../src/modules/validation/virtualStorageLayout";
import { ValidationModule } from "../../../src/modules/validation/module";
import { createValidatePipelineHarness } from "./harness";
import { DependencyResolver } from "../../../src/resolver/dependencyResolver";
import { DependencyKey } from "../../../src/resolver/dependencyKey";
import type { IRPCAdapter } from "../../../src/adapters/IRPCAdapter/interface";
import { createDiamondAdapter } from "../../../src/adapters/IDiamondAdapter/adapter";
import type { IBytecodeValidatorAdapter } from "../../../src/adapters/IBytecodeValidatorAdapter/interface";
import type { Address, Hex } from "viem";
import { BytecodeValidatorAdapter } from "../../../src/adapters/IBytecodeValidatorAdapter/adapter";

const diamondAddress = "0x0000000000000000000000000000000000000001" as Address;
const facetAddress = "0x0000000000000000000000000000000000000002" as Address;

function deployment() {
  return {
    diamond: diamondAddress,
    facets: { ExampleFacet: facetAddress },
    facetHash: "0x01",
    lastSync: "2026-09-20T00:00:00.000Z",
    txHash: "0x02",
  };
}

function bytecodeDependencies(report: ReturnType<IBytecodeValidatorAdapter["validate"]>) {
  const rpc: IRPCAdapter = {
    getBlockNumber: vi.fn().mockResolvedValue(100n),
    readContract: vi.fn().mockResolvedValue([{
      facet: facetAddress,
      functionSelectors: ["0x12345678"],
    }]),
    getCode: vi.fn().mockResolvedValue("0x6000" as Hex),
    getLogs: vi.fn(),
    getBlockTimestamp: vi.fn(),
  };
  const validator: IBytecodeValidatorAdapter = {
    validate: vi.fn().mockReturnValue(report),
  };
  return { rpc, validator };
}

function emptyReport() {
  return {
    collisions: [],
    validatedVariables: [],
    uncertainScopes: [],
    diagnostics: [],
    delegatecallWarnings: [],
  };
}

describe("validate pipeline", () => {
  it("passes source validation and skips bytecode validation when compose.lock is absent", async () => {
    const harness = await createValidatePipelineHarness([
      "FullStorageFacet",
      "CompatibleStorageFacet",
    ]);
    const logs = vi.spyOn(console, "log").mockImplementation(() => undefined);

    try {
      const result = await ValidatePipeline.execute(harness.ctx);
      expect(result.state.validatePipeline?.success).toBe(true);
      expect(result.state.bytecodeValidation).toMatchObject({
        success: true,
        result: { skipped: true, deployments: [], failures: [] },
      });
      expect(logs.mock.calls.flat().map(String)).toContain("\u001b[32m\nValidation passed.\n\u001b[39m");
    } finally {
      logs.mockRestore();
      await harness.cleanup();
    }
  }, 30_000);

  it("validates introspected facets against the diamond VSL without blocking warnings", async () => {
    const harness = await createValidatePipelineHarness([
      "FullStorageFacet",
      "CompatibleStorageFacet",
    ]);
    await harness.writeLock({ StorageDiamond: { local: deployment() } });
    const report = {
      ...emptyReport(),
      uncertainScopes: [
        {
          location: { slot: "0", offset: 0, selector: "12345678", pc: 42, symbolicPath: "slot(0)" },
          virtualPath: "compose.fixture.virtual-storage",
          reason: "Scoped evidence is incomplete.",
        },
        {
          location: { slot: "0", offset: 0, selector: "87654321", pc: 84, symbolicPath: "slot(0)" },
          virtualPath: "compose.fixture.virtual-storage",
          reason: "Scoped evidence is incomplete.",
        },
      ],
    };
    const { rpc, validator } = bytecodeDependencies(report);
    const originalResolve = DependencyResolver.resolve.bind(DependencyResolver);
    const resolver = vi.spyOn(DependencyResolver, "resolve").mockImplementation(async (requests) => {
      if (requests.some((request) => request.key === DependencyKey.BytecodeValidator)) {
        return {
          [DependencyKey.RPC]: rpc,
          [DependencyKey.Diamond]: createDiamondAdapter(rpc),
          [DependencyKey.BytecodeValidator]: validator,
        };
      }
      return originalResolve(requests);
    });
    const warnings = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const logs = vi.spyOn(console, "log").mockImplementation(() => undefined);

    try {
      const result = await ValidatePipeline.execute(harness.ctx);
      expect(result.state.validatePipeline?.success).toBe(true);
      expect(validator.validate).toHaveBeenCalledWith(expect.objectContaining({
        virtualStorageLayout: {
          records: expect.arrayContaining([
            expect.objectContaining({ diamondName: "StorageDiamond" }),
          ]),
        },
      }));
      expect(rpc.getCode).toHaveBeenCalledWith(facetAddress, 100n);
      const warningOutput = warnings.mock.calls.flat().map(String);
      expect(warningOutput).toContain(
        "\u001b[33m  Scoped evidence is incomplete.\u001b[39m",
      );
      expect(warningOutput).toContain("  compose.fixture.virtual-storage");
      expect(warningOutput.filter((line) => line.includes("Bytecode validation warning")))
        .toHaveLength(1);
      const reasonIndex = warningOutput.findIndex((line) => line.includes("Scoped evidence is incomplete."));
      const pathIndex = warningOutput.findIndex((line) => line.includes("compose.fixture.virtual-storage"));
      expect(reasonIndex).toBeGreaterThan(-1);
      expect(reasonIndex).toBeLessThan(pathIndex);
    } finally {
      resolver.mockRestore();
      warnings.mockRestore();
      logs.mockRestore();
      await harness.cleanup();
    }
  }, 30_000);

  it("completes with warnings when an introspected facet has no runtime bytecode", async () => {
    const harness = await createValidatePipelineHarness([
      "FullStorageFacet",
      "CompatibleStorageFacet",
    ]);
    await harness.writeLock({ StorageDiamond: { local: deployment() } });
    const { rpc, validator } = bytecodeDependencies(emptyReport());
    vi.mocked(rpc.getCode).mockResolvedValue("0x");
    const originalResolve = DependencyResolver.resolve.bind(DependencyResolver);
    const resolver = vi.spyOn(DependencyResolver, "resolve").mockImplementation(async (requests) => {
      if (requests.some((request) => request.key === DependencyKey.BytecodeValidator)) {
        return {
          [DependencyKey.RPC]: rpc,
          [DependencyKey.Diamond]: createDiamondAdapter(rpc),
          [DependencyKey.BytecodeValidator]: validator,
        };
      }
      return originalResolve(requests);
    });
    const warnings = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const logs = vi.spyOn(console, "log").mockImplementation(() => undefined);

    try {
      const result = await ValidatePipeline.execute(harness.ctx);
      expect(result.state.validatePipeline?.success).toBe(true);
      expect(result.state.bytecodeValidation).toMatchObject({
        success: true,
        result: { complete: false },
      });
      expect(validator.validate).not.toHaveBeenCalled();

      const warningOutput = warnings.mock.calls.flat().map(String);
      expect(warningOutput.some((message) => message.includes("Bytecode validation incomplete")))
        .toBe(true);
      expect(warningOutput).toContain("\u001b[33m\nValidation completed with warnings.\n\u001b[39m");
      expect(logs.mock.calls.flat().map(String)).not.toContain(
        "\u001b[32m\nValidation passed.\n\u001b[39m",
      );
    } finally {
      resolver.mockRestore();
      warnings.mockRestore();
      logs.mockRestore();
      await harness.cleanup();
    }
  }, 30_000);

  it("fails validation when deployed bytecode contradicts the diamond VSL", async () => {
    const harness = await createValidatePipelineHarness([
      "FullStorageFacet",
      "CompatibleStorageFacet",
    ]);
    await harness.writeLock({ StorageDiamond: { local: deployment() } });
    const collision = {
      location: { slot: "0", offset: 0, selector: "12345678", pc: 42, symbolicPath: "slot(0)" },
      virtualPath: "compose.fixture.virtual-storage",
      expectedType: "uint256",
      observedType: "address",
      reason: "type mismatch",
    };
    const { rpc, validator } = bytecodeDependencies({
      ...emptyReport(),
      collisions: [collision],
    });
    const originalResolve = DependencyResolver.resolve.bind(DependencyResolver);
    const resolver = vi.spyOn(DependencyResolver, "resolve").mockImplementation(async (requests) => {
      if (requests.some((request) => request.key === DependencyKey.BytecodeValidator)) {
        return {
          [DependencyKey.RPC]: rpc,
          [DependencyKey.Diamond]: createDiamondAdapter(rpc),
          [DependencyKey.BytecodeValidator]: validator,
        };
      }
      return originalResolve(requests);
    });
    const errors = vi.spyOn(console, "error").mockImplementation(() => undefined);

    try {
      const result = await ValidatePipeline.execute(harness.ctx);
      expect(result.state.validatePipeline?.success).toBe(false);
      expect(result.status.failedAt).toBe("validatePipeline");
      const output = errors.mock.calls.flat().map(String);
      expect(output).toEqual(expect.arrayContaining([
        "  compose.fixture.virtual-storage",
        "  Expected: uint256",
        "  Observed: address",
        "  PC: 42",
      ]));
      expect(output).toContain("  Affected:");
      expect(output.some((line) => line.startsWith("    - ") && line.includes("FullStorageFacet.sol")))
        .toBe(true);
      expect(output.some((line) => line.startsWith("    - ") && line.includes("CompatibleStorageFacet.sol")))
        .toBe(true);
      const reasonIndex = output.findIndex((line) => line.includes("type mismatch"));
      const pathIndex = output.indexOf("  compose.fixture.virtual-storage");
      expect(reasonIndex).toBeGreaterThan(-1);
      expect(reasonIndex).toBeLessThan(pathIndex);
    } finally {
      resolver.mockRestore();
      errors.mockRestore();
      await harness.cleanup();
    }
  }, 30_000);

  it("continues validating other deployments after one chain fails", async () => {
    const harness = await createValidatePipelineHarness([
      "FullStorageFacet",
      "CompatibleStorageFacet",
    ]);
    await harness.writeLock({
      StorageDiamond: {
        broken: deployment(),
        healthy: deployment(),
      },
    });
    const { rpc, validator } = bytecodeDependencies(emptyReport());
    const originalResolve = DependencyResolver.resolve.bind(DependencyResolver);
    const resolver = vi.spyOn(DependencyResolver, "resolve").mockImplementation(async (requests) => {
      if (requests.some((request) => request.key === DependencyKey.BytecodeValidator)) {
        const chainKey = requests.find((request) => request.key === DependencyKey.RPC)
          ?.params?.chainKey;
        if (chainKey === "broken") throw new Error("RPC unavailable");
        return {
          [DependencyKey.RPC]: rpc,
          [DependencyKey.Diamond]: createDiamondAdapter(rpc),
          [DependencyKey.BytecodeValidator]: validator,
        };
      }
      return originalResolve(requests);
    });
    const errors = vi.spyOn(console, "error").mockImplementation(() => undefined);

    try {
      const result = await ValidatePipeline.execute(harness.ctx);
      expect(result.state.validatePipeline?.success).toBe(false);
      expect(result.state.bytecodeValidation).toMatchObject({
        success: false,
        result: {
          deployments: [expect.objectContaining({ chainKey: "healthy" })],
          failures: [expect.objectContaining({
            chainKey: "broken",
            message: "RPC unavailable",
          })],
        },
      });
      expect(validator.validate).toHaveBeenCalledOnce();
    } finally {
      resolver.mockRestore();
      errors.mockRestore();
      await harness.cleanup();
    }
  }, 30_000);

  it("runs compiled facet bytecode through the packaged validator", async () => {
    const harness = await createValidatePipelineHarness(["FullStorageFacet"]);
    await harness.writeLock({ StorageDiamond: { local: deployment() } });
    const rpc: IRPCAdapter = {
      getBlockNumber: vi.fn().mockResolvedValue(100n),
      readContract: vi.fn().mockResolvedValue([{
        facet: facetAddress,
        functionSelectors: ["0x12345678"],
      }]),
      getCode: vi.fn(async () => {
        const artifact = JSON.parse(await fs.readFile(path.join(
          harness.projectRoot,
          "out",
          "FullStorageFacet.sol",
          "FullStorageFacet.json",
        ), "utf8")) as { deployedBytecode: { object: Hex } };
        return artifact.deployedBytecode.object;
      }),
      getLogs: vi.fn(),
      getBlockTimestamp: vi.fn(),
    };
    const originalResolve = DependencyResolver.resolve.bind(DependencyResolver);
    const resolver = vi.spyOn(DependencyResolver, "resolve").mockImplementation(async (requests) => {
      if (requests.some((request) => request.key === DependencyKey.BytecodeValidator)) {
        return {
          [DependencyKey.RPC]: rpc,
          [DependencyKey.Diamond]: createDiamondAdapter(rpc),
          [DependencyKey.BytecodeValidator]: BytecodeValidatorAdapter,
        };
      }
      return originalResolve(requests);
    });
    const warnings = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const logs = vi.spyOn(console, "log").mockImplementation(() => undefined);

    try {
      const result = await ValidatePipeline.execute(harness.ctx);
      expect(result.state.validatePipeline?.success).toBe(true);
      expect(result.state.bytecodeValidation).toMatchObject({
        success: true,
        result: {
          deployments: [{
            facets: [{
              report: { collisions: [] },
            }],
          }],
        },
      });
    } finally {
      resolver.mockRestore();
      warnings.mockRestore();
      logs.mockRestore();
      await harness.cleanup();
    }
  }, 30_000);

  it("compiles Solidity and reports only the incompatible storage variables", async () => {
    const harness = await createValidatePipelineHarness();
    const errors = vi.spyOn(console, "error").mockImplementation(() => undefined);
    const warnings = vi.spyOn(console, "warn").mockImplementation(() => undefined);

    try {
      const result = await ValidatePipeline.execute(harness.ctx);
      const validation = ValidationModule.getVirtualStorageLayoutValidationState(result);
      const collision = validation?.result?.collisions[0];
      const mismatchSummary = validation?.result?.collisions.flatMap((item) =>
        item.mismatches.map((mismatch) => [
          item.virtualPath,
          `${mismatch.left.structName}.${mismatch.left.variableName}: ${mismatch.left.typeName}`,
          `${mismatch.right.structName}.${mismatch.right.variableName}: ${mismatch.right.typeName}`,
        ].join(" | "))
      ) ?? [];
      const rootRecords = validation?.result?.records.filter(
        (record) => record.virtualPath === "compose.fixture.virtual-storage",
      ) ?? [];
      const recordFor = (contractName: string) => rootRecords.find(
        (record) => record.contractName === contractName,
      )!;

      expect(result.state.validatePipeline?.success).toBe(false);
      expect(validation?.success).toBe(false);
      expect(collision?.diamondName).toBe("StorageDiamond");
      expect(collision?.virtualPath).toBe("compose.fixture.virtual-storage");
      expect(collision?.records.map((record) => record.contractName).sort()).toEqual([
        "CompatibleStorageFacet",
        "FullStorageFacet",
        "IncompatibleStorageFacet",
      ]);
      expect(mismatchSummary).toEqual([
        "compose.fixture.virtual-storage | InlineChild.facetCount: uint32 | InlineChild.facetCount: uint64",
        "compose.fixture.virtual-storage | Storage.mapToDynamicArray: mapping(uint256 => uint256[]) | Storage.mapToDynamicArray: mapping(uint256 => address[])",
        "compose.fixture.virtual-storage | Storage.dynamicValues: uint256[] | Storage.dynamicValues: address[]",
        "compose.fixture.virtual-storage | Storage.packedDynamicValues: uint8[] | Storage.packedDynamicValues: uint16[]",
        "compose.fixture.virtual-storage | Storage.fixedFive: uint256[5] | Storage.fixedFive: address[5]",
        "compose.fixture.virtual-storage | Storage.fixedThreeHundred: uint256[300] | Storage.fixedThreeHundred: address[300]",
        "compose.fixture.virtual-storage | Storage.nestedFixed: uint256[5][10] | Storage.nestedFixed: address[5][10]",
        "compose.fixture.virtual-storage | Storage.internalFn: function (uint256) returns (uint256) | Storage.internalFn: uint256",
        "compose.fixture.virtual-storage.367 | ContainerChild.amount: uint256 | ContainerChild.amount: address",
        "compose.fixture.virtual-storage.368 | ContainerChild.amount: uint256 | ContainerChild.amount: address",
        "compose.fixture.virtual-storage.369 | ContainerChild.amount: uint256 | ContainerChild.amount: address",
        "compose.fixture.virtual-storage.373 | ContainerChild.amount: uint256 | ContainerChild.amount: address",
      ]);
      expect(findVirtualStorageLayoutCollisions([
        recordFor("FullStorageFacet"),
        recordFor("CompatibleStorageFacet"),
      ])).toEqual([]);
      expect(findVirtualStorageLayoutCollisions([
        recordFor("FullStorageFacet"),
        recordFor("IncompatibleStorageFacet"),
      ])).toHaveLength(1);
      await expect(fs.access(path.join(
        harness.projectRoot,
        "out",
        "FullStorageFacet.sol",
        "FullStorageFacet.json",
      ))).resolves.toBeUndefined();

      const output = errors.mock.calls.flat().map(String);
      expect(output).toContain("  FullStorageFacet: InlineChild.facetCount");
      expect(output).toContain("  IncompatibleStorageFacet: InlineChild.facetCount");
      expect(output).toContain("      Storage path: Storage.inlineStruct.child.facetCount");
      expect(output).toContain("  FullStorageFacet: Storage.fixedThreeHundred");
      expect(output).toContain("  IncompatibleStorageFacet: Storage.fixedThreeHundred");
      expect(output).toContain("      Storage path: Storage.fixedThreeHundred");
      expect(output).toContain("      Storage path: Storage.childByAddress[key].amount");
      expect(output).toContain("      Storage path: Storage.childList[index].amount");
      expect(output).toContain("      Storage path: Storage.fixedChildren[index].amount");
      expect(output).toContain("      Storage path: Storage.nestedChildren[key][index].amount");
      expect(output.filter((message) => message === "")).toHaveLength(12);
      expect(output.filter((message) => message === `  ${"─".repeat(48)}`)).toHaveLength(7);
      expect(output.filter((message) => message.includes("ContainerChild.amount"))).toHaveLength(8);
      expect(output.some((message) => message.includes("CompatibleStorageFacet:"))).toBe(false);
      expect(output.some((message) => message.includes("0xf1"))).toBe(false);
      expect(output.some((message) => message.includes("0x2f"))).toBe(false);

      const warningOutput = warnings.mock.calls.flat().map(String);
      expect(warningOutput.some(
        (message) => message.includes("FullStorageFacet: Storage.internalFn"),
      )).toBe(true);
      expect(warningOutput.some(
        (message) => message.includes("internal function storage type uses compiler-specific representation"),
      )).toBe(true);
    } finally {
      errors.mockRestore();
      warnings.mockRestore();
      await harness.cleanup();
    }
  }, 30_000);
});
