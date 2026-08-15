import { describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  activeClient: undefined as unknown,
  delays: [] as number[],
  createPublicClient: vi.fn(),
  withRetry: vi.fn(async (request: () => Promise<unknown>, options: {
    retryCount: number;
    delay: ({ count, error }: { count: number; error: Error }) => number;
    shouldRetry: ({ error }: { error: Error }) => boolean;
  }) => {
    let count = 0;
    while (true) {
      try {
        return await request();
      } catch (error) {
        if (count >= options.retryCount || !options.shouldRetry({ error: error as Error })) throw error;
        mocks.delays.push(options.delay({ count, error: error as Error }));
        count += 1;
      }
    }
  }),
}));

vi.mock("viem", () => ({
  createPublicClient: mocks.createPublicClient.mockImplementation(() => mocks.activeClient),
  defineChain: (chain: unknown) => chain,
  getAddress: (address: string) => address,
  http: (_url: string, _options: unknown) => ({ type: "http" }),
  withRetry: mocks.withRetry,
}));

import { createRPCAdapter } from "../../src/adapters/rpc/adapter";

type MockClient = {
  chain: { id: number };
  getChainId: ReturnType<typeof vi.fn>;
  getCode: ReturnType<typeof vi.fn>;
  readContract: ReturnType<typeof vi.fn>;
};

const address = "0x0000000000000000000000000000000000000001" as `0x${string}`;

function useClient(overrides: Record<string, unknown> = {}): void {
  mocks.delays.length = 0;
  mocks.activeClient = {
    chain: { id: 11155111 },
    getChainId: vi.fn().mockResolvedValue(11155111),
    getCode: vi.fn().mockResolvedValue("0x6000"),
    readContract: vi.fn().mockResolvedValue("result"),
    ...overrides,
  };
}

describe("createRPCAdapter", () => {
  it("verifies the endpoint chain and delegates generic reads", async () => {
    useClient();
    const adapter = await createRPCAdapter({ rpcUrl: "https://rpc.example", chainId: 11155111 });
    const result = await adapter.readContract<string>({
      address,
      abi: [],
      functionName: "example",
    } as never);

    expect(result).toBe("result");
    expect((mocks.activeClient as MockClient).readContract).toHaveBeenCalledOnce();
  });

  it("fails immediately when the endpoint chain does not match", async () => {
    useClient({ getChainId: vi.fn().mockResolvedValue(1) });

    await expect(createRPCAdapter({ rpcUrl: "https://rpc.example", chainId: 11155111 })).rejects.toMatchObject({
      code: "RPC_CHAIN_ID_MISMATCH",
    });
  });

  it("checks bytecode only when requested", async () => {
    useClient();
    const adapter = await createRPCAdapter({ rpcUrl: "https://rpc.example", chainId: 11155111 });
    await adapter.readContract({ address, abi: [], functionName: "example" } as never);
    expect((mocks.activeClient as MockClient).getCode).not.toHaveBeenCalled();

    await adapter.readContract({ address, abi: [], functionName: "example" } as never, { verifyCode: true });
    expect((mocks.activeClient as MockClient).getCode).toHaveBeenCalledOnce();
  });

  it("reports missing contract code when verification is enabled", async () => {
    useClient({ getCode: vi.fn().mockResolvedValue("0x") });
    const adapter = await createRPCAdapter({ rpcUrl: "https://rpc.example", chainId: 11155111 });

    await expect(adapter.readContract({ address, abi: [], functionName: "example" } as never, { verifyCode: true })).rejects.toMatchObject({
      code: "RPC_CONTRACT_NOT_FOUND",
    });
    expect((mocks.activeClient as MockClient).readContract).not.toHaveBeenCalled();
  });

  it("makes three total attempts for transient failures", async () => {
    const request = vi.fn()
      .mockRejectedValueOnce(Object.assign(new Error("temporary"), { status: 503 }))
      .mockRejectedValueOnce(Object.assign(new Error("temporary"), { status: 503 }))
      .mockResolvedValue("result");
    useClient({ readContract: request });
    const adapter = await createRPCAdapter({ rpcUrl: "https://rpc.example", chainId: 11155111 });

    await expect(adapter.readContract({ address, abi: [], functionName: "example" } as never)).resolves.toBe("result");
    expect(request).toHaveBeenCalledTimes(3);
    expect(mocks.delays).toEqual([100, 200]);
  });

  it("retries JSON-RPC throttling errors and honors a capped Retry-After header", async () => {
    const headers = { get: vi.fn().mockReturnValue("10") };
    const request = vi.fn()
      .mockRejectedValueOnce(Object.assign(new Error("rate limited"), { code: 429, headers }))
      .mockResolvedValue("result");
    useClient({ readContract: request });
    const adapter = await createRPCAdapter({ rpcUrl: "https://rpc.example", chainId: 11155111 });

    await expect(adapter.readContract({ address, abi: [], functionName: "example" } as never)).resolves.toBe("result");
    expect(request).toHaveBeenCalledTimes(2);
    expect(mocks.delays).toEqual([2_000]);
  });

  it("does not retry unauthorized failures", async () => {
    const request = vi.fn().mockRejectedValue(Object.assign(new Error("unauthorized"), { status: 401 }));
    useClient({ readContract: request });
    const adapter = await createRPCAdapter({ rpcUrl: "https://rpc.example", chainId: 11155111 });

    await expect(adapter.readContract({ address, abi: [], functionName: "example" } as never)).rejects.toMatchObject({ code: "RPC_UNAUTHORIZED" });
    expect(request).toHaveBeenCalledOnce();
  });
});
