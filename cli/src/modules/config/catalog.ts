import { BaseDefinition, BasesCatalog } from "./types";

/** Default empty base definition representing "None" with no required or optional facets. */
export const EMPTY_BASE: BaseDefinition = {
  label: "None",
  required: {},
  optional: {},
};

/**
 * Sorts a record of base feature definitions by their `order` metadata property,
 * falling back to alphabetical label comparison when orders are equal or missing.
 *
 * @param features - Map of feature keys to their base definitions.
 * @returns A new record with entries sorted by order, then label.
 */
export function sortBaseFeatures(features: Record<string, BaseDefinition>): Record<string, BaseDefinition> {
  return Object.fromEntries(
    Object.entries(features).sort(([_, leftDef], [__, rightDef]) => {
      const leftOrder = leftDef.order ?? Number.MAX_SAFE_INTEGER;
      const rightOrder = rightDef.order ?? Number.MAX_SAFE_INTEGER;

      if (leftOrder !== rightOrder) {
        return leftOrder - rightOrder;
      }

      return leftDef.label.localeCompare(rightDef.label);
    }),
  );
}

/**
 * Extracts and validates the Diamond compiler version from a bases catalog.
 * The version must be an exact semantic version string (e.g. "0.8.30").
 *
 * @param catalog - The bases catalog containing a globals.diamond definition.
 * @returns The validated semantic version string.
 * @throws {Error} If the compiler version is missing or not a valid semver string.
 */
export function getDiamondCompilerVersion(catalog: BasesCatalog): string {
  const compilerVersion = catalog.globals.diamond?.compilerVersion;
  if (typeof compilerVersion !== "string" || !/^\d+\.\d+\.\d+$/.test(compilerVersion)) {
    throw new Error("Diamond compilerVersion must be an exact semantic version such as 0.8.30.");
  }

  return compilerVersion;
}
