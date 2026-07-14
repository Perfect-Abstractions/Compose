import {
  BaseDefinition,
  BasesCatalog,
  CatalogSelection,
  FacetEntry,
} from "./types";
import { EMPTY_BASE } from "./catalog";
import { uniqueStrings } from "../../utils/strings";
import { isDeepEqual } from "../../utils/objects";

/**
 * Returns all features marked as access bases, excluding the currently selected base key.
 *
 * @param catalog - The bases catalog to search.
 * @param selectedBaseKey - The key of the currently selected base (excluded from results).
 * @returns A record of feature keys to their definitions where `access === true`.
 */
export function getAccessBases(
  catalog: BasesCatalog,
  selectedBaseKey?: string,
): Record<string, BaseDefinition> {
  return Object.fromEntries(
    Object.entries(catalog.features).filter(
      ([key, definition]) => definition.access === true && key !== selectedBaseKey,
    ),
  );
}

/**
 * Returns optional library facets that are not already required by the selected base
 * or by global definitions.
 *
 * @param catalog - The bases catalog containing global definitions.
 * @param selectedBase - The currently selected base definition.
 * @returns A record of facet names to their entries that are available as optional libraries.
 */
export function getAvailableLibraryFacets(
  catalog: BasesCatalog,
  selectedBase: BaseDefinition,
): Record<string, FacetEntry> {
  const requiredFacets = mergeFacetMaps(
    catalog.globals.diamond?.required ?? {},
    catalog.globals.libraries?.required ?? {},
    selectedBase.required,
  );

  return Object.fromEntries(
    [
      ...Object.entries(catalog.globals.diamond?.optional ?? {}),
      ...Object.entries(catalog.globals.libraries?.optional ?? {}),
    ].filter(([facetName]) => !(facetName in requiredFacets)),
  );
}

/**
 * Resolves a complete catalog selection from user inputs, validating all choices
 * and computing the final set of required and available facets.
 *
 * @param catalog - The bases catalog containing all available features.
 * @param selectedBaseKey - The key of the base to use, or "none" for an empty base.
 * @param selectedLibraries - Names of global libraries to include.
 * @param selectedExtensions - Names of optional base extensions to include.
 * @param selectedAccessBases - Names of access control bases to layer on.
 * @param selectedAccessExtensions - Names of optional access control extensions to include.
 * @returns The fully resolved catalog selection with all facets computed.
 * @throws {Error} If any selected key is unknown or conflicts exist.
 */
export function resolveCatalogSelection(
  catalog: BasesCatalog,
  selectedBaseKey: string,
  selectedLibraries: string[],
  selectedExtensions: string[] = [],
  selectedAccessBases: string[] = [],
  selectedAccessExtensions: string[] = [],
): CatalogSelection {
  const selectedBase = selectedBaseKey === "none"
    ? EMPTY_BASE
    : catalog.features[selectedBaseKey];
  if (!selectedBase) {
    throw new Error(
      `Unknown base: ${selectedBaseKey}. Available: ${Object.keys(catalog.features).join(", ")}`,
    );
  }

  const availableGlobalLibraryFacets = getAvailableLibraryFacets(catalog, selectedBase);
  const accessBases = getAccessBases(catalog, selectedBaseKey);
  const selectedGlobalLibraries: string[] = [];
  const selectedAccessBaseKeys: string[] = [];

  for (const libraryName of uniqueStrings(selectedLibraries)) {
    const isGlobalLibrary = libraryName in availableGlobalLibraryFacets;
    if (isGlobalLibrary) {
      selectedGlobalLibraries.push(libraryName);
      continue;
    }

    const available = Object.keys(availableGlobalLibraryFacets);
    throw new Error(`Unknown library: ${libraryName}. Available: ${available.join(", ")}`);
  }

  for (const accessName of uniqueStrings(selectedAccessBases)) {
    if (accessName === selectedBaseKey && selectedBase.access === true) {
      throw new Error(
        `Base ${selectedBaseKey} is already selected and cannot also be selected as an access layer.`,
      );
    }

    if (!accessBases[accessName]) {
      throw new Error(`Unknown access layer: ${accessName}. Available: ${Object.keys(accessBases).join(", ")}`);
    }

    selectedAccessBaseKeys.push(accessName);
  }

  validateSingleOwnershipAccessBase(accessBases, selectedAccessBaseKeys);

  const accessBaseDefinitions = selectedAccessBaseKeys.map(
    (key) => accessBases[key],
  );
  const requiredFacets = mergeFacetMaps(
    catalog.globals.diamond?.required ?? {},
    catalog.globals.libraries?.required ?? {},
    selectedBase.required,
    ...accessBaseDefinitions.map((definition) => definition.required),
  );
  const availableExtensions = mergeFacetMaps(
    selectedBase.optional,
  );
  const availableAccessExtensions = mergeFacetMaps(
    ...accessBaseDefinitions.map((definition) => definition.optional),
  );
  const normalizedExtensions = uniqueStrings(selectedExtensions);
  const normalizedAccessExtensions = uniqueStrings(selectedAccessExtensions);

  for (const extensionName of normalizedExtensions) {
    if (!availableExtensions[extensionName]) {
      throw new Error(
        `Unknown extension: ${extensionName}. Available: ${Object.keys(availableExtensions).join(", ")}`,
      );
    }
  }

  for (const extensionName of normalizedAccessExtensions) {
    if (!availableAccessExtensions[extensionName]) {
      throw new Error(
        `Unknown access extension: ${extensionName}. Available: ${Object.keys(availableAccessExtensions).join(", ")}`,
      );
    }
  }

  return {
    selectedBaseKey,
    selectedBase,
    selectedGlobalLibraries,
    selectedAccessBaseKeys,
    selectedAccessBases: accessBaseDefinitions,
    selectedExtensions: normalizedExtensions,
    selectedAccessExtensions: normalizedAccessExtensions,
    requiredFacets,
    availableGlobalLibraryFacets,
    availableExtensions,
    availableAccessExtensions,
  };
}

