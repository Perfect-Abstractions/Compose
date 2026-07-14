import { ComposeContext } from "../context/types";
import { ConfigModule } from "../modules/config/module";
import { TerminalOutputModule } from "../modules/terminalOutput/module";

/**
 * Catalog Pipeline.
 *
 * Loads the bases catalog and displays all available bases
 * with their required and optional facets.
 */
export const CatalogPipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    ctx = await ConfigModule.loadBasesCatalog(ctx);
    TerminalOutputModule.showTemplates(ctx);
    return ctx;
  },
};
