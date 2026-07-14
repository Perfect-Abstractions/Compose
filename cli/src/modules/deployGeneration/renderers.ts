import { DeployFacetEntry, DeployGenerationModel } from "./types";
import { toCamelCase } from "../../utils/strings";
import { loadTemplate } from "../../utils/codegen";

/**
 * Renders a Foundry (Solidity) deploy script that deploys a Diamond proxy
 * with all facets in base-first, library-second order.
 *
 * @param model - The deploy generation model with facet entries and output path.
 * @returns The complete Solidity deploy script source code.
 */
export async function renderFoundryDeployScript(model: DeployGenerationModel): Promise<string> {
  const template = await loadTemplate("deploy", "foundry-deploy.sol");

  const imports = model.facets
    .map((facet) => {
      const importPath = facet.origin === "local"
        ? `../${facet.importPath}`
        : facet.importPath;
      return `import {${facet.contractName}} from "${importPath}";`;
    })
    .join("\n");
  const baseFacets = model.facets.filter((facet) => facet.group === "base");
  const libraryFacets = model.facets.filter((facet) => facet.group === "library");
  let index = 0;

  const renderDeployLine = (facet: DeployFacetEntry): string => {
    const line = `        facets[${index}] = address(new ${facet.contractName}());
        console.log("${facet.contractName}:", facets[${index}]);`;
    index += 1;
    return line;
  };

  const baseLines = baseFacets.map(renderDeployLine).join("\n");
  const libraryLines = libraryFacets.map(renderDeployLine).join("\n");

  return template
    .replace("{{IMPORTS}}", imports)
    .replace("{{FACET_COUNT}}", String(model.facets.length))
    .replace("{{BASE_LINES}}", baseLines)
    .replace("{{LIBRARY_LINES}}", libraryLines);
}

/**
 * Renders a single facet deployment line using Hardhat + ethers.js.
 *
 * @param facet - The facet entry to deploy.
 * @returns TypeScript code that deploys the facet and pushes its address.
 */
function renderHardhatEthersFacetDeploy(facet: DeployFacetEntry): string {
  const variableName = toCamelCase(facet.contractName) || "facet";
  return `  const ${variableName} = await ethers.deployContract("${facet.contractName}");
  await ${variableName}.waitForDeployment();
  console.log("${facet.contractName}:", await ${variableName}.getAddress());
  facets.push(await ${variableName}.getAddress());`;
}

/**
 * Renders a single facet deployment line using Hardhat + viem.
 *
 * @param facet - The facet entry to deploy.
 * @returns TypeScript code that deploys the facet and pushes its address.
 */
function renderHardhatViemFacetDeploy(facet: DeployFacetEntry): string {
  const variableName = toCamelCase(facet.contractName) || "facet";
  return `  const ${variableName} = await viem.deployContract("${facet.contractName}");
  console.log("${facet.contractName}:", ${variableName}.address);
  facets.push(${variableName}.address);`;
}

/**
 * Renders base and library facet deploy sections for a Hardhat deploy script
 * using the provided per-facet renderer.
 *
 * @param model - The deploy generation model with facet entries.
 * @param renderFacetDeploy - Callback to render a single facet's deploy code.
 * @returns An object with `baseLines` and `libraryLines` strings.
 */
function renderHardhatDeploySections(
  model: DeployGenerationModel,
  renderFacetDeploy: (facet: DeployFacetEntry) => string,
): { baseLines: string; libraryLines: string } {
  const baseLines = model.facets
    .filter((facet) => facet.group === "base")
    .map(renderFacetDeploy)
    .join("\n\n");
  const libraryLines = model.facets
    .filter((facet) => facet.group === "library")
    .map(renderFacetDeploy)
    .join("\n\n");

  return { baseLines, libraryLines };
}

/**
 * Renders a complete Hardhat + ethers.js deploy script that deploys a Diamond proxy.
 *
 * @param model - The deploy generation model with facet entries and output path.
 * @returns The complete TypeScript deploy script source code.
 */
export async function renderHardhatEthersDeployScript(model: DeployGenerationModel): Promise<string> {
  const [template, { baseLines, libraryLines }] = await Promise.all([
    loadTemplate("deploy", "hardhat-ethers-deploy.ts"),
    renderHardhatDeploySections(model, renderHardhatEthersFacetDeploy),
  ]);

  return template
    .replace("{{BASE_LINES}}", baseLines)
    .replace("{{LIBRARY_LINES}}", libraryLines);
}

/**
 * Renders a complete Hardhat + viem deploy script that deploys a Diamond proxy.
 *
 * @param model - The deploy generation model with facet entries and output path.
 * @returns The complete TypeScript deploy script source code.
 */
export async function renderHardhatViemDeployScript(model: DeployGenerationModel): Promise<string> {
  const [template, { baseLines, libraryLines }] = await Promise.all([
    loadTemplate("deploy", "hardhat-viem-deploy.ts"),
    renderHardhatDeploySections(model, renderHardhatViemFacetDeploy),
  ]);

  return template
    .replace("{{BASE_LINES}}", baseLines)
    .replace("{{LIBRARY_LINES}}", libraryLines);
}
