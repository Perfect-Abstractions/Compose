import { BaseDefinition } from "../config/types";
import { PromptApi } from "./types";

/** A choice option for an Inquirer select or checkbox prompt. */
export type PromptChoice<Value> = {
  name: string;
  value: Value;
};

/**
 * Dynamically imports the prompt primitives used by init.
 * Importing the primitives directly keeps npm hoisting from resolving newer
 * transitive prompt internals through the umbrella @inquirer/prompts package.
 *
 * @returns The prompt API with input, select, checkbox, and confirm methods.
 */
export async function loadPrompts(): Promise<PromptApi> {
  const [
    { default: input },
    { default: select },
    { default: checkbox },
    { default: confirm },
  ] = await Promise.all([
    import("@inquirer/input"),
    import("@inquirer/select"),
    import("@inquirer/checkbox"),
    import("@inquirer/confirm"),
  ]);

  return { input, select, checkbox, confirm } as unknown as PromptApi;
}

/**
 * Converts an array of facet names into prompt choice objects.
 *
 * @param facetNames - The facet names to convert.
 * @returns Array of prompt choices with name and value set to the facet name.
 */
export function toFacetChoices(facetNames: string[]): PromptChoice<string>[] {
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
): PromptChoice<string | undefined>[] {
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
): PromptChoice<string>[] {
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
): PromptChoice<string | undefined>[] {
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
): PromptChoice<string>[] {
  if (!selectedRoleAccess) return [];
  return toFacetChoices(Object.keys(accessBases[selectedRoleAccess]?.optional ?? {}));
}

/** Custom theme for checkbox prompts with simplified icons, no help tip, and "None" when empty. */
export const checkboxTheme = {
  prefix: "",
  icon: {
    checked: "[✓]",
    unchecked: "[ ]",
    cursor: ">",
    disabledChecked: "[✓]",
    disabledUnchecked: "[ ]",
  },
  style: {
    keysHelpTip: () => undefined,
    renderSelectedChoices: (selected: readonly { short: string }[]) => {
      if (selected.length === 0) return "None";
      return selected.map((c) => c.short).join(", ");
    },
  },
} as const;

/** Custom theme for select prompts with simplified cursor and no help tip. */
export const selectTheme = {
  prefix: "",
  icon: {
    cursor: ">",
  },
  style: {
    keysHelpTip: () => undefined,
  },
} as const;
