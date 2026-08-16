import { ComposeContext } from "../context/types";
import { ConfigModule } from "../modules/config/module";
import { InitModule } from "../modules/init/module";
import { ValidationModule } from "../modules/validation/module";
import { PreflightModule } from "../modules/preflight/module";
import { ProjectDirModule } from "../modules/projectDir/module";
import { ScaffoldingModule } from "../modules/scaffolding/module";
import { DiamondGenerationModule } from "../modules/diamondGeneration/module";
import { DeployGenerationModule } from "../modules/deployGeneration/module";
import { TestGenerationModule } from "../modules/testGeneration/module";
import { DependencyKey } from "../resolver/dependencyKey";
import { DependencyResolver } from "../resolver/dependencyResolver";
import { IFrameworkAdapter } from "../adapters/interface/IFrameworkAdapter";
import { BasesCatalog } from "../modules/config/types";

/**
 * Init Pipeline.
 *
 * Orchestrates the full `init` command flow:
 * catalog load → preflight checks → input collection (interactive or --yes) →
 * project directory setup → facet validation → scaffolding → compose.json write →
 * validation report → success output
 */
export const InitPipeline = {
  /**
   * Execute the init flow end-to-end.
   * @param ctx Execution context with parsed CLI flags
   * @returns Context with init results or validation errors
   */
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    InitModule.showComposeHeader();

    ctx = await ConfigModule.loadBasesCatalog(ctx);

    ctx = ctx.param.yes
      ? await InitModule.runInitNonInteractive(ctx)
      : await InitModule.runInitInteractive(ctx);

    ctx = await PreflightModule.check(ctx);

    ctx = await ProjectDirModule.resolve(ctx);
    ctx = await ProjectDirModule.validate(ctx);

    const framework = String(ctx.param.framework ?? "foundry");

    const deps = await DependencyResolver.resolve([
      { key: DependencyKey.Hashing },
      { key: framework as DependencyKey },
    ]);

    if (!deps.hashing) {
      throw new Error("Hashing dependency was not resolved.");
    }

    const adapter = deps[framework as DependencyKey] as IFrameworkAdapter | undefined;
    if (!adapter) {
      throw new Error(`${framework} adapter was not resolved.`);
    }

    const root = String(ctx.param.projectRoot ?? "");
    const contractSourceRoot = adapter.getContractSourceRoot(root);
    const compilerVersion = ConfigModule.getDiamondCompilerVersion(ctx.config.bases as BasesCatalog);
    const projectName = String(ctx.param.projectName ?? "my-diamond");
    const installDeps = ctx.param.installDeps !== false;

    await adapter.initProject(ctx);
    const scaffoldMapEntries = await ScaffoldingModule.copyFacets(ctx, contractSourceRoot);
    await adapter.writeConfig(ctx, { compilerVersion, projectName, installDeps });
    ctx = ScaffoldingModule.recordScaffoldMap(ctx, scaffoldMapEntries);

    ctx = await ValidationModule.resolveComposeFacetSources(ctx, adapter);
    ctx = await ValidationModule.resolveProjectFacetSources(ctx, adapter);
    const facetSources = ValidationModule.getResolvedFacetSources(ctx);
    const facetNames = facetSources.map((facet) => facet.facetName);
    const astSources = await adapter.compileAst(
      ctx,
      facetSources.map((facet) => facet.sourcePath),
    );

    ctx = ValidationModule.scanFacetSelectors(ctx, astSources, facetNames);
    ctx = ValidationModule.buildVirtualStorageLayout(ctx, astSources, facetNames);
    ctx = await ValidationModule.validateSelectorExports(ctx);
    ctx = await ValidationModule.detectSelectorCollisions(ctx, { hashing: deps.hashing });

    const selectorCollisions = ValidationModule.getSelectorCollisionValidationState(ctx);
    const virtualStorageLayout = ValidationModule.getVirtualStorageLayoutValidationState(ctx);
    const validationError = selectorCollisions?.error ?? virtualStorageLayout?.error ?? null;
    const validationSuccess =
      selectorCollisions?.success === true && virtualStorageLayout?.success === true;
    ctx.state.initValidation = {
      success: validationSuccess,
      result: { checkedFacets: facetNames.length },
      error: validationError,
    };
    ctx = await ValidationModule.showReport(ctx);

    if (!validationSuccess) {
      ctx.status = {
        success: false,
        stopped: true,
        failedAt: "initValidation",
        error: validationError,
      };
      return ctx;
    }

    ctx = await DiamondGenerationModule.generateDiamondContract(ctx, contractSourceRoot);
    ctx = await DeployGenerationModule.generateDeployScript(
      ctx,
      adapter.getScriptRoot(root),
    );
    ctx = await TestGenerationModule.generateTestFile(
      ctx,
      adapter.getTestRoot(root),
    );
    ctx = ScaffoldingModule.buildComposeJson(ctx, contractSourceRoot);
    ctx = await ScaffoldingModule.validateLocalFacetFiles(ctx);
    ctx = await ScaffoldingModule.writeComposeConfig(ctx);

    ctx.state.initPipeline = {
      success: true,
      result: {
        message: `${framework.charAt(0).toUpperCase() + framework.slice(1)} demo project generated.`,
        projectRoot: ctx.param.projectRoot,
      },
      error: null,
    };

    if (ctx.state.initPipeline?.success) {
      InitModule.showSuccess(ctx);
    }

    return ctx;
  },
};
