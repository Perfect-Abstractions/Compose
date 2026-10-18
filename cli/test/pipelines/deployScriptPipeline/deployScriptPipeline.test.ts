import fs from "node:fs/promises";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { DeployScriptPipeline } from "../../../src/pipelines/deployScriptPipeline";
import type { ModuleState } from "../../../src/context/types";
import type { DeployScriptArtifact } from "../../../src/modules/deployScript/types";
import { HashingAdapter } from "../../../src/adapters/IHashingAdapter/adapter";
import { runCommand } from "../../../src/utils/exec";
import { createDeployHarness, prepareHardhatDeployProject } from "./harness";

describe("DeployScriptPipeline", () => {
  it.each(["ethers", "viem"] as const)("runs the generated Hardhat %s script using the project's toolbox", async (toolbox) => {
    const harness = await createDeployHarness("hardhat");
    try {
      await prepareHardhatDeployProject(harness, toolbox);
      const result = await DeployScriptPipeline.execute(harness.ctx);
      const artifact = (result.state.deployScript as ModuleState<DeployScriptArtifact>).result!;
      expect(result.state.deployScriptPipeline.success).toBe(true);
      expect(artifact.toolbox).toBe(toolbox);
      expect(artifact.diamond.contractName).toBe("CustomDiamond");
      expect(artifact.facets[1].artifactReference).toBe("sample-facets/PackageFacet.sol:PackageFacet");
      expect(await fs.readFile(artifact.outputPath, "utf8")).toBe(
        await fs.readFile(path.join(__dirname, `fixtures/expected/deploy-${toolbox}.ts.txt`), "utf8"),
      );
      await runCommand("npx", ["hardhat", "run", artifact.outputPath], { cwd: harness.projectRoot });
      await expect(fs.access(path.join(harness.projectRoot, "compose.lock"))).rejects.toThrow();
    } finally { await harness.cleanup(); }
  }, 120_000);

  it("compiles and simulates a script for the selected diamond without changing source, config, or lock", async () => {
    const harness = await createDeployHarness();
    try {
      const diamondPath = path.join(harness.projectRoot, "src/proxy/Proxy.sol");
      const sourceBefore = await fs.readFile(diamondPath, "utf8");
      const configBefore = await fs.readFile(path.join(harness.projectRoot, "compose.json"), "utf8");
      const lockPath = path.join(harness.projectRoot, "compose.lock");
      const lock = JSON.stringify({ compose: "0.0.7", deployments: {} });
      await fs.writeFile(lockPath, lock);
      const result = await DeployScriptPipeline.execute(harness.ctx);
      const artifact = (result.state.deployScript as ModuleState<DeployScriptArtifact>).result!;
      expect(result.state.deployScriptPipeline.success).toBe(true);
      expect(artifact).toMatchObject({ kind: "deployment-script", diamondName: "Selected", framework: "foundry", toolbox: null, chain: { key: "local", chainId: 31337 } });
      expect(artifact.diamond.reference).toBe("src/proxy/Proxy.sol:CustomDiamond");
      expect(artifact.facets.map((facet) => [facet.name, facet.expectedSelectors])).toEqual([
        ["LocalAlias", [HashingAdapter.keccak256("nextValue(uint256)").slice(0, 10)]],
        ["PackageAlias", [HashingAdapter.keccak256("packageValue()").slice(0, 10)]],
      ]);
      const script = await fs.readFile(artifact.outputPath, "utf8");
      expect(script).toBe(await fs.readFile(path.join(__dirname, "fixtures/expected/Deploy.s.sol"), "utf8"));
      expect(script).toContain('import {CustomDiamond} from "../../src/proxy/Proxy.sol";');
      expect(script).toContain('import {LocalFacet} from "../../src/nested/counter/LocalFacet.sol";');
      expect(script).not.toContain("Unselected");
      await runCommand("forge", ["script", artifact.outputPath], { cwd: harness.projectRoot });
      expect(await fs.readFile(diamondPath, "utf8")).toBe(sourceBefore);
      expect(await fs.readFile(path.join(harness.projectRoot, "compose.json"), "utf8")).toBe(configBefore);
      expect(await fs.readFile(lockPath, "utf8")).toBe(lock);
    } finally { await harness.cleanup(); }
  }, 60_000);

  it("does not emit a script when the selected facets have selector collisions", async () => {
    const harness = await createDeployHarness();
    try {
      const packagePath = path.join(harness.projectRoot, "node_modules/sample-facets/PackageFacet.sol");
      const source = await fs.readFile(packagePath, "utf8");
      await fs.writeFile(packagePath, source.replaceAll("packageValue()", "nextValue(uint256 value)").replace("return 42;", "return value;").replace("this.packageValue.selector", "this.nextValue.selector"));
      const result = await DeployScriptPipeline.execute(harness.ctx);
      expect(result.status.success).toBe(false);
      expect(result.state.deployScript).toBeUndefined();
      await expect(fs.access(path.join(harness.projectRoot, "compose-scripts"))).rejects.toThrow();
    } finally { await harness.cleanup(); }
  }, 60_000);
});
