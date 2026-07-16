import { ComposeContext } from "../../context/types";
import { loadComposeJson, parseProjectInfo } from "./loader";
import { scanFacets } from "./scanner";
import { showInfo } from "./output";

/**
 * Info Module.
 *
 * Loads compose.json, scans facets for selectors and storage layouts,
 * and displays a summary of the local project.
 */
export const InfoModule = {
  /**
   * Executes the full info command flow
   *
   * @param ctx - The compose context with project root parameter.
   * @returns The updated context with info state populated.
   */
  async displayProjectInfo(ctx: ComposeContext): Promise<ComposeContext> {
    ctx = await loadComposeJson(ctx);

    const loaderState = ctx.state.infoLoader as { success: boolean; error: { message: string } | null } | undefined;
    if (loaderState && !loaderState.success) {
      throw new Error(loaderState.error?.message ?? "Failed to load compose.json");
    }

    ctx = parseProjectInfo(ctx);
    ctx = await scanFacets(ctx);
    showInfo(ctx);

    return ctx;
  },
};
