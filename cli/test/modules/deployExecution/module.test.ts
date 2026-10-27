import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import type { Hex } from "viem";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import type {
  BroadcastTransaction,
  IFrameworkAdapter,
} from "../../../src/adapters/IFrameworkAdapter/interface";
import { Context } from "../../../src/context/context";
import type { ModuleState } from "../../../src/context/types";
import {
  DeployExecutionModule,
} from "../../../src/modules/deployExecution/module";
import type { DeployExecutionResult } from "../../../src/modules/deployExecution/types";
import type { DeployPlan } from "../../../src/modules/deployPlan/types";
import { getIgnitionDeploymentId, HARDHAT_IGNITION_MODULE_ID } from "../../../src/modules/deployScript/model";

const PLAN_HASH = `0x${"cd".repeat(32)}` as Hex;
const DIAMOND = "0x00000000000000000000000000000000000000aa";
const FACET_A = "0x00000000000000000000000000000000000000b1";
const FACET_B = "0x00000000000000000000000000000000000000b2";
const DIAMOND_TX = `0x${"33".repeat(32)}` as Hex;
const BROADCAST_DIAMOND_TX = `0x${"44".repeat(32)}`;

let projectRoot: string;

beforeEach(async () => {
  projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-deploy-exec-"));
});

afterEach(async () => {
  await fs.rm(projectRoot, { recursive: true, force: true });
});

function deployPlan(): DeployPlan {
  return {
    mode: "fresh",
    framework: "foundry",
    projectRoot,
    composeJsonPath: path.join(projectRoot, "compose.json"),
    diamondName: "CounterDiamond",
    diamond: {
      contractName: "Diamond",
      sourcePath: path.join(projectRoot, "src", "Diamond.sol"),
      importSpec: "../src/Diamond.sol",
    },
    instance: "default",
    chain: { chainKey: "local", rpcUrl: "http://127.0.0.1:8545", chainId: 31337 },
    rpcUrlOverridden: false,
    account: null,
    facets: [
      {
        name: "AlphaFacet",
        contractName: "AlphaFacet",
        sourcePath: path.join(projectRoot, "src", "AlphaFacet.sol"),
        importSpec: "../src/AlphaFacet.sol",
      },
      {
        name: "BetaFacet",
        contractName: "BetaFacet",
        sourcePath: path.join(projectRoot, "src", "BetaFacet.sol"),
        importSpec: "../src/BetaFacet.sol",
      },
    ],
    existing: null,
    diff: null,
    upgradeable: false,
    planHash: PLAN_HASH,
  };
}

function hardhatPlan(): DeployPlan {
  return { ...deployPlan(), framework: "hardhat" };
}

function stubAdapter(overrides: Partial<IFrameworkAdapter> = {}): IFrameworkAdapter {
  return {
    getContractSourceRoot: () => path.join(projectRoot, "src"),
    getScriptRoot: () => path.join(projectRoot, "script"),
    getTestRoot: () => path.join(projectRoot, "test"),
    getArtifactDir: () => path.join(projectRoot, "out"),
    compile: async () => {},
    compileAst: async () => [],
    resolveSoliditySourcePath: async () => "",
    initProject: async () => {},
    writeConfig: async () => {},
    getManagedDeployScriptPath: () => path.join(projectRoot, "script", "ComposeDeploy.s.sol"),
    getManagedDeployRunnerPath: () => null,
    getManagedDeployResultPath: () => path.join(projectRoot, "cache", "compose", "deploy-result.json"),
    createDeployCommand: () => ({ command: process.execPath, args: ["-e", ""] }),
    createTestCommand: () => ({ command: process.execPath, args: ["-e", ""] }),
    readDeployedBytecode: async () => undefined,
    readBroadcastTransactions: async () => [],
    ...overrides,
  };
}

function validResult(): Record<string, unknown> {
  return {
    mode: "deploy",
    planHash: PLAN_HASH,
    framework: "foundry",
    chainKey: "local",
    chainId: 31337,
    instance: "default",
    diamond: DIAMOND,
    facets: { AlphaFacet: FACET_A, BetaFacet: FACET_B },
    transactions: { diamond: DIAMOND_TX },
  };
}

