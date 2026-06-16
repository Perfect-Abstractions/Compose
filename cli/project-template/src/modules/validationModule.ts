import { ComposeContext, ModuleState } from "../context/types";
import { HashingAdapterInterface } from "../adapters/hashingAdapter";

// =====================
// Helper
// =====================

type FunctionInfo = {
  name: string;
  signature: string;
  visibility: "external" | "public";
};

type FacetScanResult = {
  facetName: string;
  path: string;
  functions: FunctionInfo[];
  exportedSelectors: string[];
  missingExports: string[];
  extraExports: string[];
  storageLayouts: StorageLayoutInfo[];
};

type FacetScanStateResult = {
  facets: FacetScanResult[];
  facetCount: number;
};

type SelectorExportIssue = {
  facetName: string;
  path: string;
  missingExports: string[];
  extraExports: string[];
};

type SelectorOwner = {
  facetName: string;
  path: string;
  functionName: string;
  signature: string;
};

type SelectorCollision = {
  selector: string;
  owners: SelectorOwner[];
};

type SelectorCollisionDeps = {
  hashing: HashingAdapterInterface;
};

type StorageLayoutInfo = {
  slot: string;
  layout: string[];
  source: "erc8042" | "slot-assignment";
  structName: string | null;
};

type IdentifierCollisionOwner = {
  facetName: string;
  path: string;
  slot: string;
  layout: string[];
  source: StorageLayoutInfo["source"];
  structName: string | null;
};

type IdentifierCollision = {
  identifier: string;
  owners: IdentifierCollisionOwner[];
};

// Read the facet scan result that all validation stages depend on.
function getFacetScanResult(ctx: ComposeContext): FacetScanStateResult | null {
  const state = ctx.state.facetScan as ModuleState<FacetScanStateResult> | undefined;
  return state?.result ?? null;
}

// Find facets whose exportSelectors list is incomplete or references missing functions.
function findSelectorExportIssues(facets: FacetScanResult[]): SelectorExportIssue[] {
  return facets
    .map((facet) => ({
      facetName: facet.facetName,
      path: facet.path,
      missingExports: facet.missingExports,
      extraExports: facet.extraExports,
    }))
    .filter((issue) => issue.missingExports.length > 0 || issue.extraExports.length > 0);
}

// Compute exported function selectors and group duplicate selector owners.
function findSelectorCollisions(
  facets: FacetScanResult[],
  hashing: HashingAdapterInterface,
): SelectorCollision[] {
  const ownersBySelector = new Map<string, SelectorOwner[]>();

  for (const facet of facets) {
    const functionsByName = new Map(facet.functions.map((fn) => [fn.name, fn]));

    for (const exportedName of facet.exportedSelectors) {
      const fn = functionsByName.get(exportedName);
      if (!fn) {
        continue;
      }

      const selector = hashing.keccak256(fn.signature).slice(0, 10);
      const owners = ownersBySelector.get(selector) ?? [];
      owners.push({
        facetName: facet.facetName,
        path: facet.path,
        functionName: fn.name,
        signature: fn.signature,
      });
      ownersBySelector.set(selector, owners);
    }
  }

  return [...ownersBySelector.entries()]
    .map(([selector, owners]) => ({ selector, owners }))
    .filter((collision) => new Set(collision.owners.map((owner) => owner.facetName)).size > 1);
}

// Group storage layouts by identifier and keep only incompatible groups.
function findIdentifierCollisions(facets: FacetScanResult[]): IdentifierCollision[] {
  const ownersByIdentifier = new Map<string, IdentifierCollisionOwner[]>();

  for (const facet of facets) {
    for (const storageLayout of facet.storageLayouts) {
      const identifier = buildIdentifier(storageLayout.slot);
      const owners = ownersByIdentifier.get(identifier) ?? [];
      owners.push({
        facetName: facet.facetName,
        path: facet.path,
        slot: storageLayout.slot,
        layout: storageLayout.layout,
        source: storageLayout.source,
        structName: storageLayout.structName,
      });
      ownersByIdentifier.set(identifier, owners);
    }
  }

  return [...ownersByIdentifier.entries()]
    .filter(([, owners]) => owners.length > 1)
    .filter(([, owners]) => !areLayoutsPrefixCompatible(owners.map((owner) => owner.layout)))
    .map(([identifier, owners]) => ({ identifier, owners }));
}

