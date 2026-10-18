import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { Context } from "../../../src/context/context";
import type { ComposeContext } from "../../../src/context/types";
import { runCommand } from "../../../src/utils/exec";

export type DeployHarness = {
  ctx: ComposeContext;
  projectRoot: string;
  config: Record<string, unknown>;
  writeConfig(): Promise<void>;
  cleanup(): Promise<void>;
};

export async function prepareHardhatDeployProject(harness: DeployHarness, toolbox: "ethers" | "viem"): Promise<void> {
  const template = path.join(__dirname, "project");
  try { await fs.access(path.join(template, "node_modules/hardhat/package.json")); }
  catch { await runCommand("npm", ["ci", "--workspaces=false"], { cwd: template }); }
  const dependencies = path.join(template, "node_modules");
  for (const entry of await fs.readdir(dependencies, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    await fs.symlink(path.join(dependencies, entry.name), path.join(harness.projectRoot, "node_modules", entry.name), process.platform === "win32" ? "junction" : "dir");
  }
  const plugin = `@nomicfoundation/hardhat-${toolbox}`;
  await fs.writeFile(path.join(harness.projectRoot, "package.json"), JSON.stringify({ private: true, type: "module", devDependencies: { hardhat: "3.8.0", [plugin]: "*" } }));
  await fs.writeFile(path.join(harness.projectRoot, "hardhat.config.ts"), `import { defineConfig } from "hardhat/config";
import plugin from "${plugin}";
export default defineConfig({ plugins: [plugin], solidity: { version: "0.8.30", npmFilesToBuild: ["sample-facets/PackageFacet.sol"] } });
`);
}

export async function createDeployHarness(framework: "foundry" | "hardhat" = "foundry"): Promise<DeployHarness> {
  const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-deploy-script-"));
  const sourceDir = framework === "foundry" ? "src" : "contracts";
  const fixtures = path.join(__dirname, "fixtures");
  const localDir = path.join(projectRoot, sourceDir, "nested", "counter");
  const diamondDir = path.join(projectRoot, sourceDir, "proxy");
  const packageDir = path.join(projectRoot, "node_modules", "sample-facets");
  await Promise.all([fs.mkdir(localDir, { recursive: true }), fs.mkdir(diamondDir, { recursive: true }), fs.mkdir(packageDir, { recursive: true })]);
  await fs.copyFile(path.join(fixtures, "LocalFacet.sol"), path.join(localDir, "LocalFacet.sol"));
  await fs.cp(path.join(fixtures, "helpers"), path.join(localDir, "helpers"), { recursive: true });
  await fs.copyFile(path.join(fixtures, "CustomDiamond.sol"), path.join(diamondDir, "Proxy.sol"));
  await fs.copyFile(path.join(fixtures, "PackageFacet.sol"), path.join(packageDir, "PackageFacet.sol"));
  await fs.writeFile(path.join(packageDir, "package.json"), JSON.stringify({ name: "sample-facets", version: "1.0.0", exports: { "./*": "./*" } }));
  if (framework === "foundry") {
    await fs.writeFile(path.join(projectRoot, "foundry.toml"), '[profile.default]\nsolc = "0.8.30"\noptimizer = true\n');
    await fs.mkdir(path.join(projectRoot, "lib"), { recursive: true });
    await fs.symlink(path.resolve(__dirname, "../../../../lib/forge-std"), path.join(projectRoot, "lib", "forge-std"), process.platform === "win32" ? "junction" : "dir");
  }
  const config: Record<string, unknown> = {
    framework,
    diamonds: {
      Selected: {
        contract: `${sourceDir}/proxy/Proxy.sol:CustomDiamond`,
        facets: {
          LocalAlias: { source: "local", contract: `${sourceDir}/nested/counter/LocalFacet.sol:LocalFacet` },
          PackageAlias: { source: "package", package: "sample-facets", contract: "PackageFacet" },
        },
      },
      Unselected: { contract: "missing/Other.sol:Other", facets: { Missing: { source: "local", contract: "missing/Facet.sol:Missing" } } },
    },
    chains: { local: { chainId: 31337, rpc: "http://127.0.0.1:8545" } },
  };
  const writeConfig = () => fs.writeFile(path.join(projectRoot, "compose.json"), JSON.stringify(config, null, 2));
  await writeConfig();
  const ctx = Context.create();
  ctx.param = { projectRoot: localDir, diamond: "Selected", chain: "local", yes: true };
  return { ctx, projectRoot, config, writeConfig, cleanup: () => fs.rm(projectRoot, { recursive: true, force: true }) };
}
