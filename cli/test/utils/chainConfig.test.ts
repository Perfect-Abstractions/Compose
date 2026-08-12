import { mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { RPCAdapterError } from "../../src/adapters/rpc/errors";
import { resolveChainConfig } from "../../src/utils/chainConfig";

const temporaryDirectories: string[] = [];

async function projectWithCompose(compose: unknown): Promise<string> {
  const root = await mkdtemp(path.join(os.tmpdir(), "compose-chain-"));
  temporaryDirectories.push(root);
  await writeFile(path.join(root, "compose.json"), JSON.stringify(compose), "utf8");
  return root;
}

afterEach(async () => {
  delete process.env.TEST_RPC_URL;
  delete process.env.TEST_RPC_HOST;
  delete process.env.TEST_RPC_KEY;
  await Promise.all(temporaryDirectories.splice(0).map((directory) => rm(directory, { recursive: true, force: true })));
});

describe("resolveChainConfig", () => {
  it("defaults to the local chain", async () => {
    const root = await projectWithCompose({ chains: { local: { rpc: "http://127.0.0.1:8545", chainId: 31337 } } });

    await expect(resolveChainConfig({ projectRoot: root })).resolves.toEqual({
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
    });
  });

  it("interpolates full and embedded environment variables", async () => {
    process.env.TEST_RPC_URL = "https://example.test/rpc";
    process.env.TEST_RPC_HOST = "example.test";
    process.env.TEST_RPC_KEY = "secret";
    const root = await projectWithCompose({
      chains: {
        full: { rpc: "${TEST_RPC_URL}", chainId: 1 },
        embedded: { rpc: "https://${TEST_RPC_HOST}/v1/${TEST_RPC_KEY}", chainId: 2 },
      },
    });

    await expect(resolveChainConfig({ chainKey: "full", projectRoot: root })).resolves.toMatchObject({ rpcUrl: "https://example.test/rpc" });
    await expect(resolveChainConfig({ chainKey: "embedded", projectRoot: root })).resolves.toMatchObject({ rpcUrl: "https://example.test/v1/secret" });
  });

  it("fails when an interpolated variable is missing", async () => {
    const root = await projectWithCompose({ chains: { sepolia: { rpc: "${TEST_RPC_URL}", chainId: 11155111 } } });

    await expect(resolveChainConfig({ chainKey: "sepolia", projectRoot: root })).rejects.toMatchObject<Partial<RPCAdapterError>>({
      code: "RPC_ENV_VAR_MISSING",
    });
  });

  it("fails when the default local chain is absent", async () => {
    const root = await projectWithCompose({ chains: { sepolia: { rpc: "https://example.test", chainId: 11155111 } } });

    await expect(resolveChainConfig({ projectRoot: root })).rejects.toMatchObject<Partial<RPCAdapterError>>({ code: "RPC_CHAIN_NOT_FOUND" });
  });

  it("rejects invalid chain keys and chain definitions", async () => {
    const root = await projectWithCompose({ chains: { local: { rpc: "https://example.test", chainId: 31337 } } });

    await expect(resolveChainConfig({ chainKey: null, projectRoot: root })).rejects.toMatchObject<Partial<RPCAdapterError>>({ code: "RPC_INVALID_CONFIGURATION" });
    await expect(resolveChainConfig({ chainKey: "missing", projectRoot: root })).rejects.toMatchObject<Partial<RPCAdapterError>>({ code: "RPC_CHAIN_NOT_FOUND" });
  });
});
