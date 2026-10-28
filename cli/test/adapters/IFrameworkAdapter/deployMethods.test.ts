import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { foundryAdapter } from "../../../src/adapters/IFrameworkAdapter/foundryAdapter/adapter";
import { hardhatAdapter } from "../../../src/adapters/IFrameworkAdapter/hardhatAdapter/adapter";

let projectRoot: string;

beforeEach(async () => {
  projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-deploy-adapter-"));
});

afterEach(async () => {
  await fs.rm(projectRoot, { recursive: true, force: true });
});

async function writeJson(relativePath: string, value: unknown): Promise<void> {
  const filePath = path.join(projectRoot, relativePath);
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, JSON.stringify(value), "utf8");
}

describe("Foundry adapter deploy methods", () => {
  it("resolves the managed script path and deploy command", () => {
    const scriptPath = path.join(projectRoot, "script", "ComposeDeploy.s.sol");
    expect(foundryAdapter.getManagedDeployScriptPath(projectRoot)).toBe(scriptPath);
    expect(foundryAdapter.getManagedDeployResultPath(projectRoot)).toBeNull();

    expect(
      foundryAdapter.createDeployCommand({
        projectRoot,
        scriptPath,
        chainKey: "local",
        rpcUrl: "http://127.0.0.1:8545",
        chainId: 31337,
        mode: "broadcast",
        passthrough: ["--private-key", "0xabc"],
      }),
    ).toEqual({
      command: "forge",
      args: [
        "script",
        "script/ComposeDeploy.s.sol:ComposeDeployScript",
        "--rpc-url",
        "http://127.0.0.1:8545",
        "--broadcast",
        "--private-key",
        "0xabc",
      ],
    });
  });

  it("maps a Compose account to a Foundry keystore account and sender", () => {
    const scriptPath = path.join(projectRoot, "script", "ComposeDeploy.s.sol");
    expect(foundryAdapter.createDeployCommand({
      projectRoot,
      scriptPath,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      mode: "broadcast",
      account: {
        alias: "deployer",
        address: "0x00000000000000000000000000000000000000a1",
        foundryAccount: "production-deployer",
      },
      passthrough: [],
    })).toEqual({
      command: "forge",
      args: [
        "script",
        "script/ComposeDeploy.s.sol:ComposeDeployScript",
        "--rpc-url",
        "http://127.0.0.1:8545",
        "--account",
        "production-deployer",
        "--sender",
        "0x00000000000000000000000000000000000000a1",
        "--broadcast",
      ],
    });
  });

  it("simulates at a pinned fork block without loading a signing account or broadcasting", () => {
    const scriptPath = path.join(projectRoot, "script", "ComposeDeploy.s.sol");
    expect(foundryAdapter.createDeployCommand({
      projectRoot,
      scriptPath,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      mode: "simulate",
      forkBlockNumber: 123n,
      account: {
        alias: "deployer",
        address: "0x00000000000000000000000000000000000000a1",
        foundryAccount: "production-deployer",
      },
      passthrough: [],
    })).toEqual({
      command: "forge",
      args: [
        "script",
        "script/ComposeDeploy.s.sol:ComposeDeployScript",
        "--rpc-url",
        "http://127.0.0.1:8545",
        "--fork-block-number",
        "123",
        "--sender",
        "0x00000000000000000000000000000000000000a1",
      ],
    });
  });

  it("reads deployed bytecode from forge artifacts", async () => {
    await writeJson("out/CounterFacet.sol/CounterFacet.json", {
      deployedBytecode: { object: "0x6001" },
    });

    expect(
      await foundryAdapter.readDeployedBytecode(
        projectRoot,
        path.join(projectRoot, "src", "CounterFacet.sol"),
        "CounterFacet",
      ),
    ).toBe("0x6001");
    expect(
      await foundryAdapter.readDeployedBytecode(projectRoot, "/tmp/Missing.sol", "Missing"),
    ).toBeUndefined();
  });

  it("maps the run broadcast into deployment transactions", async () => {
    await writeJson("broadcast/ComposeDeploy.s.sol/31337/run-latest.json", {
      transactions: [
        {
          hash: `0x${"01".repeat(32)}`,
          transactionType: "CREATE",
          contractName: "CounterFacet",
          contractAddress: "0x00000000000000000000000000000000000000b1",
          transaction: { from: "0x00000000000000000000000000000000000000a1" },
        },
        {
          hash: `0x${"02".repeat(32)}`,
          transactionType: "CREATE",
          contractName: "Diamond",
          contractAddress: "0x00000000000000000000000000000000000000aa",
        },
        {
          hash: `0x${"03".repeat(32)}`,
          transactionType: "CALL",
          contractName: "CounterFacet",
          contractAddress: "0x00000000000000000000000000000000000000b1",
        },
      ],
    });

    const scriptPath = path.join(projectRoot, "script", "ComposeDeploy.s.sol");
    expect(await foundryAdapter.readBroadcastTransactions(projectRoot, scriptPath, 31337)).toEqual([
      {
        contractAddress: "0x00000000000000000000000000000000000000b1",
        contractName: "CounterFacet",
        txHash: `0x${"01".repeat(32)}`,
        from: "0x00000000000000000000000000000000000000a1",
      },
      {
        contractAddress: "0x00000000000000000000000000000000000000aa",
        contractName: "Diamond",
        txHash: `0x${"02".repeat(32)}`,
      },
    ]);
    expect(await foundryAdapter.readBroadcastTransactions(projectRoot, scriptPath, 1)).toEqual([]);
  });

  it("reports an unreadable or malformed broadcast artifact", async () => {
    const scriptPath = path.join(projectRoot, "script", "ComposeDeploy.s.sol");
    const broadcastPath = path.join(projectRoot, "broadcast", "ComposeDeploy.s.sol", "31337", "run-latest.json");
    await fs.mkdir(path.dirname(broadcastPath), { recursive: true });

    await fs.writeFile(broadcastPath, "{not json", "utf8");
    await expect(
      foundryAdapter.readBroadcastTransactions(projectRoot, scriptPath, 31337),
    ).rejects.toThrow("Unable to parse the Foundry broadcast");

    await fs.writeFile(broadcastPath, JSON.stringify({ transactions: "invalid" }), "utf8");
    await expect(
      foundryAdapter.readBroadcastTransactions(projectRoot, scriptPath, 31337),
    ).rejects.toThrow("missing a transactions array");
  });
});