async function adapterWritingResult(result: Record<string, unknown>): Promise<IFrameworkAdapter> {
  const payloadPath = path.join(projectRoot, "script", "expected-result.json");
  await fs.mkdir(path.dirname(payloadPath), { recursive: true });
  await fs.writeFile(payloadPath, JSON.stringify(result), "utf8");

  const script =
    'const fs = require("fs"); fs.mkdirSync("cache/compose", { recursive: true });' +
    `fs.copyFileSync(${JSON.stringify(payloadPath)}, "cache/compose/deploy-result.json");`;
  return stubAdapter({
    createDeployCommand: () => ({ command: process.execPath, args: ["-e", script] }),
  });
}

function broadcastAdapter(transactions: BroadcastTransaction[]): IFrameworkAdapter {
  return stubAdapter({ readBroadcastTransactions: async () => transactions });
}

async function execute(
  adapter: IFrameworkAdapter,
  plan = deployPlan(),
  runnerPath: string | null = null,
): Promise<{
  result: DeployExecutionResult | null;
  success: boolean;
  message: string | null;
}> {
  const ctx = Context.create();
  ctx.param.projectRoot = projectRoot;
  let throwMessage: string | null = null;
  try {
    await DeployExecutionModule.execute(ctx, plan, "/tmp/script.s.sol", adapter, runnerPath);
  } catch (error) {
    throwMessage = (error as Error).message;
  }
  const state = ctx.state.deployExecution as ModuleState<DeployExecutionResult>;
  return {
    result: state?.result ?? null,
    success: state?.success ?? false,
    message: state?.error?.message ?? throwMessage,
  };
}

