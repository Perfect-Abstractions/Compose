import { green, yellow } from "../../utils/terminal";
import type { FacetMutationResult } from "./types";

export function showFacetManifestCreated(result: FacetMutationResult): void {
  console.log(green(`\n✔ Created ${result.operation} facet manifest`));
  console.log(`  ${result.manifestPath}`);
  console.log(`\nReview the file, then run 'compose ${result.operation} --manifest ${result.manifestPath}'.\n`);
}

export function showFacetMutation(result: FacetMutationResult): void {
  const action = result.operation === "install" ? "Registered" : "Unregistered";
  console.log(green(`\n✔ ${action} facets in Compose configuration`));
  for (const change of result.diamondChanges) {
    console.log(`  ${change.diamond}: ${change.facets.length > 0 ? change.facets.join(", ") : "no changes"}`);
  }
  if (result.changed) console.log(`  Updated: ${result.composeJsonPath}`);
  else console.log(yellow("  Configuration already matched the requested facet set."));
  for (const filePath of result.materializedFiles ?? []) console.log(`  Copied: ${filePath}`);
  console.log(yellow("  No deployed diamond or compose.lock entry was changed.\n"));
}
