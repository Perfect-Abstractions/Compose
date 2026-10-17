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
        },
        {
          hash: `0x${"02".repeat(32)}`,
          transactionType: "CREATE",
          contractName: "Diamond",
          contractAddress: "0x00000000000000000000000000000000000000aa",
        },
      ],
    });

    const scriptPath = path.join(projectRoot, "script", "ComposeDeploy.s.sol");
    expect(await foundryAdapter.readBroadcastTransactions(projectRoot, scriptPath, 31337)).toEqual([
      {
        contractAddress: "0x00000000000000000000000000000000000000b1",
        contractName: "CounterFacet",
        txHash: `0x${"01".repeat(32)}`,
      },
      {
        contractAddress: "0x00000000000000000000000000000000000000aa",
        contractName: "Diamond",
        txHash: `0x${"02".repeat(32)}`,
      },
    ]);
    expect(await foundryAdapter.readBroadcastTransactions(projectRoot, scriptPath, 1)).toEqual([]);
  });
});

describe("Hardhat adapter deploy methods", () => {
  it("resolves the managed script path and deploy command", () => {
    const scriptPath = path.join(projectRoot, "scripts", "compose-deploy.ts");
    expect(hardhatAdapter.getManagedDeployScriptPath(projectRoot)).toBe(scriptPath);
    expect(hardhatAdapter.getManagedDeployResultPath(projectRoot)).toBe(
      path.join(projectRoot, "cache", "compose", "deploy-result.json"),
    );

    expect(
      hardhatAdapter.createDeployCommand({
        projectRoot,
        scriptPath,
        chainKey: "local",
        rpcUrl: "http://127.0.0.1:8545",
        chainId: 31337,
        passthrough: ["--verbose"],
      }),
    ).toEqual({
      command: "npx",
      args: ["hardhat", "run", "scripts/compose-deploy.ts", "--network", "local", "--verbose"],
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
