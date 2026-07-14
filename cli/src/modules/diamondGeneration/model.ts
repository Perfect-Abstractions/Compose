import path from "node:path";
import { ComposeContext } from "../../context/types";
import { ConstructorEntry, Erc165Entry } from "../config/types";
import { getSelectedFacets, targetDirectoryForFacet } from "../scaffolding/module";
import { BasesCatalog } from "../config/types";
import { resolveCatalogSelection, EMPTY_BASE } from "../config/module";
import { DiamondGenerationFile, DiamondGenerationModel, DiamondImport } from "./types";
import {
  contractNameFromSourcePath,
  isComposePackagePath,
  resolveCatalogSourceForRead,
} from "../../utils/soliditySources";
import { toRelativeImport } from "../../utils/files";
import { dedupeBy } from "../../utils/arrays";

const DIAMOND_MOD_PATH = "@perfect-abstractions/compose/diamond/DiamondMod.sol";
const ERC165_MOD_PATH = "@perfect-abstractions/compose/interfaceDetection/ERC165/ERC165Mod.sol";

/**
 * Resolves the complete Diamond generation model by collecting imports, constructor
 * entries, ERC-165 registrations, and file copy operations from all selected facets.
 *
 * @param ctx - The compose context with project parameters and config.
 * @param contractSourceRoot - Directory where generated Solidity files will be written.
 * @returns The fully resolved diamond generation model.
 * @throws {Error} If base is unknown, pragma is invalid, or facets have conflicts.
 */
export function resolveDiamondGenerationModel(
  ctx: ComposeContext,
  contractSourceRoot: string,
): DiamondGenerationModel {
  const catalog = ctx.config.bases as BasesCatalog;
  const selectedBaseKey = String(ctx.param.base ?? "");
  const selectedBase = selectedBaseKey === "none"
    ? EMPTY_BASE
    : catalog.features[selectedBaseKey];
  const projectRoot = String(ctx.param.projectRoot ?? "");
  const solidityPragma = catalog.globals.diamond?.pragma;

  if (!selectedBase) {
    throw new Error(`Cannot generate Diamond.sol: unknown base "${selectedBaseKey}".`);
  }
  if (!projectRoot || !contractSourceRoot) {
    throw new Error("Cannot generate Diamond.sol: project root is not defined.");
  }
  if (
    typeof solidityPragma !== "string" ||
    solidityPragma.trim().length === 0 ||
    /[;\r\n]/.test(solidityPragma)
  ) {
    throw new Error("Cannot generate Diamond.sol: diamond pragma is missing or invalid.");
  }

  const selectedFacets = getSelectedFacets(ctx);
  const selection = resolveCatalogSelection(
    catalog,
    selectedBaseKey,
    (ctx.param.libraries as string[] | undefined) ?? [],
    (ctx.param.extensions as string[] | undefined) ?? [],
    (ctx.param.access as string[] | undefined) ?? [],
    (ctx.param.accessExtensions as string[] | undefined) ?? [],
  );
  const erc165Selected = selectedFacets.some((facet) => facet.name === "ERC165Facet");
  const imports: DiamondImport[] = [];
  const files: DiamondGenerationFile[] = [];
  const constructorEntries: ConstructorEntry[] = [];
  const erc165Registrations: Erc165Entry[] = [];

  addDiamondImport(imports, {
    alias: "DiamondMod",
    path: DIAMOND_MOD_PATH,
    style: "alias",
  });

  for (const facet of selectedFacets) {
    const entry = facet.entry;
    const entryConstructorEntries = Array.isArray(entry.constructor) ? entry.constructor : [];

    for (const constructorEntry of entryConstructorEntries) {
      if (
        !constructorEntry ||
        typeof constructorEntry !== "object" ||
        typeof constructorEntry.code !== "string" ||
        constructorEntry.code.trim().length === 0
      ) {
        throw new Error(`Cannot generate Diamond.sol: ${facet.name} has an invalid constructor entry.`);
      }
      if (
        constructorEntry.comments !== undefined &&
        (!Array.isArray(constructorEntry.comments) ||
          constructorEntry.comments.some((comment) => typeof comment !== "string" || comment.trim().length === 0))
      ) {
        throw new Error(`Cannot generate Diamond.sol: ${facet.name} has invalid constructor comments.`);
      }
      if (/\{\{[^}]+\}\}/.test(constructorEntry.code)) {
        throw new Error(`Cannot generate Diamond.sol: ${facet.name} has an unresolved constructor value.`);
      }
    }

    if (entry.mod) {
      const alias = contractNameFromSourcePath(entry.mod);
      const target = path.join(targetDirectoryForFacet(contractSourceRoot, facet), path.basename(entry.mod));
      if (!isComposePackagePath(entry.mod)) {
        addGenerationFile(files, resolveCatalogSourceForRead(entry.mod), target);
      }
      if (entryConstructorEntries.length > 0) {
        addDiamondImport(imports, {
          alias,
          path: isComposePackagePath(entry.mod) ? entry.mod : toRelativeImport(path.relative(contractSourceRoot, target)),
          style: "alias",
        });
      }
    }

    constructorEntries.push(...entryConstructorEntries);
  }

  if (erc165Selected) {
    addDiamondImport(imports, {
      alias: "ERC165Mod",
      path: ERC165_MOD_PATH,
      style: "alias",
    });

    addErc165Metadata(selectedBase.erc165, contractSourceRoot, imports, files, erc165Registrations);
    for (const accessBase of selection.selectedAccessBases) {
      addErc165Metadata(
        accessBase.erc165,
        contractSourceRoot,
        imports,
        files,
        erc165Registrations,
      );
    }
    for (const facet of selectedFacets) {
      addErc165Metadata(facet.entry.erc165, contractSourceRoot, imports, files, erc165Registrations);
    }
  }

  return {
    contractName: "Diamond",
    solidityPragma: solidityPragma.trim(),
    outputPath: path.join(contractSourceRoot, "Diamond.sol"),
    imports,
    constructorEntries: dedupeBy(constructorEntries, (entry) => entry.code),
    erc165Registrations: dedupeBy(erc165Registrations, (entry) => entry.id),
    files,
  };
}

