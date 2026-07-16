import { ComposeContext } from "../../context/types";
import { BasesCatalog, BaseDefinition } from "../config/types";
import { cyan, dim, green, yellow } from "../../utils/terminal";

/**
 * Displays available Compose bases grouped by type with facet counts.
 *
 * Reads the bases catalog from `ctx.config.bases` and prints each base
 * grouped into Features and Access Control sections.
 *
 * @param ctx - The compose context with the loaded bases catalog.
 */
export function showTemplates(ctx: ComposeContext): void {
  const catalog = ctx.config.bases as BasesCatalog;
  const features = catalog.features;

  const featureBases: [string, BaseDefinition][] = [];
  const accessBases: [string, BaseDefinition][] = [];

  for (const [key, definition] of Object.entries(features)) {
    if (definition.access) {
      accessBases.push([key, definition]);
    } else {
      featureBases.push([key, definition]);
    }
  }

  const maxIdLen = Math.max(
    ...featureBases.map(([k]) => k.length),
    ...accessBases.map(([k]) => k.length),
  );

  console.log(`\n${cyan("Compose Catalog")}\n`);

  if (featureBases.length > 0) {
    console.log(dim("  Features"));
    console.log(dim("  " + "─".repeat(maxIdLen + 28)));
    for (const [key, definition] of featureBases) {
      const required = Object.keys(definition.required).length;
      const optional = Object.keys(definition.optional).length;
      const id = key.padEnd(maxIdLen + 2);
      const label = dim(definition.label.padEnd(22));
      const counts = `${green(`${required} required`)}, ${yellow(`${optional} optional`)}`;
      console.log(`  ${cyan(id)}${label}${counts}`);
    }
    console.log("");
  }

  if (accessBases.length > 0) {
    console.log(dim("  Access Control"));
    console.log(dim("  " + "─".repeat(maxIdLen + 28)));
    for (const [key, definition] of accessBases) {
      const required = Object.keys(definition.required).length;
      const optional = Object.keys(definition.optional).length;
      const id = key.padEnd(maxIdLen + 2);
      const label = dim(definition.label.padEnd(22));
      const counts = `${green(`${required} required`)}, ${yellow(`${optional} optional`)}`;
      console.log(`  ${cyan(id)}${label}${counts}`);
    }
    console.log("");
  }

  console.log(dim("  Use --base <base-id> with compose init\n"));
}
