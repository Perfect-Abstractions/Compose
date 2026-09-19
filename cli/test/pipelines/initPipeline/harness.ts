import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { vi } from "vitest";
import {
  ConfigOptions,
  IFrameworkAdapter,
  SolidityAstSource,
} from "../../../src/adapters/IFrameworkAdapter/interface";
import { Context } from "../../../src/context/context";
import { ComposeContext } from "../../../src/context/types";
import {
  contractNameFromSourcePath,
  resolveCatalogSourceForRead,
} from "../../../src/utils/soliditySources";

export type InitFramework = "foundry" | "hardhat";

export type InitPipelineHarness = {
  adapter: IFrameworkAdapter;
  ctx: ComposeContext;
  outputRoot: string;
  projectRoot: string;
  cleanup(): Promise<void>;
};

function contractAst(sourceName: string, contractName: string, id: number): SolidityAstSource {
  return {
    sourceName,
    ast: {
      id,
      nodeType: "SourceUnit",
      src: "0:0:0",
      absolutePath: sourceName,
      nodes: [{
        id: id + 1,
        nodeType: "ContractDefinition",
        name: contractName,
        contractKind: "contract",
        linearizedBaseContracts: [id + 1],
        nodes: [],
        src: "0:0:0",
      }],
    },
  };
}

/** Implements IFrameworkAdapter without invoking network or external toolchains. */
function createFixtureAdapter(framework: InitFramework): IFrameworkAdapter {
  const sourceDirectory = framework === "foundry" ? "src" : "contracts";
  const scriptDirectory = framework === "foundry" ? "script" : "scripts";
  const artifactDirectory = framework === "foundry" ? "out" : "artifacts";

  return {
    getContractSourceRoot: (projectRoot) => path.join(projectRoot, sourceDirectory),
    getScriptRoot: (projectRoot) => path.join(projectRoot, scriptDirectory),
    getTestRoot: (projectRoot) => path.join(projectRoot, "test"),
    getArtifactDir: (projectRoot) => path.join(projectRoot, artifactDirectory),
    compile: vi.fn(async () => undefined),
    compileAst: vi.fn(async (_ctx, sourcePaths) => sourcePaths.map((sourcePath, index) =>
      contractAst(sourcePath, contractNameFromSourcePath(sourcePath), index * 10 + 1)
    )),
    resolveSoliditySourcePath: vi.fn(async (_ctx, sourcePath) =>
      resolveCatalogSourceForRead(sourcePath)),
    initProject: vi.fn(async (ctx) => {
      const projectRoot = String(ctx.param.projectRoot);
      await Promise.all([
        fs.mkdir(path.join(projectRoot, sourceDirectory), { recursive: true }),
        fs.mkdir(path.join(projectRoot, scriptDirectory), { recursive: true }),
        fs.mkdir(path.join(projectRoot, "test"), { recursive: true }),
      ]);
    }),
    writeConfig: vi.fn(async (ctx, options: ConfigOptions) => {
      const projectRoot = String(ctx.param.projectRoot);
      if (framework === "foundry") {
        await fs.writeFile(
          path.join(projectRoot, "foundry.toml"),
          `[profile.default]\nsolc = "${options.compilerVersion}"\noptimizer = true\n`,
          "utf8",
        );
        return;
      }

      await Promise.all([
        fs.writeFile(
          path.join(projectRoot, "package.json"),
          `${JSON.stringify({ name: options.projectName, private: true, type: "module" }, null, 2)}\n`,
          "utf8",
        ),
        fs.writeFile(
          path.join(projectRoot, "hardhat.config.ts"),
          `export default { solidity: "${options.compilerVersion}" };\n`,
          "utf8",
        ),
      ]);
    }),
  };
}

/** Creates a temporary project context for an InitPipeline integration test. */
export async function createInitPipelineHarness(
  framework: InitFramework,
  base: string,
  projectName: string,
): Promise<InitPipelineHarness> {
  const outputRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-init-pipeline-"));
  const projectRoot = path.join(outputRoot, projectName);
  const ctx = Context.create();
  const adapter = createFixtureAdapter(framework);

  Object.assign(ctx.param, {
    command: "init",
    yes: true,
    framework,
    toolbox: "ethers",
    base,
    projectName,
    outDir: outputRoot,
    installDeps: false,
  });

  return {
    adapter,
    ctx,
    outputRoot,
    projectRoot,
    cleanup: () => fs.rm(outputRoot, { recursive: true, force: true }),
  };
}
