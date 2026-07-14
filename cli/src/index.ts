import { Context } from "./context/context";
import { ComposeContext } from "./context/types";
import { EntryPipeline } from "./pipelines/entryPipeline";
import { exitWithError } from "./utils/errors";
import { parseArgs } from "./comander";

/**
 * Main Entrypoint for the Compose CLI
 */
async function main(): Promise<void> {
  const { command, flags } = parseArgs(process.argv);

  const ctx: ComposeContext = Context.create();
  ctx.param.command = command;
  ctx.param = { ...ctx.param, ...flags };

  try {
    await EntryPipeline.execute(ctx);
  } catch (error) {
    exitWithError(error);
  }
}

main().catch((error: unknown) => {
  exitWithError(error);
});
