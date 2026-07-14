import { ComposeContext } from "../../context/types";
import { blue, cyan, dim, green, yellow } from "../../utils/terminal";
import { ComposeProjectInfo, DiamondInfo, FacetInfo, StorageSlotInfo } from "./types";

const TREE_BRANCH = "├── ";
const TREE_LAST = "└── ";
const TREE_PIPE = "│   ";
const TREE_SPACE = "    ";

/**
 * Formats and displays the project info summary to the console.
 *
 * @param ctx - The compose context with scanned project info.
 */
export function showInfo(ctx: ComposeContext): void {
  const projectState = ctx.state.infoProject as { success: boolean; result: ComposeProjectInfo | null } | undefined;
  if (!projectState?.success || !projectState?.result) {
    console.error("No project info available.");
    return;
  }

  const info = projectState.result;

  console.log(cyan(info.project));
  console.log(dim(`${info.framework} · compose ${info.composeVersion}`));
  console.log("");

  if (info.diamonds.length === 0) {
    console.log(dim("  No diamonds defined"));
    console.log("");
    return;
  }

  for (const diamond of info.diamonds) {
    printDiamond(diamond);
    console.log("");
  }

  if (info.warnings.length > 0) {
    for (const warning of info.warnings) {
      console.log(yellow(`⚠ ${warning}`));
    }
    console.log("");
  }
}

/**
 * Prints a single diamond and its facets to the console.
 *
 * @param diamond - The diamond info to print.
 */
function printDiamond(diamond: DiamondInfo): void {
  console.log(blue(`◇ ${diamond.name}`));

  const facetCount = diamond.facets.length;
  const label = facetCount === 1 ? "facet" : "facets";
  console.log(dim(`${TREE_PIPE}${diamond.contract} · ${facetCount} ${label}`));
  console.log(dim(TREE_PIPE));

  if (facetCount === 0) {
    return;
  }

  for (let i = 0; i < facetCount; i++) {
    const isLast = i === facetCount - 1;
    printFacet(diamond.facets[i], isLast, TREE_PIPE);
  }
}

/**
 * Prints a single facet's summary to the console.
 *
 * @param facet - The facet info to print.
 * @param isLast - Whether this is the last facet in the diamond.
 * @param prefix - The tree continuation prefix from the parent.
 */
function printFacet(facet: FacetInfo, isLast: boolean, prefix: string): void {
  const branch = isLast ? TREE_LAST : TREE_BRANCH;
  const childPrefix = prefix + (isLast ? TREE_SPACE : TREE_PIPE);

  console.log(dim(`${prefix}${branch}`) + green(facet.name));

  const sourceLine = formatSource(facet);
  if (sourceLine) {
    console.log(dim(childPrefix) + sourceLine);
  }

  for (const selector of facet.selectors) {
    console.log(dim(childPrefix) + selector);
  }

  for (const slot of facet.storageSlots) {
    console.log(dim(childPrefix) + formatStorageSlot(slot));
  }
}

/**
 * Formats a facet's source type and path.
 *
 * @param facet - The facet to format source for.
 * @returns The formatted source string, or empty if unknown.
 */
function formatSource(facet: FacetInfo): string {
  switch (facet.source) {
    case "local":
      return dim(`local   ${facet.contract}`);
    case "package":
      return dim(`package ${facet.package ?? "unknown"}`);
    case "registry":
      return dim("registry");
    default:
      return dim(facet.source);
  }
}

/**
 * Formats a single storage slot annotation.
 *
 * @param slot - The storage slot info to format.
 * @returns The formatted storage slot string.
 */
function formatStorageSlot(slot: StorageSlotInfo): string {
  const structLabel = slot.structName ? `  ${slot.structName}` : "";
  const layoutStr = slot.layout.length > 0 ? `  ${dim(`[${slot.layout.join(", ")}]`)}` : "";
  return dim(slot.slot) + structLabel + layoutStr;
}
