import { ComposeContext } from "../../context/types";
import { SolidityAstSource } from "../../adapters/interface/IFrameworkAdapter";
import { DiamondValidationScope, FacetReference, SelectorCollisionDeps } from "./types";
import { matchesAstSource } from "./astIdentity";
import { scanFacetSelectorsFromAst } from "./astSelectors";
import {
  buildScopedVirtualStorageLayout,
  buildVirtualStorageLayout,
} from "./virtualStorageLayout";
import {
  findIdentifierCollisions,
  findSelectorCollisions,
  findSelectorExportIssues,
} from "./validators";
import {
  getFacetScanResult,
  getFacetScanState,
  getIdentifierCollisionValidationState,
  getSelectorCollisionValidationState,
  getSelectorExportValidationState,
  getVirtualStorageLayoutValidationState,
} from "./state";
import { showReport, showSuccess } from "./output";
import { getResolvedFacetSources, resolveFacetSources } from "./sourceResolution";
import { IFrameworkAdapter } from "../../adapters/interface/IFrameworkAdapter";

/**
 * Validates facet scans for selector export guidance and collision-free layouts.
 *
 * Compiler AST supplies selector evidence and the source-side virtual storage
 * map. Advisory uncertainty is retained while clear selector or storage
 * contradictions are blocking.
 */
