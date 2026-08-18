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
  IdentifierCollisionOwner,
  VirtualStorageLayoutRecord,
} from "./types";

type LayoutOwner = {
  contractName: string;
  sourceName: string;
  layout: string[];
};

type LayoutMismatch = {
  position: number;
  left: LayoutOwner;
  right: LayoutOwner;
};

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
    console.error(red("\nValidation failed"));
    console.error(red(virtualStorageLayoutValidation.error?.message ?? "Validation failed."));

    for (const collision of virtualStorageLayoutValidation.result?.collisions ?? []) {
      const mismatch = findLayoutMismatch(collision.records, true);
      if (!mismatch) continue;
      const scope = collision.diamondName ? `${collision.diamondName} / ` : "";
      printLayoutMismatch(`${scope}${collision.virtualPath}`, mismatch);
    }

  }

  const identifierCollisionValidation = getIdentifierCollisionValidationState(ctx);

  if (identifierCollisionValidation && !identifierCollisionValidation.success) {
    console.error(red("\nValidation failed"));
    console.error(red(identifierCollisionValidation.error?.message ?? "Validation failed."));

    for (const collision of identifierCollisionValidation.result?.collisions ?? []) {
      const owners = collision.owners.map(identifierOwnerToLayoutOwner);
      const mismatch = findLayoutMismatch(owners, false);
      if (!mismatch) continue;
      printLayoutMismatch(collision.identifier, mismatch);
    }
  }

  return ctx;
}

/** Prints the command-level success message after all validation stages pass. */
export function showSuccess(): void {
  console.log(green("\nValidation passed.\n"));
}

function findLayoutMismatch(
  records: VirtualStorageLayoutRecord[] | LayoutOwner[],
  allowUncertainTypes: boolean,
): LayoutMismatch | null {
  const owners = records.map((record) => ({
    contractName: record.contractName,
    sourceName: record.sourceName,
    layout: record.layout,
  }));

  for (let leftIndex = 0; leftIndex < owners.length; leftIndex += 1) {
    for (let rightIndex = leftIndex + 1; rightIndex < owners.length; rightIndex += 1) {
      const left = owners[leftIndex];
      const right = owners[rightIndex];
      const length = Math.min(left.layout.length, right.layout.length);

      for (let position = 0; position < length; position += 1) {
        const leftCode = left.layout[position];
        const rightCode = right.layout[position];
        if (leftCode === rightCode) continue;
        if (allowUncertainTypes && (isUncertainCode(leftCode) || isUncertainCode(rightCode))) {
          continue;
        }
        return { position, left, right };
      }
    }
  }

  return null;
}

function printLayoutMismatch(identifier: string, mismatch: LayoutMismatch): void {
  console.error(`\n${identifier}: layout position ${mismatch.position}`);
  printLayoutOwner(mismatch.left, mismatch.position);
  printLayoutOwner(mismatch.right, mismatch.position);
}

function printLayoutOwner(owner: LayoutOwner, position: number): void {
  console.error(`  ${owner.contractName}: ${owner.layout[position]}`);
  console.error(`    ${owner.sourceName}`);
}

function identifierOwnerToLayoutOwner(owner: IdentifierCollisionOwner): LayoutOwner {
  return {
    contractName: owner.facetName,
    sourceName: owner.path,
    layout: owner.layout,
  };
}

function isUncertainCode(code: string): boolean {
  return code === "0x71" || code === "0xfe";
}
