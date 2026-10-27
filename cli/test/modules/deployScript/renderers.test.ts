import { describe, expect, it } from "vitest";
import path from "node:path";
import {
  renderFoundryDeployScript,
  renderHardhatIgnitionModule,
  renderHardhatIgnitionRunner,
} from "../../../src/modules/deployScript/renderers";
import type { ManagedScriptModel } from "../../../src/modules/deployScript/types";
import type { Hex } from "viem";

const PLAN_HASH = `0x${"ab".repeat(32)}` as Hex;
const RESULT_PATH = path.join("/tmp/project", "cache", "compose", "deploy-result.json");
const IGNITION_DEPLOYMENT_ID = "compose-counter-local-default-abcdef12";

function model(overrides: Partial<ManagedScriptModel> = {}): ManagedScriptModel {
  return {
    planHash: PLAN_HASH,
    framework: "foundry",
    toolbox: null,
    outputPath: "/tmp/project/script/ComposeDeploy.s.sol",
    runnerPath: null,
    ignitionDeploymentId: null,
    resultPath: null,
    projectRoot: "/tmp/project",
    diamond: { contractName: "Diamond", importSpec: "../src/Diamond.sol" },
    facets: [
      {
        name: "AlphaFacet",
        contractName: "AlphaFacet",
        importSpec: "../src/AlphaFacet.sol",
        variableName: "alphaFacet",
        futureId: "Facet_AlphaFacet_dce992e4a97c",
      },
      {
        name: "Beta",
        contractName: "BetaFacet",
        importSpec: "@perfect-abstractions/compose/BetaFacet.sol",
        variableName: "betaFacet",
        futureId: "Facet_Beta_703390318bd5",
      },
    ],
    chainKey: "local",
    chainId: 31337,
    instance: "default",
    account: null,
    ...overrides,
  };
}

function expectNoPlaceholders(source: string): void {
  expect(source).not.toMatch(/\{\{[A-Z_]+\}\}/);
}

describe("renderFoundryDeployScript", () => {
  it("renders the plan hash, imports, and facet deployments in order", async () => {
    const source = await renderFoundryDeployScript(model());

    expect(source).toContain(`/* compose-plan-hash: ${PLAN_HASH} */`);
    expect(source).toContain("/* compose-target: local (chain id 31337) */");
    expect(source).toContain('import {Diamond} from "../src/Diamond.sol";');
    expect(source).toContain('import {AlphaFacet} from "../src/AlphaFacet.sol";');
    expect(source).toContain(
      'import {BetaFacet} from "@perfect-abstractions/compose/BetaFacet.sol";',
    );
    expect(source).toContain("address[] memory facets = new address[](2);");
    expect(source).toContain("vm.readCallers()");
    expect(source).toContain('console.log("Deployer:", composeSigner);');
    expect(source).toContain("AlphaFacet alphaFacet = new AlphaFacet();");
    expect(source).toContain("facets[0] = address(alphaFacet);");
    expect(source).toContain("facets[1] = address(betaFacet);");
    expect(source).toContain("Diamond diamond = new Diamond(facets);");
    expectNoPlaceholders(source);
  });

  it("deduplicates import lines for repeated sources", async () => {
    const source = await renderFoundryDeployScript(
      model({
        facets: [
          {
            name: "AlphaFacet",
            contractName: "AlphaFacet",
            importSpec: "../src/AlphaFacet.sol",
            variableName: "alphaFacet",
            futureId: "Facet_AlphaFacet_dce992e4a97c",
          },
          {
            name: "AlphaFacetAlias",
            contractName: "AlphaFacet",
            importSpec: "../src/AlphaFacet.sol",
            variableName: "alphaFacet2",
            futureId: "Facet_AlphaFacetAlias_different",
          },
        ],
      }),
    );

    expect(source.match(/import \{AlphaFacet\} from "\.\.\/src\/AlphaFacet\.sol";/g)).toHaveLength(1);
    expect(source).toContain("AlphaFacet alphaFacet2 = new AlphaFacet();");
  });

  it("guards a Foundry broadcast against the selected Compose account", async () => {
    const source = await renderFoundryDeployScript(model({
      account: {
        alias: "deployer",
        address: "0x00000000000000000000000000000000000000a1",
        foundryAccount: "production-deployer",
      },
    }));

    expect(source).toContain("if (composeSigner != 0x00000000000000000000000000000000000000a1)");
    expect(source).toContain("Compose: selected signer does not match account 'deployer'");
    expect(source.indexOf("selected signer does not match account 'deployer'")).toBeLessThan(
      source.indexOf("AlphaFacet alphaFacet = new AlphaFacet();"),
    );
  });
});

