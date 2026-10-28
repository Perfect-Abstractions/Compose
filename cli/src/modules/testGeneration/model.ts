import path from "node:path";
import { ComposeContext, ModuleState } from "../../context/types";
import { toPosixPath } from "../../utils/files";
import { ScaffoldingModule } from "../scaffolding/module";
import { ScaffoldMapEntry, SelectedFacet, SelectedFacetSource } from "../scaffolding/types";
import { TestFacetEntry, TestFacetGroup, TestGenerationModel } from "./types";

/**
 * Classifies a selected facet source into a test section group.
 * Base-required facets and extensions are grouped as "base"; others as "library".
 *
 * @param source - The source type of the selected facet.
 * @returns The test group classification.
 */
function classifyTestGroup(source: SelectedFacetSource): TestFacetGroup {
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
    throw new Error("Cannot generate test: scaffold map is missing.");
  }
  return state.result.entries;
}

/**
 * Resolves the test generation model by combining scaffold entries with selected
 * facets. Produces ordered facet entries with import paths relative to the
 * project root, grouped by base facets first, then library facets.
 *
 * @param ctx - The compose context with project state and parameters.
 * @param testRoot - Directory where the test file will be written.
 * @param outputFileName - Name of the output test file.
 * @returns The test generation model with output path and ordered facet entries.
 * @throws {Error} If project root, test root, or scaffold entries are invalid.
 */
export function resolveTestGenerationModel(
  ctx: ComposeContext,
  testRoot: string,
  outputFileName: string,
): TestGenerationModel {
  const projectRoot = String(ctx.param.projectRoot ?? "");
  if (!projectRoot) {
    throw new Error("Cannot generate test: project root is empty.");
  }
  if (!testRoot) {
    throw new Error("Cannot generate test: test root is empty.");
  }

  const scaffoldEntries = getScaffoldEntries(ctx);
  const scaffoldByFacetName = new Map(scaffoldEntries.map((entry) => [entry.facetName, entry]));
  const selectedFacets = ScaffoldingModule.getSelectedFacets(ctx);

  const facetEntries = selectedFacets.map((facet: SelectedFacet): TestFacetEntry => {
    const scaffoldEntry = scaffoldByFacetName.get(facet.name);
    if (!scaffoldEntry) {
      throw new Error(`Cannot generate test: scaffold entry not found for ${facet.name}.`);
    }

    const importPath = scaffoldEntry.origin === "package"
      ? scaffoldEntry.targetPath
      : toPosixPath(path.relative(projectRoot, scaffoldEntry.targetPath));
    if (!importPath) {
      throw new Error(`Cannot generate test: invalid import path for ${facet.name}.`);
    }

    return {
      facetName: facet.name,
      contractName: scaffoldEntry.contractName,
      importPath,
      group: classifyTestGroup(facet.source),
    };
  });

  const facets = [
    ...facetEntries.filter((entry) => entry.group === "base"),
    ...facetEntries.filter((entry) => entry.group === "library"),
  ];

  return {
    outputPath: path.join(testRoot, outputFileName),
    facets,
    facetCount: facets.length,
  };
}
