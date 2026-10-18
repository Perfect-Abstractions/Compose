import type { ComposeContext } from "../context/types";
import { FacetConfigModule } from "../modules/facetConfig/module";

export const InstallPipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    return FacetConfigModule.execute(ctx, "install");
  },
};
