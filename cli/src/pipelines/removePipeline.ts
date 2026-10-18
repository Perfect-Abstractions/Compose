import type { ComposeContext } from "../context/types";
import { FacetConfigModule } from "../modules/facetConfig/module";

export const RemovePipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    return FacetConfigModule.execute(ctx, "remove");
  },
};
