import { ComposeContext } from "../context/types";
import { InspectModule } from "../modules/inspect/module";

/** Diamond inspect pipeline for querying on-chain facets via Loupe. */
export const InspectPipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    return InspectModule.inspect(ctx);
  },
};
