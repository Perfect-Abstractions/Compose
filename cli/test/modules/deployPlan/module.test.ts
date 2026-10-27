import fs from "node:fs/promises";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { foundryAdapter } from "../../../src/adapters/IFrameworkAdapter/foundryAdapter/adapter";
import { HashingAdapter } from "../../../src/adapters/IHashingAdapter/adapter";
import type { ModuleState } from "../../../src/context/types";
import { DeployPlanModule } from "../../../src/modules/deployPlan/module";
import type { DeployPlan } from "../../../src/modules/deployPlan/types";
import { loadValidationProject } from "../../../src/modules/validation/project";
import {
  CHAIN_ID,
  createDeployProjectHarness,
  DEFAULT_FACETS,
  DEFAULT_FACET_ADDRESSES,
  deploymentRecord,
  RPC_URL,
  type DeployProjectHarness,
} from "./harness";

let harness: DeployProjectHarness;

beforeEach(async () => {
  harness = await createDeployProjectHarness();
});

afterEach(async () => {
  await harness.cleanup();
});

async function resolve(harness: DeployProjectHarness): Promise<DeployPlan> {
  const project = await loadValidationProject(harness.ctx);
  const resolved = await DeployPlanModule.resolve(harness.ctx, {
    project,
    adapter: foundryAdapter,
    hashing: HashingAdapter,
  });
  const state = resolved.state.deployPlan as ModuleState<DeployPlan>;
  expect(state.success).toBe(true);
  return state.result as DeployPlan;
}

