import fs from "node:fs/promises";
import path from "node:path";
import { ComposeContext } from "../../context/types";
import { BasesCatalog, BaseDefinition, BaseManifest } from "./types";
import { sortBaseFeatures } from "./catalog";
import { CLI_ROOT } from "../../utils/cliRoot";

export { EMPTY_BASE, getDiamondCompilerVersion } from "./catalog";
export { resolveCatalogSelection, getAccessBases, getAvailableLibraryFacets, validateGroupedAccessFlags } from "./selection";

/**
 * Loads and indexes the Compose bases catalog from JSON manifest files.
 *
 * Reads all `.json` files from the `bases/` directory, separates entries into
 * globals (diamond, libraries, examples) and feature bases, sorts features by
 * standard order, and stores the result on the context.
 */
export const ConfigModule = {
  /**
   * Reads JSON manifest files from `bases/` and builds the {@link BasesCatalog}.
   *
   * Each manifest is parsed and its entries are classified:
   * - Keys `diamond`, `libraries`, `examples` become globals.
   * - All other keys become feature bases, sorted by Compose's standard order
   *   (erc-20, erc-721, etc.) then alphabetically.
   *
   * The catalog is stored on `ctx.config.bases` and a summary is written to
   * `ctx.state.config`.
   *
   * @param ctx - The compose context.
   * @returns The context with the loaded bases catalog.
   */
  async loadBasesCatalog(ctx: ComposeContext): Promise<ComposeContext> {
    const basesRoot = path.resolve(CLI_ROOT, "bases");
    const entries = await fs.readdir(basesRoot, { withFileTypes: true });

    const globals: BasesCatalog["globals"] = {};
    const features: Record<string, BaseDefinition> = {};

    for (const entry of entries) {
      if (!entry.isFile() || path.extname(entry.name).toLowerCase() !== ".json") {
        continue;
      }

      const manifestPath = path.join(basesRoot, entry.name);
      const raw = await fs.readFile(manifestPath, "utf8");
      const manifest = JSON.parse(raw) as BaseManifest;

      for (const [key, definition] of Object.entries(manifest)) {
        if (key === "diamond" || key === "libraries" || key === "examples") {
          globals[key] = definition;
          continue;
        }

        features[key] = definition;
      }
    }

    const catalog = { globals, features: sortBaseFeatures(features) };

    ctx.config.bases = catalog;
    ctx.state.config = {
      success: true,
      result: {
        baseCount: Object.keys(catalog.features).length,
        hasDiamondCatalog: Boolean(globals.diamond),
        hasLibrariesCatalog: Boolean(globals.libraries),
        hasExamplesCatalog: Boolean(globals.examples),
      },
      error: null,
    };

    return ctx;
  },
};
