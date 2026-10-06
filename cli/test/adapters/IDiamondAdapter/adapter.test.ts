import { describe, expect, it, vi } from "vitest";
import { encodeFunctionData, type Address, type Hex } from "viem";
import type { IRPCAdapter } from "../../../src/adapters/IRPCAdapter/interface";
import { createDiamondAdapter } from "../../../src/adapters/IDiamondAdapter/adapter";
import { DIAMOND_INSPECT_ABI } from "../../../src/adapters/IDiamondAdapter/abi";

const diamondAddress = "0x0000000000000000000000000000000000000001" as Address;
const facetAddress = "0x0000000000000000000000000000000000000002" as Address;
const selector = "0x12345678" as Hex;

function setup() {
  const readContract = vi.fn();
  const rpc = { readContract } as unknown as IRPCAdapter;
  return { adapter: createDiamondAdapter(rpc), readContract };
}

describe("IDiamondAdapter", () => {
  it("uses the selectors exposed by DiamondInspectFacet", () => {
    expect(encodeFunctionData({ abi: DIAMOND_INSPECT_ABI, functionName: "facets" })).toBe("0x7a0ed627");
    expect(encodeFunctionData({ abi: DIAMOND_INSPECT_ABI, functionName: "facetAddresses" })).toBe("0x52ef6b2c");
    expect(encodeFunctionData({ abi: DIAMOND_INSPECT_ABI, functionName: "facetFunctionSelectors", args: [facetAddress] }).slice(0, 10)).toBe("0xadfca15e");
    expect(encodeFunctionData({ abi: DIAMOND_INSPECT_ABI, functionName: "facetAddress", args: [selector] }).slice(0, 10)).toBe("0xcdffacc6");
  });

  it("reads facets with the shared tuple shape and verifies diamond code", async () => {
    const { adapter, readContract } = setup();
    const facets = [{ facet: facetAddress, functionSelectors: [selector] }];
    readContract.mockResolvedValue(facets);

    await expect(adapter.facets(diamondAddress, { blockNumber: 100n })).resolves.toEqual(facets);
    expect(readContract).toHaveBeenCalledWith({
      address: diamondAddress,
      abi: expect.arrayContaining([expect.objectContaining({ name: "facets" })]),
      functionName: "facets",
      blockNumber: 100n,
    }, { verifyCode: true });
  });

  it("reads all facet addresses", async () => {
    const { adapter, readContract } = setup();
    readContract.mockResolvedValue([facetAddress]);

    await expect(adapter.facetAddresses(diamondAddress)).resolves.toEqual([facetAddress]);
    expect(readContract).toHaveBeenCalledWith(expect.objectContaining({
      address: diamondAddress,
      functionName: "facetAddresses",
    }), { verifyCode: true });
  });

  it("reads the selectors owned by one facet", async () => {
    const { adapter, readContract } = setup();
    readContract.mockResolvedValue([selector]);

    await expect(adapter.facetFunctionSelectors(diamondAddress, facetAddress)).resolves.toEqual([selector]);
    expect(readContract).toHaveBeenCalledWith(expect.objectContaining({
      address: diamondAddress,
      functionName: "facetFunctionSelectors",
      args: [facetAddress],
    }), { verifyCode: true });
  });

  it("reads selector ownership, including an unowned selector", async () => {
    const { adapter, readContract } = setup();
    const empty = "0x0000000000000000000000000000000000000000";
    readContract.mockResolvedValue(empty);

    await expect(adapter.facetAddress(diamondAddress, selector)).resolves.toBe(empty);
    expect(readContract).toHaveBeenCalledWith(expect.objectContaining({
      address: diamondAddress,
      functionName: "facetAddress",
      args: [selector],
    }), { verifyCode: true });
  });

  it("passes through missing-code and RPC errors from the RPC adapter", async () => {
    const { adapter, readContract } = setup();
    const error = Object.assign(new Error("No contract code found"), { code: "RPC_CONTRACT_NOT_FOUND" });
    readContract.mockRejectedValue(error);

    await expect(adapter.facets(diamondAddress)).rejects.toBe(error);
  });
});
