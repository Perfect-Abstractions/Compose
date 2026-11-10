import type { ComposeContext } from "../../context/types";
import type { BasesCatalog } from "../config/types";
import { loadPrompts, checkboxTheme, selectTheme, isInteractive } from "../../utils/inquirer";
import { dim } from "../../utils/terminal";
import {
  contractReferenceName,
  listAvailableCatalogFacetNames,
  listCatalogFacetNames,
  type FacetReferenceResolutionOptions,
} from "./facetResolver";

/** Resolution hooks that let interactive installs pick among fuzzy source matches. */
export function facetReferenceOptions(): FacetReferenceResolutionOptions | undefined {
  if (!isInteractive()) return undefined;
  return {
    selectLocalMatch: async (candidates: string[]) => {
      const { select } = await loadPrompts();
      return select({
        message: "Multiple project sources match this facet; select one:",
        choices: candidates.map((candidate) => ({ name: candidate, value: candidate })),
        theme: selectTheme,
      });
    },
  };
}

/**
 * Resolves the diamond named by `--diamond`, or the sole defined diamond.
 *
 * @param ctx - The compose context with command parameters.
 * @param names - Diamond names defined in the project.
 * @param operation - Human-readable action used in the prompt.
 * @param options - Prompt behavior for ambiguous projects.
 * @param options.allowPrompt - Whether an ambiguous project may prompt interactively.
 * @returns The selected diamond name.
 */
export async function selectDiamond(
  ctx: ComposeContext,
  names: string[],
  operation: string,
  options: { allowPrompt?: boolean } = {},
): Promise<string> {
  if (typeof ctx.param.diamond === "string" && ctx.param.diamond.trim()) {
    if (!names.includes(ctx.param.diamond)) {
      throw new Error(`Diamond '${ctx.param.diamond}' not found. Available: ${names.join(", ")}`);
    }
    return ctx.param.diamond;
  }
  if (names.length === 1) return names[0];
  if (options.allowPrompt === false || !isInteractive()) {
    throw new Error(`Specify --diamond for this project. Available: ${names.join(", ")}`);
  }
  const { select } = await loadPrompts();
  return select({
    message: `Select the diamond to ${operation}:`,
    choices: names.map((name) => ({ name, value: name })),
    theme: selectTheme,
  });
}

/** Shared selection skeleton: explicit arguments win, otherwise one multi-select prompt. */
async function selectFacetNames(
  ctx: ComposeContext,
  options: {
    promptMessage: string;
    withoutArgumentsMessage: string;
    choices: () => Promise<string[]>;
  },
): Promise<string[]> {
  if (Array.isArray(ctx.param.facets) && ctx.param.facets.length > 0) {
    return ctx.param.facets.filter((facet): facet is string => typeof facet === "string");
  }
  if (!isInteractive()) throw new Error(options.withoutArgumentsMessage);

  const names = await options.choices();
  const { checkbox } = await loadPrompts();
  const selected = await checkbox({
    message: options.promptMessage,
    choices: names.map((name) => ({ name, value: name })),
    theme: checkboxTheme,
  });
  if (selected.length === 0) throw new Error("No facets selected.");
  return selected;
}

export async function selectInstallReferences(
  ctx: ComposeContext,
  catalog: BasesCatalog,
  diamondName: string,
  registeredFacetNames: Iterable<string>,
): Promise<string[]> {
  return selectFacetNames(ctx, {
    promptMessage: "Select facets to register:",
    withoutArgumentsMessage: "Provide facet names or path.sol:Contract references, or use --manifest.",
    choices: async () => {
      const registeredNames = [...registeredFacetNames];
      const registered = new Set(registeredNames);
      const registeredCatalogFacets = listCatalogFacetNames(catalog)
        .filter((name) => registered.has(name));
      if (registeredCatalogFacets.length > 0) {
        console.log(dim(`Already registered on ${diamondName}: ${registeredCatalogFacets.join(", ")}`));
      }
      const availableFacetNames = listAvailableCatalogFacetNames(catalog, registeredNames);
      if (availableFacetNames.length === 0) {
        throw new Error(`All selectable catalog facets are already registered on '${diamondName}'. Use a local path reference to add a custom facet.`);
      }
      return availableFacetNames;
    },
  });
}

export async function selectRemoveFacetNames(
  ctx: ComposeContext,
  diamondName: string,
  configuredFacets: Record<string, unknown>,
): Promise<string[]> {
  const names = await selectFacetNames(ctx, {
    promptMessage: `Select facets to unregister from ${diamondName}:`,
    withoutArgumentsMessage: "Provide facet names to remove, or use --manifest.",
    choices: async () => {
      const configured = Object.keys(configuredFacets);
      if (configured.length === 0) throw new Error(`Diamond '${diamondName}' has no registered facets.`);
      return configured;
    },
  });
  // Callers pass the same `path.sol:ContractName` reference they used to install; the key is the contract name.
  return names.map((name) => contractReferenceName(name) ?? name);
}

export async function confirmRemoval(ctx: ComposeContext, names: string[]): Promise<void> {
  if (ctx.param.yes || !isInteractive()) return;
  const { confirm } = await loadPrompts();
  const accepted = await confirm({
    message: `Unregister ${names.join(", ")}? This only changes compose.json.`,
    default: false,
  });
  if (!accepted) throw new Error("Facet removal cancelled.");
}
