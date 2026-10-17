import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import type { Hex } from "viem";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { foundryAdapter } from "../../../src/adapters/IFrameworkAdapter/foundryAdapter/adapter";
import { hardhatAdapter } from "../../../src/adapters/IFrameworkAdapter/hardhatAdapter/adapter";
import { Context } from "../../../src/context/context";
import type { ModuleState } from "../../../src/context/types";
import type { DeployPlan } from "../../../src/modules/deployPlan/types";
import { DeployScriptModule } from "../../../src/modules/deployScript/module";
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
    resultPath: null,
    projectRoot,
    diamond: { contractName: "Diamond", importSpec: "../src/Diamond.sol" },
    facets: [
      {
        name: "CounterFacet",
        contractName: "CounterFacet",
        importSpec: "../src/CounterFacet.sol",
        variableName: "counterFacet",
      },
    ],
    chainKey: "local",
    chainId: 31337,
    instance: "default",
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
  });

  it("records the Hardhat deploy result path in the model", async () => {
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

    expect(state.result?.path).toBe(path.join(projectRoot, "scripts", "compose-deploy.ts"));
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

describe("DeployScriptModule.readPlanHash", () => {
  it("reads a lowercase plan hash from the script header", async () => {
    const scriptPath = path.join(projectRoot, "ComposeDeploy.s.sol");
    await fs.writeFile(
      scriptPath,
      `// compose-plan-hash: 0x${"Ab".repeat(32)}\ncontract ComposeDeployScript {}\n`,
      "utf8",
    );

    expect(await DeployScriptModule.readPlanHash(scriptPath)).toBe(`0x${"ab".repeat(32)}`);
  });

  it("returns null for missing files and files without a hash header", async () => {
    expect(await DeployScriptModule.readPlanHash(path.join(projectRoot, "missing.sol"))).toBeNull();

    const scriptPath = path.join(projectRoot, "Other.s.sol");
    await fs.writeFile(scriptPath, "// no hash here\n", "utf8");
    expect(await DeployScriptModule.readPlanHash(scriptPath)).toBeNull();
  });
});

describe("DeployScriptModule.write", () => {
  it("renders and writes the managed script", async () => {
    const model = managedModel();
    await DeployScriptModule.write(model);

    const source = await fs.readFile(model.outputPath, "utf8");
    expect(source).toContain(`/* compose-plan-hash: ${PLAN_HASH} */`);
    expect(source).toContain("CounterFacet counterFacet = new CounterFacet();");
    expect(await DeployScriptModule.readPlanHash(model.outputPath)).toBe(PLAN_HASH);
  });
});
