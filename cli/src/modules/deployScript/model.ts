import fs from "node:fs/promises";
import path from "node:path";
import type { IFrameworkAdapter } from "../../adapters/IFrameworkAdapter/interface";
import { toCamelCase } from "../../utils/strings";
import type { DeployPlan } from "../deployPlan/types";
import type { ManagedScriptModel, ScriptFacetEntry, ScriptToolbox } from "./types";

/**
 * Detects which Hardhat toolbox the project uses by reading package.json.
 * Defaults to the ethers toolbox when the file is missing or unclear.
 *
 * @param projectRoot - Absolute project root.
 * @returns The detected toolbox variant.
 */
export async function detectHardhatToolbox(projectRoot: string): Promise<ScriptToolbox> {
  try {
    const packageJson = JSON.parse(
      await fs.readFile(path.join(projectRoot, "package.json"), "utf8"),
    ) as { dependencies?: Record<string, string>; devDependencies?: Record<string, string> };
    const dependencies = { ...packageJson.dependencies, ...packageJson.devDependencies };
    return dependencies["@nomicfoundation/hardhat-toolbox-viem"] ? "viem" : "ethers";
  } catch {
    return "ethers";
  }
}

/** Assigns a unique camelCase variable name to every facet entry. */
function assignVariableNames(facets: DeployPlan["facets"]): ScriptFacetEntry[] {
  const used = new Set(["diamond", "facets"]);
  return facets.map((facet, index) => {
    const base = toCamelCase(facet.contractName) || `facet${index}`;
    let variableName = base;
    let suffix = 2;
    while (used.has(variableName)) {
      variableName = `${base}${suffix}`;
      suffix += 1;
    }
    used.add(variableName);
    return {
      name: facet.name,
      contractName: facet.contractName,
      importSpec: facet.importSpec,
      variableName,
    };
  });
}

/**
 * Builds the managed script model for a plan.
 *
 * @param plan - The resolved deployment plan.
 * @param adapter - The framework adapter resolving script locations.
 * @returns The model consumed by the script renderers.
 */
export async function buildScriptModel(
  plan: DeployPlan,
  adapter: IFrameworkAdapter,
): Promise<ManagedScriptModel> {
  return {
    planHash: plan.planHash,
    framework: plan.framework,
    toolbox: plan.framework === "hardhat" ? await detectHardhatToolbox(plan.projectRoot) : null,
    outputPath: adapter.getManagedDeployScriptPath(plan.projectRoot),
    resultPath: adapter.getManagedDeployResultPath(plan.projectRoot),
    projectRoot: plan.projectRoot,
    diamond: { contractName: plan.diamond.contractName, importSpec: plan.diamond.importSpec },
    facets: assignVariableNames(plan.facets),
    chainKey: plan.chain.chainKey,
    chainId: plan.chain.chainId,
    instance: plan.instance,
  };
}
