import { BaseDefinition } from "../config/types";

/**
 * Converts an array of facet names into prompt choice objects.
 *
 * @param facetNames - The facet names to convert.
 * @returns Array of prompt choices with name and value set to the facet name.
 */
export function toFacetChoices(facetNames: string[]): { name: string; value: string }[] {
  return facetNames.map((facetName) => ({
    name: facetName,
    value: facetName,
  }));
}

/**
 * Returns ownership base choices for the select prompt, with "None" as the first option.
 *
 * @param accessBases - Available access bases from the catalog.
 * @returns Choices for ownership selection (includes undefined for "None").
 */
export function getOwnershipChoices(
  accessBases: Record<string, BaseDefinition>,
): { name: string; value: string | undefined }[] {
  return [
    { name: "None", value: undefined },
    ...Object.entries(accessBases)
      .filter(([, definition]) => definition.accessType === "ownership")
      .map(([baseKey, definition]) => ({
        name: definition.label,
        value: baseKey,
      })),
  ];
}

/**
 * Returns optional extension facets available for the selected ownership base.
 *
 * @param accessBases - Available access bases from the catalog.
 * @param selectedOwnership - The selected ownership base key, or undefined.
 * @returns Checkbox choices for ownership extensions, or empty if none selected.
 */
export function getOwnershipExtensionChoices(
  accessBases: Record<string, BaseDefinition>,
  selectedOwnership: string | undefined,
): { name: string; value: string }[] {
  if (!selectedOwnership) return [];
  return toFacetChoices(Object.keys(accessBases[selectedOwnership]?.optional ?? {}));
}

/**
 * Returns role-based access control base choices (excludes ownership types), with "None" as the first option.
 *
 * @param accessBases - Available access bases from the catalog.
 * @returns Choices for role-based access control (includes undefined for "None").
 */
export function getRoleAccessChoices(
  accessBases: Record<string, BaseDefinition>,
): { name: string; value: string | undefined }[] {
  return [
    { name: "None", value: undefined },
    ...Object.entries(accessBases)
      .filter(([, definition]) => definition.accessType !== "ownership")
      .map(([baseKey, definition]) => ({
        name: definition.label,
        value: baseKey,
      })),
  ];
}

/**
 * Returns optional extension facets available across all selected role-based access bases.
 *
 * @param accessBases - Available access bases from the catalog.
 * @param selectedRoleAccess - Key of the selected role-based access base, or undefined.
 * @returns Deduplicated checkbox choices for access control extensions.
 */
export function getRoleAccessExtensionChoices(
  accessBases: Record<string, BaseDefinition>,
  selectedRoleAccess: string | undefined,
): { name: string; value: string }[] {
  if (!selectedRoleAccess) return [];
  return toFacetChoices(Object.keys(accessBases[selectedRoleAccess]?.optional ?? {}));
}
