import { describe, expect, it } from "vitest";
import { renderFacetSections } from "../../src/modules/facetSections";

describe("renderFacetSections", () => {
  it("preserves group order and renders base entries before libraries", () => {
    const facets = [
      { name: "libraryFirst", group: "library" },
      { name: "baseFirst", group: "base" },
      { name: "librarySecond", group: "library" },
      { name: "baseSecond", group: "base" },
    ] as const;
    const renderOrder: string[] = [];

    const sections = renderFacetSections(facets, (facet) => {
      renderOrder.push(facet.name);
      return `rendered:${facet.name}`;
    }, "\n\n");

    expect(sections).toEqual({
      baseLines: "rendered:baseFirst\n\nrendered:baseSecond",
      libraryLines: "rendered:libraryFirst\n\nrendered:librarySecond",
    });
    expect(renderOrder).toEqual(["baseFirst", "baseSecond", "libraryFirst", "librarySecond"]);
  });

  it("renders empty groups as empty strings", () => {
    const sections = renderFacetSections(
      [{ group: "base", name: "BaseFacet" }],
      (facet) => facet.name,
      "\n",
    );

    expect(sections).toEqual({ baseLines: "BaseFacet", libraryLines: "" });
  });
});
