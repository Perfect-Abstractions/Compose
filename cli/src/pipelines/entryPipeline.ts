import { ComposeContext } from "../context/types";
import { PipelineBuilderModule } from "../modules/pipelineBuilder/module";

/**
 * Entrypoint Pipeline.
 *
 * Routes the parsed command to the appropriate pipeline.
 */
export const EntryPipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    if (!ctx.param.command) {
      return ctx;
    }
    ctx = await PipelineBuilderModule.route(ctx);
    return ctx;
  },
};
