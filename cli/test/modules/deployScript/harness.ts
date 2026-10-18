import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { Context } from "../../../src/context/context";
import type { DeployProject } from "../../../src/modules/deployScript/types";
import type { SolidityAstSource } from "../../../src/adapters/IFrameworkAdapter/interface";

/** Minimal filesystem inputs for module actions, without pipeline or compiler setup. */
export async function createDeployModuleHarness() {
  const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-deploy-module-"));
  const packageRoot = path.join(projectRoot, "node_modules/sample-facets");
  await fs.mkdir(packageRoot, { recursive: true });
  await fs.writeFile(path.join(packageRoot, "PackageFacet.sol"), "contract PackageFacet {}\n");
  const config = {
    framework: "foundry",
    diamonds: {
      Selected: {
        contract: "src/proxy/Proxy.sol:CustomDiamond",
        facets: {
          LocalAlias: { source: "local", contract: "src/LocalFacet.sol:LocalFacet" },
          PackageAlias: { source: "package", package: "sample-facets", contract: "PackageFacet" },
        },
      },
      Unselected: { contract: "missing/Other.sol:Other", facets: {} },
    } as Record<string, Record<string, unknown>>,
    chains: { local: { chainId: 31337, rpc: "http://127.0.0.1:8545" } },
  };
  const writeConfig = () => fs.writeFile(path.join(projectRoot, "compose.json"), JSON.stringify(config));
  await writeConfig();
  const ctx = Context.create();
  ctx.param = { projectRoot, diamond: "Selected", yes: true };
  return { ctx, projectRoot, config, writeConfig, cleanup: () => fs.rm(projectRoot, { recursive: true, force: true }) };
}

/** Compiler-shaped prerequisite data for focused constructor-policy tests. */
export function constructorSources(project: DeployProject, unsupported: "facet" | "diamond"): SolidityAstSource[] {
  return [project.diamond, ...project.facets].map((identity, index) => {
    const types = index === 0
      ? unsupported === "diamond" ? ["address[] memory", "address"] : ["address[] memory"]
      : unsupported === "facet" ? ["uint256"] : [];
    return {
      sourceName: identity.sourcePath,
      ast: {
        id: index * 10, nodeType: "SourceUnit", src: "0:0:0",
        nodes: [{
          nodeType: "ContractDefinition", name: identity.contractName, contractKind: "contract",
          nodes: [{
            nodeType: "FunctionDefinition", kind: "constructor",
            parameters: { parameters: types.map((typeString) => ({ typeDescriptions: { typeString } })) },
          }],
        }],
      },
    };
  });
}
