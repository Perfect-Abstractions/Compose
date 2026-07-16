import { BasesCatalog, FacetEntry } from "../config/types";
import { ConfigModule } from "../config/module";
import { SelectedFacet } from "./types";
import { ComposeContext } from "../../context/types";
import { isDeepEqual } from "../../utils/objects";

/**
 * Collects all selected facets from the catalog based on the user's choices,
 * ordered by source priority: diamond-required, library-required, base-required,
 * access-required, then optional/extension facets.
 *
 * Detects conflicting definitions for the same facet name across selected bases.
 *
 * @param ctx - The compose context with CLI parameters and loaded catalog.
 * @returns Ordered array of selected facets with their source classification.
 * @throws {Error} If a facet has conflicting definitions across bases.
 */
export function getSelectedFacets(ctx: ComposeContext): SelectedFacet[] {
  const catalog = ctx.config.bases as BasesCatalog;
  const selectedBaseKey = String(ctx.param.base ?? "");
  const selectedLibraryNames = new Set((ctx.param.libraries as string[] | undefined) ?? []);
  const selectedExtensionNames = new Set((ctx.param.extensions as string[] | undefined) ?? []);
  const selectedAccessNames = new Set((ctx.param.access as string[] | undefined) ?? []);
  const selectedAccessExtensionNames = new Set((ctx.param.accessExtensions as string[] | undefined) ?? []);
  const selection = ConfigModule.resolveCatalogSelection(
    catalog,
    selectedBaseKey,
    [...selectedLibraryNames],
    [...selectedExtensionNames],
    [...selectedAccessNames],
    [...selectedAccessExtensionNames],
  );

  const selected: SelectedFacet[] = [];
  const selectedNames = new Map<string, FacetEntry>();
  const addSelectedFacet = (facet: SelectedFacet): void => {
    const existing = selectedNames.get(facet.name);
    if (existing) {
      if (!isDeepEqual(existing, facet.entry)) {
        throw new Error(`Facet ${facet.name} has conflicting definitions across selected bases.`);
      }
      return;
    }
    selectedNames.set(facet.name, facet.entry);
    selected.push(facet);
  };

  for (const [name, entry] of Object.entries(catalog.globals.diamond?.required ?? {})) {
    addSelectedFacet({ name, entry, source: "diamond-required" });
  }

  for (const [name, entry] of Object.entries(catalog.globals.libraries?.required ?? {})) {
    addSelectedFacet({ name, entry, source: "library-required" });
  }

  for (const [name, entry] of Object.entries(selection.selectedBase.required)) {
    addSelectedFacet({ name, entry, source: "base-required" });
  }

  for (const accessBase of selection.selectedAccessBases) {
    for (const [name, entry] of Object.entries(accessBase.required)) {
      addSelectedFacet({ name, entry, source: "access-required" });
    }
  }

  for (const [name, entry] of Object.entries(catalog.globals.diamond?.optional ?? {})) {
    if (selection.selectedGlobalLibraries.includes(name)) {
      addSelectedFacet({ name, entry, source: "diamond-optional" });
    }
  }

  for (const [name, entry] of Object.entries(catalog.globals.libraries?.optional ?? {})) {
    if (selection.selectedGlobalLibraries.includes(name)) {
      addSelectedFacet({ name, entry, source: "library-optional" });
    }
  }

  for (const [name, entry] of Object.entries(selection.selectedBase.optional)) {
    if (selectedExtensionNames.has(name)) {
      addSelectedFacet({ name, entry, source: "extension" });
    }
  }

  for (const accessBase of selection.selectedAccessBases) {
    for (const [name, entry] of Object.entries(accessBase.optional)) {
      if (selectedAccessExtensionNames.has(name)) {
        addSelectedFacet({ name, entry, source: "access-extension" });
      }
    }
  }

  return selected;
}
