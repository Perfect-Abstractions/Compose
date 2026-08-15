import { cyan, dim, green } from "../../utils/terminal";
import type { InspectResult } from "./types";

export function showInspect(result: InspectResult): void {
  const totalSelectors = result.facets.reduce((sum, f) => sum + f.selectors.length, 0);

  console.log(`\n${cyan("Diamond Inspect")}\n`);
  console.log(`  ${dim("Diamond:")}  ${result.diamond}`);
  console.log(`  ${dim("Chain:")}    ${result.chainKey} (${result.chainId})`);
  console.log(`  ${dim("Facets:")}   ${result.facets.length}`);
  console.log(`  ${dim("Selectors:")} ${totalSelectors}`);

  for (const facet of result.facets) {
    console.log(`\n  ${green(`Facet ${facet.index}`)} (${facet.address})`);
    for (const sel of facet.selectors) {
      console.log(`    ${dim("-")} ${sel.selector}  ${sel.signature}`);
    }
  }

  console.log();
}
