import path from "node:path";
import type { IFrameworkAdapter } from "../adapters/IFrameworkAdapter/interface";
import type { ComposeContext } from "../context/types";
import { FrameworkModule } from "../modules/framework/module";
import { DependencyKey } from "../resolver/dependencyKey";
import { DependencyResolver } from "../resolver/dependencyResolver";
import { toPassthroughArgs } from "../utils/args";
import { locateComposeProjectFile } from "../utils/composeProjectFile";
import { runCommand } from "../utils/exec";

/**
 * Test pipeline.
 *
 * Resolves the nearest Compose project root, detects its framework, and runs
 * the framework's native test command with inherited stdio. Test output and
 * exit codes stay in the framework's hands; everything after `--` is
 * forwarded as-is.
 */
export const TestPipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    const startDirectory = String(ctx.param.projectRoot ?? process.cwd());
    const composeProject = await locateComposeProjectFile(startDirectory);
    const projectRoot = composeProject?.root ?? path.resolve(startDirectory);

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

    const command = adapter.createTestCommand({
      projectRoot,
      passthrough: toPassthroughArgs(ctx.param.passthrough),
    });
    await runCommand(command.command, command.args, { cwd: projectRoot });

    return ctx;
  },
};
