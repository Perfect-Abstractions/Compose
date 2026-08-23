import { ComposeContext } from "../../context/types";
import { green, yellow, red } from "../../utils/terminal";
import {
  getFacetScanState,
  getSelectorExportValidationState,
  getSelectorCollisionValidationState,
  getIdentifierCollisionValidationState,
  getVirtualStorageLayoutValidationState,
} from "./state";
import {
  FacetScanWarning,
  StorageVariableReference,
  VirtualStorageLayoutRecord,
} from "./types";

/**
 * Renders validation warnings and fail-fast error reports.
 *
 * Displays facet scan and selector export warnings in yellow, then checks
 * selector and identifier collisions. Blocking failures are printed in red.
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
  const selectorExportIssues = selectorExportValidation?.result?.issues ?? [];

  if (selectorExportIssues.length > 0) {
    console.warn(yellow("\nSelector export warnings"));

    for (const issue of selectorExportIssues) {
      console.warn(`\n${issue.facetName}`);
      console.warn(`  ${issue.path}`);

      if (issue.missingExportSelectorsFunction) {
        console.warn("  Missing exportSelectors() function");
      }

      if (issue.missingExports.length > 0) {
        console.warn(`  Missing exports: ${issue.missingExports.join(", ")}`);
      }

      if (issue.extraExports.length > 0) {
        console.warn(`  Extra exports: ${issue.extraExports.join(", ")}`);
      }
    }
  }

  const virtualStorageLayoutValidation = getVirtualStorageLayoutValidationState(ctx);
  const virtualStorageLayoutWarnings = virtualStorageLayoutValidation?.result?.warnings ?? [];

  if (virtualStorageLayoutWarnings.length > 0) {
    console.warn(yellow("\nVirtual storage warnings"));
    for (const warning of virtualStorageLayoutWarnings) {
      const scope = warning.diamondName ? `${warning.diamondName} / ` : "";
      console.warn(`\n${scope}${warning.sourceName}`);
      console.warn(`  ${warning.message}`);
    }
  }

  const selectorCollisionValidation = getSelectorCollisionValidationState(ctx);

  if (selectorCollisionValidation && !selectorCollisionValidation.success) {
    console.error(red("\nValidation failed"));
    console.error(red(selectorCollisionValidation.error?.message ?? "Validation failed."));

    for (const collision of selectorCollisionValidation.result?.collisions ?? []) {
      const scope = collision.diamondName ? `${collision.diamondName} / ` : "";
      console.error(`\n${scope}${collision.selector}`);
      for (const owner of collision.owners) {
        console.error(`  ${owner.facetName}: ${owner.signature}`);
        console.error(`    ${owner.path}`);
      }
    }

  }

  if (virtualStorageLayoutValidation && !virtualStorageLayoutValidation.success) {
    const unsupported = virtualStorageLayoutValidation.result?.unsupported ?? [];
    const hasCollisions = (virtualStorageLayoutValidation.result?.collisions.length ?? 0) > 0;

    if (!hasCollisions && unsupported.length > 0) {
      console.warn(yellow("\nValidation incomplete"));
      console.warn(yellow(
        virtualStorageLayoutValidation.error?.message ?? "Storage layout compatibility is unknown.",
      ));
      for (const item of unsupported) {
        const scope = item.diamondName ? `${item.diamondName} / ` : "";
        console.warn(`\n${scope}${item.virtualPath}`);
        for (const record of item.records) {
          console.warn(`  ${record.contractName}`);
          console.warn(`    ${record.sourceName}`);
        }
      }
    } else {
      console.error(red("\nValidation failed"));
      console.error(red(virtualStorageLayoutValidation.error?.message ?? "Validation failed."));
    }

    for (const collision of virtualStorageLayoutValidation.result?.collisions ?? []) {
      const scope = collision.diamondName ? `${collision.diamondName} / ` : "";
      console.error(`\n${scope}${collision.virtualPath}`);
      if (collision.mismatches.length > 0) {
        for (const [index, mismatch] of collision.mismatches.entries()) {
          if (index > 0) console.error("  " + "─".repeat(48));
          printStorageVariable(mismatch.left);
          console.error("");
          printStorageVariable(mismatch.right);
        }
      } else {
        for (const record of collision.records) printStorageRecord(record);
      }
    }

  }

  const identifierCollisionValidation = getIdentifierCollisionValidationState(ctx);

  if (identifierCollisionValidation && !identifierCollisionValidation.success) {
    console.error(red("\nValidation failed"));
    console.error(red(identifierCollisionValidation.error?.message ?? "Validation failed."));

    for (const collision of identifierCollisionValidation.result?.collisions ?? []) {
      console.error(`\n${collision.identifier}`);
      for (const owner of collision.owners) {
        console.error(`  ${owner.facetName}`);
        console.error(`    ${owner.path}`);
      }
    }
  }

  return ctx;
}

/** Prints the command-level success message after all validation stages pass. */
export function showSuccess(): void {
  console.log(green("\nValidation passed.\n"));
}

function printStorageVariable(variable: StorageVariableReference): void {
  const name = variable.structName
    ? `${variable.structName}.${variable.variableName}`
    : variable.variableName;
  console.error(`  ${variable.contractName}: ${name}`);
  console.error(`      Type: ${variable.typeName}`);
  console.error(`      Storage path: ${variable.storagePath}`);
  console.error(`      Source: ${variable.sourceName}`);
}

function printStorageRecord(record: VirtualStorageLayoutRecord): void {
  console.error(`  ${record.contractName}: ${record.structName ?? "storage layout"}`);
  console.error(`    ${record.sourceName}`);
}
