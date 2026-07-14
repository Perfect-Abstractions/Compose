import { ComposeContext } from "../../context/types";
import { InitPipeline } from "../../pipelines/initPipeline";
import { InfoPipeline } from "../../pipelines/infoPipeline";

/**
 * Pipeline builder module that routes CLI commands to their corresponding pipelines.
 *
 * Dispatches by command name (`init`, `validate`).
 *
 * Used by {@link EntryPipeline} for top-level command routing.
 */
export const PipelineBuilderModule = {
  /**
   * Routes the execution context to the appropriate pipeline based on the
   * command in `ctx.param.command`.
   * 
   * Unknown or missing command — sets `ctx.state.commandRouting` with a
   *   `COMMAND_NOT_SUPPORTED` error.
   *
   * @param ctx - The compose context with `param.command` populated by the args parser.
   * @returns The context enriched with `commandSelected` or `commandRouting` state.
   */
  async route(ctx: ComposeContext): Promise<ComposeContext> {
    switch (ctx.param.command) {
      case "init":
        ctx.state.commandSelected = {
          success: true,
          result: { command: ctx.param.command, framework: ctx.param.framework },
          error: null,
        };
        return InitPipeline.execute(ctx);
      case "validate":
        ctx.state.commandSelected = {
          success: true,
          result: { command: ctx.param.command },
          error: null,
        };
        return ctx;
      case "info":
        ctx.state.commandSelected = {
          success: true,
          result: { command: ctx.param.command },
          error: null,
        };
        return InfoPipeline.execute(ctx);
      default:
        ctx.state.commandRouting = {
          success: false,
          result: null,
          error: {
            code: "COMMAND_NOT_SUPPORTED",
            message: `Unknown command: ${ctx.param.command}. Run 'compose --help' for usage.`,
            nativeError: null,
          },
        };
        return ctx;
    }
  },
};