describe("Hardhat adapter deploy methods", () => {
  it("resolves the managed script path and deploy command", () => {
    const scriptPath = path.join(projectRoot, "ignition", "modules", "ComposeDeploy.ts");
    const runnerPath = path.join(projectRoot, "scripts", ".compose", "ignition-runner.ts");
    expect(hardhatAdapter.getScriptRoot(projectRoot)).toBe(path.join(projectRoot, "ignition", "modules"));
    expect(hardhatAdapter.getManagedDeployScriptPath(projectRoot)).toBe(scriptPath);
    expect(hardhatAdapter.getManagedDeployRunnerPath(projectRoot)).toBe(runnerPath);
    expect(hardhatAdapter.getManagedDeployResultPath(projectRoot)).toBe(
      path.join(projectRoot, "cache", "compose", "deploy-result.json"),
    );

    expect(
      hardhatAdapter.createDeployCommand({
        projectRoot,
        scriptPath,
        runnerPath,
        chainKey: "local",
        rpcUrl: "http://127.0.0.1:8545",
        chainId: 31337,
        mode: "broadcast",
        passthrough: ["--verbose"],
      }),
    ).toEqual({
      command: "npx",
      args: [
        "hardhat",
        "--build-profile",
        "production",
        "run",
        "scripts/.compose/ignition-runner.ts",
        "--network",
        "local",
        "--verbose",
      ],
      env: {
        COMPOSE_DEPLOY_RPC_URL: "http://127.0.0.1:8545",
        COMPOSE_DEPLOY_MODE: "broadcast",
      },
    });
  });

  it("passes the pinned fork block to the Hardhat simulation mode", () => {
    const scriptPath = path.join(projectRoot, "ignition", "modules", "ComposeDeploy.ts");
    const runnerPath = path.join(projectRoot, "scripts", ".compose", "ignition-runner.ts");
    expect(hardhatAdapter.createDeployCommand({
      projectRoot,
      scriptPath,
      runnerPath,
      chainKey: "sepolia",
      rpcUrl: "https://rpc.example.test",
      chainId: 11155111,
      mode: "simulate",
      forkBlockNumber: 987n,
      passthrough: [],
    })).toEqual({
      command: "npx",
      args: [
        "hardhat",
        "--build-profile",
        "production",
        "run",
        "scripts/.compose/ignition-runner.ts",
        "--network",
        "sepolia",
      ],
      env: {
        COMPOSE_DEPLOY_RPC_URL: "https://rpc.example.test",
        COMPOSE_DEPLOY_MODE: "simulate",
        COMPOSE_DEPLOY_FORK_BLOCK_NUMBER: "987",
      },
    });
  });

  it("reads deployed bytecode for project contracts", async () => {
    await writeJson("artifacts/contracts/CounterFacet.sol/CounterFacet.json", {
      deployedBytecode: "0x6002",
    });

    expect(
      await hardhatAdapter.readDeployedBytecode(
        projectRoot,
        path.join(projectRoot, "contracts", "CounterFacet.sol"),
        "CounterFacet",
      ),
    ).toBe("0x6002");
  });

  it("reads deployed bytecode for npm package contracts", async () => {
    await writeJson("node_modules/@perfect-abstractions/compose/package.json", {
      name: "@perfect-abstractions/compose",
      version: "9.9.9",
    });
    await writeJson(
      "artifacts/npm/@perfect-abstractions/compose@9.9.9/diamond/DiamondInspectFacet.sol/DiamondInspectFacet.json",
      { deployedBytecode: "0x6003" },
    );

    expect(
      await hardhatAdapter.readDeployedBytecode(
        projectRoot,
        path.join(
          projectRoot,
          "node_modules",
          "@perfect-abstractions",
          "compose",
          "diamond",
          "DiamondInspectFacet.sol",
        ),
        "DiamondInspectFacet",
      ),
    ).toBe("0x6003");

    expect(
      await hardhatAdapter.readDeployedBytecode(projectRoot, "/elsewhere/Facet.sol", "Facet"),
    ).toBeUndefined();
  });

  it("reports no broadcast transactions", async () => {
    expect(
      await hardhatAdapter.readBroadcastTransactions(
        projectRoot,
        path.join(projectRoot, "scripts", "compose-deploy.ts"),
        31337,
      ),
    ).toEqual([]);
  });
});
