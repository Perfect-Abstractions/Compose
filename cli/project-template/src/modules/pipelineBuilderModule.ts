import { ComposeContext } from "../context/types";
import { FoundryInitPipeline } from "../pipelines/foundryInitPipeline";

// =====================
// Modules
// =====================

export const PipelineBuilderModule = {
  // Route the parsed command and framework to the correct command pipeline.
  async route(ctx: ComposeContext): Promise<ComposeContext> {
    const command = String(ctx.param.command ?? "");
    const args = (ctx.param.args as string[]) ?? [];

    let framework = String(ctx.param.framework ?? "foundry").toLowerCase();
    for (let i = 0; i < args.length; i++) {
      if (args[i] === "--framework" && args[i + 1]) {
        framework = args[i + 1].toLowerCase();
        break;
      }
    }

    switch (ctx.param.command) {
      case "init":
        ctx.state.commandSelected = {
          success: true,
          result: { command, framework },
          error: null,
        };

        if (framework === "foundry") {
          return FoundryInitPipeline.execute(ctx);
        }
        ctx.state.commandRouting = {
          success: false,
          result: null,
          error: {
            code: "UNSUPPORTED_FRAMEWORK",
            message: `Init pipeline is not implemented for framework: ${framework}`,
            nativeError: null,
          },
        };
        return ctx;
      case "validate":
      case "inspect":
        ctx.state.commandSelected = {
          success: true,
          result: { command },
          error: null,
        };
        return ctx;
      default:
        return ctx;
    }
  },
};