describe("DeployExecutionModule.execute", () => {
  it("accepts a result file that matches the plan", async () => {
    const adapter = await adapterWritingResult(validResult());
    const outcome = await execute(adapter);

    expect(outcome.success).toBe(true);
    expect(outcome.result).toEqual({
      diamond: DIAMOND,
      facets: { AlphaFacet: FACET_A, BetaFacet: FACET_B },
      transactions: { diamond: DIAMOND_TX },
    });

    const gitignore = await fs.readFile(
      path.join(projectRoot, "cache", "compose", ".gitignore"),
      "utf8",
    );
    expect(gitignore).toContain("deploy-result.json");
  });

  it("passes adapter environment overrides to the framework command", async () => {
    const rpcUrl = "https://rpc.example.test/v1/private-token";
    const resultPath = path.join(projectRoot, "cache", "compose", "deploy-result.json");
    const observedPath = path.join(projectRoot, "observed-rpc-url.txt");
    const script = [
      'const fs = require("node:fs");',
      'fs.mkdirSync("cache/compose", { recursive: true });',
      `fs.writeFileSync(${JSON.stringify(resultPath)}, ${JSON.stringify(JSON.stringify(validResult()))});`,
      `fs.writeFileSync(${JSON.stringify(observedPath)}, process.env.COMPOSE_DEPLOY_RPC_URL ?? "");`,
    ].join("\n");
    const adapter = stubAdapter({
      createDeployCommand: () => ({
        command: process.execPath,
        args: ["-e", script],
        env: { COMPOSE_DEPLOY_RPC_URL: rpcUrl },
      }),
    });

    const outcome = await execute(adapter);

    expect(outcome.success).toBe(true);
    expect(await fs.readFile(observedPath, "utf8")).toBe(rpcUrl);
  });

  it("does not manage a capture file for frameworks without one", async () => {
    const adapter = stubAdapter({
      getManagedDeployResultPath: () => null,
      readBroadcastTransactions: async () => [
        { contractName: "AlphaFacet", contractAddress: FACET_A, txHash: `0x${"01".repeat(32)}` },
        { contractName: "BetaFacet", contractAddress: FACET_B, txHash: `0x${"02".repeat(32)}` },
        { contractName: "Diamond", contractAddress: DIAMOND, txHash: BROADCAST_DIAMOND_TX },
      ],
    });

    const outcome = await execute(adapter);

    expect(outcome.success).toBe(true);
    await expect(fs.access(path.join(projectRoot, "cache", "compose"))).rejects.toThrow();
  });

  it("rejects a result written by a different plan", async () => {
    const adapter = await adapterWritingResult({
      ...validResult(),
      planHash: `0x${"ee".repeat(32)}`,
    });
    const outcome = await execute(adapter);

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("different plan");
  });

  it("rejects a result whose facet set differs from the plan", async () => {
    const adapter = await adapterWritingResult({
      ...validResult(),
      facets: { AlphaFacet: FACET_A, BetaFacet: FACET_B, ExtraFacet: DIAMOND },
    });
    const outcome = await execute(adapter);

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("do not match the plan");
    expect(outcome.message).toContain("ExtraFacet");
  });

  it("records and verifies the selected Hardhat account address", async () => {
    const accountAddress = "0x00000000000000000000000000000000000000a1";
    const plan = {
      ...deployPlan(),
      framework: "hardhat" as const,
      account: { alias: "deployer", address: accountAddress as Hex },
    };
    const ignitionDeploymentId = getIgnitionDeploymentId(plan);
    const journalPath = path.join(projectRoot, "ignition", "deployments", ignitionDeploymentId, "journal.jsonl");
    await fs.mkdir(path.dirname(journalPath), { recursive: true });
    await fs.writeFile(journalPath, JSON.stringify({
      type: "TRANSACTION_CONFIRM",
      futureId: `${HARDHAT_IGNITION_MODULE_ID}#Diamond`,
      hash: DIAMOND_TX,
      receipt: { status: "SUCCESS" },
    }), "utf8");
    const result = {
      ...validResult(),
      framework: "hardhat",
      deployer: accountAddress,
      ignitionDeploymentId,
    };

    const outcome = await execute(await adapterWritingResult(result), plan);

    expect(outcome.success).toBe(true);
    expect(outcome.result?.deployer).toBe(accountAddress);
  });

  it("takes the Hardhat diamond transaction hash from the matching successful Ignition journal future", async () => {
    const plan = hardhatPlan();
    const runnerPath = path.join(projectRoot, "scripts", ".compose", "ignition-runner.ts");
    await fs.mkdir(path.dirname(runnerPath), { recursive: true });
    await fs.writeFile(runnerPath, "transient", "utf8");
    const ignitionDeploymentId = getIgnitionDeploymentId(plan);
    const journalPath = path.join(
      projectRoot,
      "ignition",
      "deployments",
      ignitionDeploymentId,
      "journal.jsonl",
    );
    await fs.mkdir(path.dirname(journalPath), { recursive: true });
    await fs.writeFile(journalPath, [
      JSON.stringify({
        type: "TRANSACTION_CONFIRM",
        futureId: `${HARDHAT_IGNITION_MODULE_ID}#Facet_0`,
        hash: `0x${"11".repeat(32)}`,
        receipt: { status: "SUCCESS" },
      }),
      JSON.stringify({
        type: "TRANSACTION_CONFIRM",
        futureId: `${HARDHAT_IGNITION_MODULE_ID}#Diamond`,
        hash: DIAMOND_TX,
        receipt: { status: "SUCCESS" },
      }),
      "",
    ].join("\n"), "utf8");

    const result = {
      ...validResult(),
      framework: "hardhat",
      ignitionDeploymentId,
      transactions: { diamond: BROADCAST_DIAMOND_TX },
    };
    const outcome = await execute(await adapterWritingResult(result), plan, runnerPath);

    expect(outcome.success).toBe(true);
    expect(outcome.result).toEqual({
      diamond: DIAMOND,
      facets: { AlphaFacet: FACET_A, BetaFacet: FACET_B },
      ignitionDeploymentId,
      transactions: { diamond: DIAMOND_TX },
    });
    await expect(fs.access(runnerPath)).rejects.toThrow();
  });

  it("rejects a Hardhat result associated with another Ignition deployment ID", async () => {
    const outcome = await execute(await adapterWritingResult({
      ...validResult(),
      framework: "hardhat",
      ignitionDeploymentId: "compose-unrelated-deployment",
    }), hardhatPlan());

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("unexpected Hardhat Ignition deployment ID");
  });

  it("rejects a deployment from a different account than the Compose alias", async () => {
    const plan = {
      ...deployPlan(),
      account: {
        alias: "deployer",
        address: "0x00000000000000000000000000000000000000a1" as Hex,
      },
    };

    const outcome = await execute(
      await adapterWritingResult({ ...validResult(), deployer: "0x00000000000000000000000000000000000000a2" }),
      plan,
    );

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("expected Compose account 'deployer'");
  });

  it("rejects a result targeting another chain", async () => {
    const adapter = await adapterWritingResult({ ...validResult(), chainId: 1 });
    const outcome = await execute(adapter);

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("chain id");
  });

  it("fails when neither a result file nor broadcast deployments exist", async () => {
    const outcome = await execute(stubAdapter());

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("did not report a deployment for facet 'AlphaFacet'");
  });

  it("derives the deployment from broadcast transactions when no result file exists", async () => {
    const adapter = broadcastAdapter([
      { contractName: "AlphaFacet", contractAddress: FACET_A, txHash: `0x${"01".repeat(32)}` },
      { contractName: "BetaFacet", contractAddress: FACET_B, txHash: `0x${"02".repeat(32)}` },
      { contractName: "Diamond", contractAddress: DIAMOND, txHash: BROADCAST_DIAMOND_TX },
    ]);
    const outcome = await execute(adapter);

    expect(outcome.success).toBe(true);
    expect(outcome.result).toEqual({
      diamond: DIAMOND,
      facets: { AlphaFacet: FACET_A, BetaFacet: FACET_B },
      transactions: { diamond: BROADCAST_DIAMOND_TX },
    });
  });

  it("verifies the selected Compose account against the Foundry broadcast sender", async () => {
    const accountAddress = "0x00000000000000000000000000000000000000a1";
    const plan = {
      ...deployPlan(),
      account: { alias: "deployer", address: accountAddress as Hex, foundryAccount: "deployer" },
    };
    const adapter = broadcastAdapter([
      { contractName: "AlphaFacet", contractAddress: FACET_A, txHash: `0x${"01".repeat(32)}`, from: accountAddress },
      { contractName: "BetaFacet", contractAddress: FACET_B, txHash: `0x${"02".repeat(32)}`, from: accountAddress },
      { contractName: "Diamond", contractAddress: DIAMOND, txHash: BROADCAST_DIAMOND_TX, from: accountAddress },
    ]);

    const outcome = await execute(adapter, plan);

    expect(outcome.success).toBe(true);
    expect(outcome.result?.deployer).toBe(accountAddress);
  });

  it("rejects a Foundry broadcast from a different Compose account", async () => {
    const plan = {
      ...deployPlan(),
      account: {
        alias: "deployer",
        address: "0x00000000000000000000000000000000000000a1" as Hex,
        foundryAccount: "deployer",
      },
    };
    const adapter = broadcastAdapter([
      { contractName: "AlphaFacet", contractAddress: FACET_A, txHash: `0x${"01".repeat(32)}` },
      { contractName: "BetaFacet", contractAddress: FACET_B, txHash: `0x${"02".repeat(32)}` },
      { contractName: "Diamond", contractAddress: DIAMOND, txHash: BROADCAST_DIAMOND_TX, from: "0x00000000000000000000000000000000000000a2" },
    ]);

    const outcome = await execute(adapter, plan);

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("does not match Compose account 'deployer'");
  });

  it("falls back to broadcast transactions for the diamond hash", async () => {
    const adapter = await adapterWritingResult({ ...validResult(), transactions: {} });
    const withBroadcast = stubAdapter({
      createDeployCommand: adapter.createDeployCommand,
      readBroadcastTransactions: async () => [
        { contractName: "Diamond", contractAddress: DIAMOND, txHash: BROADCAST_DIAMOND_TX },
      ],
    });
    const outcome = await execute(withBroadcast);

    expect(outcome.success).toBe(true);
    expect(outcome.result?.transactions.diamond).toBe(BROADCAST_DIAMOND_TX);
  });

  it("fails when no diamond deployment transaction is recorded", async () => {
    const adapter = broadcastAdapter([
      { contractName: "AlphaFacet", contractAddress: FACET_A, txHash: `0x${"01".repeat(32)}` },
      { contractName: "BetaFacet", contractAddress: FACET_B, txHash: `0x${"02".repeat(32)}` },
      { contractName: "Diamond", contractAddress: DIAMOND, txHash: null },
    ]);
    const outcome = await execute(adapter);

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("No diamond deployment transaction was recorded");
  });
});
