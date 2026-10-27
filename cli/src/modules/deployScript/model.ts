import fs from "node:fs/promises";
import path from "node:path";
import { createHash } from "node:crypto";
import type { IFrameworkAdapter } from "../../adapters/IFrameworkAdapter/interface";
import { toCamelCase } from "../../utils/strings";
import type { DeployPlan } from "../deployPlan/types";
import type { ManagedScriptModel, ScriptFacetEntry, ScriptToolbox } from "./types";

/**
 * Detects the Hardhat contract interaction plugin from package.json.
 *
 * @param projectRoot - Absolute project root.
 * @returns The detected toolbox variant.
 * @throws {Error} If the project has no supported Hardhat ethers or viem plugin.
 */
export async function detectHardhatToolbox(projectRoot: string): Promise<ScriptToolbox> {
  let packageJson: {
    dependencies?: Record<string, string>;
    devDependencies?: Record<string, string>;
  };
  try {
    packageJson = JSON.parse(
      await fs.readFile(path.join(projectRoot, "package.json"), "utf8"),
    ) as { dependencies?: Record<string, string>; devDependencies?: Record<string, string> };
  } catch {
    throw new Error("Cannot determine the Hardhat toolbox: package.json is missing or invalid.");
  }

  const dependencies = { ...packageJson.dependencies, ...packageJson.devDependencies };
  if (
    dependencies["@nomicfoundation/hardhat-toolbox-viem"]
    || dependencies["@nomicfoundation/hardhat-viem"]
  ) return "viem";
  if (
    dependencies["@nomicfoundation/hardhat-toolbox-mocha-ethers"]
    || dependencies["@nomicfoundation/hardhat-ethers"]
  ) return "ethers";

  throw new Error(
    "Compose Hardhat deploy requires @nomicfoundation/hardhat-ethers or @nomicfoundation/hardhat-viem. "
    + "Install the toolbox matching your Hardhat project, then retry.",
  );
}

export const HARDHAT_IGNITION_MODULE_ID = "ComposeDeploy";

/** Ignition Future IDs use a predictable identifier independent of local variable naming. */
function toIgnitionFacetId(name: string): string {
  const slug = name.replace(/[^A-Za-z0-9_]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 32) || "Facet";
  const digest = createHash("sha256").update(name).digest("hex").slice(0, 12);
  return `Facet_${slug}_${digest}`;
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
      futureId: toIgnitionFacetId(facet.name),
    };
  });
}

/** Builds a stable journal ID for a plan, with a distinct ID for each redeploy generation. */
export function getIgnitionDeploymentId(plan: DeployPlan): string {
  const slug = (value: string): string =>
    value.toLowerCase().replace(/[^a-z0-9_-]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 22) || "default";
  const identity = [plan.diamondName, plan.chain.chainKey, plan.instance].map(slug).join("-");
  const planSuffix = plan.planHash.slice(2, 18);
  const redeploySuffix = plan.mode === "redeploy" && plan.existing
    ? `-from-${plan.existing.txHash.slice(2, 14).toLowerCase()}`
    : "";
  return `compose-${identity}-${planSuffix}${redeploySuffix}`;
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
    runnerPath: adapter.getManagedDeployRunnerPath(plan.projectRoot),
    ignitionDeploymentId: plan.framework === "hardhat" ? getIgnitionDeploymentId(plan) : null,
    resultPath: adapter.getManagedDeployResultPath(plan.projectRoot),
    projectRoot: plan.projectRoot,
    diamond: { contractName: plan.diamond.contractName, importSpec: plan.diamond.importSpec },
    facets: assignVariableNames(plan.facets),
    chainKey: plan.chain.chainKey,
    chainId: plan.chain.chainId,
    instance: plan.instance,
    account: plan.account,
  };
}
