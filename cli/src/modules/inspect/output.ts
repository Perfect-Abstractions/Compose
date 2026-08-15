import { cyan, dim, green } from "../../utils/terminal";
import type { InspectResult } from "./types";

const TREE_BRANCH = "├── ";
const TREE_LAST = "└── ";
const TREE_PIPE = "│   ";
const TREE_SPACE = "    ";

/**
 * Prints a formatted summary of the inspect result to the console.
 *
 * Displays the diamond address, chain, facet count, total selector count, and
 * each facet with its decoded selectors in a tree layout.
 *
 * @param result - The inspect result containing the diamond info and facets.
 */
export function showInspect(result: InspectResult): void {
  const totalSelectors = result.facets.reduce((sum, f) => sum + f.selectors.length, 0);

  console.log(`\n${cyan("Diamond Inspect")}\n`);
  console.log(`  ${result.diamond}`);
  console.log(`  ${dim(`${result.chainKey} (${result.chainId}) · ${result.facets.length} facets · ${totalSelectors} selectors`)}`);
  console.log();

  for (let i = 0; i < result.facets.length; i++) {
    const facet = result.facets[i];
    const isLast = i === result.facets.length - 1;
    const branch = isLast ? TREE_LAST : TREE_BRANCH;
    const childPrefix = isLast ? TREE_SPACE : TREE_PIPE;

    console.log(`  ${dim(branch)}${facet.address}`);

    for (let j = 0; j < facet.selectors.length; j++) {
      const sel = facet.selectors[j];
      const isLastSelector = j === facet.selectors.length - 1;
      const selectorBranch = isLastSelector ? TREE_LAST : TREE_BRANCH;

      console.log(`  ${dim(childPrefix + selectorBranch)}${dim(sel.selector)}  ${green(sel.signature)}`);
    }

    if (!isLast) {
      console.log(`  ${dim(TREE_PIPE)}`);
    }
  }

  console.log();
}
