import { ComposeContext } from "../context/types";
import { InfoModule } from "../modules/info/module";

/**
 * Info Pipeline.
 *
 * Loads compose.json, scans facets for selectors and storage layouts,
 * and displays a summary of the local project.
 */
export const InfoPipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    return InfoModule.displayProjectInfo(ctx);
  },
};