describe("Hardhat Ignition renderers", () => {
  function hardhatModel(toolbox: "ethers" | "viem", overrides: Partial<ManagedScriptModel> = {}) {
    return model({
      framework: "hardhat",
      toolbox,
      outputPath: path.join("/tmp/project", "ignition", "modules", "ComposeDeploy.ts"),
      runnerPath: path.join("/tmp/project", "scripts", ".compose", "ignition-runner.ts"),
      ignitionDeploymentId: IGNITION_DEPLOYMENT_ID,
      resultPath: RESULT_PATH,
      ...overrides,
    });
  }

  it("renders a reviewable module with stable facet and diamond future IDs", async () => {
    const source = await renderHardhatIgnitionModule(hardhatModel("ethers"));

    expect(source).toContain(`// compose-plan-hash: ${PLAN_HASH}`);
    expect(source).toContain(`// compose-ignition-deployment-id: ${IGNITION_DEPLOYMENT_ID}`);
    expect(source).toContain('buildModule("ComposeDeploy"');
    expect(source).toContain('m.contract("AlphaFacet", [], {');
    expect(source).toContain('id: "Facet_AlphaFacet_dce992e4a97c"');
    expect(source).toContain('m.contract("Diamond", [[alphaFacet, betaFacet]], {');
    expect(source).toContain('id: "Diamond"');
    expect(source).toContain("return {\n    diamond,");
    expectNoPlaceholders(source);
  });

  it("renders an ethers runner that selects the configured account and captures Ignition outputs", async () => {
    const source = await renderHardhatIgnitionRunner(hardhatModel("ethers", {
      account: {
        alias: "deployer",
        address: "0x00000000000000000000000000000000000000a1",
      },
    }));

    expect(source).toContain('from "../../ignition/modules/ComposeDeploy.js"');
    expect(source).toContain("const configuredSigners = await targetEthers.getSigners();");
    expect(source).toContain("targetConnection.provider.request({ method: \"eth_chainId\", params: [] })");
    expect(source).toContain("forking: { url: rpcUrl, blockNumber: forkBlockNumber }");
    expect(source).toContain('deploymentConnection.ignition.deploy(ComposeDeploy, {');
    expect(source).toContain(`deploymentId: executionDeploymentId`);
    expect(source).toContain('"AlphaFacet": await addressOf(outputs.alphaFacet)');
    expect(source).toContain("ignitionDeploymentId,");
    expect(source).not.toContain("transactions:");
    expect(source).toContain("Simulation succeeded. No transactions were broadcast.");
    expectNoPlaceholders(source);
  });

  it("renders the viem signer resolver using the official toolbox integration", async () => {
    const source = await renderHardhatIgnitionRunner(hardhatModel("viem"));

    expect(source).toContain("const { viem: targetViem } = targetConnection;");
    expect(source).toContain("const configuredWallets = await targetViem.getWalletClients();");
    expect(source).toContain("deploymentConnection.ignition.deploy(ComposeDeploy");
    expect(source).toContain('"Beta": await addressOf(outputs.betaFacet)');
    expectNoPlaceholders(source);
  });

  it("requires the Ignition metadata and runtime paths", async () => {
    await expect(renderHardhatIgnitionModule(hardhatModel("ethers", {
      ignitionDeploymentId: null,
    }))).rejects.toThrow("deployment ID");
    await expect(renderHardhatIgnitionRunner(hardhatModel("ethers", {
      runnerPath: null,
    }))).rejects.toThrow("runner is missing");
  });
});