// Build the identifier key used to group storage layouts.
function buildIdentifier(slot: string): string {
  return slot;
}

// Check whether all layouts are safe prefix extensions of the shortest layout.
function areLayoutsPrefixCompatible(layouts: string[][]): boolean {
  if (layouts.length <= 1) {
    return true;
  }

  const sorted = [...layouts].sort((a, b) => a.length - b.length);
  const shortest = sorted[0];

  return sorted.every((layout) => isPrefix(shortest, layout));
}

// Return true when the first layout is a prefix of the second layout.
function isPrefix(prefix: string[], layout: string[]): boolean {
  if (prefix.length > layout.length) {
    return false;
  }

  return prefix.every((value, index) => layout[index] === value);
}

// =====================
// Modules
// =====================

export const ValidationModule = {
  // Validate that every public/external function is exported by exportSelectors.
  async validateSelectorExports(ctx: ComposeContext): Promise<ComposeContext> {
    const facetScan = getFacetScanResult(ctx);

    if (!facetScan) {
      ctx.state.validationSelectorExports = {
        success: false,
        result: null,
        error: {
          code: "FACET_SCAN_MISSING",
          message: "Facet scan must run before selector export validation.",
          nativeError: null,
        },
      };
      return ctx;
    }

    const issues = findSelectorExportIssues(facetScan.facets);
    const success = issues.length === 0;

    ctx.state.validationSelectorExports = {
      success,
      result: {
        checkedFacets: facetScan.facetCount,
        issues,
      },
      error: success
        ? null
        : {
            code: "SELECTOR_EXPORT_INVALID",
            message: "One or more selected facets do not export all intended selectors.",
            nativeError: null,
          },
    };

    return ctx;
  },

  // Detect duplicate 4-byte selectors across selected exported facet functions.
  async detectSelectorCollisions(
    ctx: ComposeContext,
    { hashing }: SelectorCollisionDeps,
  ): Promise<ComposeContext> {
    const facetScan = getFacetScanResult(ctx);

    if (!facetScan) {
      ctx.state.validationSelectorCollisions = {
        success: false,
        result: null,
        error: {
          code: "FACET_SCAN_MISSING",
          message: "Facet scan must run before selector collision detection.",
          nativeError: null,
        },
      };
      return ctx;
    }

    const collisions = findSelectorCollisions(facetScan.facets, hashing);
    const success = collisions.length === 0;

    ctx.state.validationSelectorCollisions = {
      success,
      result: {
        checkedFacets: facetScan.facetCount,
        collisions,
      },
      error: success
        ? null
        : {
            code: "SELECTOR_COLLISION_DETECTED",
            message: "Two or more selected facets export the same function selector.",
            nativeError: null,
          },
    };

    return ctx;
  },

  // Detect incompatible storage layouts sharing the same storage identifier.
  async detectIdentifierCollisions(ctx: ComposeContext): Promise<ComposeContext> {
    const facetScan = getFacetScanResult(ctx);

    if (!facetScan) {
      ctx.state.validationIdentifierCollisions = {
        success: false,
        result: null,
        error: {
          code: "FACET_SCAN_MISSING",
          message: "Facet scan must run before identifier collision detection.",
          nativeError: null,
        },
      };
      return ctx;
    }

    const collisions = findIdentifierCollisions(facetScan.facets);
    const success = collisions.length === 0;

    ctx.state.validationIdentifierCollisions = {
      success,
      result: {
        checkedFacets: facetScan.facetCount,
        collisions,
      },
      error: success
        ? null
        : {
            code: "IDENTIFIER_COLLISION_DETECTED",
            message: "Two or more selected facets use incompatible storage layouts for the same identifier.",
            nativeError: null,
          },
    };

    return ctx;
  },
};
