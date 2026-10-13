import { describe, expect, it } from "vitest";
import type { BasesCatalog } from "../../../src/modules/config/types";
import { listAvailableCatalogFacetNames } from "../../../src/modules/facetConfig/facetResolver";

describe("facet install choices", () => {
  it("omits catalog facets already registered on the selected diamond", () => {
    const catalog: BasesCatalog = {
      globals: {
        diamond: {
          label: "Diamond",
          required: { DiamondInspectFacet: { path: "@perfect-abstractions/compose/diamond/DiamondInspectFacet.sol" } },
          optional: { DiamondUpgradeFacet: { path: "@perfect-abstractions/compose/diamond/DiamondUpgradeFacet.sol" } },
        },
        libraries: {
          label: "Libraries",
          required: {},
          optional: { ERC165Facet: { path: "@perfect-abstractions/compose/interfaceDetection/ERC165/ERC165Facet.sol" } },
        },
      },
      features: {
        "erc-20": {
          label: "ERC-20",
          required: { ERC20DataFacet: { path: "@perfect-abstractions/compose/token/ERC20/Data/ERC20DataFacet.sol" } },
          optional: { ERC20BurnFacet: { path: "@perfect-abstractions/compose/token/ERC20/Burn/ERC20BurnFacet.sol" } },
        },
      },
    };

    expect(listAvailableCatalogFacetNames(catalog, ["DiamondInspectFacet", "ERC20DataFacet"])).toEqual([
      "DiamondUpgradeFacet",
      "ERC165Facet",
      "ERC20BurnFacet",
    ]);
  });
});
