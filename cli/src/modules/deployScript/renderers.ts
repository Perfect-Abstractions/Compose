import { loadTemplate } from "../../utils/codegen";
import { toProjectRelativePath } from "../../utils/files";
import type { ManagedScriptModel, ScriptFacetEntry } from "./types";

/** Escapes a string for embedding inside a JSON string literal. */
function jsonEscape(value: string): string {
  return JSON.stringify(value).slice(1, -1);
}

/** Unique import lines: the diamond contract first, then every facet source. */
function importLines(model: ManagedScriptModel): string[] {
  const lines = [
    `import {${model.diamond.contractName}} from "${model.diamond.importSpec}";`,
    ...model.facets.map((facet) => `import {${facet.contractName}} from "${facet.importSpec}";`),
  ];
  return [...new Set(lines)];
}

/**
 * Renders the Foundry managed deploy script for a plan.
 *
 * The script only deploys facets and the diamond; `compose deploy` derives
 * the resulting addresses from the run broadcast, because Foundry restricts
 * cheatcode file writes to explicitly permitted paths.
 *
 * @param model - The managed script model.
 * @returns The complete Solidity script source.
 */
export async function renderFoundryDeployScript(model: ManagedScriptModel): Promise<string> {
  const template = await loadTemplate("deploy", "compose-foundry.s.sol");

  const deployLines = model.facets
    .map((facet, index) =>
      [
        `        ${facet.contractName} ${facet.variableName} = new ${facet.contractName}();`,
        `        facets[${index}] = address(${facet.variableName});`,
        `        console.log("${jsonEscape(facet.name)}:", address(${facet.variableName}));`,
      ].join("\n"),
    )
    .join("\n\n");

  return template
    .replace(/\{\{PLAN_HASH\}\}/g, model.planHash)
    .replace(/\{\{IMPORTS\}\}/g, importLines(model).join("\n"))
    .replace(/\{\{DIAMOND_CONTRACT\}\}/g, model.diamond.contractName)
    .replace(/\{\{FACET_COUNT\}\}/g, String(model.facets.length))
    .replace(/\{\{DEPLOY_LINES\}\}/g, deployLines)
    .replace(/\{\{CHAIN_KEY\}\}/g, jsonEscape(model.chainKey))
    .replace(/\{\{CHAIN_ID\}\}/g, String(model.chainId));
}

function renderHardhatEthersDeployLines(facets: ScriptFacetEntry[]): string {
  return facets
    .map((facet) =>
      [
        `  const ${facet.variableName} = await ethers.deployContract("${facet.contractName}");`,
        `  await ${facet.variableName}.waitForDeployment();`,
        `  facets.push(await ${facet.variableName}.getAddress());`,
        `  console.log("${jsonEscape(facet.name)}:", await ${facet.variableName}.getAddress());`,
      ].join("\n"),
    )
    .join("\n\n");
}

function renderHardhatViemDeployLines(facets: ScriptFacetEntry[]): string {
  return facets
    .map((facet) =>
      [
        `  const ${facet.variableName}Deployment = await viem.sendDeploymentTransaction("${facet.contractName}");`,
        `  await publicClient.waitForTransactionReceipt({ hash: ${facet.variableName}Deployment.deploymentTransaction.hash });`,
        `  facets.push(${facet.variableName}Deployment.contract.address);`,
        `  console.log("${jsonEscape(facet.name)}:", ${facet.variableName}Deployment.contract.address);`,
      ].join("\n"),
    )
    .join("\n\n");
}

function renderFacetEntries(
  facets: ScriptFacetEntry[],
  addressExpression: (facet: ScriptFacetEntry) => string,
): string {
  return facets
    .map((facet) => `    "${jsonEscape(facet.name)}": ${addressExpression(facet)},`)
    .join("\n");
}

/**
 * Renders the Hardhat managed deploy script (ethers or viem toolbox) for a plan.
 *
 * @param model - The managed script model.
 * @returns The complete TypeScript script source.
 * @throws {Error} If the model has no deploy result path.
 */
export async function renderHardhatDeployScript(model: ManagedScriptModel): Promise<string> {
  if (!model.resultPath) {
    throw new Error("The Hardhat managed script requires a deploy result path.");
  }

  const viem = model.toolbox === "viem";
  const template = await loadTemplate(
    "deploy",
    viem ? "compose-hardhat-viem.ts" : "compose-hardhat-ethers.ts",
  );

  const deployLines = viem
    ? renderHardhatViemDeployLines(model.facets)
    : renderHardhatEthersDeployLines(model.facets);
  const facetEntries = renderFacetEntries(
    model.facets,
    viem
      ? (facet) => `${facet.variableName}Deployment.contract.address`
      : (facet) => `await ${facet.variableName}.getAddress()`,
  );

  return template
    .replace(/\{\{PLAN_HASH\}\}/g, model.planHash)
    .replace(/\{\{DIAMOND_CONTRACT\}\}/g, model.diamond.contractName)
    .replace(/\{\{DEPLOY_LINES\}\}/g, deployLines)
    .replace(/\{\{FACET_ENTRIES\}\}/g, facetEntries)
    .replace(/\{\{RESULT_PATH\}\}/g, jsonEscape(toProjectRelativePath(model.projectRoot, model.resultPath)))
    .replace(/\{\{CHAIN_KEY\}\}/g, jsonEscape(model.chainKey))
    .replace(/\{\{CHAIN_ID\}\}/g, String(model.chainId))
    .replace(/\{\{INSTANCE\}\}/g, jsonEscape(model.instance));
}
