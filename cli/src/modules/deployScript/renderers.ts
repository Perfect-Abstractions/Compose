import { loadTemplate } from "../../utils/codegen";
import { toPosixPath, toProjectRelativePath } from "../../utils/files";
import path from "node:path";
import { HARDHAT_IGNITION_MODULE_ID } from "./model";
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
  const accountGuard = model.account
    ? [
        `        (, address composeSigner, ) = vm.readCallers();`,
        `        console.log("Deployer:", composeSigner);`,
        `        if (composeSigner != ${model.account.address}) revert("Compose: selected signer does not match account '${jsonEscape(model.account.alias)}'");`,
      ].join("\n")
    : `        (, address composeSigner, ) = vm.readCallers();\n        console.log("Deployer:", composeSigner);`;

  return template
    .replace(/\{\{PLAN_HASH\}\}/g, model.planHash)
    .replace(/\{\{IMPORTS\}\}/g, importLines(model).join("\n"))
    .replace(/\{\{DIAMOND_CONTRACT\}\}/g, model.diamond.contractName)
    .replace(/\{\{FACET_COUNT\}\}/g, String(model.facets.length))
    .replace(/\{\{ACCOUNT_GUARD\}\}/g, accountGuard)
    .replace(/\{\{DEPLOY_LINES\}\}/g, deployLines)
    .replace(/\{\{CHAIN_KEY\}\}/g, jsonEscape(model.chainKey))
    .replace(/\{\{CHAIN_ID\}\}/g, String(model.chainId));
}

function renderIgnitionFacetFutures(facets: ScriptFacetEntry[]): string {
  return facets.map((facet) =>
    `  const ${facet.variableName} = m.contract(${JSON.stringify(facet.contractName)}, [], {\n`
    + `    id: ${JSON.stringify(facet.futureId)},\n`
    + "  });",
  ).join("\n\n");
}

function renderIgnitionResultEntries(facets: ScriptFacetEntry[]): string {
  return facets.map((facet) => `    ${facet.variableName},`).join("\n");
}

/** Renders the reviewable Hardhat Ignition module. */
export async function renderHardhatIgnitionModule(model: ManagedScriptModel): Promise<string> {
  if (!model.ignitionDeploymentId) {
    throw new Error("The Hardhat Ignition module requires a deployment ID.");
  }
  const template = await loadTemplate("deploy", "compose-hardhat-ignition-module.ts");
  return template
    .split("{{PLAN_HASH}}").join(model.planHash)
    .split("{{IGNITION_DEPLOYMENT_ID}}").join(model.ignitionDeploymentId)
    .split("{{IGNITION_MODULE_ID}}").join(HARDHAT_IGNITION_MODULE_ID)
    .split("{{FACET_FUTURES}}").join(renderIgnitionFacetFutures(model.facets))
    .split("{{DIAMOND_CONTRACT}}").join(model.diamond.contractName)
    .split("{{FACET_VARIABLES}}").join(model.facets.map((facet) => facet.variableName).join(", "))
    .split("{{FACET_RESULTS}}").join(renderIgnitionResultEntries(model.facets));
}

function renderSignerResolution(model: ManagedScriptModel): string {
  const expected = JSON.stringify(model.account?.address ?? null);
  const missingSigner = JSON.stringify(model.account
    ? `Hardhat has no configured signer for Compose account '${model.account.alias}' (${model.account.address}).`
    : "Hardhat has no configured deployment signer.");
  const signerMismatch = JSON.stringify(model.account
    ? `Resolved signer does not match Compose account '${model.account.alias}'.`
    : "Resolved signer does not match the expected account.");
  const prefix = `  const expectedAccountAddress: string | null = ${expected};\n`;

  if (model.toolbox === "viem") {
    return prefix
      + "  const { viem: targetViem } = targetConnection;\n"
      + "  const configuredWallets = await targetViem.getWalletClients();\n"
      + "  const targetDeployer = expectedAccountAddress\n"
      + "    ? configuredWallets.find((wallet) => wallet.account?.address.toLowerCase() === expectedAccountAddress.toLowerCase())\n"
      + "    : configuredWallets[0];\n"
      + "  const deployerAddress = targetDeployer?.account?.address;\n"
      + `  if (!deployerAddress) throw new Error(${missingSigner});\n`
      + "  if (expectedAccountAddress && deployerAddress.toLowerCase() !== expectedAccountAddress.toLowerCase()) {\n"
      + `    throw new Error(${signerMismatch});\n`
      + "  }";
  }

  return prefix
    + "  const { ethers: targetEthers } = targetConnection;\n"
    + "  const configuredSigners = await targetEthers.getSigners();\n"
    + "  const targetDeployer = expectedAccountAddress\n"
    + "    ? await (async () => {\n"
    + "        for (const signer of configuredSigners) {\n"
    + "          if ((await signer.getAddress()).toLowerCase() === expectedAccountAddress.toLowerCase()) return signer;\n"
    + "        }\n"
    + "        return undefined;\n"
    + "      })()\n"
    + "    : configuredSigners[0];\n"
    + `  if (!targetDeployer) throw new Error(${missingSigner});\n`
    + "  const deployerAddress = await targetDeployer.getAddress();\n"
    + "  if (expectedAccountAddress && deployerAddress.toLowerCase() !== expectedAccountAddress.toLowerCase()) {\n"
    + `    throw new Error(${signerMismatch});\n`
    + "  }";
}

function renderFacetAddressEntries(facets: ScriptFacetEntry[]): string {
  return facets.map((facet) =>
    `    ${JSON.stringify(facet.name)}: await addressOf(outputs.${facet.variableName}),`,
  ).join("\n");
}

/** Renders the ignored, transient runner that executes the reviewed module. */
export async function renderHardhatIgnitionRunner(model: ManagedScriptModel): Promise<string> {
  if (!model.runnerPath || !model.ignitionDeploymentId || !model.resultPath || !model.toolbox) {
    throw new Error("The Hardhat Ignition runner is missing required deployment paths or metadata.");
  }
  const template = await loadTemplate("deploy", "compose-hardhat-ignition-runner.ts");
  const moduleImport = toPosixPath(path.relative(path.dirname(model.runnerPath), model.outputPath))
    .replace(/\.ts$/, ".js");
  const moduleSpecifier = moduleImport.startsWith(".") ? moduleImport : `./${moduleImport}`;
  return template
    .split("{{MODULE_IMPORT}}").join(moduleSpecifier)
    .split("{{CHAIN_ID}}").join(String(model.chainId))
    .split("{{IGNITION_DEPLOYMENT_ID}}").join(JSON.stringify(model.ignitionDeploymentId))
    .split("{{ACCOUNT_ADDRESS}}").join(JSON.stringify(model.account?.address ?? null))
    .split("{{RESULT_PATH}}").join(JSON.stringify(toProjectRelativePath(model.projectRoot, model.resultPath)))
    .split("{{CHAIN_KEY}}").join(JSON.stringify(model.chainKey))
    .split("{{RESOLVE_SIGNER}}").join(renderSignerResolution(model))
    .split("{{FACET_ADDRESS_ENTRIES}}").join(renderFacetAddressEntries(model.facets))
    .split("{{PLAN_HASH}}").join(model.planHash)
    .split("{{INSTANCE}}").join(JSON.stringify(model.instance));
}
