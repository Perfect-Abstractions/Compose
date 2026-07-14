import fs from "node:fs/promises";
import { ComposeContext } from "../../context/types";
import { DiamondInfo, FacetInfo } from "./types";
import { findFileAncestor } from "../../utils/files";

/**
 * Reads and parses compose.json, storing the result in ctx.state.infoLoader.
 *
 * @param ctx - The compose context with project root parameter.
 * @returns The updated context with loader state.
 */
export async function loadComposeJson(ctx: ComposeContext): Promise<ComposeContext> {
  const startDir = String(ctx.param.projectRoot ?? process.cwd());
  const composeJsonPath = await findFileAncestor(startDir, "compose.json");

  if (!composeJsonPath) {
    ctx.state.infoLoader = {
      success: false,
      result: null,
      error: {
        code: "COMPOSE_JSON_NOT_FOUND",
        message: "compose.json not found. Run 'compose init' first or navigate to a Compose project directory.",
        nativeError: null,
      },
    };
    return ctx;
  }

  const content = await fs.readFile(composeJsonPath, "utf8");
  const composeJson = JSON.parse(content);

  ctx.config.composeJson = composeJson;
  ctx.state.infoLoader = {
    success: true,
    result: {
      composeJsonPath,
      composeJson,
    },
    error: null,
  };

  return ctx;
}

/**
 * Parses the raw compose.json into structured ComposeProjectInfo.
 *
 * @param ctx - The compose context with loaded compose.json state.
 * @returns The updated context with parsed project info.
 */
export function parseProjectInfo(ctx: ComposeContext): ComposeContext {
  const loaderState = ctx.state.infoLoader as { success: boolean; result: { composeJson: Record<string, unknown> } | null };
  if (!loaderState?.success || !loaderState?.result) {
    return ctx;
  }

  const composeJson = loaderState.result.composeJson;
  const project = String(composeJson.project ?? "unknown");
  const composeVersion = String(composeJson.compose ?? "unknown");
  const framework = String(composeJson.framework ?? "unknown");

  const diamondsRaw = composeJson.diamonds as Record<string, { contract: string; facets: Record<string, { source: string; contract: string; package?: string }> }> | undefined;
  const diamonds: DiamondInfo[] = [];
  const warnings: string[] = [];

  if (!diamondsRaw) {
    warnings.push("No diamonds defined in compose.json");
  } else {
    for (const [diamondName, diamondDef] of Object.entries(diamondsRaw)) {
      const facets: FacetInfo[] = [];

      for (const [facetName, facetDef] of Object.entries(diamondDef.facets)) {
        facets.push({
          name: facetName,
          source: facetDef.source as FacetInfo["source"],
          contract: facetDef.contract,
          package: facetDef.package,
          selectors: [],
          storageSlots: [],
        });
      }

      diamonds.push({
        name: diamondName,
        contract: diamondDef.contract,
        facets,
      });
    }
  }

  ctx.state.infoProject = {
    success: true,
    result: {
      project,
      composeVersion,
      framework,
      diamonds,
      warnings,
    },
    error: null,
  };

  return ctx;
}