export const ValidationModule = {
  showReport,
  showSuccess,
  getFacetScanState,
  getSelectorExportValidationState,
  getSelectorCollisionValidationState,
  getIdentifierCollisionValidationState,
  getVirtualStorageLayoutValidationState,
  getResolvedFacetSources,

  /** Resolves selected Compose package facets into compiler input paths. */
  async resolveComposeFacetSources(
    ctx: ComposeContext,
    adapter: IFrameworkAdapter,
  ): Promise<ComposeContext> {
    const sources = await resolveFacetSources(ctx, adapter, "package");
    ctx.state.validationComposeFacetSources = {
      success: true,
      result: { sources },
      error: null,
    };
    return ctx;
  },

  /** Resolves copied project facets into compiler input paths. */
  async resolveProjectFacetSources(
    ctx: ComposeContext,
    adapter: IFrameworkAdapter,
  ): Promise<ComposeContext> {
    const sources = await resolveFacetSources(ctx, adapter, "local");
    ctx.state.validationProjectFacetSources = {
      success: true,
      result: { sources },
      error: null,
    };
    return ctx;
  },

  /** Scans referenced facets from compiler AST and stores selector evidence in facetScan state. */
  scanFacetSelectors(
    ctx: ComposeContext,
    sources: SolidityAstSource[],
    facets: FacetReference[],
  ): ComposeContext {
    const scannedFacets = scanFacetSelectorsFromAst(sources, facets);
    ctx.state.facetScan = {
      success: true,
      result: {
        facets: scannedFacets,
        facetCount: scannedFacets.length,
      },
      error: null,
    };
    return ctx;
  },

  /** Builds and validates the source-side virtual storage layout from compiler AST. */
  buildVirtualStorageLayout(
    ctx: ComposeContext,
    sources: SolidityAstSource[],
    facets: FacetReference[],
    scopes?: DiamondValidationScope[],
  ): ComposeContext {
    const result = scopes
      ? buildScopedVirtualStorageLayout(sources, scopes)
      : buildVirtualStorageLayout(sources, facets);
    const success = result.collisions.length === 0 && result.unsupported.length === 0;
    const unsupported = result.collisions.length === 0 && result.unsupported.length > 0;

    ctx.state.validationVirtualStorageLayout = {
      success,
      result,
      error: success
        ? null
        : {
            code: unsupported
              ? "VIRTUAL_STORAGE_LAYOUT_UNSUPPORTED"
              : "VIRTUAL_STORAGE_COLLISION_DETECTED",
            message: unsupported
              ? "Storage layout compatibility could not be proven."
              : "Selected facets declare incompatible storage layouts.",
            nativeError: null,
          },
    };
    return ctx;
  },
  
  /**
   * Returns true when selector export validation could not run.
   *
   * Keeps validation state reads inside the validation module boundary.
   */
  hasSelectorExportFailure(ctx: ComposeContext): boolean {
    const state = getSelectorExportValidationState(ctx);
    return Boolean(state && !state.success);
  },

  /**
   * Returns true when selector collision validation has found blocking issues.
   *
   * Keeps validation state reads inside the validation module boundary.
   */
  hasSelectorCollisionFailure(ctx: ComposeContext): boolean {
    const state = getSelectorCollisionValidationState(ctx);
    return Boolean(state && !state.success);
  },

  /**
   * Returns true when identifier collision validation has found blocking issues.
   *
   * Keeps validation state reads inside the validation module boundary.
   */
  hasIdentifierCollisionFailure(ctx: ComposeContext): boolean {
    const state = getIdentifierCollisionValidationState(ctx);
    return Boolean(state && !state.success);
  },

  /** Returns true when source-derived virtual storage layouts collide. */
  hasVirtualStorageLayoutFailure(ctx: ComposeContext): boolean {
    const state = getVirtualStorageLayoutValidationState(ctx);
    return Boolean(state && !state.success);
  },

  /**
   * Returns true when any validation stage has produced a blocking failure.
   *
   * Pipelines can use this for orchestration without importing validation helpers.
   */
  hasBlockingFailure(ctx: ComposeContext): boolean {
    return (
      ValidationModule.hasSelectorExportFailure(ctx) ||
      ValidationModule.hasSelectorCollisionFailure(ctx) ||
      ValidationModule.hasVirtualStorageLayoutFailure(ctx) ||
      ValidationModule.hasIdentifierCollisionFailure(ctx)
    );
  },

  /**
   * Records advisory differences between public/external functions and `exportSelectors()`.
   *
   * Requires `ctx.state.facetScan` to have been populated. For each facet,
   * checks whether `exportSelectors()` exists and reports missing or extra
   * signatures without blocking validation.
   *
   * @param ctx - The compose context with facet scan results.
   * @returns The context with `ctx.state.validationSelectorExports` populated.
   */
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
    ctx.state.validationSelectorExports = {
      success: true,
      result: {
        checkedFacets: facetScan.facetCount,
        issues,
      },
      error: null,
    };

    return ctx;
  },

  /**
   * Detects duplicate 4-byte selectors across selected exported facet functions.
   *
   * Uses the provided hashing adapter to compute 4-byte selectors, then groups
   * facets by selector to find collisions. Requires `ctx.state.facetScan` to
   * have been populated first.
   *
   * @param ctx - The compose context with facet scan results.
   * @param deps - Dependencies: an `IHashingAdapter` for keccak256 computation.
   * @returns The context with `ctx.state.validationSelectorCollisions` populated.
   */
  async detectSelectorCollisions(
    ctx: ComposeContext,
    { hashing, scopes }: SelectorCollisionDeps,
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

    const collisions = scopes
      ? scopes.flatMap((scope) => {
          const scopedFacets = facetScan.facets.filter((scannedFacet) =>
            scope.facets.some((facet) =>
              facet.contractName === scannedFacet.facetName &&
              matchesAstSource(scannedFacet.path, facet.sourcePath)));
          return findSelectorCollisions(scopedFacets, hashing).map((collision) => ({
            ...collision,
            diamondName: scope.diamondName,
          }));
        })
      : findSelectorCollisions(facetScan.facets, hashing);
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

  /**
   * Detects incompatible storage layouts sharing the same storage identifier.
   *
   * Groups storage layouts by slot identifier and checks whether all layouts
   * for a given slot are prefix-compatible (safe extensions). Requires
   * `ctx.state.facetScan` to have been populated first.
   *
   * @param ctx - The compose context with facet scan results.
   * @returns The context with `ctx.state.validationIdentifierCollisions` populated.
   */
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
