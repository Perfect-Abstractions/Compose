import { describe, expect, it, vi } from "vitest";
import {
  IFrameworkAdapter,
  SolidityAstSource,
} from "../../../src/adapters/interface/IFrameworkAdapter";
import { HashingAdapter } from "../../../src/adapters/hashingAdapter";
import { Context } from "../../../src/context/context";
import { ConfigModule } from "../../../src/modules/config/module";
import { DeployGenerationModule } from "../../../src/modules/deployGeneration/module";
import { DiamondGenerationModule } from "../../../src/modules/diamondGeneration/module";
import { InitModule } from "../../../src/modules/init/module";
import { PreflightModule } from "../../../src/modules/preflight/module";
import { ProjectDirModule } from "../../../src/modules/projectDir/module";
import { ScaffoldingModule } from "../../../src/modules/scaffolding/module";
import { TestGenerationModule } from "../../../src/modules/testGeneration/module";
import { ValidationModule } from "../../../src/modules/validation/module";
import { InitPipeline } from "../../../src/pipelines/initPipeline";
import { DependencyResolver } from "../../../src/resolver/dependencyResolver";

function contractAst(sourceName: string, contractName: string, id: number): SolidityAstSource {
  return {
    sourceName,
    ast: {
      id,
      nodeType: "SourceUnit",
      src: "0:0:0",
      absolutePath: sourceName,
      nodes: [
        {
          id: id + 1,
          nodeType: "ContractDefinition",
          name: contractName,
          contractKind: "contract",
          linearizedBaseContracts: [id + 1],
          nodes: [],
          src: "0:0:0",
        },
      ],
    },
  };
}

describe("InitPipeline source validation", () => {
  it("merges Compose package and project facet paths before compiling AST", async () => {
    const ctx = Context.create();
    const packagePath = "@perfect-abstractions/compose/diamond/PackageFacet.sol";
    const resolvedPackagePath = "/tmp/compose-project/lib/Compose/src/diamond/PackageFacet.sol";
    const projectPath = "/tmp/compose-project/src/facets/ProjectFacet.sol";
    Object.assign(ctx.param, {
      yes: true,
      framework: "foundry",
      projectRoot: "/tmp/compose-project",
      projectName: "example",
      installDeps: false,
      base: "counter",
      libraries: [],
      extensions: [],
      access: [],
      accessExtensions: [],
    });

    const compileAst = vi.fn(async () => [
      contractAst(packagePath, "PackageFacet", 1),
      contractAst(projectPath, "ProjectFacet", 10),
    ]);
    const adapter = {
      getContractSourceRoot: vi.fn(() => "/tmp/compose-project/src"),
      getScriptRoot: vi.fn(() => "/tmp/compose-project/script"),
      getTestRoot: vi.fn(() => "/tmp/compose-project/test"),
      resolveSoliditySourcePath: vi.fn(async (_ctx, sourcePath: string) =>
        sourcePath === packagePath ? resolvedPackagePath : sourcePath),
      compileAst,
      initProject: vi.fn(async () => undefined),
      writeConfig: vi.fn(async () => undefined),
    } as unknown as IFrameworkAdapter;

    vi.spyOn(InitModule, "showComposeHeader").mockImplementation(() => undefined);
    vi.spyOn(InitModule, "showSuccess").mockImplementation(() => undefined);
    vi.spyOn(ConfigModule, "loadBasesCatalog").mockImplementation(async (parentCtx) => {
      parentCtx.config.bases = {};
      return parentCtx;
    });
    vi.spyOn(ConfigModule, "getDiamondCompilerVersion").mockReturnValue("0.8.30");
    vi.spyOn(InitModule, "runInitNonInteractive").mockImplementation(async (parentCtx) => parentCtx);
    vi.spyOn(PreflightModule, "check").mockImplementation(async (parentCtx) => parentCtx);
    vi.spyOn(ProjectDirModule, "resolve").mockImplementation(async (parentCtx) => parentCtx);
    vi.spyOn(ProjectDirModule, "validate").mockImplementation(async (parentCtx) => parentCtx);
    vi.spyOn(ScaffoldingModule, "copyFacets").mockResolvedValue([
      {
        facetName: "package",
        contractName: "PackageFacet",
        targetPath: packagePath,
        origin: "package",
      },
      {
        facetName: "project",
        contractName: "ProjectFacet",
        targetPath: projectPath,
        origin: "local",
      },
    ]);
    vi.spyOn(ValidationModule, "showReport").mockImplementation(async (parentCtx) => parentCtx);
    vi.spyOn(DiamondGenerationModule, "generateDiamondContract")
      .mockImplementation(async (parentCtx) => parentCtx);
    vi.spyOn(DeployGenerationModule, "generateDeployScript")
      .mockImplementation(async (parentCtx) => parentCtx);
    vi.spyOn(TestGenerationModule, "generateTestFile")
      .mockImplementation(async (parentCtx) => parentCtx);
    vi.spyOn(ScaffoldingModule, "buildComposeJson").mockImplementation((parentCtx) => parentCtx);
    vi.spyOn(ScaffoldingModule, "validateLocalFacetFiles")
      .mockImplementation(async (parentCtx) => parentCtx);
    vi.spyOn(ScaffoldingModule, "writeComposeConfig")
      .mockImplementation(async (parentCtx) => parentCtx);
    vi.spyOn(DependencyResolver, "resolve").mockResolvedValue({
      foundry: adapter,
      hashing: HashingAdapter,
    });

    try {
      const result = await InitPipeline.execute(ctx);

      expect(result).toBe(ctx);
      expect(compileAst).toHaveBeenCalledWith(ctx, [resolvedPackagePath, projectPath]);
      expect(result.state.validationComposeFacetSources?.success).toBe(true);
      expect(result.state.validationProjectFacetSources?.success).toBe(true);
      expect(result.state.initValidation?.success).toBe(true);
      expect(result.status.success).toBe(true);
    } finally {
      vi.restoreAllMocks();
    }
  });
});
