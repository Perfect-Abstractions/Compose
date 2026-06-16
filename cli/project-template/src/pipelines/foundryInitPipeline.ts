import { ComposeContext, ModuleState } from "../context/types";
import { ValidationModule } from "../modules/validationModule";
import { ScaffoldingModule } from "../modules/scaffoldingModule";
import { FoundryProjectModule } from "../modules/foundryProjectModule";
import { DependencyKey } from "../resolver/dependencyKey";
import { DependencyResolver } from "../resolver/dependencyResolver";

export const FoundryInitPipeline = {
  // Execute Foundry init by validating selected facets, resolving the project root, and scaffolding.
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    ctx = await ScaffoldingModule.scanSelectedFacets(ctx);
    ctx = await ValidationModule.validateSelectorExports(ctx);

    const selectorExportValidation = ctx.state.validationSelectorExports as ModuleState | undefined;
    if (selectorExportValidation && !selectorExportValidation.success) {
      return ctx;
    }

    const deps = await DependencyResolver.resolve([
      { key: DependencyKey.Hashing },
    ]);

    if (!deps.hashing) {
      throw new Error("Hashing dependency was not resolved.");
    }

    ctx = await ValidationModule.detectSelectorCollisions(ctx, {
      hashing: deps.hashing,
    });

    const selectorCollisionValidation = ctx.state.validationSelectorCollisions as ModuleState | undefined;
    if (selectorCollisionValidation && !selectorCollisionValidation.success) {
      return ctx;
    }

    ctx = await ValidationModule.detectIdentifierCollisions(ctx);

    const identifierCollisionValidation = ctx.state.validationIdentifierCollisions as ModuleState | undefined;
    if (identifierCollisionValidation && !identifierCollisionValidation.success) {
      return ctx;
    }

    ctx = await FoundryProjectModule.resolveProjectRoot(ctx);
    ctx = await ScaffoldingModule.scaffoldFoundryLayout(ctx);
    ctx = await ScaffoldingModule.writeComposeConfig(ctx);

    ctx.state.initPipeline = {
      success: true,
      result: {
        message: "Foundry demo project generated.",
        projectRoot: ctx.param.projectRoot,
      },
      error: null,
    };

    return ctx;
  },
};
