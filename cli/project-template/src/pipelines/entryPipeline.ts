import { ComposeContext } from "../context/types";
import { ConfigModule } from "../modules/configModule";
import { EntryModule } from "../modules/entryModule";
import { PipelineBuilderModule } from "../modules/pipelineBuilderModule";

export const EntryPipeline = {
  // Execute top-level CLI flow: parse command, run interactive entry work, route, and report.
  async execute(ctx: ComposeContext): Promise<ComposeContext> {

    const argv = (ctx.param.argv as string[]) ?? [];

    if (argv.length === 0) {
      ctx = await EntryModule.showHelp(ctx);
      return ctx;
    }
    
    ctx.param.command = argv[0] ?? "";
    ctx.param.args = argv.slice(1);
    const args = (ctx.param.args as string[]) ?? [];

    if (ctx.param.command === "init" && args.length === 0) {
      ctx = await EntryModule.showComposeHeader(ctx);
      ctx = await ConfigModule.loadBasesCatalog(ctx);
      ctx = await EntryModule.runInitInteractive(ctx);
    }

    ctx = await PipelineBuilderModule.route(ctx);
    ctx = await EntryModule.showReport(ctx);

    if (ctx.status.stopped) {
      return ctx;
    }

    if (!ctx.state.commandSelected && !ctx.state.commandRouting) {
      ctx.state.commandRouting = {
        success: false,
        result: null,
        error: {
          code: "COMMAND_NOT_SUPPORTED",
          message: "Unknown or missing command.",
          nativeError: null,
        },
      };
    }

    return ctx;
  },
};
