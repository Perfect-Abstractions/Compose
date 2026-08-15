import { describe, expect, it, vi } from "vitest";
import { Context } from "../../../src/context/context";
import { DependencyKey } from "../../../src/resolver/dependencyKey";

const mocks = vi.hoisted(() => ({
  resolveChainConfig: vi.fn(),
  resolve: vi.fn(),
  showInspect: vi.fn(),
}));

vi.mock("../../../src/utils/chainConfig", () => ({ resolveChainConfig: mocks.resolveChainConfig }));
vi.mock("../../../src/resolver/dependencyResolver", () => ({ DependencyResolver: { resolve: mocks.resolve } }));
vi.mock("../../../src/modules/inspect/output", () => ({ showInspect: mocks.showInspect }));

import { InspectPipeline } from "../../../src/pipelines/inspectPipeline";

describe("InspectPipeline", () => {
  it("delegates to InspectModule with valid address", async () => {
    const readContract = vi.fn().mockResolvedValue([
      { facet: "0x0000000000000000000000000000000000000002", functionSelectors: ["0x313ce567"] },
    ]);
    const getCode = vi.fn().mockResolvedValue("0x6000");
    mocks.resolveChainConfig.mockResolvedValue({ chainKey: "sepolia", rpcUrl: "https://rpc.example", chainId: 11155111 });
    mocks.resolve.mockResolvedValue({ [DependencyKey.RPC]: { readContract, getCode } });

    const ctx = Context.create();
    ctx.param = {
      address: "0x0000000000000000000000000000000000000001",
      chain: "sepolia",
    };

    const result = await InspectPipeline.execute(ctx);

    expect(mocks.resolve).toHaveBeenCalledWith([{
      key: DependencyKey.RPC,
      params: { chainKey: "sepolia" },
    }]);
    expect(result.state.inspect).toMatchObject({
      success: true,
      result: { chainKey: "sepolia", chainId: 11155111 },
    });
    expect(mocks.showInspect).toHaveBeenCalledOnce();
  });
});