/**
 * Adds ERC-165 metadata to the generation model, including the import statement,
 * file copy entry, and interface registration.
 *
 * @param metadata - The ERC-165 entry to add, or undefined to skip.
 * @param contractSourceRoot - Directory where interface files will be written.
 * @param imports - Mutable array of diamond imports to append to.
 * @param files - Mutable array of file generation entries to append to.
 * @param registrations - Mutable array of ERC-165 registrations to append to.
 * @throws {Error} If metadata is missing path or id.
 */
function addErc165Metadata(
  metadata: Erc165Entry | undefined,
  contractSourceRoot: string,
  imports: DiamondImport[],
  files: DiamondGenerationFile[],
  registrations: Erc165Entry[],
): void {
  if (!metadata) return;
  if (!metadata.path || !metadata.id) {
    throw new Error("Invalid ERC-165 metadata: both path and id are required.");
  }

  const alias = contractNameFromSourcePath(metadata.path);
  const target = path.join(contractSourceRoot, "interfaces", path.basename(metadata.path));
  if (!isComposePackagePath(metadata.path)) {
    addGenerationFile(files, resolveCatalogSourceForRead(metadata.path), target);
  }
  addDiamondImport(imports, {
    alias,
    path: isComposePackagePath(metadata.path) ? metadata.path : toRelativeImport(path.relative(contractSourceRoot, target)),
    style: "named",
  });
  registrations.push(metadata);
}

/**
 * Adds a diamond import to the list, ensuring no alias conflicts exist.
 *
 * @param imports - Mutable array of existing imports.
 * @param candidate - The import to add.
 * @throws {Error} If the alias already maps to a different path.
 */
function addDiamondImport(imports: DiamondImport[], candidate: DiamondImport): void {
  const aliasMatch = imports.find((entry) => entry.alias === candidate.alias);
  if (aliasMatch && aliasMatch.path !== candidate.path) {
    throw new Error(
      `Cannot generate Diamond.sol: import alias ${candidate.alias} maps to both ${aliasMatch.path} and ${candidate.path}.`,
    );
  }
  if (!aliasMatch) imports.push(candidate);
}

/**
 * Adds a file generation entry, ensuring no target path conflicts exist.
 *
 * @param files - Mutable array of file generation entries.
 * @param source - Source file path to copy from.
 * @param target - Target file path to copy to.
 * @throws {Error} If multiple sources map to the same target.
 */
function addGenerationFile(files: DiamondGenerationFile[], source: string, target: string): void {
  const targetMatch = files.find((entry) => entry.target === target);
  if (targetMatch && targetMatch.source !== source) {
    throw new Error(`Cannot generate Diamond.sol: multiple sources map to ${target}.`);
  }
  if (!targetMatch) files.push({ source, target });
}
