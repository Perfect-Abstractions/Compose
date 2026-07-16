import { ComposeContext } from "../../context/types";
import { yellow, red } from "../../utils/terminal";
import {
  getFacetScanState,
  getSelectorExportValidationState,
  getSelectorCollisionValidationState,
  getIdentifierCollisionValidationState,
} from "./state";
import { FacetScanWarning } from "./types";

/**
 * Renders validation warnings and fail-fast error reports.
 *
 * Displays facet scan warnings (yellow), then checks for selector export
 * issues, selector collisions, and identifier collisions in order. Each
 * failure is printed in red with details and the method returns early.
 *
 * @param ctx - The compose context with validation state populated.
 * @returns The context unchanged.
 */
export async function showReport(ctx: ComposeContext): Promise<ComposeContext> {
  const facetScan = getFacetScanState(ctx);
  const scanWarnings = (facetScan?.result?.facets ?? [])
    .map((facet: FacetScanWarning) => facet)
    .filter((facet: FacetScanWarning) => facet.warnings.length > 0);

  if (scanWarnings.length > 0) {
    console.warn(yellow("\nValidation warnings"));
    for (const facet of scanWarnings) {
      console.warn(`\n${facet.facetName}`);
      console.warn(`  ${facet.path}`);
      for (const warning of facet.warnings) {
        console.warn(`  ${warning}`);
      }
    }
  }

  const selectorExportValidation = getSelectorExportValidationState(ctx);

  if (selectorExportValidation && !selectorExportValidation.success) {
    console.error(red("\nValidation failed"));
    console.error(red(selectorExportValidation.error?.message ?? "Validation failed."));

    for (const issue of selectorExportValidation.result?.issues ?? []) {
      console.error(`\n${issue.facetName}`);
      console.error(`  ${issue.path}`);

      if (issue.missingExports.length > 0) {
        console.error(`  Missing exports: ${issue.missingExports.join(", ")}`);
      }

      if (issue.extraExports.length > 0) {
        console.error(`  Extra exports: ${issue.extraExports.join(", ")}`);
      }
    }

    return ctx;
  }

  const selectorCollisionValidation = getSelectorCollisionValidationState(ctx);

  if (selectorCollisionValidation && !selectorCollisionValidation.success) {
    console.error(red("\nValidation failed"));
    console.error(red(selectorCollisionValidation.error?.message ?? "Validation failed."));

    for (const collision of selectorCollisionValidation.result?.collisions ?? []) {
      console.error(`\n${collision.selector}`);
      for (const owner of collision.owners) {
        console.error(`  ${owner.facetName}: ${owner.signature}`);
        console.error(`    ${owner.path}`);
      }
    }

    return ctx;
  }

  const identifierCollisionValidation = getIdentifierCollisionValidationState(ctx);

  if (identifierCollisionValidation && !identifierCollisionValidation.success) {
    console.error(red("\nValidation failed"));
    console.error(red(identifierCollisionValidation.error?.message ?? "Validation failed."));

    for (const collision of identifierCollisionValidation.result?.collisions ?? []) {
      console.error(`\n${collision.identifier}`);
      for (const owner of collision.owners) {
        console.error(`  ${owner.facetName}: [${owner.layout.join(", ")}]`);
        console.error(`    ${owner.path}`);
      }
    }
  }

  return ctx;
}
