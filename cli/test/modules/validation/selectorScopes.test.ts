import { describe, expect, it } from "vitest";
import { HashingAdapter } from "../../../src/adapters/hashingAdapter";
import { Context } from "../../../src/context/context";
import { ValidationModule } from "../../../src/modules/validation/module";
import { FacetScanResult } from "../../../src/modules/validation/types";

describe("selector collision scopes", () => {
  it("allows the same selector in independent diamonds", async () => {
    const ctx = Context.create();
    setFacetScan(ctx, [facet("AlphaFacet"), facet("BetaFacet")]);

    await ValidationModule.detectSelectorCollisions(ctx, {
      hashing: HashingAdapter,
      scopes: [
        { diamondName: "Alpha", facets: [reference("AlphaFacet")] },
        { diamondName: "Beta", facets: [reference("BetaFacet")] },
      ],
    });

    expect(ctx.state.validationSelectorCollisions?.success).toBe(true);
    expect(ctx.state.validationSelectorCollisions?.result).toEqual({
      checkedFacets: 2,
      collisions: [],
    });
  });

  it("reports the diamond containing a selector collision", async () => {
    const ctx = Context.create();
    setFacetScan(ctx, [facet("AlphaFacet"), facet("BetaFacet")]);

    await ValidationModule.detectSelectorCollisions(ctx, {
      hashing: HashingAdapter,
      scopes: [
        {
          diamondName: "SharedDiamond",
          facets: [reference("AlphaFacet"), reference("BetaFacet")],
        },
      ],
    });

    expect(ctx.state.validationSelectorCollisions?.success).toBe(false);
    expect(ctx.state.validationSelectorCollisions?.result).toEqual({
      checkedFacets: 2,
      collisions: [
        expect.objectContaining({
          diamondName: "SharedDiamond",
          selector: HashingAdapter.keccak256("transfer(address,uint256)").slice(0, 10),
        }),
      ],
    });
  });
});

function facet(facetName: string): FacetScanResult {
  return {
    facetName,
    path: `src/${facetName}.sol`,
    functions: [{
      name: "transfer",
      signature: "transfer(address,uint256)",
      visibility: "external",
    }],
    exportedSelectors: ["transfer(address,uint256)"],
    hasExportSelectorsFunction: true,
    missingExports: [],
    extraExports: [],
    storageLayouts: [],
    warnings: [],
  };
}

function reference(contractName: string): { contractName: string; sourcePath: string } {
  return { contractName, sourcePath: `src/${contractName}.sol` };
}

function setFacetScan(
  ctx: ReturnType<typeof Context.create>,
  facets: FacetScanResult[],
): void {
  ctx.state.facetScan = {
    success: true,
    result: { facets, facetCount: facets.length },
    error: null,
  };
}
