import dotenv from "dotenv";
import path from "node:path";
import { Context } from "./context/context";
import { ComposeContext } from "./context/types";
import { EntryPipeline } from "./pipelines/entryPipeline";
import { exitWithError } from "./utils/errors";
import { parseArgs } from "./comander";

function loadEnvFiles(): void {
  const root = path.parse(process.cwd()).root;
  let dir = process.cwd();
  const files: string[] = [];
  while (dir !== root) {
    files.push(path.join(dir, ".env"));
    dir = path.dirname(dir);
  }
  files.push(path.join(root, ".env"));
  for (const file of files.reverse()) {
    dotenv.config({ path: file });
  }
}

/**
 * Main Entrypoint for the Compose CLI
 */
async function main(): Promise<void> {
  loadEnvFiles();
  const { command, flags } = parseArgs(process.argv);

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
