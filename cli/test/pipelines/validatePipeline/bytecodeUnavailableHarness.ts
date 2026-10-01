import { createBytecodeE2EHarness } from "./bytecodeHarness";

type RpcResponse<T> = {
  error?: { code: number; message: string };
  result?: T;
};

export type BytecodeUnavailableHarness = {
  canonicalFacetAddress: string;
  projectRoot: string;
  removeCanonicalFacetCode(): Promise<void>;
  runValidate(): ReturnType<Awaited<ReturnType<typeof createBytecodeE2EHarness>>["runValidate"]>;
  cleanup(): Promise<void>;
};

async function rpc<T>(rpcUrl: string, method: string, params: unknown[]): Promise<T> {
  const response = await fetch(rpcUrl, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  const payload = await response.json() as RpcResponse<T>;
  if (!response.ok || payload.error) {
    throw new Error(payload.error?.message ?? `${method} failed with HTTP ${response.status}.`);
  }
  return payload.result as T;
}

/** Creates a deployed Diamond whose declared canonical facet can be made unavailable. */
export async function createBytecodeUnavailableHarness(): Promise<BytecodeUnavailableHarness> {
  const harness = await createBytecodeE2EHarness();
  try {
    const projectRoot = await harness.createValidationProject("compatible");
    return {
      canonicalFacetAddress: harness.canonicalFacetAddress,
      projectRoot,
      async removeCanonicalFacetCode() {
        await rpc(harness.rpcUrl, "anvil_setCode", [harness.canonicalFacetAddress, "0x"]);
        await rpc(harness.rpcUrl, "evm_mine", []);
        const code = await rpc<string>(
          harness.rpcUrl,
          "eth_getCode",
          [harness.canonicalFacetAddress, "latest"],
        );
        if (code !== "0x") throw new Error("Anvil did not clear the canonical facet bytecode.");
      },
      runValidate: () => harness.runValidate(projectRoot),
      cleanup: () => harness.cleanup(),
    };
  } catch (error) {
    await harness.cleanup();
    throw error;
  }
}
