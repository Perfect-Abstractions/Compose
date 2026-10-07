import { describe, expect, it, vi } from "vitest";
import { Context } from "../../../src/context/context";
import { DependencyKey } from "../../../src/resolver/dependencyKey";

const mocks = vi.hoisted(() => ({
  resolveChainConfig: vi.fn(),
  resolve: vi.fn(),
  showSelectors: vi.fn(),
}));

vi.mock("../../../src/utils/chainConfig", () => ({ resolveChainConfig: mocks.resolveChainConfig }));
vi.mock("../../../src/resolver/dependencyResolver", () => ({ DependencyResolver: { resolve: mocks.resolve } }));
vi.mock("../../../src/modules/selectors/output", () => ({ showSelectors: mocks.showSelectors }));

import { SelectorsPipeline } from "../../../src/pipelines/selectorsPipeline";

const address = "0x0000000000000000000000000000000000000001";

describe("SelectorsPipeline", () => {
  it("rejects an invalid address before resolving the chain", async () => {
    const ctx = Context.create();
    ctx.param = { address: "invalid" };
    await expect(SelectorsPipeline.execute(ctx)).rejects.toMatchObject({ code: "RPC_INVALID_ADDRESS" });
    expect(mocks.resolveChainConfig).not.toHaveBeenCalled();
  });

  it("propagates an unknown chain error before resolving the adapter", async () => {
    mocks.resolveChainConfig.mockRejectedValueOnce(new Error("Unknown chain: missing"));
    const ctx = Context.create();
    ctx.param = { address, chain: "missing" };

    await expect(SelectorsPipeline.execute(ctx)).rejects.toThrow("Unknown chain: missing");
    expect(mocks.resolve).not.toHaveBeenCalled();
  });

  it("queries facets and decodes selectors", async () => {
    const facets = vi.fn().mockResolvedValue([
      { facet: "0x0000000000000000000000000000000000000002", functionSelectors: ["0x7a0ed627", "0xdeadbeef"] },
    ]);
    mocks.resolveChainConfig.mockResolvedValue({ chainKey: "sepolia", rpcUrl: "https://rpc.example", chainId: 11155111 });
    mocks.resolve.mockResolvedValue({ [DependencyKey.Diamond]: { facets } });

    const ctx = Context.create();
    ctx.param = { address, chain: "sepolia" };
    const result = await SelectorsPipeline.execute(ctx);

    expect(mocks.resolve).toHaveBeenCalledWith([{ key: DependencyKey.Diamond, params: { chainKey: "sepolia" } }]);
    expect(facets).toHaveBeenCalledWith(address);
    expect(result.state.selectors).toMatchObject({
      success: true,
      result: { facets: [{ selectors: [
        { selector: "0x7a0ed627", signature: "facets()" },
        { selector: "0xdeadbeef", signature: "0xdeadbeef" },
      ] }] },
    });
    expect(mocks.showSelectors).toHaveBeenCalledOnce();
  });

  it("propagates RPC failures", async () => {
    mocks.resolveChainConfig.mockResolvedValue({ chainKey: "local", rpcUrl: "http://localhost", chainId: 31337 });
    mocks.resolve.mockResolvedValue({ [DependencyKey.Diamond]: { facets: vi.fn().mockRejectedValue(new Error("RPC unavailable")) } });
    const ctx = Context.create();
    ctx.param = { address };
    await expect(SelectorsPipeline.execute(ctx)).rejects.toThrow("RPC unavailable");
  });
});
