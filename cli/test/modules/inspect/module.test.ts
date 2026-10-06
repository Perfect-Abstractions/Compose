import { describe, expect, it, vi } from "vitest";
import { Context } from "../../../src/context/context";
import { decodeSelector } from "../../../src/modules/inspect/selectorDecoder";
import type { IDiamondAdapter } from "../../../src/adapters/IDiamondAdapter/interface";

const mocks = vi.hoisted(() => ({
  showInspect: vi.fn(),
}));

vi.mock("../../../src/modules/inspect/output", () => ({ showInspect: mocks.showInspect }));

import { InspectModule } from "../../../src/modules/inspect/module";

const VALID_ADDRESS = "0x0000000000000000000000000000000000000001";
const chain = { chainKey: "sepolia", rpcUrl: "https://rpc.example", chainId: 11155111 };

function diamondAdapter(facets: ReturnType<typeof vi.fn>): IDiamondAdapter {
  return { facets } as unknown as IDiamondAdapter;
}

describe("InspectModule", () => {
  it("inspects a diamond and displays facets", async () => {
    const facets = vi.fn().mockResolvedValue([
      {
        facet: "0x0000000000000000000000000000000000000002",
        functionSelectors: ["0x313ce567", "0x18160ddd"],
      },
      {
        facet: "0x0000000000000000000000000000000000000003",
        functionSelectors: ["0x095ea7b3"],
      },
    ]);

    const ctx = Context.create();
    ctx.param = { address: VALID_ADDRESS, chain: "sepolia" };

    const result = await InspectModule.inspect(ctx, diamondAdapter(facets), chain);

    expect(facets).toHaveBeenCalledWith(VALID_ADDRESS);
    expect(result.state.inspect).toMatchObject({
      success: true,
      result: {
        diamond: VALID_ADDRESS,
        chainKey: "sepolia",
        chainId: 11155111,
        facets: [
          { address: "0x0000000000000000000000000000000000000002", index: 0, selectors: expect.any(Array) },
          { address: "0x0000000000000000000000000000000000000003", index: 1, selectors: expect.any(Array) },
        ],
      },
    });
    expect(mocks.showInspect).toHaveBeenCalledOnce();
  });

  it("throws RPC_INVALID_ADDRESS for an invalid address", async () => {
    const ctx = Context.create();
    ctx.param = { address: "not-an-address", chain: "sepolia" };

    await expect(InspectModule.inspect(ctx, diamondAdapter(vi.fn()), chain)).rejects.toMatchObject({
      code: "RPC_INVALID_ADDRESS",
    });
  });

  it("throws RPC_CONTRACT_NOT_FOUND when no bytecode exists", async () => {
    const facets = vi.fn().mockRejectedValue(Object.assign(new Error("No contract code found"), {
      code: "RPC_CONTRACT_NOT_FOUND",
    }));

    const ctx = Context.create();
    ctx.param = { address: VALID_ADDRESS, chain: "local" };

    await expect(InspectModule.inspect(ctx, diamondAdapter(facets), chain)).rejects.toMatchObject({
      code: "RPC_CONTRACT_NOT_FOUND",
    });
  });

  it("defaults chain to local when not provided", async () => {
    const facets = vi.fn().mockResolvedValue([]);

    const ctx = Context.create();
    ctx.param = { address: VALID_ADDRESS };

    const result = await InspectModule.inspect(ctx, diamondAdapter(facets), {
      ...chain, chainKey: "local", chainId: 31337,
    });

    expect(result.state.inspect).toMatchObject({
      success: true,
      result: { chainKey: "local", facets: [] },
    });
  });

  it("propagates RPC readContract failures", async () => {
    const facets = vi.fn().mockRejectedValue(new Error("execution reverted"));

    const ctx = Context.create();
    ctx.param = { address: VALID_ADDRESS, chain: "local" };

    await expect(InspectModule.inspect(ctx, diamondAdapter(facets), chain)).rejects.toThrow("execution reverted");
  });
});

describe("decodeSelector", () => {
  it("decodes Diamond introspection selectors", () => {
    expect(decodeSelector("0x7a0ed627")).toBe("facets()");
    expect(decodeSelector("0x52ef6b2c")).toBe("facetAddresses()");
    expect(decodeSelector("0xadfca15e")).toBe("facetFunctionSelectors(address)");
    expect(decodeSelector("0xcdffacc6")).toBe("facetAddress(bytes4)");
  });

  it("decodes common ERC selectors", () => {
    expect(decodeSelector("0x313ce567")).toBe("decimals()");
    expect(decodeSelector("0x18160ddd")).toBe("totalSupply()");
    expect(decodeSelector("0x095ea7b3")).toBe("approve(address,uint256)");
  });

  it("decodes Compose library selectors", () => {
    expect(decodeSelector("0xf2fde38b")).toBe("transferOwnership(address)");
    expect(decodeSelector("0x8da5cb5b")).toBe("owner()");
    expect(decodeSelector("0x715018a6")).toBe("renounceOwnership()");
  });

  it("returns raw hex for unknown selectors", () => {
    expect(decodeSelector("0xdeadbeef")).toBe("0xdeadbeef");
  });

  it("handles selectors case-insensitively", () => {
    expect(decodeSelector("0x313CE567")).toBe("decimals()");
  });
});
