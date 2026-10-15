type GroupedFacet = { group: "base" | "library" };

export type RenderedFacetSections = {
  baseLines: string;
  libraryLines: string;
};

/** Renders base facets first, followed by library facets, into separate sections. */
export function renderFacetSections<T extends GroupedFacet>(
  facets: readonly T[],
  renderFacet: (facet: T) => string,
  separator: string,
): RenderedFacetSections {
  const baseFacets: T[] = [];
  const libraryFacets: T[] = [];

  for (const facet of facets) {
    if (facet.group === "base") {
      baseFacets.push(facet);
    } else {
      libraryFacets.push(facet);
    }
  }

  return {
    baseLines: baseFacets.map(renderFacet).join(separator),
    libraryLines: libraryFacets.map(renderFacet).join(separator),
  };
}
