import fs from "node:fs/promises";
import path from "node:path";
import { describe, expect, it, vi } from "vitest";
import { ValidatePipeline } from "../../../src/pipelines/validatePipeline";
import { findVirtualStorageLayoutCollisions } from "../../../src/modules/validation/virtualStorageLayout";
import { ValidationModule } from "../../../src/modules/validation/module";
import { createValidatePipelineHarness } from "./harness";

describe("validate pipeline", () => {
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
        "compose.fixture.virtual-storage.368 | ContainerChild.amount: uint256 | ContainerChild.amount: address",
        "compose.fixture.virtual-storage.369 | ContainerChild.amount: uint256 | ContainerChild.amount: address",
        "compose.fixture.virtual-storage.370 | ContainerChild.amount: uint256 | ContainerChild.amount: address",
        "compose.fixture.virtual-storage.374 | ContainerChild.amount: uint256 | ContainerChild.amount: address",
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
      expect(output.filter((message) => message === "")).toHaveLength(11);
      expect(output.filter((message) => message === `  ${"─".repeat(48)}`)).toHaveLength(6);
      expect(output.filter((message) => message.includes("ContainerChild.amount"))).toHaveLength(8);
      expect(output.some((message) => message.includes("CompatibleStorageFacet:"))).toBe(false);
      expect(output.some((message) => message.includes("0xf1"))).toBe(false);
      expect(output.some((message) => message.includes("0x2f"))).toBe(false);
    } finally {
      errors.mockRestore();
      warnings.mockRestore();
      await harness.cleanup();
    }
  }, 30_000);
});
