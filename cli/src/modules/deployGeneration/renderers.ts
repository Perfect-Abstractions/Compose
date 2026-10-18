import { DeployFacetEntry, DeployGenerationModel } from "./types";
import { toCamelCase } from "../../utils/strings";
import { loadTemplate } from "../../utils/codegen";
import path from "node:path";
import { toPosixPath, toRelativeImport } from "../../utils/files";
import { renderFacetSections } from "../facetSections";

function scriptImport(model: DeployGenerationModel, importPath: string): string {
  return toRelativeImport(toPosixPath(path.relative(
    path.dirname(model.outputPath), path.resolve(model.projectRoot, importPath),
  )));
}

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
      const importPath = facet.origin === "local" || !facet.importPath.startsWith("@")
        ? scriptImport(model, facet.importPath)
        : facet.importPath;
      return `import {${facet.contractName}} from "${importPath}";`;
    })
    .join("\n");
  let index = 0;

  const renderDeployLine = (facet: DeployFacetEntry): string => {
    const line = `        facets[${index}] = address(new ${facet.contractName}());
        console.log("${facet.contractName}:", facets[${index}]);`;
    index += 1;
    return line;
  };

  const { baseLines, libraryLines } = renderFacetSections(model.facets, renderDeployLine, "\n");

  return template
    .replaceAll("{{DIAMOND_NAME}}", model.diamond.contractName)
    .replace("{{DIAMOND_IMPORT}}", scriptImport(model, model.diamond.importPath))
    .replace("{{IMPORTS}}", imports)
    .replace("{{FACET_COUNT}}", String(model.facets.length))
    .replace("{{BASE_LINES}}", baseLines)
    .replace("{{LIBRARY_SECTION}}", libraryLines ? `\n\n        /* Library facet generation. */\n${libraryLines}` : "");
}

/**
 * Renders a single facet deployment line using Hardhat + ethers.js.
 *
 * @param facet - The facet entry to deploy.
 * @returns TypeScript code that deploys the facet and pushes its address.
 */
function renderHardhatEthersFacetDeploy(facet: DeployFacetEntry): string {
  const variableName = toCamelCase(facet.contractName) || "facet";
  return `  const ${variableName} = await ethers.deployContract("${facet.deploymentReference ?? `${facet.importPath}:${facet.contractName}`}");
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
  return `  const ${variableName} = await viem.deployContract("${facet.deploymentReference ?? `${facet.importPath}:${facet.contractName}`}");
  console.log("${facet.contractName}:", ${variableName}.address);
  facets.push(${variableName}.address);`;
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
    renderFacetSections(model.facets, renderHardhatEthersFacetDeploy, "\n\n"),
  ]);

  return template
    .replace("{{DIAMOND_REFERENCE}}", model.diamond.deploymentReference ?? `${toPosixPath(model.diamond.importPath)}:${model.diamond.contractName}`)
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
    renderFacetSections(model.facets, renderHardhatViemFacetDeploy, "\n\n"),
  ]);

  return template
    .replace("{{DIAMOND_REFERENCE}}", model.diamond.deploymentReference ?? `${toPosixPath(model.diamond.importPath)}:${model.diamond.contractName}`)
    .replace("{{BASE_LINES}}", baseLines)
    .replace("{{LIBRARY_LINES}}", libraryLines);
}
