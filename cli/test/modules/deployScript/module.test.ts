import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import type { Hex } from "viem";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { foundryAdapter } from "../../../src/adapters/IFrameworkAdapter/foundryAdapter/adapter";
import { hardhatAdapter } from "../../../src/adapters/IFrameworkAdapter/hardhatAdapter/adapter";
import { HashingAdapter } from "../../../src/adapters/IHashingAdapter/adapter";
import { Context } from "../../../src/context/context";
import type { ModuleState } from "../../../src/context/types";
import type { DeployPlan } from "../../../src/modules/deployPlan/types";
import { DeployScriptModule } from "../../../src/modules/deployScript/module";
import { buildScriptModel, getIgnitionDeploymentId } from "../../../src/modules/deployScript/model";
import type { ManagedScriptModel } from "../../../src/modules/deployScript/types";

const PLAN_HASH = `0x${"cd".repeat(32)}` as Hex;

let projectRoot: string;

beforeEach(async () => {
  projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-deploy-script-"));
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
        name: "CounterFacet",
        contractName: "CounterFacet",
        sourcePath: path.join(projectRoot, "src", "CounterFacet.sol"),
        importSpec: "../src/CounterFacet.sol",
      },
    ],
    existing: null,
    diff: null,
    upgradeable: false,
    planHash: PLAN_HASH,
  };
}

function managedModel(): ManagedScriptModel {
  return {
    planHash: PLAN_HASH,
    framework: "foundry",
    toolbox: null,
    outputPath: path.join(projectRoot, "script", "ComposeDeploy.s.sol"),
    runnerPath: null,
    ignitionDeploymentId: null,
    resultPath: null,
    projectRoot,
    diamond: { contractName: "Diamond", importSpec: "../src/Diamond.sol" },
    facets: [
      {
        name: "CounterFacet",
        contractName: "CounterFacet",
        importSpec: "../src/CounterFacet.sol",
        variableName: "counterFacet",
        futureId: "Facet_0_CounterFacet",
      },
    ],
    chainKey: "local",
    chainId: 31337,
    instance: "default",
    account: null,
  };
}

