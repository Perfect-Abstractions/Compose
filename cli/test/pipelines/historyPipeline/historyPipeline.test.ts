import { describe, expect, it, vi } from "vitest";
import { Context } from "../../../src/context/context";
import { DependencyKey } from "../../../src/resolver/dependencyKey";

const mocks = vi.hoisted(() => ({
  resolveChainConfig: vi.fn(),
  resolve: vi.fn(),
  list: vi.fn(),
}));

vi.mock("../../../src/utils/chainConfig", () => ({ resolveChainConfig: mocks.resolveChainConfig }));
vi.mock("../../../src/resolver/dependencyResolver", () => ({ DependencyResolver: { resolve: mocks.resolve } }));
vi.mock("../../../src/modules/history/module", () => ({ HistoryModule: { list: mocks.list } }));

import { HistoryPipeline } from "../../../src/pipelines/historyPipeline";

const address = "0x0000000000000000000000000000000000000001";

describe("HistoryPipeline", () => {
  it("validates the address before resolving a chain", async () => {
    const ctx = Context.create();
    ctx.param = { address: "invalid" };
    await expect(HistoryPipeline.execute(ctx)).rejects.toMatchObject({ code: "RPC_INVALID_ADDRESS" });
    expect(mocks.resolveChainConfig).not.toHaveBeenCalled();
  });

  it("resolves the RPC adapter and runs the history module", async () => {
    const ctx = Context.create();
    ctx.param = { address, chain: "sepolia" };
    const chain = { chainKey: "sepolia", chainId: 11155111, rpcUrl: "https://rpc.example" };
    const rpc = { getLogs: vi.fn() };
    mocks.resolveChainConfig.mockResolvedValue(chain);
    mocks.resolve.mockResolvedValue({ [DependencyKey.RPC]: rpc });
    mocks.list.mockResolvedValue(ctx);

    await expect(HistoryPipeline.execute(ctx)).resolves.toBe(ctx);
    expect(mocks.resolve).toHaveBeenCalledWith([{ key: DependencyKey.RPC, params: { chainKey: "sepolia" } }]);
    expect(mocks.list).toHaveBeenCalledWith(ctx, rpc, chain, address);
  });

  it("propagates unknown chains and RPC failures", async () => {
    const ctx = Context.create();
    ctx.param = { address, chain: "missing" };
    mocks.resolveChainConfig.mockRejectedValueOnce(new Error("Unknown chain"));
    await expect(HistoryPipeline.execute(ctx)).rejects.toThrow("Unknown chain");

    mocks.resolveChainConfig.mockResolvedValue({ chainKey: "local" });
    mocks.resolve.mockRejectedValueOnce(new Error("RPC unavailable"));
    await expect(HistoryPipeline.execute(ctx)).rejects.toThrow("RPC unavailable");
  });
});
