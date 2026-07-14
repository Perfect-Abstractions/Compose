import path from "node:path";
import { ComposeContext, ModuleState } from "../../context/types";
import { TestFacetEntry, TestGenerationModel } from "./types";

/** Result shape from the deploy script generation step. */
type DeployScriptResult = {
  outputPath: string;
  facets: {
    facetName: string;
    contractName: string;
    importPath: string;
    group: string;
  }[];
  framework: string;
  toolbox: string | null;
};

/**
 * Extracts the deploy script generation result from the compose context.
 *
 * @param ctx - The compose context with deploy script state.
 * @returns The deploy script result.
 * @throws {Error} If deploy script generation is missing or failed.
 */
function getDeployResult(ctx: ComposeContext): DeployScriptResult {
  const state = ctx.state.generateDeployScript as ModuleState<DeployScriptResult> | undefined;
  if (!state?.success || !state.result) {
    throw new Error("Cannot generate test: deploy script generation is missing.");
  }
  return state.result;
}

/**
 * Resolves the test generation model by extracting facet entries from the
 * deploy script result.
 *
 * @param ctx - The compose context with deploy script generation state.
 * @param testRoot - Directory where the test file will be written.
 * @param outputFileName - Name of the output test file.
 * @returns The test generation model with output path and facet entries.
 * @throws {Error} If deploy script generation is missing.
 */
export function resolveTestGenerationModel(
  ctx: ComposeContext,
  testRoot: string,
  outputFileName: string,
): TestGenerationModel {
  const deployResult = getDeployResult(ctx);

  const facets: TestFacetEntry[] = deployResult.facets.map((facet) => ({
    facetName: facet.facetName,
    contractName: facet.contractName,
    importPath: facet.importPath,
    group: facet.group as TestFacetEntry["group"],
  }));

  return {
    outputPath: path.join(testRoot, outputFileName),
    facets,
    facetCount: facets.length,
  };
}