describe("DeployPlanModule.resolve", () => {
  it("plans a fresh deployment from compose.json", async () => {
    const plan = await resolve(harness);

    expect(plan.mode).toBe("fresh");
    expect(plan.framework).toBe("foundry");
    expect(plan.diamondName).toBe("CounterDiamond");
    expect(plan.diamond).toEqual({
      contractName: "Diamond",
      sourcePath: path.join(harness.projectRoot, "src", "Diamond.sol"),
      importSpec: "../src/Diamond.sol",
    });
    expect(plan.instance).toBe("default");
    expect(plan.chain).toEqual({ chainKey: "local", rpcUrl: RPC_URL, chainId: CHAIN_ID });
    expect(plan.existing).toBeNull();
    expect(plan.diff).toBeNull();
    expect(plan.upgradeable).toBe(false);
    expect(plan.planHash).toMatch(/^0x[0-9a-f]{64}$/);

    expect(plan.facets.map((facet) => facet.name)).toEqual([
      "DiamondInspectFacet",
      "CounterFacet",
    ]);
    expect(plan.facets[0]).toMatchObject({
      contractName: "DiamondInspectFacet",
      importSpec: "@perfect-abstractions/compose/diamond/DiamondInspectFacet.sol",
      sourcePath: path.join(
        harness.projectRoot,
        "lib",
        "Compose",
        "src",
        "diamond",
        "DiamondInspectFacet.sol",
      ),
    });
    expect(plan.facets[1]).toMatchObject({
      contractName: "CounterFacet",
      importSpec: "../src/CounterFacet.sol",
      sourcePath: path.join(harness.projectRoot, "src", "CounterFacet.sol"),
    });
  });

  it("resolves the chain's default Compose account profile", async () => {
    const composePath = path.join(harness.projectRoot, "compose.json");
    const composeJson = JSON.parse(await fs.readFile(composePath, "utf8")) as Record<string, unknown>;
    composeJson.accounts = {
      deployer: {
        address: "0x00000000000000000000000000000000000000a1",
        foundry: { account: "production-deployer" },
      },
    };
    composeJson.chains = {
      local: { rpc: RPC_URL, chainId: CHAIN_ID, account: "deployer" },
    };
    await fs.writeFile(composePath, JSON.stringify(composeJson, null, 2), "utf8");

    const plan = await resolve(harness);

    expect(plan.account).toEqual({
      alias: "deployer",
      address: "0x00000000000000000000000000000000000000A1",
      foundryAccount: "production-deployer",
    });
  });

  it("uses --account to override the chain's default signer", async () => {
    const composePath = path.join(harness.projectRoot, "compose.json");
    const composeJson = JSON.parse(await fs.readFile(composePath, "utf8")) as Record<string, unknown>;
    composeJson.accounts = {
      deployer: {
        address: "0x00000000000000000000000000000000000000a1",
        foundry: { account: "production-deployer" },
      },
      operator: {
        address: "0x00000000000000000000000000000000000000a2",
        foundry: { account: "production-operator" },
      },
    };
    composeJson.chains = {
      local: { rpc: RPC_URL, chainId: CHAIN_ID, account: "deployer" },
    };
    await fs.writeFile(composePath, JSON.stringify(composeJson, null, 2), "utf8");
    harness.ctx.param.account = "operator";

    const plan = await resolve(harness);

    expect(plan.account).toEqual({
      alias: "operator",
      address: "0x00000000000000000000000000000000000000A2",
      foundryAccount: "production-operator",
    });
  });

  it("reports in-sync when the recorded facet set matches compose.json", async () => {
    await harness.writeLock({
      CounterDiamond: { local: { default: deploymentRecord(DEFAULT_FACET_ADDRESSES) } },
    });

    const plan = await resolve(harness);

    expect(plan.mode).toBe("in-sync");
    expect(plan.existing).toEqual(deploymentRecord(DEFAULT_FACET_ADDRESSES));
    expect(plan.diff).toBeNull();
  });

  it("reports the composition diff when the recorded facet set differs", async () => {
    await harness.writeLock({
      CounterDiamond: {
        local: {
          default: deploymentRecord({ DiamondInspectFacet: DEFAULT_FACET_ADDRESSES.DiamondInspectFacet }),
        },
      },
    });

    const plan = await resolve(harness);

    expect(plan.mode).toBe("diff");
    expect(plan.diff).toEqual({ added: ["CounterFacet"], removed: [] });
  });

  it("reports removed facets that are no longer in compose.json", async () => {
    await harness.writeLock({
      CounterDiamond: {
        local: {
          default: deploymentRecord({
            ...DEFAULT_FACET_ADDRESSES,
            RemovedFacet: "0x00000000000000000000000000000000000000c1",
          }),
        },
      },
    });

    const plan = await resolve(harness);

    expect(plan.mode).toBe("diff");
    expect(plan.diff).toEqual({ added: [], removed: ["RemovedFacet"] });
  });

  it("switches to redeploy when --redeploy is set and a record exists", async () => {
    await harness.writeLock({
      CounterDiamond: { local: { default: deploymentRecord(DEFAULT_FACET_ADDRESSES) } },
    });
    harness.ctx.param.redeploy = true;

    const plan = await resolve(harness);

    expect(plan.mode).toBe("redeploy");
    expect(plan.diff).toBeNull();
  });

  it("selects the requested instance instead of the default one", async () => {
    await harness.writeLock({
      CounterDiamond: { local: { staging: deploymentRecord(DEFAULT_FACET_ADDRESSES) } },
    });
    harness.ctx.param.instance = "staging";

    const plan = await resolve(harness);

    expect(plan.instance).toBe("staging");
    expect(plan.mode).toBe("in-sync");

    harness.ctx.param.instance = "default";
    const defaultPlan = await resolve(harness);
    expect(defaultPlan.mode).toBe("fresh");
  });

  it("flags upgradeable compositions", async () => {
    await harness.writeComposeJson({
      ...DEFAULT_FACETS,
      DiamondUpgradeFacet: {
        source: "local",
        contract: "src/DiamondUpgradeFacet.sol:DiamondUpgradeFacet",
      },
    });

    const plan = await resolve(harness);

    expect(plan.upgradeable).toBe(true);
    expect(plan.facets.map((facet) => facet.name)).toContain("DiamondUpgradeFacet");
  });

  it("rejects instance names that cannot become lock keys", async () => {
    harness.ctx.param.instance = "__proto__";
    await expect(resolve(harness)).rejects.toThrow("Invalid deployment instance");
  });
});
