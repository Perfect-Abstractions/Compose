import { Context } from "./context/context";
import { ComposeContext } from "./context/types";
import { EntryPipeline } from "./pipelines/entryPipeline";

// Create the command context, run the entry pipeline, and set the process exit code.
async function main(argv: string[]): Promise<void> {
  const ctx: ComposeContext = Context.create();
  ctx.param.argv = argv;

  const result = await EntryPipeline.execute(ctx);
  if (!result.status.success) {
    process.exitCode = 1;
  }
}

main(process.argv.slice(2)).catch((error: unknown) => {
  // Keep failure handling simple in the template.
  console.error("Unhandled error:", error);
  process.exitCode = 1;
});
