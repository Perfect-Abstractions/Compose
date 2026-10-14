import assert from "node:assert/strict";
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import fs from "node:fs/promises";
import { existsSync } from "node:fs";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import { getAddress } from "viem";
import type { Address, Hex } from "viem";

const CHAIN_ID = 31337;
const PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const COMPOSE_ROOT = path.resolve(__dirname, "../../../..");
const FIXTURES = path.join(__dirname, "fixtures");

type BroadcastTransaction = {
  contractName?: string;
  contractAddress?: Address;
  hash?: Hex;
  transaction?: { to?: Address };
};

type Receipt = {
  status: Hex;
  blockNumber: Hex;
  logs: { address: Address; topics: Hex[] }[];
};

export type HistoryHarness = {
  projectRoot: string;
  diamond: Address;
  facetAddresses: Record<string, Address>;
  upgradeBlocks: bigint[];
  rpcUrl: string;
  rpc(method: string, params?: unknown[]): Promise<unknown>;
  runHistory(): Promise<string>;
  cleanup(): Promise<void>;
};

function foundryTool(name: string): string {
  const executable = `${name}${process.platform === "win32" ? ".exe" : ""}`;
  const local = path.join(os.homedir(), ".foundry", "bin", executable);
  return existsSync(local) ? local : name;
}

function runProcess(command: string, args: string[], cwd: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd, windowsHide: true, stdio: ["ignore", "pipe", "pipe"] });
    let output = "";
    child.stdout.on("data", (chunk: Buffer) => { output += chunk.toString(); });
    child.stderr.on("data", (chunk: Buffer) => { output += chunk.toString(); });
    child.once("error", reject);
    child.once("close", (code) => code === 0 ? resolve(output) : reject(new Error(`${command} exited ${code}\n${output}`)));
  });
}

async function freePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      server.close((error) => error ? reject(error) : resolve(typeof address === "object" && address ? address.port : 0));
    });
  });
}

async function rpc(url: string, method: string, params: unknown[] = []): Promise<unknown> {
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  const body = await response.json() as { result?: unknown; error?: { message: string } };
  if (!response.ok || body.error) throw new Error(body.error?.message ?? response.statusText);
  return body.result;
}

