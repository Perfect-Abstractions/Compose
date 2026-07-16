import { ComposeContext } from "../context/types";
import { ConfigModule } from "../modules/config/module";
import { CatalogModule } from "../modules/catalog/module";

/**
 * Catalog Pipeline.
 *
 * Loads the bases catalog and displays all available bases
 * with their required and optional facets.
 */
export const CatalogPipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    ctx = await ConfigModule.loadBasesCatalog(ctx);
    CatalogModule.showTemplates(ctx);
    return ctx;
  },
};
