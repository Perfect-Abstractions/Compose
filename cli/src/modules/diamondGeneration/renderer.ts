import { ConstructorEntry, Erc165Entry } from "../config/types";
import { DiamondGenerationModel, DiamondImport } from "./types";
import { loadTemplate } from "../../utils/codegen";

/**
 * Renders the complete Diamond.sol contract by filling a template with imports,
 * constructor blocks, and ERC-165 registrations from the generation model.
 *
 * @param model - The diamond generation model with all data needed for rendering.
 * @returns The complete Solidity source code for Diamond.sol.
 */
export async function renderDiamondContract(model: DiamondGenerationModel): Promise<string> {
  const template = await loadTemplate("diamond", "diamond.sol");

  const imports = model.imports.map(renderDiamondImport).join("\n");
  const constructorBlocks = [
    "        DiamondMod.addFacets(_facets);",
    ...model.constructorEntries.map(renderConstructorEntry),
    ...model.erc165Registrations.map(renderErc165Registration),
  ].join("\n\n");

  return template
    .replace("{{SOLIDITY_PRAGMA}}", model.solidityPragma)
    .replace("{{IMPORTS}}", imports)
    .replace("{{CONTRACT_NAME}}", model.contractName)
    .replace("{{CONSTRUCTOR_BLOCKS}}", constructorBlocks);
}

/**
 * Renders a single Solidity import statement in named or alias style.
 *
 * @param entry - The diamond import entry to render.
 * @returns The formatted import statement string.
 */
function renderDiamondImport(entry: DiamondImport): string {
  if (entry.style === "named") return `import {${entry.alias}} from "${entry.path}";`;
  return `import "${entry.path}" as ${entry.alias};`;
}

/**
 * Renders a constructor entry with optional preceding comment lines.
 *
 * @param entry - The constructor entry containing code and optional comments.
 * @returns The formatted constructor code block.
 */
function renderConstructorEntry(entry: ConstructorEntry): string {
  return renderCommentedCode(entry.comments, entry.code);
}

/**
 * Renders an ERC-165 interface registration call with optional comments.
 *
 * @param entry - The ERC-165 entry containing the interface ID and comments.
 * @returns The formatted registration code block.
 */
function renderErc165Registration(entry: Erc165Entry): string {
  return renderCommentedCode(entry.comments, `ERC165Mod.registerInterface(${entry.id});`);
}

/**
 * Renders a code line with optional comment lines above it, each indented
 * with 8 spaces to align with the Diamond contract body.
 *
 * @param comments - Optional array of comment strings (may contain newlines).
 * @param code - The code line to render.
 * @returns The formatted block with comments and code.
 */
function renderCommentedCode(comments: string[] | undefined, code: string): string {
  return [
    ...(comments ?? []).flatMap((comment) => comment.split(/\r?\n/).map((line) => `        // ${line}`)),
    `        ${code}`,
  ].join("\n");
}