async function startAnvil(port: number, projectRoot: string): Promise<{ child: ChildProcessWithoutNullStreams; url: string }> {
  const child = spawn(foundryTool("anvil"), [
    "--host", "127.0.0.1", "--port", String(port), "--chain-id", String(CHAIN_ID), "--silent",
  ], { cwd: projectRoot, windowsHide: true });
  let output = "";
  child.stdout.on("data", (chunk: Buffer) => { output += chunk.toString(); });
  child.stderr.on("data", (chunk: Buffer) => { output += chunk.toString(); });
  const errors: Error[] = [];
  child.on("error", (error) => errors.push(error));
  const url = `http://127.0.0.1:${port}`;
  for (let attempt = 0; attempt < 100; attempt += 1) {
    if (errors.length > 0 || child.exitCode !== null) break;
    try {
      if (await rpc(url, "eth_chainId") === "0x7a69") return { child, url };
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
  }
  child.kill();
  throw errors[0] ?? new Error(`Anvil did not start\n${output}`);
}

async function prepareProject(projectRoot: string, url: string): Promise<void> {
  await Promise.all([
    fs.mkdir(path.join(projectRoot, "src"), { recursive: true }),
    fs.mkdir(path.join(projectRoot, "script"), { recursive: true }),
  ]);
  await Promise.all([
    fs.copyFile(path.join(FIXTURES, "HistoryDiamond.sol"), path.join(projectRoot, "src", "HistoryDiamond.sol")),
    fs.copyFile(path.join(FIXTURES, "HistoryFacets.sol"), path.join(projectRoot, "src", "HistoryFacets.sol")),
    fs.copyFile(path.join(FIXTURES, "Deploy.s.sol"), path.join(projectRoot, "script", "Deploy.s.sol")),
    fs.writeFile(path.join(projectRoot, "foundry.toml"), [
      "[profile.default]", 'src = "src"', 'script = "script"', 'out = "out"', 'libs = []', 'solc = "0.8.30"', "optimizer = true", "",
    ].join("\n")),
    fs.writeFile(path.join(projectRoot, "remappings.txt"), [
      `@perfect-abstractions/compose/=${COMPOSE_ROOT.replaceAll("\\", "/")}/src/`,
      `forge-std/=${COMPOSE_ROOT.replaceAll("\\", "/")}/lib/forge-std/src/`,
      "",
    ].join("\n")),
    fs.writeFile(path.join(projectRoot, "compose.json"), JSON.stringify({
      chains: { local: { chainId: CHAIN_ID, rpc: url } },
    })),
  ]);
}

async function deployment(projectRoot: string, url: string): Promise<Omit<HistoryHarness, "projectRoot" | "rpcUrl" | "rpc" | "runHistory" | "cleanup">> {
  await runProcess(foundryTool("forge"), [
    "script", "script/Deploy.s.sol:DeployScript", "--broadcast", "--slow", "--non-interactive",
    "--rpc-url", url, "--private-key", PRIVATE_KEY,
  ], projectRoot);
  const broadcast = JSON.parse(await fs.readFile(path.join(
    projectRoot, "broadcast", "Deploy.s.sol", String(CHAIN_ID), "run-latest.json",
  ), "utf8")) as { transactions: BroadcastTransaction[] };

  const facetAddresses: Record<string, Address> = {};
  for (const name of ["DiamondUpgradeFacet", "HistoryFacetA", "HistoryFacetB", "HistoryFacetC", "HistoryFacetB2", "HistoryInitializer"]) {
    const address = broadcast.transactions.find((item) => item.contractName === name)?.contractAddress;
    assert.ok(address, `Missing ${name} deployment`);
    facetAddresses[name] = getAddress(address);
  }
  const diamond = broadcast.transactions.find((item) => item.contractName === "HistoryDiamond")?.contractAddress;
  assert.ok(diamond, "Missing HistoryDiamond deployment");

  const upgrades = broadcast.transactions.filter((item) => item.transaction?.to?.toLowerCase() === diamond.toLowerCase());
  assert.equal(upgrades.length, 7, "Expected three adds, replace, remove, metadata, and delegatecall");
  const upgradeBlocks: bigint[] = [];
  for (const upgrade of upgrades) {
    const receipt = await rpc(url, "eth_getTransactionReceipt", [upgrade.hash]) as Receipt;
    assert.equal(receipt.status, "0x1", `Upgrade reverted: ${upgrade.hash}`);
    assert.equal(receipt.logs.length, 1, "Each upgrade should emit one ERC-8153 event");
    assert.equal(receipt.logs[0].address.toLowerCase(), diamond.toLowerCase());
    upgradeBlocks.push(BigInt(receipt.blockNumber));
  }
  assert.equal(new Set(upgradeBlocks).size, 7, "Upgrade transactions must land in separate blocks");
  assert.ok(upgradeBlocks.every((block, index) => index === 0 || block > upgradeBlocks[index - 1]));

  return { diamond: getAddress(diamond), facetAddresses, upgradeBlocks };
}

export async function createHistoryHarness(): Promise<HistoryHarness> {
  const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-history-e2e-"));
  let anvil: ChildProcessWithoutNullStreams | undefined;
  const cleanup = async () => {
    if (anvil && anvil.exitCode === null) {
      anvil.kill();
      await Promise.race([
        new Promise((resolve) => anvil!.once("exit", resolve)),
        new Promise((resolve) => setTimeout(resolve, 2_000)),
      ]);
    }
    const parent = path.resolve(os.tmpdir());
    const target = path.resolve(projectRoot);
    assert.ok(target.startsWith(`${parent}${path.sep}`) && path.basename(target).startsWith("compose-history-e2e-"));
    await fs.rm(target, { recursive: true, force: true });
  };

  try {
    const started = await startAnvil(await freePort(), projectRoot);
    anvil = started.child;
    await prepareProject(projectRoot, started.url);
    const result = await deployment(projectRoot, started.url);
    return {
      ...result,
      projectRoot,
      rpcUrl: started.url,
      rpc: (method, params) => rpc(started.url, method, params),
      runHistory: () => {
        const entry = process.env.COMPOSE_E2E_CLI_ENTRY ?? path.join(COMPOSE_ROOT, "cli", "dist", "index.js");
        assert.ok(existsSync(entry), `Compose CLI build not found: ${entry}`);
        return runProcess(process.execPath, [entry, "history", result.diamond, "--chain", "local"], projectRoot);
      },
      cleanup,
    };
  } catch (error) {
    await cleanup();
    throw error;
  }
}
