import path from "node:path";
import { ComposeContext, ModuleState } from "../../context/types";
import { getSelectedFacets } from "../scaffolding/module";
import { ScaffoldMapEntry, SelectedFacet, SelectedFacetSource } from "../scaffolding/types";
import { DeployFacetEntry, DeployFacetGroup, DeployGenerationModel } from "./types";
import { toPosixPath } from "../../utils/files";

/**
 * Classifies a selected facet source into a deploy facet group.
 * Base-required facets and extensions are grouped as "base"; others as "library".
 *
 * @param source - The source type of the selected facet.
 * @returns The deploy group classification.
 */
function classifyDeployGroup(source: SelectedFacetSource): DeployFacetGroup {
  if (source === "base-required" || source === "extension") {
    return "base";
  }
  return "library";
}

/**
 * Extracts scaffold map entries from the compose context state.
 *
 * @param ctx - The compose context containing scaffold map state.
 * @returns The list of scaffold map entries.
 * @throws {Error} If the scaffold map is missing or in a failed state.
 */
function getScaffoldEntries(ctx: ComposeContext): ScaffoldMapEntry[] {
  const state = ctx.state.scaffoldMap as ModuleState<{ entries: ScaffoldMapEntry[] }> | undefined;
  if (!state?.success || !state.result) {
    throw new Error("Cannot generate deploy script: scaffold map is missing.");
  }
  return state.result.entries;
}

/**
 * Resolves the deploy generation model by combining scaffold entries with selected facets.
 * Produces ordered deploy facet entries with import paths relative to the project root,
 * grouped by base facets first, then library facets.
 *
 * @param ctx - The compose context with project state and parameters.
 * @param scriptRoot - Directory where the deploy script will be written.
 * @param outputFileName - Name of the output deploy script file.
 * @returns The deploy generation model with output path and ordered facet entries.
 * @throws {Error} If project root, script root, or scaffold entries are invalid.
 */
export function resolveDeployGenerationModel(
  ctx: ComposeContext,
  scriptRoot: string,
  outputFileName: string,
): DeployGenerationModel {
  const projectRoot = String(ctx.param.projectRoot ?? "");
  if (!projectRoot) {
    throw new Error("Cannot generate deploy script: project root is empty.");
  }
  if (!scriptRoot) {
    throw new Error("Cannot generate deploy script: script root is empty.");
  }

  const scaffoldEntries = getScaffoldEntries(ctx);
  const scaffoldByFacetName = new Map(scaffoldEntries.map((entry) => [entry.facetName, entry]));
  const selectedFacets = getSelectedFacets(ctx);
  
  const deployEntries = selectedFacets.map((facet: SelectedFacet): DeployFacetEntry => {
    const scaffoldEntry = scaffoldByFacetName.get(facet.name);
    if (!scaffoldEntry) {
      throw new Error(`Cannot generate deploy script: scaffold entry not found for ${facet.name}.`);
    }

    const importPath = scaffoldEntry.origin === "package"
      ? scaffoldEntry.targetPath
      : toPosixPath(path.relative(projectRoot, scaffoldEntry.targetPath));
    if (!importPath) {
      throw new Error(`Cannot generate deploy script: invalid import path for ${facet.name}.`);
    }

    return {
      facetName: facet.name,
      contractName: scaffoldEntry.contractName,
      importPath,
      source: facet.source,
      origin: scaffoldEntry.origin,
      group: classifyDeployGroup(facet.source),
    };
  });

  const facets = [
    ...deployEntries.filter((entry) => entry.group === "base"),
    ...deployEntries.filter((entry) => entry.group === "library"),
  ];

  return {
    outputPath: path.join(scriptRoot, outputFileName),
    facets,
  };
}