/**
 * Validates that grouped access flags (ownership vs role-based) are internally consistent.
 * Ensures at most one ownership base is selected and that extensions belong to valid bases.
 *
 * @param catalog - The bases catalog containing access base definitions.
 * @param selectedBaseKey - The currently selected base key (cannot also be an access layer).
 * @param selectedOwnership - Names of ownership-type access bases (at most one).
 * @param selectedRoleAccess - Names of role-based access bases.
 * @param selectedOwnershipExtensions - Extensions to apply to the ownership base.
 * @param selectedRoleAccessExtensions - Extensions to apply to role-based access bases.
 * @throws {Error} If ownership count exceeds one or extensions reference invalid bases.
 */
export function validateGroupedAccessFlags(
  catalog: BasesCatalog,
  selectedBaseKey: string,
  selectedOwnership: string[],
  selectedRoleAccess: string[],
  selectedOwnershipExtensions: string[],
  selectedRoleAccessExtensions: string[],
): void {
  const accessBases = getAccessBases(catalog, selectedBaseKey);

  if (selectedOwnership.length > 1) {
    throw new Error("--ownership accepts only one ownership base.");
  }

  for (const baseKey of selectedOwnership) {
    if (accessBases[baseKey]?.accessType !== "ownership") {
      throw new Error(`Invalid ownership base: ${baseKey}. Choose a base with accessType "ownership".`);
    }
  }

  for (const baseKey of selectedRoleAccess) {
    if (!accessBases[baseKey] || accessBases[baseKey].accessType === "ownership") {
      throw new Error(`Invalid access-control base: ${baseKey}. Choose a non-ownership access base.`);
    }
  }

  validateExtensionsFromBases(
    selectedOwnershipExtensions,
    selectedOwnership.map((baseKey) => accessBases[baseKey]),
    "ownership extension",
  );
  validateExtensionsFromBases(
    selectedRoleAccessExtensions,
    selectedRoleAccess.map((baseKey) => accessBases[baseKey]),
    "access-control extension",
  );
}

/**
 * Ensures at most one ownership-type access base is selected.
 *
 * @param accessBases - All available access bases.
 * @param selectedAccessBaseKeys - Keys of the selected access bases.
 * @throws {Error} If more than one ownership base is selected.
 */
function validateSingleOwnershipAccessBase(
  accessBases: Record<string, BaseDefinition>,
  selectedAccessBaseKeys: string[],
): void {
  const ownershipKeys = selectedAccessBaseKeys.filter(
    (key) => accessBases[key]?.accessType === "ownership",
  );

  if (ownershipKeys.length > 1) {
    throw new Error(
      `Access layers cannot be selected together: ${ownershipKeys.join(", ")}. Choose one ownership model.`,
    );
  }
}

/**
 * Validates that all extension names exist in the optional facets of the given bases.
 *
 * @param extensionNames - Names of extensions to validate.
 * @param bases - Base definitions whose optional facets are considered valid.
 * @param label - Human-readable label for error messages (e.g. "ownership extension").
 * @throws {Error} If any extension name is not found in the bases' optional facets.
 */
function validateExtensionsFromBases(
  extensionNames: string[],
  bases: BaseDefinition[],
  label: string,
): void {
  const available = mergeFacetMaps(...bases.map((definition) => definition.optional));

  for (const extensionName of uniqueStrings(extensionNames)) {
    if (!available[extensionName]) {
      throw new Error(`Unknown ${label}: ${extensionName}. Available: ${Object.keys(available).join(", ")}`);
    }
  }
}

/**
 * Merges multiple facet maps into one, throwing on conflicting definitions.
 * Earlier maps take precedence; later entries with the same name must be identical.
 *
 * @param facetMaps - Facet maps to merge, in order of precedence.
 * @returns A single merged facet map.
 * @throws {Error} If two maps define the same facet with different entries.
 */
function mergeFacetMaps(
  ...facetMaps: Record<string, FacetEntry>[]
): Record<string, FacetEntry> {
  const merged: Record<string, FacetEntry> = {};

  for (const facetMap of facetMaps) {
    for (const [name, entry] of Object.entries(facetMap)) {
      const existing = merged[name];
      if (existing && !isDeepEqual(existing, entry)) {
        throw new Error(`Facet ${name} has conflicting definitions across selected bases.`);
      }
      merged[name] = existing ?? entry;
    }
  }

  return merged;
}
