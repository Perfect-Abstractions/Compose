import fs from "node:fs/promises";
import path from "node:path";
import { ComposeContext } from "../../context/types";
import {
  extractSolidityContractBody,
  parseExportedSelectorSignatures,
  parseSolidityFunctions,
} from "../../utils/solidityText";
import { ScaffoldingModule } from "../scaffolding/module";
import { ComposeProjectInfo, DiamondInfo, FacetInfo } from "./types";

/**
 * Resolves a local facet contract path to an absolute file path,
 * relative to the compose.json directory.
 *
 * @param contract - The contract reference from compose.json (may contain ":" suffix).
 * @param composeJsonDir - Directory containing compose.json.
 * @returns The resolved absolute file path.
 */
function resolveLocalFacetPath(
  contract: string,
  composeJsonDir: string,
): string {
  const contractPath = contract.split(":")[0];
  return path.resolve(composeJsonDir, contractPath);
}

/**
 * Searches for a package facet's .sol file in the installed package directories.
 * Checks node_modules and Foundry lib directories.
 *
 * @param facetName - Name of the facet contract file (without extension).
 * @param packageName - The npm or package name to search within.
 * @param projectRoot - The project root directory.
 * @returns The resolved absolute path, or null if not found.
 */
async function resolvePackageFacetPath(
  facetName: string,
  packageName: string,
  projectRoot: string,
): Promise<string | null> {
  const candidates = [
    path.join(projectRoot, "node_modules", packageName),
    path.join(projectRoot, "lib", "Compose", "src"),
  ];

  for (const candidate of candidates) {
    try {
      const entries = await fs.readdir(candidate, { recursive: true, withFileTypes: true });
      for (const entry of entries) {
        if (entry.isFile() && entry.name === `${facetName}.sol`) {
          return path.join(entry.parentPath ?? entry.path, entry.name);
        }
      }
    } catch {
      // Directory doesn't exist, continue
    }
  }

  return null;
}

/**
 * Scans all facets in all diamonds to extract selectors and storage layouts.
 * Updates the projectInfo in ctx.state.infoProject with the scanned data.
 *
 * @param ctx - The compose context with parsed project info.
 * @returns The updated context with scanned facet data.
 */
export async function scanFacets(ctx: ComposeContext): Promise<ComposeContext> {
  const projectState = ctx.state.infoProject as { success: boolean; result: ComposeProjectInfo | null } | undefined;
  if (!projectState?.success || !projectState?.result) {
    return ctx;
  }

  const loaderState = ctx.state.infoLoader as { result: { composeJsonPath: string } | null } | undefined;
  const composeJsonPath = loaderState?.result?.composeJsonPath;
  if (!composeJsonPath) {
    return ctx;
  }

  const composeJsonDir = path.dirname(composeJsonPath);
  const projectInfo = projectState.result;
  const warnings: string[] = [...projectInfo.warnings];

  for (const diamond of projectInfo.diamonds) {
    await scanDiamond(diamond, composeJsonDir, warnings);
  }

  projectInfo.warnings = warnings;

  ctx.state.infoProject = {
    success: true,
    result: projectInfo,
    error: null,
  };

  return ctx;
}

/**
 * Scans a single diamond's facets for selectors and storage layouts.
 *
 * @param diamond - The diamond to scan (mutated in place).
 * @param composeJsonDir - Directory containing compose.json for path resolution.
 * @param warnings - Mutable array to append warning messages to.
 */
async function scanDiamond(
  diamond: DiamondInfo,
  composeJsonDir: string,
  warnings: string[],
): Promise<void> {
  for (const facet of diamond.facets) {
    await scanFacet(facet, composeJsonDir, warnings);
  }
}

/**
 * Scans a single facet for selectors and storage layouts by reading its source file.
 *
 * @param facet - The facet to scan (mutated in place).
 * @param composeJsonDir - Directory containing compose.json for path resolution.
 * @param warnings - Mutable array to append warning messages to.
 */
async function scanFacet(
  facet: FacetInfo,
  composeJsonDir: string,
  warnings: string[],
): Promise<void> {
  if (facet.source === "package") {
    if (!facet.package) {
      warnings.push(`Package facet ${facet.name}: missing "package" field in compose.json`);
      return;
    }

    const resolvedPath = await resolvePackageFacetPath(facet.name, facet.package, composeJsonDir);
    if (!resolvedPath) {
      warnings.push(`Package facet ${facet.name}: source not found in ${facet.package}`);
      return;
    }

    try {
      const source = await fs.readFile(resolvedPath, "utf8");
      extractFacetInfo(facet, source, warnings);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      warnings.push(`Package facet ${facet.name}: cannot read source - ${message}`);
    }
    return;
  }

  // Local facets: resolve relative to compose.json directory
  try {
    const resolvedPath = resolveLocalFacetPath(facet.contract, composeJsonDir);
    const source = await fs.readFile(resolvedPath, "utf8");
    extractFacetInfo(facet, source, warnings);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    warnings.push(`Facet ${facet.name}: cannot read source - ${message}`);
  }
}

/**
 * Extracts selectors and storage layouts from facet Solidity source code.
 *
 * @param facet - The facet to populate (mutated in place).
 * @param source - The Solidity source code string.
 * @param warnings - Mutable array to append warning messages to.
 */
function extractFacetInfo(
  facet: FacetInfo,
  source: string,
  warnings: string[],
): void {
  const contractBody = extractSolidityContractBody(source, facet.name);
  if (!contractBody) {
    warnings.push(`Facet ${facet.name}: contract ${facet.name} not found in source`);
    return;
  }

  // Extract functions and exported selectors
  const functions = parseSolidityFunctions(contractBody);
  const exportedSignatures = parseExportedSelectorSignatures(contractBody, functions);
  facet.selectors = exportedSignatures;

  if (exportedSignatures.length === 0) {
    warnings.push(`Facet ${facet.name}: no exported selectors found`);
  }

  // Extract storage layouts
  const storageScan = ScaffoldingModule.parseStorageLayouts(source);
  facet.storageSlots = storageScan.layouts.map((layout) => ({
    slot: layout.slot,
    layout: layout.layout,
    source: layout.source,
    structName: layout.structName,
  }));

  if (storageScan.warnings.length > 0) {
    for (const warning of storageScan.warnings) {
      warnings.push(`Facet ${facet.name}: ${warning}`);
    }
  }
}
