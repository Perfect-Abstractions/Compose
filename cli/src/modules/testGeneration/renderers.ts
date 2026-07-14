import { TestFacetEntry, TestGenerationModel } from "./types";
import { toCamelCase } from "../../utils/strings";
import { loadTemplate } from "../../utils/codegen";

/**
 * Checks if an import path refers to an npm package (starts with "@").
 *
 * @param importPath - The import path to check.
 * @returns True if the path is a package import.
 */
function isPackagePath(importPath: string): boolean {
  return importPath.startsWith("@");
}

/**
 * Renders a Foundry (Solidity) test file that deploys all facets and
 * creates a Diamond instance for testing.
 *
 * @param model - The test generation model with facet entries.
 * @returns The complete Solidity test source code.
 */
export async function renderFoundryTest(model: TestGenerationModel): Promise<string> {
  const template = await loadTemplate("test", "foundry-test.sol");

  const imports = model.facets
    .map((facet) => {
      const importPath = isPackagePath(facet.importPath)
        ? facet.importPath
        : `../${facet.importPath}`;
      return `import {${facet.contractName}} from "${importPath}";`;
    })
    .join("\n");

  const baseFacets = model.facets.filter((facet) => facet.group === "base");
  const libraryFacets = model.facets.filter((facet) => facet.group === "library");
  let index = 0;

  const renderSetupLine = (facet: TestFacetEntry): string => {
    const line = `        facets[${index}] = address(new ${facet.contractName}());`;
    index += 1;
    return line;
  };

  const baseLines = baseFacets.map(renderSetupLine).join("\n");
  const libraryLines = libraryFacets.map(renderSetupLine).join("\n");

  return template
    .replaceAll("{{IMPORTS}}", imports)
    .replaceAll("{{FACET_COUNT}}", String(model.facetCount))
    .replaceAll("{{BASE_LINES}}", baseLines)
    .replaceAll("{{LIBRARY_LINES}}", libraryLines);
}

/**
 * Renders a single facet deployment line using Hardhat + ethers.js.
 *
 * @param facet - The facet entry to deploy.
 * @returns TypeScript code that deploys the facet and pushes its address.
 */
function renderHardhatEthersFacetDeploy(facet: TestFacetEntry): string {
  const variableName = toCamelCase(facet.contractName) || "facet";
  return `    const ${variableName} = await ethers.deployContract("${facet.contractName}");
    await ${variableName}.waitForDeployment();
    facets.push(await ${variableName}.getAddress());`;
}

/**
 * Renders a single facet deployment line using Hardhat + viem.
 *
 * @param facet - The facet entry to deploy.
 * @returns TypeScript code that deploys the facet and pushes its address.
 */
function renderHardhatViemFacetDeploy(facet: TestFacetEntry): string {
  const variableName = toCamelCase(facet.contractName) || "facet";
  return `    const ${variableName} = await viem.deployContract("${facet.contractName}");
    facets.push(${variableName}.address);`;
}

/**
 * Renders base and library facet deploy sections for a Hardhat test file
 * using the provided per-facet renderer.
 *
 * @param model - The test generation model with facet entries.
 * @param renderFacetDeploy - Callback to render a single facet's deploy code.
 * @returns An object with `baseLines` and `libraryLines` strings.
 */
function renderHardhatDeploySections(
  model: TestGenerationModel,
  renderFacetDeploy: (facet: TestFacetEntry) => string,
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
 * Renders a complete Hardhat + ethers.js test file for the Diamond.
 *
 * @param model - The test generation model with facet entries.
 * @returns The complete TypeScript test source code.
 */
export async function renderHardhatEthersTest(model: TestGenerationModel): Promise<string> {
  const [template, { baseLines, libraryLines }] = await Promise.all([
    loadTemplate("test", "hardhat-ethers-test.ts"),
    renderHardhatDeploySections(model, renderHardhatEthersFacetDeploy),
  ]);

  return template
    .replaceAll("{{BASE_LINES}}", baseLines)
    .replaceAll("{{LIBRARY_LINES}}", libraryLines)
    .replaceAll("{{FACET_COUNT}}", String(model.facetCount));
}

/**
 * Renders a complete Hardhat + viem test file for the Diamond.
 *
 * @param model - The test generation model with facet entries.
 * @returns The complete TypeScript test source code.
 */
export async function renderHardhatViemTest(model: TestGenerationModel): Promise<string> {
  const [template, { baseLines, libraryLines }] = await Promise.all([
    loadTemplate("test", "hardhat-viem-test.ts"),
    renderHardhatDeploySections(model, renderHardhatViemFacetDeploy),
  ]);

  return template
    .replaceAll("{{BASE_LINES}}", baseLines)
    .replaceAll("{{LIBRARY_LINES}}", libraryLines)
    .replaceAll("{{FACET_COUNT}}", String(model.facetCount));
}
