import fs from "node:fs/promises";
import path from "node:path";
import { ComposeContext } from "../context/types";

export type FacetEntry = {
  path: string;
};

export type BaseDefinition = {
  label: string;
  required: Record<string, FacetEntry>;
  optional: Record<string, FacetEntry>;
};

type BaseManifest = Record<string, BaseDefinition>;

export type BasesCatalog = {
  globals: {
    diamond?: BaseDefinition;
    libraries?: BaseDefinition;
    examples?: BaseDefinition;
  };
  features: Record<string, BaseDefinition>;
};

// =====================
// Helper
// =====================

const BASE_ORDER = new Map([
  ["erc-20", 20],
  ["erc-721", 721],
  ["erc-721-enumerable", 722],
  ["erc-1155", 1155],
  ["erc-6909", 6909],
]);

// Sort base features by Compose standard order, then by label for custom bases.
function sortBaseFeatures(features: Record<string, BaseDefinition>): Record<string, BaseDefinition> {
  return Object.fromEntries(
    Object.entries(features).sort(([leftKey, leftDefinition], [rightKey, rightDefinition]) => {
      const leftOrder = BASE_ORDER.get(leftKey) ?? Number.MAX_SAFE_INTEGER;
      const rightOrder = BASE_ORDER.get(rightKey) ?? Number.MAX_SAFE_INTEGER;

      if (leftOrder !== rightOrder) {
        return leftOrder - rightOrder;
      }

      return leftDefinition.label.localeCompare(rightDefinition.label);
    }),
  );
}

// =====================
// Modules
// =====================

export const ConfigModule = {
  // Load Compose-owned base, diamond, library, and example metadata from bases/.
  async loadBasesCatalog(ctx: ComposeContext): Promise<ComposeContext> {
    const basesRoot = path.resolve(process.cwd(), "bases");
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