describe("DeployScriptModule.buildModel", () => {
  it("builds the model from the resolved deploy plan", async () => {
    const ctx = Context.create();
    ctx.param.projectRoot = projectRoot;
    ctx.state.deployPlan = { success: true, result: deployPlan(), error: null };

    const resolved = await DeployScriptModule.buildModel(ctx, foundryAdapter);
    const state = resolved.state.deployScript as ModuleState<{
      path: string;
      model: ManagedScriptModel;
    }>;

    expect(state.success).toBe(true);
    expect(state.result?.path).toBe(path.join(projectRoot, "script", "ComposeDeploy.s.sol"));
    expect(state.result?.model.resultPath).toBeNull();
    expect(state.result?.model.facets[0]).toMatchObject({
      name: "CounterFacet",
      contractName: "CounterFacet",
      variableName: "counterFacet",
    });
    expect(state.result?.model.facets[0].futureId).toMatch(/^Facet_CounterFacet_[0-9a-f]{12}$/);
  });

  it("keeps Ignition future IDs stable by facet key and gives each redeploy a new journal ID", async () => {
    const plan = deployPlan();
    plan.facets.push({
      name: "Other-Facet",
      contractName: "OtherFacet",
      sourcePath: path.join(projectRoot, "src", "OtherFacet.sol"),
      importSpec: "../src/OtherFacet.sol",
    });
    const normal = await buildScriptModel(plan, foundryAdapter);
    const reordered = await buildScriptModel({ ...plan, facets: [...plan.facets].reverse() }, foundryAdapter);
    expect(normal.facets.find((facet) => facet.name === "CounterFacet")?.futureId)
      .toBe(reordered.facets.find((facet) => facet.name === "CounterFacet")?.futureId);

    const existing = {
      diamond: "0x00000000000000000000000000000000000000aa" as Hex,
      facets: {},
      facetHash: `0x${"00".repeat(32)}` as Hex,
      lastSync: new Date(0).toISOString(),
      txHash: `0x${"11".repeat(32)}` as Hex,
    };
    const freshId = getIgnitionDeploymentId({ ...plan, framework: "hardhat" });
    const redeployId = getIgnitionDeploymentId({
      ...plan,
      framework: "hardhat",
      mode: "redeploy",
      existing,
    });
    expect(redeployId).not.toBe(freshId);
    expect(getIgnitionDeploymentId({
      ...plan,
      framework: "hardhat",
      mode: "redeploy",
      existing,
    })).toBe(redeployId);
  });

  it("records the Hardhat Ignition module, runner, and result paths in the model", async () => {
    await fs.writeFile(
      path.join(projectRoot, "package.json"),
      JSON.stringify({ devDependencies: { "@nomicfoundation/hardhat-toolbox-mocha-ethers": "^3.0.0" } }),
      "utf8",
    );
    const ctx = Context.create();
    ctx.param.projectRoot = projectRoot;
    ctx.state.deployPlan = {
      success: true,
      result: { ...deployPlan(), framework: "hardhat" },
      error: null,
    };

    const resolved = await DeployScriptModule.buildModel(ctx, hardhatAdapter);
    const state = resolved.state.deployScript as ModuleState<{
      path: string;
      model: ManagedScriptModel;
    }>;

    expect(state.result?.path).toBe(path.join(projectRoot, "ignition", "modules", "ComposeDeploy.ts"));
    expect(state.result?.model.runnerPath).toBe(
      path.join(projectRoot, "scripts", ".compose", "ignition-runner.ts"),
    );
    expect(state.result?.model.ignitionDeploymentId).toContain("compose-counterdiamond-local-default-");
    expect(state.result?.model.resultPath).toBe(
      path.join(projectRoot, "cache", "compose", "deploy-result.json"),
    );
  });

  it("fails when no plan has been resolved", async () => {
    const ctx = Context.create();
    ctx.param.projectRoot = projectRoot;

    await expect(DeployScriptModule.buildModel(ctx, foundryAdapter)).rejects.toThrow(
      "deploy plan is missing",
    );
  });
});

describe("DeployScriptModule.readScriptHash", () => {
  it("hashes the complete source, including content beyond the plan marker", async () => {
    const scriptPath = path.join(projectRoot, "ComposeDeploy.s.sol");
    const source = `// compose-plan-hash: ${PLAN_HASH}\ncontract ComposeDeployScript {}\n`;
    await fs.writeFile(scriptPath, source, "utf8");

    expect(await DeployScriptModule.readScriptHash(scriptPath, HashingAdapter)).toBe(
      HashingAdapter.keccak256(source),
    );

    const modifiedSource = `${source}extraTransaction();\n`;
    await fs.writeFile(scriptPath, modifiedSource, "utf8");
    expect(await DeployScriptModule.readScriptHash(scriptPath, HashingAdapter)).toBe(
      HashingAdapter.keccak256(modifiedSource),
    );
    expect(HashingAdapter.keccak256(modifiedSource)).not.toBe(HashingAdapter.keccak256(source));
  });

  it("returns null for missing files", async () => {
    expect(
      await DeployScriptModule.readScriptHash(path.join(projectRoot, "missing.sol"), HashingAdapter),
    ).toBeNull();
  });
});

describe("DeployScriptModule.write", () => {
  it("renders and writes the managed script", async () => {
    const model = managedModel();
    await DeployScriptModule.write(model);

    const source = await fs.readFile(model.outputPath, "utf8");
    expect(source).toContain(`/* compose-plan-hash: ${PLAN_HASH} */`);
    expect(source).toContain("CounterFacet counterFacet = new CounterFacet();");
    expect(await DeployScriptModule.readScriptHash(model.outputPath, HashingAdapter)).toBe(
      HashingAdapter.keccak256(source),
    );
  });
});
