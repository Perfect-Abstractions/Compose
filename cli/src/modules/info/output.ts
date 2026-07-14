import { ComposeContext } from "../../context/types";
import { cyan, dim, green, yellow } from "../../utils/terminal";
import { ComposeProjectInfo, DiamondInfo, FacetInfo, StorageSlotInfo } from "./types";

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

  // Header
  console.log(cyan(`Project: ${info.project}`));
  console.log(dim(`Framework: ${info.framework}`));
  console.log("");

  if (info.diamonds.length === 0) {
    console.log(yellow("  No diamonds defined in compose.json"));
    return;
  }

  // Diamonds
  for (const diamond of info.diamonds) {
    printDiamond(diamond);
  }

  // Warnings
  if (info.warnings.length > 0) {
    console.log(yellow("\nWarnings:"));
    for (const warning of info.warnings) {
      console.log(yellow(`  ${warning}`));
    }
  }

  console.log("");
}

/**
 * Prints a single diamond's summary to the console.
 *
 * @param diamond - The diamond info to print.
 */
function printDiamond(diamond: DiamondInfo): void {
  console.log(cyan(`Diamond: ${diamond.name}`));
  console.log(dim(`  Contract: ${diamond.contract}`));
  console.log("");

  if (diamond.facets.length === 0) {
    console.log(dim("  No facets defined"));
    console.log("");
    return;
  }

  console.log(`  Facets (${diamond.facets.length}):`);
  console.log("");

  for (const facet of diamond.facets) {
    printFacet(facet);
  }
}

/**
 * Prints a single facet's summary to the console.
 *
 * @param facet - The facet info to print.
 */
function printFacet(facet: FacetInfo): void {
  console.log(green(`    ${facet.name}`));
  printSource(facet);
  printSelectors(facet);
  printStorageSlots(facet);
  console.log("");
}

/**
 * Prints the facet source type and path to the console.
 *
 * @param facet - The facet info to print source for.
 */
function printSource(facet: FacetInfo): void {
  switch (facet.source) {
    case "local":
      console.log(dim(`      Source: local (${facet.contract})`));
      break;
    case "package":
      console.log(dim(`      Source: package (${facet.package ?? "unknown"})`));
      break;
    case "registry":
      console.log(dim(`      Source: registry`));
      break;
    default:
      console.log(dim(`      Source: ${facet.source}`));
  }
}

/**
 * Prints the facet's exported selectors to the console.
 *
 * @param facet - The facet info to print selectors for.
 */
function printSelectors(facet: FacetInfo): void {
  if (facet.selectors.length === 0) {
    console.log(dim("      Selectors: (none)"));
    return;
  }

  console.log("      Selectors:");
  for (const selector of facet.selectors) {
    console.log(`        ${selector}`);
  }
}

/**
 * Prints the facet's storage slot annotations to the console.
 *
 * @param facet - The facet info to print storage slots for.
 */
function printStorageSlots(facet: FacetInfo): void {
  if (facet.storageSlots.length === 0) {
    return;
  }

  console.log("      Storage:");
  for (const slot of facet.storageSlots) {
    printStorageSlot(slot);
  }
}

/**
 * Prints a single storage slot annotation to the console.
 *
 * @param slot - The storage slot info to print.
 */
function printStorageSlot(slot: StorageSlotInfo): void {
  const structLabel = slot.structName ? ` (${slot.structName})` : "";
  const layoutStr = slot.layout.length > 0 ? ` [${slot.layout.join(", ")}]` : "";

  console.log(`        ${slot.slot}${structLabel}${layoutStr}`);
}
