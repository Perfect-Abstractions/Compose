import { cyan, dim, green, yellow } from "../../utils/terminal";
import type { InspectResult } from "../inspect/types";

/** Prints a selector-first view grouped by facet address. */
export function showSelectors(result: InspectResult): void {
  console.log(`\n${cyan("Diamond Selectors")}\n`);
  console.log(`  Diamond: ${result.diamond}`);
  console.log(`  Chain: ${result.chainKey} (${result.chainId})`);
  console.log();

  for (const facet of result.facets) {
    console.log(`  ${facet.address}`);
    if (facet.selectors.length === 0) {
      console.log(`    ${dim("No selectors")}`);
    }
    for (const { selector, signature } of facet.selectors) {
      const unknown = signature.toLowerCase() === selector.toLowerCase();
      console.log(`    ${dim(selector)}  ${unknown ? yellow("Unknown signature") : green(signature)}`);
    }
    console.log();
  }
  if (result.facets.length === 0) console.log(`  ${dim("No facets found")}\n`);
}
