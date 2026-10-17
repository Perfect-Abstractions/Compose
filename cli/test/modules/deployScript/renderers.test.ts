import { describe, expect, it } from "vitest";
import path from "node:path";
import {
  renderFoundryDeployScript,
  renderHardhatDeployScript,
} from "../../../src/modules/deployScript/renderers";
import type { ManagedScriptModel } from "../../../src/modules/deployScript/types";
import type { Hex } from "viem";

const PLAN_HASH = `0x${"ab".repeat(32)}` as Hex;
const RESULT_PATH = path.join("/tmp/project", "cache", "compose", "deploy-result.json");

function model(overrides: Partial<ManagedScriptModel> = {}): ManagedScriptModel {
  return {
    planHash: PLAN_HASH,
    framework: "foundry",
    toolbox: null,
    outputPath: "/tmp/project/script/ComposeDeploy.s.sol",
    resultPath: null,
    projectRoot: "/tmp/project",
    diamond: { contractName: "Diamond", importSpec: "../src/Diamond.sol" },
    facets: [
      {
        name: "AlphaFacet",
        contractName: "AlphaFacet",
        importSpec: "../src/AlphaFacet.sol",
        variableName: "alphaFacet",
      },
      {
        name: "Beta",
        contractName: "BetaFacet",
        importSpec: "@perfect-abstractions/compose/BetaFacet.sol",
        variableName: "betaFacet",
      },
    ],
    chainKey: "local",
    chainId: 31337,
    instance: "default",
    ...overrides,
  };
}

function expectNoPlaceholders(source: string): void {
  expect(source).not.toMatch(/\{\{[A-Z_]+\}\}/);
}

describe("renderFoundryDeployScript", () => {
  it("renders the plan hash, imports, and facet deployments in order", async () => {
    const source = await renderFoundryDeployScript(model());

    expect(source).toContain(`// compose-plan-hash: ${PLAN_HASH}`);
    expect(source).toContain("// compose-target: local (chain id 31337)");
    expect(source).toContain('import {Diamond} from "../src/Diamond.sol";');
    expect(source).toContain('import {AlphaFacet} from "../src/AlphaFacet.sol";');
    expect(source).toContain(
      'import {BetaFacet} from "@perfect-abstractions/compose/BetaFacet.sol";',
    );
    expect(source).toContain("address[] memory facets = new address[](2);");
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
          },
          {
            name: "AlphaFacetAlias",
            contractName: "AlphaFacet",
            importSpec: "../src/AlphaFacet.sol",
            variableName: "alphaFacet2",
          },
        ],
      }),
    );

    expect(source.match(/import \{AlphaFacet\} from "\.\.\/src\/AlphaFacet\.sol";/g)).toHaveLength(1);
    expect(source).toContain("AlphaFacet alphaFacet2 = new AlphaFacet();");
  });
});

describe("renderHardhatDeployScript", () => {
  it("renders the ethers script with explicit network selection", async () => {
    const source = await renderHardhatDeployScript(
      model({ framework: "hardhat", toolbox: "ethers", resultPath: RESULT_PATH }),
    );

    expect(source).toContain(`// compose-plan-hash: ${PLAN_HASH}`);
    expect(source).toContain('await network.create({ network: "local" });');
    expect(source).toContain('const alphaFacet = await ethers.deployContract("AlphaFacet");');
    expect(source).toContain("facets.push(await alphaFacet.getAddress());");
    expect(source).toContain('"AlphaFacet": await alphaFacet.getAddress(),');
    expect(source).toContain('diamond.deploymentTransaction()?.hash ?? null');
    expect(source).toContain('const resultPath = "cache/compose/deploy-result.json";');
    expect(source).toContain("fs.writeFileSync(resultPath, JSON.stringify(result, null, 2));");
    expect(source).toContain('console.log("Result:", resultPath);');
    expect(source).toContain("chainId: 31337");
    expectNoPlaceholders(source);
  });

  it("renders the viem script with receipt waits and deployment transactions", async () => {
    const source = await renderHardhatDeployScript(
      model({ framework: "hardhat", toolbox: "viem", resultPath: RESULT_PATH }),
    );

    expect(source).toContain('await network.create({ network: "local" });');
    expect(source).toContain(
      'const alphaFacetDeployment = await viem.sendDeploymentTransaction("AlphaFacet");',
    );
    expect(source).toContain(
      "await publicClient.waitForTransactionReceipt({ hash: alphaFacetDeployment.deploymentTransaction.hash });",
    );
    expect(source).toContain('"Beta": betaFacetDeployment.contract.address,');
    expect(source).toContain("transactions: { diamond: diamondDeployment.deploymentTransaction.hash },");
    expect(source).toContain('const resultPath = "cache/compose/deploy-result.json";');
    expectNoPlaceholders(source);
  });

  it("fails when the model has no result path", async () => {
    await expect(
      renderHardhatDeployScript(model({ framework: "hardhat", toolbox: "ethers" })),
    ).rejects.toThrow("result path");
  });
});
