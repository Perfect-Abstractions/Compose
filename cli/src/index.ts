import { Context } from "./context/context";
import { ComposeContext } from "./context/types";
import { EntryPipeline } from "./pipelines/entryPipeline";
import { exitWithError } from "./utils/errors";
import { loadProjectEnv } from "./utils/env";
import { parseArgs } from "./comander";

/**
 * Main Entrypoint for the Compose CLI
 */
async function main(): Promise<void> {
  const { command, flags } = parseArgs(process.argv);
  const projectRoot = typeof flags.projectRoot === "string" ? flags.projectRoot : process.cwd();
  await loadProjectEnv(projectRoot);

  const ctx: ComposeContext = Context.create();
  ctx.param.command = command;
  ctx.param = { ...ctx.param, ...flags };

  try {
    const result = await EntryPipeline.execute(ctx);
    if (!result.status.success) {
      process.exitCode = 1;
    }
  } catch (error) {
    exitWithError(error);
  }
}

main().catch((error: unknown) => {
  exitWithError(error);
});
