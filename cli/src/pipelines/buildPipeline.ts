import { ComposeContext } from "../context/types";
import { CompileModule } from "../modules/compile/module";
import { FrameworkModule } from "../modules/framework/module";
import { DependencyKey } from "../resolver/dependencyKey";
import { DependencyResolver } from "../resolver/dependencyResolver";
import { IFrameworkAdapter } from "../adapters/interface/IFrameworkAdapter";

export const BuildPipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    const projectRoot = String(ctx.param.projectRoot ?? process.cwd());

    const framework = FrameworkModule.detect(projectRoot);

    if (!framework) {
      throw new Error(
        `No supported framework detected in ${projectRoot}. ` +
          `Expected foundry.toml or hardhat.config.*`,
      );
    }

    const deps = await DependencyResolver.resolve([
      { key: framework as DependencyKey },
    ]);

    const adapter = deps[framework as DependencyKey] as IFrameworkAdapter | undefined;
    if (!adapter) {
      throw new Error(`${framework} adapter was not resolved.`);
    }

    await CompileModule.compileIfNeeded(projectRoot, adapter);

    return ctx;
  },
};
