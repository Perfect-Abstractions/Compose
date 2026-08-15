import { describe, expect, it, vi } from "vitest";
import { Context } from "../../../src/context/context";
import { DependencyKey } from "../../../src/resolver/dependencyKey";

const mocks = vi.hoisted(() => ({
  resolveChainConfig: vi.fn(),
  resolve: vi.fn(),
  showRPCCheck: vi.fn(),
}));

vi.mock("../../../src/utils/chainConfig", () => ({ resolveChainConfig: mocks.resolveChainConfig }));
vi.mock("../../../src/resolver/dependencyResolver", () => ({ DependencyResolver: { resolve: mocks.resolve } }));
vi.mock("../../../src/modules/rpc/output", () => ({ showRPCCheck: mocks.showRPCCheck }));

import { RPCPipeline } from "../../../src/pipelines/rpcPipeline";

describe("RPCPipeline", () => {
  it("checks connectivity and optional contract bytecode through the resolver", async () => {
    const getCode = vi.fn().mockResolvedValue("0x6000");
    mocks.resolveChainConfig.mockResolvedValue({ chainKey: "sepolia", rpcUrl: "https://rpc.example", chainId: 11155111 });
    mocks.resolve.mockResolvedValue({ [DependencyKey.RPC]: { getCode } });
    const ctx = Context.create();
    ctx.param = {
      chain: "sepolia",
      address: "0x0000000000000000000000000000000000000001",
    };

    const result = await RPCPipeline.execute(ctx);

    expect(mocks.resolve).toHaveBeenCalledWith([{
      key: DependencyKey.RPC,
      params: { chainKey: "sepolia" },
    }]);
    expect(getCode).toHaveBeenCalledWith("0x0000000000000000000000000000000000000001");
    expect(result.state.rpcCheck).toMatchObject({
      success: true,
      result: { chainKey: "sepolia", chainId: 11155111, hasCode: true },
    });
    expect(mocks.showRPCCheck).toHaveBeenCalledOnce();
  });
});
